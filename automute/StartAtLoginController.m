#import "StartAtLoginController.h"
#import <ServiceManagement/ServiceManagement.h>

@implementation StartAtLoginController

- (BOOL)startAtLogin
{
    if (@available(macOS 13.0, *)) {
        return SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
    }
    return NO;
}

- (void)setStartAtLogin:(BOOL)flag
{
    if (@available(macOS 13.0, *)) {
        NSError *error = nil;
        if (flag) {
            [SMAppService.mainAppService registerAndReturnError:&error];
        } else {
            [SMAppService.mainAppService unregisterAndReturnError:&error];
        }
        if (error) {
            NSLog(@"SMAppService %@ failed: %@", flag ? @"register" : @"unregister", error);
        }
    }
}

- (BOOL)enabled
{
    return self.startAtLogin;
}

@end
