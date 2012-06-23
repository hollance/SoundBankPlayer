
// The sounds in this demo project were taken from Fluid R3 by Frank Wen,
// a freely distributable SoundFont.

#import <QuartzCore/CABase.h>
#import "DemoViewController.h"
#import "SoundBankPlayer.h"

@implementation DemoViewController
{
	SoundBankPlayer *_soundBankPlayer;
	NSTimer *_timer;
	BOOL _playingArpeggio;
	NSArray *_arpeggioNotes;
	NSUInteger _arpeggioIndex;
	double _arpeggioStartTime;
	double _arpeggioDelay;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		_playingArpeggio = NO;

		// Create the player and tell it which sound bank to use.
		_soundBankPlayer = [[SoundBankPlayer alloc] init];
		[_soundBankPlayer setSoundBank:@"Piano"];

		// We use a timer to play arpeggios.
		[self startTimer];
	}
	return self;
}

- (void)dealloc
{
	[self stopTimer];
}

- (IBAction)strumCMajorChord
{
	[_soundBankPlayer queueNote:48 gain:0.4f];
	[_soundBankPlayer queueNote:55 gain:0.4f];
	[_soundBankPlayer queueNote:64 gain:0.4f];
	[_soundBankPlayer playQueuedNotes];
}

- (IBAction)arpeggiateCMajorChord
{
	NSArray *notes = [NSArray arrayWithObjects:
		[NSNumber numberWithInt:48],
		[NSNumber numberWithInt:55],
		[NSNumber numberWithInt:64],
		nil];

	[self playArpeggioWithNotes:notes delay:0.05];
}

- (IBAction)strumAMinorChord
{
	[_soundBankPlayer queueNote:45 gain:0.4f];
	[_soundBankPlayer queueNote:52 gain:0.4f];
	[_soundBankPlayer queueNote:60 gain:0.4f];
	[_soundBankPlayer queueNote:67 gain:0.4f];
	[_soundBankPlayer playQueuedNotes];
}

- (IBAction)arpeggiateAMinorChord
{
	NSArray *notes = [NSArray arrayWithObjects:
		[NSNumber numberWithInt:33],
		[NSNumber numberWithInt:45],
		[NSNumber numberWithInt:52],
		[NSNumber numberWithInt:60],
		[NSNumber numberWithInt:67],
		nil];

	[self playArpeggioWithNotes:notes delay:0.1];
}

- (void)playArpeggioWithNotes:(NSArray *)notes delay:(double)delay
{
	if (!_playingArpeggio)
	{
		_playingArpeggio = YES;
		_arpeggioNotes = [notes copy];
		_arpeggioIndex = 0;
		_arpeggioDelay = delay;
		_arpeggioStartTime = CACurrentMediaTime();
	}
}

- (void)startTimer
{
	_timer = [NSTimer scheduledTimerWithTimeInterval:0.05  // 50 ms
											  target:self
										    selector:@selector(handleTimer:)
										    userInfo:nil
											 repeats:YES];
}

- (void)stopTimer
{
	if (_timer != nil && [_timer isValid])
	{
		[_timer invalidate];
		_timer = nil;
	}
}

- (void)handleTimer:(NSTimer *)timer
{
	if (_playingArpeggio)
	{
		// Play each note of the arpeggio after "arpeggioDelay" seconds.
		double now = CACurrentMediaTime();
		if (now - _arpeggioStartTime >= _arpeggioDelay)
		{
			NSNumber *number = (NSNumber *)[_arpeggioNotes objectAtIndex:_arpeggioIndex];
			[_soundBankPlayer noteOn:[number intValue] gain:0.4f];

			++_arpeggioIndex;
			if (_arpeggioIndex == [_arpeggioNotes count])
			{
				_playingArpeggio = NO;
				_arpeggioNotes = nil;
			}
			else  // schedule next note
			{
				_arpeggioStartTime = now;
			}
		}
	}
}

@end
