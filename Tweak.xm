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
#import <notify.h>
#import <objc/runtime.h>
#import "Headers.h"
#import "Immortalizer.h"
#import "Localizer.h"

static BOOL immortalizerEnabled;
static BOOL isFolderTransitioning = false;
static BOOL isIndicatorEnabled;
static BOOL isToastEnabled;
static BOOL isLockIndicatorEnabled;
static BOOL isIndicatorSuppressed;

static NSData *shortcutIconData(void) {
    static NSData *data = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        data = UIImagePNGRepresentation([UIImage systemImageNamed:@"hourglass.bottomhalf.fill"]);
    });
    return data;
}

// processState is a non-nil object whenever the application object exists, so it
// only says whether the app is running once you look at the pid.
static long long accessoryTypeForBundle(NSString *bundleIdentifier) {
    SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:bundleIdentifier];
    SBApplicationProcessState *state = app.processState;

    if (!state) return 2;
    if (![state respondsToSelector:@selector(pid)]) return 4;
    return state.pid > 0 ? 4 : 2;
}

// A scene has to be configured once before it means anything to keep it in the
// foreground, and swallowing that first update is what kills an app Myrtle
// launches straight into a window.
static BOOL sceneWasConfigured(id scene) {
    static NSHashTable *scenes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        scenes = [NSHashTable weakObjectsHashTable];
    });

    @synchronized (scenes) {
        if ([scenes containsObject:scene]) return YES;
        [scenes addObject:scene];
        return NO;
    }
}

static BOOL isAppLibraryLocation(NSString *location) {
    return [location hasPrefix:@"SBIconLocationAppLibrary"];
}

static Ivar rolesToLayoutItemsIvar(void) {
    static Ivar ivar = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ivar = class_getInstanceVariable(objc_getClass("SBAppLayout"), "_rolesToLayoutItemsMap");
    });
    return ivar;
}

%group init

%hook SpringBoard
- (void)frontDisplayDidChange:(id)arg1 {
    %orig;
    notify_post("com.sergy.immortalizer.updatecc");
}
%end

%hook SBIconView
-(long long)currentLabelAccessoryType {
    // The cluster that closes an App Library pod is a folder of the apps the pod
    // had no room for, and it carries no label for an accessory to sit under.
    // SpringBoard folds a folder's contents into its own accessory, so the app
    // hook has to stand down for the whole lookup or the cluster picks the
    // indicator back up. App icons in the library keep theirs.
    if (immortalizerEnabled && isIndicatorEnabled && isAppLibraryLocation(self.location) && ![self.icon applicationBundleID]) {
        isIndicatorSuppressed = YES;
        long long accessory = %orig;
        isIndicatorSuppressed = NO;
        return accessory;
    }

    long long accessory = %orig;
    if (immortalizerEnabled && isIndicatorEnabled) {
        Immortalizer *immortalizer = [Immortalizer sharedInstance];
        SBIcon *icon = self.icon;
        NSString *bundleID = [icon applicationBundleID];
        BOOL isDocked = [self.location containsString:@"Dock"];

        if (isDocked && [immortalizer isImmortalized:bundleID])
            accessory = accessoryTypeForBundle(bundleID);

        if (!isFolderTransitioning && [icon isKindOfClass:[%c(SBFolderIcon) class]]) {
            SBFolder *folder = [(SBFolderIcon *)icon folder];

            for (SBIcon *folderedIcon in [folder icons]) {
                NSString *folderedBundleID = [folderedIcon applicationBundleID];
                if ([immortalizer isImmortalized:folderedBundleID]) {
                    accessory = accessoryTypeForBundle(folderedBundleID);
                    break;
                }
            }
        }
    }
    return accessory;
}

-(NSArray *)applicationShortcutItems {
    NSArray *orig = %orig;
    if (immortalizerEnabled) {
        NSString *bundleID = [self.icon applicationBundleID];

        if (!bundleID) return orig;

        BOOL isImmortal = [[Immortalizer sharedInstance] isImmortalized:bundleID];

        SBSApplicationShortcutItem* immortalItem = [[%c(SBSApplicationShortcutItem) alloc] init];
        if (isImmortal) {
            immortalItem.localizedTitle = localizer(@"DISABLE_IMMORTAL_FOREGROUND");
        } else {
            immortalItem.localizedTitle = localizer(@"ENABLE_IMMORTAL_FOREGROUND");
        }
        immortalItem.type = @"com.sergy.immortalizer.immortalForeground.item";
        immortalItem.icon = [[%c(SBSApplicationShortcutCustomImageIcon) alloc] initWithImageData:shortcutIconData() dataType:0 isTemplate:1];

        immortalItem.bundleIdentifierToLaunch = bundleID;

        return [orig arrayByAddingObject:immortalItem];
    } else
        return orig;
}

