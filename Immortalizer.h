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

@interface Immortalizer : NSObject
+ (instancetype)sharedInstance;
- (NSString *)getAppNameForBundle:(NSString *)bundle;
- (void)updateAccessoryForBundle:(NSString *)bundle;
- (void)showToastWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon autoHide:(int)autoHide;
- (NSArray *)getNotificationEnabledApps;
- (BOOL)isNotificationEnabledForBundleIdentifier:(NSString *)bundleIdentifier;

// Only written from inside SpringBoard, so the in-process copy is authoritative.
- (BOOL)isImmortalized:(NSString *)bundleIdentifier;
- (void)setImmortalized:(BOOL)immortalized forBundle:(NSString *)bundleIdentifier;
- (BOOL)hasImmortalizedApps;
- (NSArray *)immortalizedBundles;
- (BOOL)isLocked:(NSString *)bundleIdentifier;
- (void)setLocked:(BOOL)locked forBundle:(NSString *)bundleIdentifier;
- (NSArray *)lockedBundles;
@end
