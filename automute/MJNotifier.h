#import <Foundation/Foundation.h>

@interface MJNotifier : NSObject

- (void)showHeadphonesDisconnectedMuteNotification;
- (void)showSleepMuteNotification;
- (void)showLockMuteNotification;

- (void)showWakeRestoreNotification;
- (void)showUnlockRestoreNotification;

@end