+(void)activateShortcut:(SBSApplicationShortcutItem*)item withBundleIdentifier:(NSString*)bundleID forIconView:(id)iconView {
    if (immortalizerEnabled && [[item type] isEqualToString:@"com.sergy.immortalizer.immortalForeground.item"]) {
        Immortalizer *immortalizer = [Immortalizer sharedInstance];
        BOOL isImmortal = [immortalizer isImmortalized:bundleID];

        if ([bundleID isEqualToString:@"com.apple.camera"] && !isImmortal) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [immortalizer showAlertWithMessage:localizer(@"CREEP_ALERT") buttonTitle:localizer(@"LMAO")];
            });
        }

        if (isImmortal) {
			SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:bundleID];
			if (app.processState != nil) [[%c(FBSSystemService) sharedService] openApplication:bundleID options:nil withResult:nil];
            if (isToastEnabled) [immortalizer showToastWithTitle:[immortalizer getAppNameForBundle:bundleID] subtitle:localizer(@"AT_REST") icon:[UIImage systemImageNamed:@"arrow.uturn.left.circle.fill"] autoHide:3.0];
        } else {
            if (isToastEnabled) [immortalizer showToastWithTitle:[immortalizer getAppNameForBundle:bundleID] subtitle:localizer(@"IMMORTALIZED") icon:[UIImage systemImageNamed:@"hourglass.bottomhalf.fill"] autoHide:3.0];
			[[%c(FBSSystemService) sharedService] openApplication:bundleID options:nil withResult:nil];
        }
            [immortalizer setImmortalized:!isImmortal forBundle:bundleID];
            [immortalizer updateAccessoryForBundle:bundleID];
    } else {
        %orig;
    }
}
%end

%hook FBScene
-(void)updateSettings:(id)arg1 withTransitionContext:(id)arg2 completion:(id)arg3{
    BOOL configured = sceneWasConfigured(self);
    FBProcess *process = self.clientProcess;
    if (configured && immortalizerEnabled && process) {
        NSString *bundleIdentifier = process.bundleIdentifier;
        Immortalizer *immortalizer = [Immortalizer sharedInstance];

        if (arg2 == nil && [immortalizer isImmortalized:bundleIdentifier]) {
            [immortalizer updateAccessoryForBundle:bundleIdentifier];
            return;
        }
    }
    %orig;
}
%end

%hook SBApplication
-(long long)labelAccessoryTypeForIcon:(id)arg1 {
    long long accessory = %orig;
    if (immortalizerEnabled && isIndicatorEnabled && !isIndicatorSuppressed) {
        if ([[Immortalizer sharedInstance] isImmortalized:self.bundleIdentifier])
            accessory = accessoryTypeForBundle(self.bundleIdentifier);
    }
    return accessory;
}

-(NSString *)displayName {
    NSString *originalName = %orig;

    if (immortalizerEnabled && isLockIndicatorEnabled && [[Immortalizer sharedInstance] isLocked:self.bundleIdentifier])
        return [originalName stringByAppendingString:@"🔒"];

    return originalName;
}

-(void)_didExitWithContext:(id)arg1 {
	%orig;
    if (immortalizerEnabled) {
        Immortalizer *immortalizer = [Immortalizer sharedInstance];
        [immortalizer updateAccessoryForBundle:self.bundleIdentifier];
        if ([immortalizer isImmortalized:self.bundleIdentifier] && isToastEnabled) {
            [immortalizer showToastWithTitle:[immortalizer getAppNameForBundle:self.bundleIdentifier] subtitle:localizer(@"TERMINATED") icon:[UIImage systemImageNamed:@"exclamationmark.triangle.fill"] autoHide:3.0];
        }
    }
}

%end

%hook SBFolderView
-(void)willTransitionAnimated:(BOOL)arg1 withSettings:(id)arg2 {
    if (immortalizerEnabled && isIndicatorEnabled) isFolderTransitioning = true;
    %orig;
}

-(void)didTransitionAnimated:(BOOL)arg1 {
    if (immortalizerEnabled && isIndicatorEnabled) {
        isFolderTransitioning = false;
        [self.folder.icon _notifyAccessoriesDidUpdate];
    }
    %orig;
}
%end

%hook UNSUserNotificationServer
-(void)willPresentNotification:(id)arg1 forBundleIdentifier:(id)arg2 withCompletionHandler:(id)arg3 {
    if (immortalizerEnabled) {
        Immortalizer *immortalizer = [Immortalizer sharedInstance];
        if ([immortalizer isNotificationEnabledForBundleIdentifier:arg2]) {
            [self _didChangeApplicationState:4 forBundleIdentifier:arg2];
        }
    }
    %orig;
}
%end

