#import <Foundation/Foundation.h>

@interface StartAtLoginController : NSObject

@property (assign, nonatomic, readwrite) BOOL startAtLogin;
@property (assign, nonatomic, readonly) BOOL enabled;

@end
