
#import <AudioToolbox/AudioToolbox.h>
#import "SoundBankPlayer.h"
#import "OpenALSupport.h"

// How many Buffer objects we have. This limits the number of sound samples
// there can be in the sound bank.
#define MAX_BUFFERS 128

// How many Note objects we have. We can handle the entire MIDI range (0-127).
#define NUM_NOTES 128

// Describes a sound sample and connects it to an OpenAL buffer.
typedef struct
{
	float pitch;           // pitch of the note in the sound sample
	CFStringRef filename;  // name of the sound sample file
	ALuint bufferId;       // OpenAL buffer name
	void *data;            // the buffer sample data
}
Buffer;

// Tracks an OpenAL source.
typedef struct
{
	ALuint sourceId;      // OpenAL source name
	int noteIndex;        // which note is playing or -1 if idle
	bool queued;          // is this source queued to be played later?
	NSTimeInterval time;  // time at which this source was enqueued
}
Source;

// Describes a MIDI note and how it will be played.
typedef struct
{
	float pitch;      // pitch of the note
	int bufferIndex;  // which buffer is assigned to this note (-1 = none)
	float panning;    // < 0 is left, 0 is center, > 0 is right
}
Note;

@interface SoundBankPlayer ()
- (void)audioSessionBeginInterruption;
- (void)audioSessionEndInterruption;
@end

@implementation SoundBankPlayer
{
	BOOL _initialized;             // whether OpenAL is initialized
	int _numBuffers;               // the number of active Buffer objects
	int _sampleRate;               // the sample rate of the sound bank

	Buffer _buffers[MAX_BUFFERS];  // list of buffers, not all are active
	Source _sources[NUM_SOURCES];  // list of active sources
	Note _notes[NUM_NOTES];        // the notes indexed by MIDI note number

	ALCcontext *_context;          // OpenAL context
	ALCdevice *_device;            // OpenAL device

	NSString *_soundBankName;      // name of the current sound bank
}

- (id)init
{
	if ((self = [super init]))
	{
		_initialized = NO;
		_soundBankName = @"";
		_loopNotes = NO;
		[self initNotes];
		[self setUpAudioSession];
	}

	return self;
}

- (void)dealloc
{
	[self tearDownAudio];
	[self tearDownAudioSession];
}

- (void)setSoundBank:(NSString *)newSoundBankName
{
	if (![newSoundBankName isEqualToString:_soundBankName])
	{
		_soundBankName = [newSoundBankName copy];

		[self tearDownAudio];
		[self loadSoundBank:_soundBankName];
		[self setUpAudio];
	}
}

- (void)setUpAudio
{
	if (!_initialized)
	{
		[self setUpOpenAL];
		[self initBuffers];
		[self initSources];
		_initialized = YES;
	}
}

- (void)tearDownAudio
{
	if (_initialized)
	{
		[self freeSources];
		[self freeBuffers];
		[self tearDownOpenAL];
		_initialized = NO;
	}
}

- (void)initNotes
{
	// Initialize note pitches using equal temperament (12-TET)
	for (int t = 0; t < NUM_NOTES; ++t)
	{
		_notes[t].pitch = 440.0f * pow(2, (t - 69)/12.0);  // A4 = MIDI key 69
		_notes[t].bufferIndex = -1;
		_notes[t].panning = 0.0f;
	}

	// Panning ranges between C3 (-50%) to G5 (+50%)
	for (int t = 0; t < 48; ++t)
		_notes[t].panning = -50.0f;
	for (int t = 48; t < 80; ++t)
		_notes[t].panning = ((((t - 48.0f) / (79 - 48)) * 200.0f) - 100.f) / 2.0f;
	for (int t = 80; t < 128; ++t)
		_notes[t].panning = 50.0f;
}

