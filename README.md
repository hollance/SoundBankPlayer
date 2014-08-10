# SoundBankPlayer: Using OpenAL to Play Musical Instruments in Your iOS App

This is a sample-based audio player for iOS that uses OpenAL. A "sound bank" can have multiple samples, each covering one or more notes. This allows you to implement a full instrument with only a few samples. It's like SoundFonts but simpler.

The sounds in this demo project were taken from Fluid R3 by Frank Wen, a freely distributable SoundFont.

SoundBankPlayer is open source under the terms of the MIT license.

## Why do you need this?

Suppose you want your iPhone or iPad app to play all the notes from a certain instrument, such as a piano. There are 88 unique notes on a piano so you could sample each note of a real piano and put those 88 sound samples in your app. That's exactly what some iPhone piano apps do; you can see this for yourself when you examine their application bundles.

For many apps, sampling every note that an instrument can produce is overkill and it will make the application bundle unnecessarily large, especially if you have more than one instrument.

One solution to this problem is the use of SoundFonts. The [SoundFont format](http://en.wikipedia.org/wiki/SoundFont) was originally created by Creative Labs for the Sound Blaster range of sound cards. Instead of requiring a unique sample for each note, the SoundFont allows a single sample to play a range of notes. Now it's possible to create a realistic piano sound with 8 samples instead of 88.

### SoundFonts simplified

For my app [Reverse Chord Finder](http://www.reversechord.com), I needed a way to play notes from multiple instruments without making the app's download much larger. I found some good piano and guitar SoundFont files but I did not want to write a complete SoundFont implementation. Instead, I wrote a simple class, **SoundBankPlayer**, that works in a similar fashion but does not have all the features of a full SoundFont player.

SoundBankPlayer doesn't read actual SoundFont files but “sound banks”, which are simply PLIST files that describe which notes should be played by which sound samples. This makes it very easy to create new sound banks.

In this article I will explain how to use SoundBankPlayer and how it works internally. I will touch briefly on OpenAL because that is what SoundBankPlayer uses to play back the sounds.

### Pitch shifting

Why use OpenAL? I primarily chose to use OpenAL because it has pitch shifting built in and I did not want to write my own pitch shifting algorithm. Pitch shifting is necessary to make one sample cover multiple notes.

An audio recording of a piano key being pressed down (or a guitar string being strummed, etc) obviously only corresponds to the single note that is being played. When we want to use that waveform to play other notes as well, we have to change its frequency up or down a little. It is not entirely proper to do this but it works well for neighboring notes because the difference is very small here.

Pitch shifting works less well for notes that are further away; there the distortion becomes much more obvious. That's why a single sound sample for the entire instrument won't suffice. We don't need 88 samples to cover an entire piano, but we do need more than 1.

Fun fact: If you open up a SoundFont file in a SoundFont editor, you'll often see that the low and high octaves have just one or two samples but the mid-range octaves have many, often one sample for each two or three notes. The more likely a note will be played, the better it needs to sound!

The disadvantage to using OpenAL is that it only supports mono sounds. OpenAL is really intended for positional 3D audio in games. It's possible to create stereo sound by playing two sounds simultaneously, one in the left speaker and one in the right, but SoundBankPlayer does not go that far. Instead, it pans the sounds based on their octave: lower sounds more to the left, higher sounds more to the right.

### The demo project

The [demo app](https://github.com/hollance/SoundBankPlayer/tree/master/Demo) is not much to look at but in this particular project it is the audio that counts, not the visuals. There are four buttons, two that play straight chords (C major and A minor) and two that play the chords arpeggiated.

As you can tell from **DemoViewController.m**, using SoundBankPlayer is very simple. You instantiate the object and tell it to load a sound bank:

```objc    
- (id)init
{
    if ((self = [super init]))
    {
        ...

        _soundBankPlayer = [[SoundBankPlayer alloc] init];
        [_soundBankPlayer setSoundBank:@"Piano"];

        ...
    }
    return self;
}
```

Apps that play or record audio should set up an audio session that tells iOS what kind of audio the app will use and how it should be mixed with music from the iPod. SoundBankPlayer takes care of this behind the scenes so you don't have to worry about that.

Once the SoundBankPlayer is initialized, you can play a single note with:

```objc    
[_soundBankPlayer noteOn:48 gain:1.0f];
```

This will play the note C3, which is MIDI note number 48. SoundBankPlayer does not use MIDI of any kind but I find it convenient to refer to notes as MIDI note numbers. There are 128 MIDI notes in total. The notes 21 to 108 corresponds to the range of a piano (A0 to C8). Here is a [chart of MIDI note numbers](http://www.phys.unsw.edu.au/jw/notes.html).

To strum an entire chord you would do:

```objc    
- (IBAction)strumCMajorChord
{
    [_soundBankPlayer queueNote:48 gain:0.4f];
    [_soundBankPlayer queueNote:55 gain:0.4f];
    [_soundBankPlayer queueNote:64 gain:0.4f];
    [_soundBankPlayer playQueuedNotes];
}
```

This tells the SoundBankPlayer that it should play three notes, C3, G3 and E4, but it does not start them until `-playQueuedNotes` is called.

You can also play a chord by calling `-noteOn:gain:` three times in a row, but using the queued version gives better performance.

The "gain" parameter is typically used to attenuate the sound. When you play more than one note at once, the sound may become too loud for the speakers, which results in unpleasant clipping. You can lower the gain to prevent this from happening.

DemoViewController can also play arpeggiated chords. It does this with an NSTimer. If an arpeggio is scheduled to play, the timer calls `-noteOn:gain:` on each note of the chord in succession when it is fired.

### Converting audio files

The demo project comes with a single instrument, a great-sounding piano from Frank Wen's Fluid R3, a freely distributable SoundFont. Fluid R3's homepage seems to no longer exist, but you can [download Fluid from HammerSound](http://www.hammersound.net/cgi-bin/soundlink.pl?action=view_category&category=Collections&ListStart=15&ListLength=15).

Because SoundBankPlayer does not load SoundFonts directly, I had to extract the piano samples from the Fluid R3 SoundFont by hand and save them in the format that SoundBankPlayer expects.

I used [Viena](http://www.synthfont.com/#Viena), a free SoundFont editor for Windows to extract the audio files from the SoundFont, and [Audacity](http://audacity.sourceforge.net/) to trim them to about one second in length and fade them out.

Then I converted the WAV files to CAF using the Mac OS X Terminal:
    
    /usr/bin/afconvert -f caff -d LEI16 "P200 Piano D2.wav"

This converts the WAV file to a 16-bit little-endian CAF file and saves it as "P200 Piano D2.caf". The iPhone can play WAV files just fine but CAF is its native format, so I prefer to use that. The sample rate for the piano waveforms is 32000 Hz.

### The sound bank format

A sound bank consists of one or more sound samples (in CAF format) and a PLIST that describes how these samples map to the full range of MIDI notes. There are 128 possible MIDI notes and we must assign a sample to each of them. Fortunately, we don't have to spell out each note separately.

The sound bank in the demo project is named “Piano.list”. Here is an excerpt:

    <plist version="1.0">
    <array>
    <string>32000</string>
    <string>P200 Piano D2</string>
    <string>26</string>
    <string>26</string>
    <string>P200 Piano F#2</string>
    <string>30</string>
    <string>30</string>
    <string>P200 Piano A#2</string>
    <string>34</string>
    <string>34</string>
    ...

As you can see, the file format is very simple: a big array that consists of strings. The very first string contains the sample rate in Hz. Different sound banks can have different sample rates but all the samples in one sound bank are expected to have the same sample rate. SoundBankPlayer uses this to set the overall sample rate of the OpenAL mixer.

Following the sample rate are the samples and their note ranges. For each sample there are three fields. The first field contains the name of the audio waveform (without file extension). The second field is the last MIDI note in the range of notes for this sample.

In the excerpt above, the “P200 Piano D2” sample's last MIDI note is 26, which means it covers the range of notes 0 to 26. The “P200 Piano F#2” sample covers the range 27-30, and so on.

The third field for each sample is the root note. This is the note that corresponds to the natural pitch of the recording in the audio waveform. The “P200 Piano D2” sample's root note is MIDI note 26, which corresponds to a D1 in the [chart](http://www.phys.unsw.edu.au/jw/notes.html) I mentioned earlier. People aren't always consisted in their octave numbering but trust me, it's the same note. ;-)

It is important to set the root note correctly, otherwise the pitch shifting calculations will be wrong. D1 has a pitch frequency of 36.708 Hz. Suppose you want to play MIDI note 24, or C1, which has a frequency of 32.703 Hz. OpenAL now has to play the “P200 Piano D2” waveform at C1's pitch.

We don't specify an absolute pitch to OpenAL but a multiplier, which for this example is: 32.703 / 36.708 = 0.891. If we had the root note wrong for the "P200 Piano D2" waveform, then the multiplier would be wrong and any of the notes that are played using this sample would sound "off".

### How the code works

The source code of SoundBankPlayer is fairly well documented, but I'd like to explain how some of it works from the conceptual level.

OpenAL uses _buffers_ and _sources_. A buffer represents an audio waveform and we have one buffer for each sample in our sound bank. A source is a sound that is currently playing. Each source plays a single buffer. There is a limit to how many sources can be playing at any given time that depends on the OpenAL implementation. The iPhone has a maximum of 32 simultaneous sources.

#### Buffers

In **SoundBankPlayer.m** I have defined a struct that holds information about a buffer:

```objc
typedef struct
{
    float pitch;
    CFStringRef filename;
    ALuint bufferId;
    void* data;
}
Buffer;
```

The “filename” field contains the name of the sound sample file. The “pitch” field stores the pitch of the note that is played by the sound sample file. This pitch value is derived from the “root note” field in the PLIST file and is the basis for the pitch shifting calculations that will occur when this buffer is played.

The “data” field stores the sample data for the buffer, i.e. the contents of the sound sample file. All the buffers are loaded into memory at once when SoundBankPlayer initializes OpenAL. That should not be problem generally because we will have only a few sound samples. The code could be modified to delay loading of a buffer until that buffer must actually be played, but that in turn could cause a short delay before you hear the sound. So it's a trade-off between memory and responsiveness.

Finally, “bufferId” stores the OpenAL buffer “name”. When we load the sound bank, we ask OpenAL to generate a buffer. OpenAL then gives us an identifier that we can use to reference the buffer later.

#### Sources

In a similar fashion, there is a struct for our sources:

```objc
typedef struct
{
    ALuint sourceId;
    int noteIndex;
    bool queued;
    NSTimeInterval time;
}
Source;
```

A source describes a sound that is currently playing. When the SoundBankPlayer is created, it allocates the sources and stores their identifiers in the “sourceId” field but doesn't do anything with these sources yet. Only when you call `-noteOn:gain:` or `-queueNote:gain:` are the other fields filled in.

The “noteIndex” field stores the MIDI note number of the note that this source will be playing. This field is -1 if the source is not playing anything. If `-queueNote:gain:` was called to start this source then “queued” is true; if `-noteOn:gain:` was called, it is false. We need to keep track of which sources contain queued notes, so we can start them all at once from `-playQueuedNotes`.

Finally, the “time” field contains the time at which this source was assigned a note to play. This is important when you want to play a note but there are no more free sources. Even though there are 32 sources on the iPhone, you can easily run out of them if you're playing big chords or arpeggios with multiple instruments. SoundBankPlayer will then stop the oldest source, i.e. the source that has been playing the longest, and tell it to start playing the new note. For our purposes this works quite well.

#### Notes

There is also a struct for each note:

```objc
typedef struct
{
    float pitch;
    int bufferIndex;
    float panning;
}
Note;
```

SoundBankPlayer contains an array of 128 of these Note objects, each one corresponding to a note in the MIDI spectrum. Essentially, this is where we map the Buffer objects to the MIDI note numbers; the Notes array describes which buffers will be used to play which notes.

The pitches of the notes are calculated using equal temperament (also called [12-TET](http://en.wikipedia.org/wiki/Equal_temperament)):

```objc
for (int t = 0; t < NUM_NOTES; ++t)
{
    notes[t].pitch = 440.0f * pow(2, (t - 69)/12.0);  // A4 = MIDI key 69
```

The “panning” is calculated based on the octave of the note. Notes lower than C3 are panned 50% to the left, notes higher than G5 are panned 50% to the right. The rest sits somewhere between these two extremes; F4 is smack in the center.

Pitch and panning are pre-calculated once when the SoundBankPlayer is initialized and these values never change. We could calculate these on-the-fly when the note needs to be played, but doing it once up front is just as easy. The "bufferIndex" is filled in when the sound bank is loaded because you can switch sound banks during the life-time of the SoundBankPlayer.

#### Playing the Sounds

Most of the code in **SoundBankPlayer.m** is set-up and tear-down code for Audio Sessions, OpenAL, and the structures we've examined above. The bits of interest are the functions that actually play the sounds.

When you call `-noteOn:gain:`, the code simply queues the note using `-queueNote:gain:` and then immediately calls `-playQueuedNotes` in order to play that note (and everything queued up to that point).

Most of the good stuff happens in `-queueNote:gain:`. First, we look if the note in question actually has a buffer associated with it. It should, except if you did not set up the sound bank's PLIST file properly.

```objc
Note *note = notes + midiNoteNumber;
if (note->bufferIndex != -1)
{
```

Then we try to find an available source that can be used to play back this new note:

```objc
	int sourceIndex = [self findAvailableSource];
	if (sourceIndex != -1)
	{
```

If we've found a source (and we should, unless OpenAL is acting up), we can set up the source with all the data it needs to start playing:

```objc
		Buffer *buffer = _buffers + note->bufferIndex;
		Source *source = _sources + sourceIndex;

		source->time = [NSDate timeIntervalSinceReferenceDate];
		source->noteIndex = midiNoteNumber;
		source->queued = YES;
```

Note that this:

```objc
Buffer *buffer = _buffers + note->bufferIndex;
```

is the same as:

```objc
Buffer *buffer = &_buffers[note->bufferIndex];
```

It simply gets a pointer to a Buffer object. I prefer the former notation, but either one is fine.

Then we call OpenAL's `alSource()` function to configure the source. Pitch shifting is almost too easy: we simply divide the note's pitch frequency by the natural pitch from the audio waveform and we're done.

```objc
		alSourcef(source->sourceId, AL_PITCH, note->pitch/buffer->pitch);
		alSourcei(source->sourceId, AL_LOOPING, AL_FALSE);
		alSourcef(source->sourceId, AL_REFERENCE_DISTANCE, 100.0f);
		alSourcef(source->sourceId, AL_GAIN, gain);
```

Setting up the panning is similarly easy. We only use the “x”-coordinate of the source position. If you wanted 3D sound, you'd also use the other two.

```objc
		float sourcePos[] = { note->panning, 0.0f, 0.0f };
		alSourcefv(source->sourceId, AL_POSITION, sourcePos);
```

And finally we hook up the buffer to the source:

```objc
		alSourcei(source->sourceId, AL_BUFFER, AL_NONE);
		alSourcei(source->sourceId, AL_BUFFER, buffer->bufferId);
```

Note that we don't actually start the source yet. That happens in `-playQueuedNotes`.

Near the top of `-queueNote:gain:` we called the `-findAvailableSource` method. The code looks like this:

```objc
- (int)findAvailableSource
{
	alGetError();  // clear any errors
```

I did not point this out before but after every call to an OpenAL function you need to call `alGetError()` to find out if there was an error. If you don't care about the error, you should still call `alGetError()` to clear out any previous errors, otherwise you might get an old error the next time you call this function.

First, we try to find a source that is currently idle. That is, any source that is not currently playing and that is not queued to be played later:

```objc
	int oldest = 0;    
	for (int t = 0; t < NUM_SOURCES; ++t)
	{
		ALint sourceState;
		alGetSourcei(_sources[t].sourceId, AL_SOURCE_STATE, &sourceState);
		if (sourceState != AL_PLAYING && !_sources[t].queued)
			return t;

		if (_sources[t].time < _sources[oldest].time)
			oldest = t;
	}
```

On every iteration through the loop, we also keep track of the oldest source currently playing. This is needed in case we cannot find a free source. If that happens, we will force the oldest source to stop playing right now and we'll return the identifier for that source:

```objc
	alSourceStop(_sources[oldest].sourceId);
	return oldest;
}
```

The `-playQueuedNotes` function makes a list of all the sources that are queued but not currently playing. Then it calls OpenAL's `alSourcePlayv()` function to start all those sources at once.

### Limitations

A limitation of SoundBankPlayer is that you can only tell a sound to start and then it plays until completion. The piano samples in the demo project each last about a second, after which they will have fully faded out. There is currently no way to sustain the sound or to tell a sound to stop playing. These were not requirements for my project so I never bothered to put this in.

Currently you can use only one instrument at a time. It shouldn't be too hard to extend the class to load multiple sound banks but remember that you can never have more than 32 sounds playing simultaneously.

### That's It!

I have to give props here to π who made two important changes to SoundBankPlayer. He adding the queuing mechanism, which gives much better performance when playing chords (or any combination of multiple notes at the same time). He also improved the polyphony algorithm. Previously the player would always re-use source 0 but now it uses the oldest source, which makes more sense and sounds better. Thanks, π!
