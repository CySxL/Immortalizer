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
#import "IPBRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <AltList/ATLApplicationListSubcontrollerController.h>
#import "Localizer.h"

// theos defines exactly one of these, so nothing needs wiring in the Makefile.
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#define PACKAGE_SCHEME "roothide"
#elif defined(THEOS_PACKAGE_SCHEME_ROOTLESS)
#define PACKAGE_SCHEME "rootless"
#elif defined(THEOS_PACKAGE_SCHEME_ROOTFUL)
#define PACKAGE_SCHEME "rootful"
#else
#error theos defined no package scheme
#endif

static const CGFloat kIPBIconSide = 80.0;
static const CGFloat kIPBHeaderGap = 16.0;
// The cap from the side-by-side header; the name is far narrower than the
// 254 pt beside the icon on a 14 Pro Max.
static const CGFloat kIPBNameSize = 34.0;
static const CGFloat kIPBVersionSize = 15.0;
static const CGFloat kIPBSchemeSize = 13.0;
static const CGFloat kIPBNameToVersion = 24.0;
static const CGFloat kIPBVersionToScheme = 19.0;

static UIFont *IPBHeaderNameFont(CGFloat size) {
    UIFontDescriptor *bold = [[UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleLargeTitle]
                                 fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    return [UIFont fontWithDescriptor:bold size:size];
}

// Where the name's baseline sits against the icon's middle, the block centred
// on it, so a larger name would grow upward only.
static CGFloat IPBNameBaselineOffset(CGFloat scale) {
    UIFont *reference = IPBHeaderNameFont(kIPBNameSize * scale);
    UIFont *scheme = [UIFont systemFontOfSize:kIPBSchemeSize * scale];
    CGFloat height = reference.ascender + (kIPBNameToVersion + kIPBVersionToScheme) * scale - scheme.descender;
    return reference.ascender - height / 2.0;
}

@interface IPBHeaderCell : PSTableCell
@end

@implementation IPBHeaderCell {
    UILabel *_name;
    UILabel *_version;
    UILabel *_scheme;
    UIStackView *_text;
    NSLayoutConstraint *_nameBaseline;
    CGFloat _scale;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:identifier specifier:specifier];
    if (!self) return nil;

    UIImage *artwork = [UIImage imageNamed:@"icon" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    UIImageView *icon = [[UIImageView alloc] initWithImage:artwork];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.clipsToBounds = YES;
    icon.layer.cornerCurve = kCACornerCurveContinuous;
    icon.layer.cornerRadius = kIPBIconSide * 0.225;
    [self.contentView addSubview:icon];

    _name = [[UILabel alloc] init];
    _name.text = @"Immortalizer";
    // The icon's purple, and its hourglass on a dark page where the purple
    // would not read.
    _name.textColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        if (traits.userInterfaceStyle == UIUserInterfaceStyleDark)
            return [UIColor colorWithRed:0xf3 / 255.0 green:0xe6 / 255.0 blue:0xe6 / 255.0 alpha:1.0];
        return [UIColor colorWithRed:0x38 / 255.0 green:0x04 / 255.0 blue:0x6e / 255.0 alpha:1.0];
    }];

    _version = [[UILabel alloc] init];
    _version.text = @"Version " PACKAGE_VERSION;
    _version.textColor = [UIColor systemGrayColor];

    _scheme = [[UILabel alloc] init];
    _scheme.text = @PACKAGE_SCHEME.capitalizedString;
    _scheme.textColor = [UIColor systemGrayColor];

    // Spacing is baseline to baseline, so the large name does not push the two
    // lines under it away with its own leading.
    _text = [[UIStackView alloc] initWithArrangedSubviews:@[ _name, _version, _scheme ]];
    _text.axis = UILayoutConstraintAxisVertical;
    _text.alignment = UIStackViewAlignmentLeading;
    _text.baselineRelativeArrangement = YES;
    _text.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_text];
    _nameBaseline = [_name.firstBaselineAnchor constraintEqualToAnchor:icon.centerYAnchor];
    [self applyTextScale:1.0];

    UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:kIPBIconSide],
        [icon.heightAnchor constraintEqualToConstant:kIPBIconSide],
        [icon.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_text.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:kIPBHeaderGap],
        _nameBaseline
    ]];

    return self;
}

