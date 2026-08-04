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

#import "ImmortalizerCCMenu.h"
#import "Localizer.h"

@implementation ImmortalizerCCUIMenuModuleViewController {
    int _updateToken;
    BOOL _observing;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        __weak typeof(self) weakSelf = self;
        _observing = notify_register_dispatch("com.sergy.immortalizer.updatecc", &_updateToken, dispatch_get_main_queue(), ^(int token) {
            [weakSelf refreshSelectedState];
        }) == NOTIFY_STATUS_OK;

        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightRegular];
        self.glyphImage = [[UIImage systemImageNamed:@"hourglass.bottomhalf.fill"] imageByApplyingSymbolConfiguration:config];
        self.selectedGlyphImage = [[UIImage systemImageNamed:@"hourglass.bottomhalf.fill"] imageByApplyingSymbolConfiguration:config];
        self.selectedGlyphColor = [UIColor blueColor];
        self.title = @"Immortalizer";
    }
    return self;
}

- (void)dealloc {
    if (_observing) notify_cancel(_updateToken);
}

- (void)refreshSelectedState {
    SBApplication *frontMostApp = [(SpringBoard *)UIApplication.sharedApplication _accessibilityFrontMostApplication];
    NSUserDefaults *const prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.sergy.immortalizer.prefs"];
    BOOL immortalizerStatus = [prefs objectForKey:@"isEnabled"] ? [prefs boolForKey:@"isEnabled"] : YES;
    Immortalizer *immortalizer = [objc_getClass("Immortalizer") sharedInstance];

    [self setSelected:(immortalizerStatus && [immortalizer isImmortalized:frontMostApp.bundleIdentifier])];
}

- (void)viewWillAppear:(BOOL)animated{
	[super viewWillAppear:animated];
}

- (CGFloat)preferredExpandedContentWidth{
	return CCUIDefaultExpandedContentModuleWidth();
}
- (void)buttonTapped:(id)arg1 forEvent:(UIEvent *)event{ 
    Immortalizer *immortalizer = [objc_getClass("Immortalizer") sharedInstance];
    SBApplication *frontMostApp = [(SpringBoard *)UIApplication.sharedApplication _accessibilityFrontMostApplication];
    NSUserDefaults *const prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.sergy.immortalizer.prefs"];
    BOOL immortalizerStatus = [prefs objectForKey:@"isEnabled"] ? [prefs boolForKey:@"isEnabled"] : YES;
    BOOL isToastEnabled = [prefs objectForKey:@"isToastEnabled"] ? [prefs boolForKey:@"isToastEnabled"] : YES;
    if (immortalizerStatus) {
        if (frontMostApp) {
            BOOL wasImmortalized = [immortalizer isImmortalized:frontMostApp.bundleIdentifier];
            [immortalizer setImmortalized:!wasImmortalized forBundle:frontMostApp.bundleIdentifier];
            if (isToastEnabled)
                [immortalizer showToastWithTitle:frontMostApp.displayName
                                        subtitle:localizer(wasImmortalized ? @"AT_REST" : @"IMMORTALIZED")
                                            icon:[UIImage systemImageNamed:(wasImmortalized ? @"arrow.uturn.left.circle.fill" : @"hourglass.bottomhalf.fill")]
                                        autoHide:3.0];
            [immortalizer updateAccessoryForBundle:frontMostApp.bundleIdentifier];
            [self setSelected:!wasImmortalized];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Immortalizer"
                                                                                        message:localizer(@"IMMORTALIZER_CC_TOGGLE_FOOTER")
                                                                                preferredStyle:UIAlertControllerStyleAlert];

                [alertController addAction:[UIAlertAction actionWithTitle:localizer(@"OOOPS")
                                                                    style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
                }]];
                
                    UIWindow *keyWindow = nil;
                    for (UIWindow *window in UIApplication.sharedApplication.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                    if (!keyWindow) keyWindow = UIApplication.sharedApplication.windows.firstObject;
                    UIViewController *rootViewController = keyWindow.rootViewController;
                    [rootViewController presentViewController:alertController animated:YES completion:nil];
            });
        }
    } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Immortalizer"
                                                                                        message:localizer(@"IMMORTALIZER_CC_ON_FOOTER")
                                                                                preferredStyle:UIAlertControllerStyleAlert];

                [alertController addAction:[UIAlertAction actionWithTitle:localizer(@"OKAY")
                                                                    style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * _Nonnull action) {
                }]];
                
                    UIWindow *keyWindow = nil;
                    for (UIWindow *window in UIApplication.sharedApplication.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                    if (!keyWindow) keyWindow = UIApplication.sharedApplication.windows.firstObject;
                    UIViewController *rootViewController = keyWindow.rootViewController;
                    [rootViewController presentViewController:alertController animated:YES completion:nil];
            });
    }
}

- (BOOL)_canShowWhileLocked{
	return YES;
}

