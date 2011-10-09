
// The sounds in this demo project were taken from Fluid R3 by Frank Wen,
// a freely distributable SoundFont.

#import <QuartzCore/CABase.h>
#import "DemoViewController.h"

@interface DemoViewController ()
- (void)playArpeggioWithNotes:(NSArray*)notes delay:(double)delay;
- (void)startTimer;
- (void)stopTimer;
@end

@implementation DemoViewController

- (id)initWithCoder:(NSCoder*)decoder
{
	if ((self = [super initWithCoder:decoder]))
	{
		playingArpeggio = NO;

		// Create the player and tell it which sound bank to use.
		player = [[SoundBankPlayer alloc] init];
		[player setSoundBank:@"Piano"];

		// We use a timer to play arpeggios.
		[self startTimer];
	}
	return self;
}

- (void)dealloc
{
	[self stopTimer];
	[player release];

	[super dealloc];
}

- (IBAction)strumCMajorChord
{
	[player queueNote:48 gain:0.4f];
	[player queueNote:55 gain:0.4f];
	[player queueNote:64 gain:0.4f];
	[player playQueuedNotes];
}

- (IBAction)arpeggiateCMajorChord
{
	NSArray* notes = [NSArray arrayWithObjects:
			[NSNumber numberWithInt:48],
			[NSNumber numberWithInt:55],
			[NSNumber numberWithInt:64],
			nil];

	[self playArpeggioWithNotes:notes delay:0.05];
}

- (IBAction)strumAMinorChord
{
	[player queueNote:45 gain:0.4f];
	[player queueNote:52 gain:0.4f];
	[player queueNote:60 gain:0.4f];
	[player queueNote:67 gain:0.4f];
	[player playQueuedNotes];
}

- (IBAction)arpeggiateAMinorChord
{
	NSArray* notes = [NSArray arrayWithObjects:
			[NSNumber numberWithInt:33],
			[NSNumber numberWithInt:45],
			[NSNumber numberWithInt:52],
			[NSNumber numberWithInt:60],
			[NSNumber numberWithInt:67],
			nil];

	[self playArpeggioWithNotes:notes delay:0.1];
}

- (void)playArpeggioWithNotes:(NSArray*)notes delay:(double)delay
{
	if (!playingArpeggio)
	{
		playingArpeggio = YES;
		arpeggioNotes = [notes retain];
		arpeggioIndex = 0;
		arpeggioDelay = delay;
		arpeggioStartTime = CACurrentMediaTime();
	}
}

- (void)startTimer
{
	timer = [NSTimer scheduledTimerWithTimeInterval: 0.05  // 50 ms
											 target: self
										   selector: @selector(handleTimer:)
										   userInfo: nil
											repeats: YES];
}

- (void)stopTimer
{
	if (timer != nil && [timer isValid])
	{
		[timer invalidate];
		timer = nil;
	}
}

- (void)handleTimer:(NSTimer*)timer
{
	if (playingArpeggio)
	{
		// Play each note of the arpeggio after "arpeggioDelay" seconds.
		double now = CACurrentMediaTime();
		if (now - arpeggioStartTime >= arpeggioDelay)
		{
			NSNumber* number = (NSNumber*)[arpeggioNotes objectAtIndex:arpeggioIndex];
			[player noteOn:[number intValue] gain:0.4f];

			++arpeggioIndex;
			if (arpeggioIndex == [arpeggioNotes count])
			{
				playingArpeggio = NO;
				[arpeggioNotes release];
				arpeggioNotes = nil;
			}
			else  // schedule next note
			{
				arpeggioStartTime = now;
			}
		}
	}
}

@end