// The text block at a fraction of its full size: fonts and spacing together, so
// the three lines keep their proportions. The icon is never scaled.
- (void)applyTextScale:(CGFloat)scale {
    if (scale == _scale) return;
    _scale = scale;
    _name.font = IPBHeaderNameFont(kIPBNameSize * scale);
    _version.font = [UIFont systemFontOfSize:kIPBVersionSize * scale];
    _scheme.font = [UIFont systemFontOfSize:kIPBSchemeSize * scale];
    [_text setCustomSpacing:kIPBNameToVersion * scale afterView:_name];
    [_text setCustomSpacing:kIPBVersionToScheme * scale afterView:_version];
    _nameBaseline.constant = IPBNameBaselineOffset(scale);
}

// Full size wherever the name fits beside the icon; a narrower phone shrinks the
// whole block by the name's overflow rather than truncating it.
- (void)layoutSubviews {
    CGFloat available = CGRectGetWidth(self.contentView.layoutMarginsGuide.layoutFrame) - kIPBIconSide - kIPBHeaderGap;
    CGFloat natural = [_name.text sizeWithAttributes:@{ NSFontAttributeName: IPBHeaderNameFont(kIPBNameSize) }].width;
    [self applyTextScale:(available > 0 && natural > available) ? available / natural : 1.0];
    [super layoutSubviews];
}

// The row carries the page's own heading, not a setting, so it takes no
// selection, no separator and none of the grouped background.
- (void)setSeparatorStyle:(UITableViewCellSeparatorStyle)style {
    [super setSeparatorStyle:UITableViewCellSeparatorStyleNone];
}

- (void)setBackgroundColor:(UIColor *)color {
    [super setBackgroundColor:[UIColor clearColor]];
}

- (UITableViewCellSelectionStyle)selectionStyle {
    return UITableViewCellSelectionStyleNone;
}

@end

@implementation IPBRootListController
-(NSArray *)specifiers {
    if (!_specifiers) {
        PSSpecifier *header = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:NULL get:NULL detail:nil cell:PSStaticTextCell edit:nil];
        [header setProperty:[IPBHeaderCell class] forKey:@"cellClass"];
        [header setProperty:@142 forKey:@"height"];

        // Root.plist opens with a group, which is the one the header needs after it.
        NSMutableArray *specifiers = [NSMutableArray arrayWithObject:header];
        [specifiers addObjectsFromArray:[self loadSpecifiersFromPlistName:@"Root" target:self]];
        _specifiers = specifiers;
    }

    [self localizeSpecifiers:_specifiers];

    return _specifiers;
}

-(void)sourceCode {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/sergealagon/Immortalizer/"] withCompletionHandler:nil];
}

-(void)supportPage {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://buymeacoffee.com/sergy"] withCompletionHandler:nil];
}

-(void)socialPage {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://x.com/@srgndrlgn"] withCompletionHandler:nil];
}

-(void)maintainerPage {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/CySxL"] withCompletionHandler:nil];
}

- (void)localizeSpecifiers:(NSArray *)specifiers {
    for (PSSpecifier *specifier in specifiers) {
        NSString *labelKey = specifier.properties[@"label"];
        NSString *footerTextKey = specifier.properties[@"footerText"];
        NSArray *validTitles = specifier.properties[@"validTitles"];

        if (labelKey) specifier.name = localizer(labelKey);
        if (footerTextKey) [specifier setProperty:localizer(footerTextKey) forKey:@"footerText"];

        if (validTitles) {
            NSMutableDictionary *mutableTitleDictionary = [NSMutableDictionary dictionary];
            for (NSUInteger i = 0; i < validTitles.count; i++) {
                mutableTitleDictionary[@(i)] = localizer(validTitles[i]);  
            }

            specifier.titleDictionary = [mutableTitleDictionary copy];
        }

    }
}
@end
