#import "ChristianLyricsPlugin.h"
#if __has_include(<christian_lyrics/christian_lyrics-Swift.h>)
#import <christian_lyrics/christian_lyrics-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "christian_lyrics-Swift.h"
#endif

@implementation ChristianLyricsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftChristianLyricsPlugin registerWithRegistrar:registrar];
}
@end