- (void)populateActions {
    Immortalizer *immortalizer = [objc_getClass("Immortalizer") sharedInstance];
    SBApplication *frontMostApp = [(SpringBoard *)UIApplication.sharedApplication _accessibilityFrontMostApplication];
    NSString *frontMostBundleID = frontMostApp.bundleIdentifier;
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.sergy.immortalizer.prefs"];
    __block BOOL isToastEnabled = [prefs objectForKey:@"isToastEnabled"] ? [prefs boolForKey:@"isToastEnabled"] : YES;
    __block BOOL immortalizerStatus = [prefs objectForKey:@"isEnabled"] ? [prefs boolForKey:@"isEnabled"] : YES;
    BOOL isFrontAppImmortalized = [immortalizer isImmortalized:frontMostBundleID];
    BOOL isFrontAppLocked = [immortalizer isLocked:frontMostBundleID];
    BOOL isFrontAppNotifEnabled = [immortalizer isNotificationEnabledForBundleIdentifier:frontMostBundleID];
    __weak typeof(self) weakSelf = self;

    if (frontMostApp && immortalizerStatus) {
        [self addActionWithTitle:(isFrontAppImmortalized ? localizer(@"DISABLE_IMMORTAL_FOREGROUND") : localizer(@"ENABLE_IMMORTAL_FOREGROUND")) subtitle:[NSString stringWithFormat:(localizer(@"FOR_APPS")),  frontMostApp.displayName] glyph:[UIImage systemImageNamed:@"hourglass.bottomhalf.fill"] handler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                // The state may have moved on since the menu was built.
                BOOL wasImmortalized = [immortalizer isImmortalized:frontMostBundleID];
                [immortalizer setImmortalized:!wasImmortalized forBundle:frontMostBundleID];
                if (isToastEnabled)
                    [immortalizer showToastWithTitle:frontMostApp.displayName
                                            subtitle:localizer(wasImmortalized ? @"AT_REST" : @"IMMORTALIZED")
                                                icon:[UIImage systemImageNamed:(wasImmortalized ? @"arrow.uturn.left.circle.fill" : @"hourglass.bottomhalf.fill")]
                                            autoHide:3.0];
                [immortalizer updateAccessoryForBundle:frontMostBundleID];
                [weakSelf setSelected:!wasImmortalized];
            });
        }];

        [self addActionWithTitle:[NSString stringWithFormat:(isFrontAppLocked ? localizer(@"UNLOCK") : localizer(@"LOCK")), frontMostApp.displayName] subtitle:(isFrontAppLocked ? localizer(@"SWITCHER_CLOSE_FOOTER")  : localizer(@"SWITCHER_LOCK_FOOTER") ) glyph:[UIImage systemImageNamed:(isFrontAppLocked ? @"lock.open.fill" : @"lock.fill")] handler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL wasLocked = [immortalizer isLocked:frontMostBundleID];
                [immortalizer setLocked:!wasLocked forBundle:frontMostBundleID];
                if (isToastEnabled)
                    [immortalizer showToastWithTitle:frontMostApp.displayName
                                            subtitle:localizer(wasLocked ? @"RELEASED" : @"JAILEDE")
                                                icon:[UIImage systemImageNamed:(wasLocked ? @"lock.open.fill" : @"lock.fill")]
                                            autoHide:3.0];
                [immortalizer updateAccessoryForBundle:frontMostBundleID];
            });
        }];


        [self addActionWithTitle:[NSString stringWithFormat:(isFrontAppNotifEnabled ? localizer(@"DISABLE_NOTIFICATION") : localizer(@"ENABLE_NOTIFICATION")), frontMostApp.displayName] subtitle:(isFrontAppNotifEnabled ? localizer(@"DISABLE_NOTIFICATION_FOOTER") : localizer(@"ENABLE_NOTIFICATION_FOOTER")) glyph:[UIImage systemImageNamed:(isFrontAppNotifEnabled ? @"bell.slash.fill" : @"bell.fill")] handler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableArray *enabledAppNotifsList = [[immortalizer getNotificationEnabledApps] mutableCopy];
                if (!enabledAppNotifsList) enabledAppNotifsList = [NSMutableArray array];
                BOOL wasNotifEnabled = [enabledAppNotifsList containsObject:frontMostBundleID];

                if (wasNotifEnabled) [enabledAppNotifsList removeObject:frontMostBundleID];
                else [enabledAppNotifsList addObject:frontMostBundleID];

                if (isToastEnabled)
                    [immortalizer showToastWithTitle:frontMostApp.displayName
                                            subtitle:localizer(wasNotifEnabled ? @"DISABLE" : @"ENABLE")
                                                icon:[UIImage systemImageNamed:(wasNotifEnabled ? @"bell.slash.fill" : @"bell.fill")]
                                            autoHide:3.0];

                [prefs setObject:enabledAppNotifsList forKey:@"selectedApplications"];
                [prefs synchronize];
                notify_post("com.sergy.immortalizer.preferenceschanged.notifs");
            });
        }];   
    }

    if (immortalizerStatus && !frontMostApp)
        [self addActionWithTitle:localizer(@"NO_APP_OPEN")  subtitle:localizer(@"OPEN_APP_IMMORTALIZE")  glyph:[UIImage systemImageNamed:@"questionmark.circle.fill"] handler:^{}];

    [self addActionWithTitle:(immortalizerStatus ? localizer(@"DISABLE_TWEAK")  : localizer(@"ENABLE_TWEAK") ) subtitle:(immortalizerStatus ? localizer(@"DISABLE_FOOTER")  : localizer(@"ENABLE_FOOTER"))  glyph:[UIImage systemImageNamed:@"hammer.fill"] handler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL newStatus = !immortalizerStatus;
            [prefs setBool:newStatus forKey:@"isEnabled"];
            [prefs synchronize];
            notify_post("com.sergy.immortalizer.preferenceschanged");
        });

    }];
    [self addActionWithTitle:localizer(@"IMMORTALIZER_SETTINGS")  subtitle:localizer(@"IMMORTALIZER_SETTINGS_FOOTER") glyph:[UIImage systemImageNamed:@"gear"] handler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *url = [NSURL URLWithString:@"prefs:root=Immortalizer"];
            [[UIApplication sharedApplication] _openURL:url];
        });
    }];

}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	
	[coordinator animateAlongsideTransition:^(id <UIViewControllerTransitionCoordinatorContext>context)
	{
		[self.view setNeedsLayout];
		[self.view layoutIfNeeded];
	} completion:nil];
}

-(BOOL)shouldBeginTransitionToExpandedContentModule{
    [self populateActions];
    return true;
}
@end
