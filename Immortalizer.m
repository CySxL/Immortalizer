    /*
        Copyright (C) 2024  Serge Alagon

        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program.  If not, see <https://www.gnu.org/licenses/>.
    */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Headers.h"
#import "Immortalizer.h"
#import "CustomToastView.h"

NSString *const ImmortalizerLockMark = @"🔒";

static NSString *const ImmortalBundlesKey = @"ImmortalForegroundBundleIDs";
static NSString *const LockedBundlesKey = @"LockedBundleIDs";

@interface Immortalizer ()
// Swapped wholesale rather than mutated, so readers never see a half-updated set.
@property (atomic, copy) NSSet *cachedImmortalBundles;
@property (atomic, copy) NSSet *cachedLockedBundles;
@end

@implementation Immortalizer
+ (instancetype)sharedInstance {
    static Immortalizer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

// objc_getClass locks the runtime class table, and this sits under every
// accessory refresh. Cached only once the class turns up, so an early call
// cannot pin nil.
static SBIconController *iconController(void) {
    static Class controllerClass = Nil;
    if (!controllerClass) controllerClass = objc_getClass("SBIconController");
    return (SBIconController *)[controllerClass sharedInstance];
}

static SBIconModel *iconModel(void) {
    return iconController().model;
}

static NSUserDefaults *immortalizerDefaults(void) {
    return [[NSUserDefaults alloc] initWithSuiteName:@"com.sergy.immortalizer.prefs"];
}

static NSSet *bundleSetFromArray(NSArray *stored) {
    NSMutableSet *bundles = [NSMutableSet set];
    for (id bundleIdentifier in stored) {
        if ([bundleIdentifier isKindOfClass:[NSString class]]) [bundles addObject:bundleIdentifier];
    }
    return bundles;
}

// Both lists used to live in SpringBoard's own domain, where removing the tweak
// leaves them behind. Moved across on the first read and taken out of the old
// one, so a downgrade starts from an empty list rather than a stale one.
static NSSet *storedBundles(NSString *key) {
    NSUserDefaults *prefs = immortalizerDefaults();
    NSArray *stored = [prefs arrayForKey:key];
    if (stored) return bundleSetFromArray(stored);

    NSUserDefaults *legacy = [NSUserDefaults standardUserDefaults];
    NSArray *inherited = [legacy arrayForKey:key];
    if (!inherited) return [NSSet set];

    [prefs setObject:inherited forKey:key];
    [legacy removeObjectForKey:key];
    return bundleSetFromArray(inherited);
}

-(instancetype)init {
    self = [super init];
    if (self) {
        _cachedImmortalBundles = storedBundles(ImmortalBundlesKey);
        _cachedLockedBundles = storedBundles(LockedBundlesKey);
    }
    return self;
}

-(NSString *)getAppNameForBundle:(NSString *)bundle {
    if (!bundle) return nil;
    NSString *name = [[iconModel() applicationIconForBundleIdentifier:bundle] displayName];
    if ([name hasSuffix:ImmortalizerLockMark])
        name = [name substringToIndex:name.length - ImmortalizerLockMark.length];
    return name;
}

-(void)updateAccessoryForBundle:(NSString *)bundle {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[iconModel() applicationIconForBundleIdentifier:bundle] _notifyAccessoriesDidUpdate];
    });
}

// An icon announces an accessory change but not a name change, so the label is
// rebuilt through the view that draws it. A firmware that moved either selector
// leaves the label as it was until the next respring.
-(void)updateLabelForBundle:(NSString *)bundle {
    dispatch_async(dispatch_get_main_queue(), ^{
        SBIcon *icon = [iconModel() applicationIconForBundleIdentifier:bundle];
        SBIconController *controller = iconController();
        if (!icon || ![controller respondsToSelector:@selector(homescreenIconViewMap)]) return;

        SBIconViewMap *map = controller.homescreenIconViewMap;
        if (![map respondsToSelector:@selector(mappedIconViewForIcon:)]) return;

        SBIconView *iconView = [map mappedIconViewForIcon:icon];
        if ([iconView respondsToSelector:@selector(_updateLabel)]) [iconView _updateLabel];
    });
}

-(void)showToastWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon autoHide:(int)seconds {
    CustomToastView *toast = [[CustomToastView alloc] initWithTitle:title subtitle:subtitle icon:icon autoHide:seconds];
    [toast presentToast];
}

-(void)showAlertWithMessage:(NSString *)message buttonTitle:(NSString *)buttonTitle {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (!keyWindow) keyWindow = UIApplication.sharedApplication.windows.firstObject;

        // Presenting on a controller that is already presenting does nothing.
        UIViewController *presenter = keyWindow.rootViewController;
        while (presenter.presentedViewController) presenter = presenter.presentedViewController;
        if (!presenter) return;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Immortalizer"
                                                                      message:message
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:buttonTitle style:UIAlertActionStyleDefault handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
    });
}

-(NSArray *)getNotificationEnabledApps {
    // Written by Settings, so this is read fresh rather than cached.
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.sergy.immortalizer.prefs"];
    return [prefs arrayForKey:@"selectedApplications"];
}

-(BOOL)isNotificationEnabledForBundleIdentifier:(NSString *)bundleIdentifier {
    if (!bundleIdentifier) return NO;
    return [[self getNotificationEnabledApps] containsObject:bundleIdentifier];
}

-(void)storeBundles:(NSSet *)bundles forKey:(NSString *)key {
    NSUserDefaults *prefs = immortalizerDefaults();
    [prefs setObject:bundles.allObjects forKey:key];
    [prefs synchronize];
}

-(BOOL)isImmortalized:(NSString *)bundleIdentifier {
    return bundleIdentifier && [self.cachedImmortalBundles containsObject:bundleIdentifier];
}

-(void)setImmortalized:(BOOL)immortalized forBundle:(NSString *)bundleIdentifier {
    if (!bundleIdentifier) return;
    NSMutableSet *bundles = [self.cachedImmortalBundles mutableCopy];
    if (immortalized) [bundles addObject:bundleIdentifier];
    else [bundles removeObject:bundleIdentifier];
    self.cachedImmortalBundles = bundles;
    [self storeBundles:bundles forKey:ImmortalBundlesKey];
}

-(NSArray *)immortalizedBundles {
    return self.cachedImmortalBundles.allObjects;
}

-(BOOL)isLocked:(NSString *)bundleIdentifier {
    return bundleIdentifier && [self.cachedLockedBundles containsObject:bundleIdentifier];
}

-(void)setLocked:(BOOL)locked forBundle:(NSString *)bundleIdentifier {
    if (!bundleIdentifier) return;
    NSMutableSet *bundles = [self.cachedLockedBundles mutableCopy];
    if (locked) [bundles addObject:bundleIdentifier];
    else [bundles removeObject:bundleIdentifier];
    self.cachedLockedBundles = bundles;
    [self storeBundles:bundles forKey:LockedBundlesKey];
}

-(NSArray *)lockedBundles {
    return self.cachedLockedBundles.allObjects;
}
@end
