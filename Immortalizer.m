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

static NSSet *storedBundles(NSString *key) {
    NSMutableSet *bundles = [NSMutableSet set];
    for (id bundleIdentifier in [[NSUserDefaults standardUserDefaults] arrayForKey:key]) {
        if ([bundleIdentifier isKindOfClass:[NSString class]]) [bundles addObject:bundleIdentifier];
    }
    return bundles;
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
    return [[((SBIconController *)[objc_getClass("SBIconController") sharedInstance]).model applicationIconForBundleIdentifier:bundle] displayName];
}

-(void)updateAccessoryForBundle:(NSString *)bundle {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[((SBIconController *)[objc_getClass("SBIconController") sharedInstance]).model applicationIconForBundleIdentifier:bundle] _notifyAccessoriesDidUpdate];
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
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.sergy.immortalizer.prefs"];
    NSArray *selectedApps = [prefs objectForKey:@"selectedApplications"];
    return selectedApps;
}

-(BOOL)isNotificationEnabledForBundleIdentifier:(NSString *)bundleIdentifier {
    NSArray *selectedApps = [self getNotificationEnabledApps];
    return [selectedApps containsObject:bundleIdentifier];
}

-(void)storeBundles:(NSSet *)bundles forKey:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:bundles.allObjects forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
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

-(BOOL)hasImmortalizedApps {
    return self.cachedImmortalBundles.count > 0;
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