- (void)loadSoundBank:(NSString *)filename
{
	NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"plist"];
	NSArray *array = [NSArray arrayWithContentsOfFile:path];
	if (array == nil)
	{
		NSLog(@"Could not load sound bank '%@'", path);
		return;
	}

	_sampleRate = [(NSString *)array[0] intValue];

	_numBuffers = (int)([array count] - 1) / 3;
	if (_numBuffers > MAX_BUFFERS)
		_numBuffers = MAX_BUFFERS;

	int midiStart = 0;
	for (int t = 0; t < _numBuffers; ++t)
	{
		_buffers[t].filename = CFBridgingRetain(array[1 + t*3]);
		int midiEnd = [(NSString *)array[1 + t*3 + 1] intValue];
		int rootKey = [(NSString *)array[1 + t*3 + 2] intValue];
		_buffers[t].pitch = _notes[rootKey].pitch;

		if (t == _numBuffers - 1)
			midiEnd = 127;

		for (int n = midiStart; n <= midiEnd; ++n)
			_notes[n].bufferIndex = t;

		midiStart = midiEnd + 1;
	}
}

#pragma mark - Audio Session

static void InterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
	SoundBankPlayer *player = (__bridge SoundBankPlayer *)inClientData;
	if (inInterruptionState == kAudioSessionBeginInterruption)
		[player audioSessionBeginInterruption];
	else if (inInterruptionState == kAudioSessionEndInterruption)
		[player audioSessionEndInterruption];
}

- (void)registerAudioSessionCategory
{
	UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
	AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
}

- (void)setUpAudioSession
{
	AudioSessionInitialize(NULL, NULL, InterruptionListener, (__bridge void *)self);
	[self registerAudioSessionCategory];
	AudioSessionSetActive(true);
}

- (void)tearDownAudioSession
{
	AudioSessionSetActive(false);
}

- (void)audioSessionBeginInterruption
{
	AudioSessionSetActive(false);

	alGetError();  // clear any errors
	alcMakeContextCurrent(NULL);
	alcSuspendContext(_context);
}

- (void)audioSessionEndInterruption
{
	[self registerAudioSessionCategory];  // re-register the category
	AudioSessionSetActive(true);

	alGetError();  // clear any errors
	alcMakeContextCurrent(_context);
	alcProcessContext(_context);
}

#pragma mark - OpenAL

- (void)setUpOpenAL
{
	if ((_device = alcOpenDevice(NULL)) != NULL)
	{
		// Set the mixer rate to the same rate as our sound samples.
		// Must be done before creating the context.
		alcMacOSXMixerOutputRateProc(_sampleRate);

		if ((_context = alcCreateContext(_device, NULL)) != NULL)
		{
			alcMakeContextCurrent(_context);
		}
	}
}

- (void)tearDownOpenAL
{
	alcMakeContextCurrent(NULL);
	alcDestroyContext(_context);
	alcCloseDevice(_device);
}

- (void)initBuffers
{
	for (int t = 0; t < _numBuffers; ++t)
	{
		alGetError();  // clear any errors

		alGenBuffers(1, &_buffers[t].bufferId);
		ALenum error;
		if ((error = alGetError()) != AL_NO_ERROR)
		{
			NSLog(@"Error generating OpenAL buffer: %x", error);
			return;
		}

		NSString *filename = (__bridge NSString *)_buffers[t].filename;
		NSURL *url = [[NSBundle mainBundle] URLForResource:filename withExtension:nil];
		if (url == nil)
		{
			NSLog(@"Could not find file '%@'", filename);
			return;
		}

		ALenum format;
		ALsizei size;
		ALsizei freq;
		_buffers[t].data = GetOpenALAudioData((__bridge CFURLRef)url, &size, &format, &freq);

		if (_buffers[t].data == NULL)
		{
			NSLog(@"Error loading sound");
			return;
		}

		alBufferDataStaticProc(_buffers[t].bufferId, format, _buffers[t].data, size, freq);

		if ((error = alGetError()) != AL_NO_ERROR)
		{
			NSLog(@"Error attaching audio to buffer: %x", error);
			return;
		}
	}
}

- (void)freeBuffers
{
	for (int t = 0; t < _numBuffers; ++t)
	{
		alDeleteBuffers(1, &_buffers[t].bufferId);
		free(_buffers[t].data);
		CFRelease(_buffers[t].filename);
		_buffers[t].bufferId = 0;
		_buffers[t].data = NULL;
	}
}

