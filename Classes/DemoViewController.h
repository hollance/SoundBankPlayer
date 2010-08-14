
#import "SoundBankPlayer.h"

@interface DemoViewController : UIViewController
{
	SoundBankPlayer* player;
	NSTimer* timer;
	BOOL playingArpeggio;
	NSArray* arpeggioNotes;
	int arpeggioIndex;
	double arpeggioStartTime;
	double arpeggioDelay;
}

- (IBAction)strumCMajorChord;
- (IBAction)arpeggiateCMajorChord;

- (IBAction)strumAMinorChord;
- (IBAction)arpeggiateAMinorChord;

@end
