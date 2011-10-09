
#import <AudioToolbox/AudioToolbox.h>
#import "SoundBankPlayer.h"
#import "OpenALSupport.h"

@interface SoundBankPlayer ()
- (void)initNotes;
- (void)loadSoundBank:(NSString*)filename;
- (void)setUpAudio;
- (void)tearDownAudio;
- (void)setUpAudioSession;
- (void)tearDownAudioSession;
- (void)audioSessionBeginInterruption;
- (void)audioSessionEndInterruption;
- (void)setUpOpenAL;
- (void)tearDownOpenAL;
- (void)initBuffers;
- (void)freeBuffers;
- (void)initSources;
- (void)freeSources;
@end

@implementation SoundBankPlayer

@synthesize loopNotes;

- (id)init
{
	if ((self = [super init]))
	{
		initialized = NO;
		soundBankName = @"";
		loopNotes = NO;
		[self initNotes];
		[self setUpAudioSession];
	}

	return self;
}

- (void)dealloc
{
	[self tearDownAudio];
	[self tearDownAudioSession];
	[soundBankName release];
	[super dealloc];
}

- (void)setSoundBank:(NSString*)theSoundBankName
{
	if (![theSoundBankName isEqualToString:soundBankName])
	{
		[soundBankName release];
		soundBankName = [theSoundBankName copy];

		[self tearDownAudio];
		[self loadSoundBank:soundBankName];
		[self setUpAudio];
	}
}

- (void)setUpAudio
{
	if (!initialized)
	{
		[self setUpOpenAL];
		[self initBuffers];
		[self initSources];
		initialized = YES;
	}
}

- (void)tearDownAudio
{
	if (initialized)
	{
		[self freeSources];
		[self freeBuffers];
		[self tearDownOpenAL];
		initialized = NO;
	}
}

- (void)initNotes
{
	// Initialize note pitches using equal temperament (12-TET)
	for (int t = 0; t < NUM_NOTES; ++t)
	{
		notes[t].pitch = 440.0f * pow(2, (t - 69)/12.0);  // A4 = MIDI key 69
		notes[t].bufferIndex = -1;
		notes[t].panning = 0.0f;
	}

	// Panning ranges between C3 (-50%) to G5 (+50%)
	for (int t = 0; t < 48; ++t)
		notes[t].panning = -50.0f;
	for (int t = 48; t < 80; ++t)
		notes[t].panning = ((((t - 48.0f) / (79 - 48)) * 200.0f) - 100.f) / 2.0f;
	for (int t = 80; t < 128; ++t)
		notes[t].panning = 50.0f;
}

- (void)loadSoundBank:(NSString*)filename
{
	NSString* path = [[NSBundle mainBundle] pathForResource:filename ofType:@"plist"];
	NSArray* array = [NSArray arrayWithContentsOfFile:path];
	if (array == nil)
	{
		NSLog(@"Could not load soundbank '%@'", path);
		return;
	}

	sampleRate = [(NSString*)[array objectAtIndex:0] intValue];

	numBuffers = (array.count - 1) / 3;
	if (numBuffers > MAX_BUFFERS)
		numBuffers = MAX_BUFFERS;

	int midiStart = 0;
	for (int t = 0; t < numBuffers; ++t)
	{
		buffers[t].filename = [array objectAtIndex:1 + t*3];
		int midiEnd = [(NSString*)[array objectAtIndex:1 + t*3 + 1] intValue];
		int rootKey = [(NSString*)[array objectAtIndex:1 + t*3 + 2] intValue];
		buffers[t].pitch = notes[rootKey].pitch;

		if (t == numBuffers - 1)
			midiEnd = 127;

		for (int n = midiStart; n <= midiEnd; ++n)
			notes[n].bufferIndex = t;

		midiStart = midiEnd + 1;
	}
}

#pragma mark -
#pragma mark Audio Session

static void interruptionListener(void* inClientData, UInt32 inInterruptionState)
{
	SoundBankPlayer* player = (SoundBankPlayer*)inClientData;
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
	AudioSessionInitialize(NULL, NULL, interruptionListener, self);
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
	alcSuspendContext(context);
}

- (void)audioSessionEndInterruption
{
	[self registerAudioSessionCategory];  // re-register the category
	AudioSessionSetActive(true);

	alGetError();  // clear any errors
	alcMakeContextCurrent(context);
	alcProcessContext(context);
}

#pragma mark -
#pragma mark OpenAL

- (void)setUpOpenAL
{
	if ((device = alcOpenDevice(NULL)) != NULL)
	{
		// Set the mixer rate to the same rate as our sound samples.
		// Must be done before creating the context.
		alcMacOSXMixerOutputRateProc(sampleRate);

		if ((context = alcCreateContext(device, NULL)) != NULL)
		{
			alcMakeContextCurrent(context);
		}
	}
}