- (void)initSources
{
	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		alGetError();  // clear any errors

		alGenSources(1, &_sources[t].sourceId);
		ALenum error;
		if ((error = alGetError()) != AL_NO_ERROR) 
		{
			NSLog(@"Error generating OpenAL source: %x", error);
			return;
		}

		_sources[t].noteIndex = -1;
		_sources[t].queued = NO;
	}
}

- (void)freeSources
{
	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		alSourceStop(_sources[t].sourceId);
		alSourcei(_sources[t].sourceId, AL_BUFFER, AL_NONE);
		alDeleteSources(1, &_sources[t].sourceId);
	}
}

#pragma mark - Playing Sounds

- (int)findAvailableSource
{
	alGetError();  // clear any errors

	// Find a source that is no longer playing and not currently queued.
	int oldest = 0;
	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		ALint sourceState;
		alGetSourcei(_sources[t].sourceId, AL_SOURCE_STATE, & sourceState);
		if (sourceState != AL_PLAYING && !_sources[t].queued)
			return t;

		if (_sources[t].time < _sources[oldest].time)
			oldest = t;
	}

	// If no free source was found, then forcibly use the oldest.
	alSourceStop(_sources[oldest].sourceId);
	return oldest;
}

- (void)noteOn:(int)midiNoteNumber gain:(float)gain
{
	[self queueNote:midiNoteNumber gain:gain];
	[self playQueuedNotes];
}

- (void)queueNote:(int)midiNoteNumber gain:(float)gain
{
	if (!_initialized)
	{
		NSLog(@"SoundBankPlayer is not initialized yet");
		return;
	}

	Note *note = _notes + midiNoteNumber;
	if (note->bufferIndex != -1)
	{
		int sourceIndex = [self findAvailableSource];
		if (sourceIndex != -1)
		{
			alGetError();  // clear any errors

			Buffer *buffer = _buffers + note->bufferIndex;
			Source *source = _sources + sourceIndex;

			source->time = [NSDate timeIntervalSinceReferenceDate];
			source->noteIndex = midiNoteNumber;
			source->queued = YES;

			alSourcef(source->sourceId, AL_PITCH, note->pitch/buffer->pitch);
			alSourcei(source->sourceId, AL_LOOPING, self.loopNotes ? AL_TRUE : AL_FALSE);
			alSourcef(source->sourceId, AL_REFERENCE_DISTANCE, 100.0f);
			alSourcef(source->sourceId, AL_GAIN, gain);
		
			float sourcePos[] = { note->panning, 0.0f, 0.0f };
			alSourcefv(source->sourceId, AL_POSITION, sourcePos);

			alSourcei(source->sourceId, AL_BUFFER, AL_NONE);
			alSourcei(source->sourceId, AL_BUFFER, buffer->bufferId);

			ALenum error = alGetError();
			if (error != AL_NO_ERROR)
			{
				NSLog(@"Error attaching buffer to source: %x", error);
				return;
			}
		}
	}
}

- (void)playQueuedNotes
{
	ALuint queuedSources[NUM_SOURCES] = { 0 };
	ALsizei count = 0;

	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		if (_sources[t].queued)
		{
			queuedSources[count++] = _sources[t].sourceId;
			_sources[t].queued = NO;
		}
	}

	alSourcePlayv(count, queuedSources);

	ALenum error = alGetError();
	if (error != AL_NO_ERROR)
		NSLog(@"Error starting source: %x", error);
}

- (void)noteOff:(int)midiNoteNumber
{
	if (!_initialized)
	{
		NSLog(@"SoundBankPlayer is not initialized yet");
		return;
	}

	alGetError();  // clear any errors

	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		if (_sources[t].noteIndex == midiNoteNumber)
		{
			alSourceStop(_sources[t].sourceId);

			ALenum error = alGetError();
			if (error != AL_NO_ERROR)
				NSLog(@"Error stopping source: %x", error);
		}
	}
}

- (void)allNotesOff
{
	if (!_initialized)
	{
		NSLog(@"SoundBankPlayer is not initialized yet");
		return;
	}

	alGetError();  // clear any errors

	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		alSourceStop(_sources[t].sourceId);

		ALenum error = alGetError();
		if (error != AL_NO_ERROR)
			NSLog(@"Error stopping source: %x", error);
	}
}

@end
