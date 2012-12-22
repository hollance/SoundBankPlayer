/*
 * Copyright (c) 2008-2012 Matthijs Hollemans.
 * With contributions from π.
 * Licensed under the terms of the MIT license.
 */

#import <Foundation/Foundation.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>

/*
 * How many OpenAL sources we will use. Each source plays a single buffer, so
 * this effectively determines the maximum polyphony. There is an upper limit
 * to the number of simultaneously playing sources that OpenAL supports.
 * http://stackoverflow.com/questions/2871905/openal-determine-maximum-sources
 */ 
#define NUM_SOURCES 32

/*
 * SoundBankPlayer is a sample-based audio player that uses OpenAL. It employs
 * a "sound bank", which contains a set of samples that each cover one or more
 * notes, allowing you to implement a full instrument with only a few samples.
 * It's like SoundFonts but simpler.
 *
 * The SoundBankPlayer takes care of setting up the Audio Session. You only
 * have to provide the sound samples (in CAF, M4A, or any other supported audio
 * format) and a PLIST file that describes how the samples map to MIDI notes.
 *
 * The sound samples must always be mono. SoundBankPlayer pans the notes to 
 * achieve a stereo effect.
 */
@interface SoundBankPlayer : NSObject

/*
 * For continuous tone instruments (such as an organ sound) set this to YES.
 *
 * Make sure you provide raw sound fonts that wrap nicely, i.e. try to catch a 
 * whole number of waves in the sample and clip it at the zero crossings. Even 
 * then it's hard to get perfect, so it's better to use really long samples. 
 * If you set loopNotes to YES, then you will need to call noteOff: to quiet a 
 * playing note.
 *
 * For piano notes and other sounds that naturally decay to silence, set this 
 * property to NO. You don't need to call noteOff:, the note will automatically
 * terminate itself when it has played to the end of the sample.
 */
@property (nonatomic, assign) BOOL loopNotes;

/*
 * Sets the sound bank that the sounds will be loaded from.
 *
 * @param soundBankName the name of a PLIST file from the bundle
 */
- (void)setSoundBank:(NSString *)soundBankName;

/*
 * Plays the note with the specified MIDI note number. 
 *
 * If there are no free sources found (i.e. there are more than NUM_SOURCES
 * notes playing), an existing source may be terminated to make room for the
 * new sound. The algorithm for this currently always picks the oldest source.
 *
 * @param midiNoteNumber the MIDI note number
 * @param gain An attenuation factor. If you are going to play multiple notes
 *        at the same time, then it's wise to set gain to 0.5f or lower to
 *        prevent clipping distortion.
 */
- (void)noteOn:(int)midiNoteNumber gain:(float)gain;

/*
 * To play a chord, performance will be better if you enqueue a bunch of notes
 * and then play them all simultaneously.
 */
- (void)queueNote:(int)midiNoteNumber gain:(float)gain;

/*
 * Plays the enqueued notes.
 */
- (void)playQueuedNotes;

/*
 * Stops playing a particular note. This method is really only useful when 
 * loopNotes is set to YES. Turning a note off when it is not playing is okay, 
 * it just does nothing.
 */
- (void)noteOff:(int)midiNoteNumber;

/*
 * Stops all playing notes.
 */
- (void)allNotesOff;

@end
