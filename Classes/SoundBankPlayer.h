/*!
 * \file SoundBankPlayer.h
 */

#import <Foundation/Foundation.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>

/*! 
 * How many Buffer objects we have. This limits the number of sound samples
 * there can be in the sound bank.
 */
#define MAX_BUFFERS 20

/*!
 * How many OpenAL sources we will use. Each source plays a single buffer, so
 * this effectively determines the maximum polyphony. There is an upper limit
 * to the number of simultaneously playing sources that OpenAL supports.
 */ 
#define NUM_SOURCES 12

/*!
 * How many Note objects we have. We can handle the entire MIDI range (0-127).
 */
#define NUM_NOTES 128

/*!
 * Buffer describes a sound sample and connects it to an OpenAL buffer.
 */
typedef struct
{
	float pitch;         ///< pitch of the note in the sound sample
	NSString* filename;  ///< name of the sound sample file
	ALuint bufferId;     ///< OpenAL buffer name
	void* data;          ///< the buffer sample data
}
Buffer;

/*!
 * Source tracks an OpenAL source.
 */
typedef struct
{
	ALuint sourceId;  ///< OpenAL source name
	int noteIndex;    ///< which note is playing or -1 if idle
}
Source;

/*!
 * Note describes a MIDI note and how it will be played.
 */
typedef struct
{
	float pitch;      ///< pitch of the note
	int bufferIndex;  ///< which buffer is assigned to this note (-1 = none)
	float panning;    ///< < 0 is left, 0 is center, > 0 is right
}
Note;

/*!
 * SoundBankPlayer is a sample-based audio player that uses OpenAL. It employs
 * "sound banks", which contain a set of samples. Each sample covers one or 
 * more notes, which allows you to implement a full instrument with only a few 
 * samples (like SoundFonts but simpler).
 *
 * The SoundBankPlayer takes care of setting up the Audio Session. You only
 * have to provide the sound samples (in CAF format) and a PLIST file that 
 * describes how the samples map to MIDI notes.
 *
 * The sound samples must always be mono. SoundBankPlayer pans the notes to 
 * achieve a stereo effect.
 *
 * \note Because OpenAL does not work well on the simulator, SoundBankPlayer  
 * only produces sound when running on an actual device.
 */
@interface SoundBankPlayer : NSObject
{
	BOOL initialized;  ///< whether OpenAL is initialized
	int numBuffers;    ///< the number of active Buffer objects
	int sampleRate;    ///< the sample rate of the sound bank

	Buffer buffers[MAX_BUFFERS];  ///< list of buffers, not all are active
	Source sources[NUM_SOURCES];  ///< list of active sources
	Note notes[NUM_NOTES];        ///< the notes indexed by MIDI note number

	ALCcontext* context;  ///< OpenAL context
	ALCdevice* device;    ///< OpenAL device
}

/*!
 * Sets the sound bank that the sounds will be loaded from.
 *
 * @param soundBankName the name of a PLIST file from the bundle
 */
- (void)setSoundBank:(NSString*)soundBankName;

/*!
 * Plays the note with the specified MIDI note number. 
 * 
 * The sample is always played until completion; there is no corresponding 
 * noteOff method.
 *
 * If there are no free sources found (i.e. there are more than NUM_SOURCES
 * notes playing), an existing source may be terminated to make room for the
 * new sound. The algorithm for this is not particularly pretty (currently it
 * simply frees up source 0).
 *
 * @param midiNoteNumber the MIDI note number
 * @param gain An attenuation factor. If you are going to play multiple notes
 *        at the same time, then it's wise to set \a gain to 0.5f or lower to
 *        prevent clipping.
 */
- (void)noteOn:(int)midiNoteNumber gain:(float)gain;

/*!
 * Stops all playing notes.
 */
- (void)allNotesOff;

@end
