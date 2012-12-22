
// The sounds in this demo project were taken from Fluid R3 by Frank Wen,
// a freely distributable SoundFont.

#import <QuartzCore/QuartzCore.h>
#import "DemoViewController.h"
#import "SoundBankPlayer.h"

@implementation DemoViewController
{
	SoundBankPlayer *_soundBankPlayer;
	NSTimer *_timer;
	BOOL _playingArpeggio;
	NSArray *_arpeggioNotes;
	NSUInteger _arpeggioIndex;
	CFTimeInterval _arpeggioStartTime;
	CFTimeInterval _arpeggioDelay;
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
	[self playArpeggioWithNotes:@[@48, @55, @64] delay:0.05f];
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
	[self playArpeggioWithNotes:@[@33, @45, @52, @60, @67] delay:0.1f];
}

- (void)playArpeggioWithNotes:(NSArray *)notes delay:(CFTimeInterval)delay
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
	_timer = [NSTimer scheduledTimerWithTimeInterval:0.05f  // 50 ms
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
		CFTimeInterval now = CACurrentMediaTime();
		if (now - _arpeggioStartTime >= _arpeggioDelay)
		{
			NSNumber *number = _arpeggioNotes[_arpeggioIndex];
			[_soundBankPlayer noteOn:[number intValue] gain:0.4f];

			_arpeggioIndex += 1;
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
