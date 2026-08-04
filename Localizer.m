#import "Localizer.h"

static NSBundle *tweakBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bundle = [NSBundle bundleWithPath:jbroot(@"/Library/Application Support/Immortalizer.bundle")];
    });
    return bundle;
}

static NSBundle *englishBundle(void) {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bundle = [NSBundle bundleWithPath:jbroot(@"/Library/Application Support/Immortalizer.bundle/en.lproj")];
    });
    return bundle;
}

NSString *localizer(NSString *key) {
    NSBundle *bundle = tweakBundle();
    if (!bundle) return key;

    NSString *localizedString = [bundle localizedStringForKey:key value:key table:nil];

    if ([localizedString isEqualToString:key]) {
        NSString *fallback = [englishBundle() localizedStringForKey:key value:key table:nil];
        if (fallback) localizedString = fallback;
    }

    return localizedString;
}
