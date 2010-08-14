
#import "DemoAppDelegate.h"
#import "DemoViewController.h"

@implementation DemoAppDelegate

@synthesize window;
@synthesize viewController;

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
	[window addSubview:viewController.view];
	[window makeKeyAndVisible];
	return YES;
}

- (void)dealloc
{
	[viewController release];
	[window release];
	[super dealloc];
}

@end