%hook UIMutableApplicationSceneSettings
-(void)setDeactivationReasons:(unsigned long long)arg1 {
    // The settings object carries no scene identity, so this cannot be per app.
    if (arg1 != 0 && immortalizerEnabled && [[Immortalizer sharedInstance] hasImmortalizedApps])
        return;
    %orig;
}

%end

%hook SBFluidSwitcherItemContainer
-(void)setKillable:(BOOL)arg1 {
    BOOL shouldTerminate = arg1;

    if (immortalizerEnabled) {
        SBAppLayout *appLayout = [self appLayout];
        NSDictionary *bundles = nil;
        Immortalizer *immortalizer = [Immortalizer sharedInstance];

        if (@available(iOS 16.0, *)) bundles = [appLayout itemsToLayoutAttributesMap];
        else if (rolesToLayoutItemsIvar()) bundles = (NSDictionary *)object_getIvar(appLayout, rolesToLayoutItemsIvar());

        if (bundles) {
            if (@available(iOS 16.0, *)) {
                for (SBDisplayItem *displayItem in bundles) {
                    if (![displayItem respondsToSelector:@selector(bundleIdentifier)]) continue;
                    if ([immortalizer isLocked:[displayItem bundleIdentifier]]) {
                        shouldTerminate = false;
                        break;
                    }
                }
            }
            else {
                SBDisplayItem *displayItem = bundles[@1];
                if ([displayItem respondsToSelector:@selector(bundleIdentifier)] && [immortalizer isLocked:[displayItem bundleIdentifier]])
                    shouldTerminate = false;
            }
        }
    }

    %orig(shouldTerminate);
}
%end

%end

static void prefsLockIndicatorChanged() {
    Immortalizer *immortalizer = [Immortalizer sharedInstance];
    NSUserDefaults *const prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.sergy.immortalizer.prefs"];
    isLockIndicatorEnabled = [prefs objectForKey:@"isLockIndicatorEnabled"] ? [prefs boolForKey:@"isLockIndicatorEnabled"] : YES;
    for (NSString *bundleIdentifier in [immortalizer lockedBundles])
        [immortalizer updateAccessoryForBundle:bundleIdentifier];
}

static void immortalizerPreferencesChanged() {
    Immortalizer *immortalizer = [Immortalizer sharedInstance];
    NSUserDefaults *const prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.sergy.immortalizer.prefs"];
    immortalizerEnabled = [prefs objectForKey:@"isEnabled"] ? [prefs boolForKey:@"isEnabled"] : YES;
        for (NSString *bundleIdentifier in [immortalizer immortalizedBundles])
            [immortalizer updateAccessoryForBundle:bundleIdentifier];
    notify_post("com.sergy.immortalizer.updatecc");
}

static void prefsNotifsChanged() {
    Immortalizer *immortalizer = [Immortalizer sharedInstance];
    for (NSString * immortalApp in [immortalizer immortalizedBundles]) {
        if ([immortalizer isNotificationEnabledForBundleIdentifier:immortalApp]) {
            [[%c(UNSUserNotificationServer) sharedInstance] _didChangeApplicationState:4 forBundleIdentifier:immortalApp];
        } else {
            [[%c(UNSUserNotificationServer) sharedInstance] _didChangeApplicationState:8 forBundleIdentifier:immortalApp];
        }
    }
}

static void prefsIndicatorChanged() {
    NSUserDefaults *const indicatorPrefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.sergy.immortalizer.prefs"];
    isIndicatorEnabled = [indicatorPrefs objectForKey:@"isIndicatorEnabled"] ? [indicatorPrefs boolForKey:@"isIndicatorEnabled"] : YES;
}

static void prefsToastChanged() {
    NSUserDefaults *const toastPrefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.sergy.immortalizer.prefs"];
    isToastEnabled = [toastPrefs objectForKey:@"isToastEnabled"] ? [toastPrefs boolForKey:@"isToastEnabled"] : YES;
}

static id observer;
static void loadAllImmortalizerPrefs() {
    observer = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *_) {
        immortalizerPreferencesChanged();
        prefsNotifsChanged();
        prefsIndicatorChanged();
        prefsToastChanged();
        prefsLockIndicatorChanged();
        [NSNotificationCenter.defaultCenter removeObserver: observer];
    }];
}

%ctor {
    %init(init);
    loadAllImmortalizerPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)immortalizerPreferencesChanged, CFSTR("com.sergy.immortalizer.preferenceschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)prefsNotifsChanged, CFSTR("com.sergy.immortalizer.preferenceschanged.notifs"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)prefsIndicatorChanged, CFSTR("com.sergy.immortalizer.preferenceschanged.indicator"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)prefsToastChanged, CFSTR("com.sergy.immortalizer.preferenceschanged.toast"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)prefsLockIndicatorChanged, CFSTR("com.sergy.immortalizer.preferenceschanged.lockindicator"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