- (void)tearDownOpenAL
{
	alcMakeContextCurrent(NULL);
	alcDestroyContext(context);
	alcCloseDevice(device);
}

- (void)initBuffers
{
	for (int t = 0; t < numBuffers; ++t)
	{
		alGetError();  // clear any errors

		alGenBuffers(1, &buffers[t].bufferId);
		ALenum error;
		if ((error = alGetError()) != AL_NO_ERROR)
		{
			NSLog(@"Error generating OpenAL buffer: %x", error);
			exit(1);
		}

		NSString* path = [[NSBundle mainBundle] pathForResource:buffers[t].filename ofType:@"caf"];
		CFURLRef fileURL = (CFURLRef)[[NSURL fileURLWithPath:path] retain];
		if (fileURL == NULL)
		{
			NSLog(@"Could not find file '%@'", path);
			exit(1);
		}

		ALenum format;
		ALsizei size;
		ALsizei freq;
		buffers[t].data = GetOpenALAudioData(fileURL, &size, &format, &freq);
		CFRelease(fileURL);

		if (buffers[t].data == NULL)
		{
			NSLog(@"Error loading sound");
			exit(1);
		}

		alBufferDataStaticProc(buffers[t].bufferId, format, buffers[t].data, size, freq);

		if ((error = alGetError()) != AL_NO_ERROR)
		{
			NSLog(@"Error attaching audio to buffer: %x", error);
			exit(1);
		}
	}
}

- (void)freeBuffers
{
	for (int t = 0; t < numBuffers; ++t)
	{
		alDeleteBuffers(1, &buffers[t].bufferId);
		free(buffers[t].data);
		buffers[t].bufferId = 0;
		buffers[t].data = NULL;
	}
}

- (void)initSources
{
	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		alGetError();  // clear any errors

		alGenSources(1, &sources[t].sourceId);
		ALenum error;
		if ((error = alGetError()) != AL_NO_ERROR) 
		{
			NSLog(@"Error generating OpenAL source: %x", error);
			exit(1);
		}

		sources[t].noteIndex = -1;
		sources[t].queued = NO;
	}
}

- (void)freeSources
{
	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		alSourceStop(sources[t].sourceId);
		alSourcei(sources[t].sourceId, AL_BUFFER, AL_NONE);
		alDeleteSources(1, &sources[t].sourceId);
	}
}

#pragma mark -
#pragma mark Playing Sounds

- (int)findAvailableSource
{
	alGetError();  // clear any errors

	// Find a source that is no longer playing and not currently queued.
	int oldest = 0;
	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		ALint sourceState;
		alGetSourcei(sources[t].sourceId, AL_SOURCE_STATE, & sourceState);
		if (sourceState != AL_PLAYING && !sources[t].queued)
			return t;

		if (sources[t].time < sources[oldest].time)
			oldest = t;
	}

	// If no free source was found, then forcibly use the oldest.
	alSourceStop(sources[oldest].sourceId);
	return oldest;
}

- (void)noteOn:(int)midiNoteNumber gain:(float)gain
{
	[self queueNote:midiNoteNumber gain:gain];
	[self playQueuedNotes];
}

- (void)queueNote:(int)midiNoteNumber gain:(float)gain;
{
	if (!initialized)
	{
		NSLog(@"SoundBankPlayer is not initialized yet");
		return;
	}

	Note* note = notes + midiNoteNumber;
	if (note->bufferIndex != -1)
	{
		int sourceIndex = [self findAvailableSource];
		if (sourceIndex != -1)
		{
			alGetError();  // clear any errors

			Buffer* buffer = buffers + note->bufferIndex;
			Source* source = sources + sourceIndex;

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
		if (sources[t].queued)
		{
			queuedSources[count++] = sources[t].sourceId;
			sources[t].queued = NO;
		}
	}

	alSourcePlayv(count, queuedSources);

	ALenum error = alGetError();
	if (error != AL_NO_ERROR)
		NSLog(@"Error starting source: %x", error);
}

- (void)noteOff:(int)midiNoteNumber
{
	if (!initialized)
	{
		NSLog(@"SoundBankPlayer is not initialized yet");
		return;
	}

	alGetError();  // clear any errors

	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		if (sources[t].noteIndex == midiNoteNumber)
		{
			alSourceStop(sources[t].sourceId);

			ALenum error = alGetError();
			if (error != AL_NO_ERROR)
				NSLog(@"Error stopping source: %x", error);
		}
	}
}

- (void)allNotesOff
{
	if (!initialized)
	{
		NSLog(@"SoundBankPlayer is not initialized yet");
		return;
	}

	alGetError();  // clear any errors

	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		alSourceStop(sources[t].sourceId);

		ALenum error = alGetError();
		if (error != AL_NO_ERROR)
			NSLog(@"Error stopping source: %x", error);
	}
}

@end
