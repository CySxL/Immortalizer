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

static const CGFloat kIPBAvatarSide = 38.0;

// The row indents its text by the width of its image, so a symbol takes the same square as the avatar.
static UIImage *IPBSymbol(NSString *name, CGFloat side) {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightMedium];
    UIImage *symbol = [UIImage systemImageNamed:name withConfiguration:configuration] ?: [UIImage systemImageNamed:@"link" withConfiguration:configuration];
    if (!symbol) return nil;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)];
    UIImage *padded = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [symbol drawInRect:CGRectMake((side - symbol.size.width) / 2.0, (side - symbol.size.height) / 2.0, symbol.size.width, symbol.size.height)];
    }];
    return [padded imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface IPBCreditCell : PSTableCell
@end

// A row carrying ipbBranch hangs off the row above it: a line from that row's avatar bends into it,
// and the row above, carrying ipbBranchBelow, drops its separator and draws the top of the line.
@implementation IPBCreditCell {
    UIImageView *_avatarView;
    CAShapeLayer *_branch;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier specifier:specifier];
    if (!self) return nil;
    self.detailTextLabel.text = [specifier propertyForKey:@"subtitle"] ?: @"";
    self.detailTextLabel.textColor = [UIColor systemGrayColor];
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    BOOL branch = [[specifier propertyForKey:@"ipbBranch"] isEqual:@YES];
    if (branch || [[specifier propertyForKey:@"ipbBranchBelow"] isEqual:@YES]) {
        _branch = [CAShapeLayer layer];
        _branch.fillColor = nil;
        _branch.lineWidth = 1.5;
        _branch.lineCap = kCALineCapRound;
        [self.contentView.layer addSublayer:_branch];
    }
    if (branch) {
        // An empty slot as wide as the avatar, so the text lines up with the name above.
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(kIPBAvatarSide, 16.0), NO, [UIScreen mainScreen].scale);
        [specifier setProperty:UIGraphicsGetImageFromCurrentImageContext() forKey:@"iconImage"];
        UIGraphicsEndImageContext();
        UIImageSymbolConfiguration *small = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
        NSString *symbolName = [specifier propertyForKey:@"ipbBranchSymbol"];
        if (![symbolName isKindOfClass:[NSString class]]) symbolName = @"chevron.left.forwardslash.chevron.right";
        NSTextAttachment *mark = [[NSTextAttachment alloc] init];
        mark.image = [[UIImage systemImageNamed:symbolName withConfiguration:small] imageWithTintColor:[UIColor linkColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        NSMutableAttributedString *title = [[NSMutableAttributedString alloc] init];
        if (mark.image) [title appendAttributedString:[NSAttributedString attributedStringWithAttachment:mark]];
        [title appendAttributedString:[[NSAttributedString alloc] initWithString:[@"  " stringByAppendingString:specifier.name ?: @""]
            attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:13.0], NSForegroundColorAttributeName: [UIColor linkColor] }]];
        self.textLabel.attributedText = title;
        // nil rather than empty, so the subtitle style centres the one line.
        self.detailTextLabel.text = nil;
        return self;
    }
    UIImage *avatar = [specifier propertyForKey:@"ipbAvatar"];
    if (![avatar isKindOfClass:[UIImage class]]) {
        self.imageView.tintColor = [UIColor secondaryLabelColor];
        return self;
    }
    // An empty image of the right size, so the row lays out before the avatar is drawn into it.
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kIPBAvatarSide, kIPBAvatarSide), NO, [UIScreen mainScreen].scale);
    [specifier setProperty:UIGraphicsGetImageFromCurrentImageContext() forKey:@"iconImage"];
    UIGraphicsEndImageContext();
    _avatarView = [[UIImageView alloc] initWithFrame:self.imageView.bounds];
    _avatarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _avatarView.contentMode = UIViewContentModeScaleAspectFill;
    _avatarView.clipsToBounds = YES;
    _avatarView.layer.cornerRadius = kIPBAvatarSide * 0.5;
    _avatarView.layer.minificationFilter = kCAFilterTrilinear;
    _avatarView.image = avatar;
    [self.imageView addSubview:_avatarView];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!_branch) return;
    BOOL branch = [[self.specifier propertyForKey:@"ipbBranch"] isEqual:@YES];
    BOOL below = [[self.specifier propertyForKey:@"ipbBranchBelow"] isEqual:@YES];
    if (below) {
        for (UIView *view in self.subviews) {
            if ([NSStringFromClass([view class]) hasSuffix:@"SeparatorView"]) view.hidden = YES;
        }
    }
    _branch.strokeColor = [[UIColor systemGray3Color] resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    CGRect slot = [self.contentView convertRect:self.imageView.bounds fromView:self.imageView];
    CGFloat x = round(CGRectGetMidX(slot));
    UIBezierPath *path = [UIBezierPath bezierPath];
    if (branch) {
        CGFloat y = round(CGRectGetMidY(slot)), r = 6.0;
        [path moveToPoint:CGPointMake(x, 0)];
        [path addLineToPoint:CGPointMake(x, y - r)];
        [path addQuadCurveToPoint:CGPointMake(x + r, y) controlPoint:CGPointMake(x, y)];
        [path addLineToPoint:CGPointMake(CGRectGetMaxX(slot), y)];
        // A branch with another below it carries the line on to the next one.
        if (below) {
            [path moveToPoint:CGPointMake(x, y - r)];
            [path addLineToPoint:CGPointMake(x, CGRectGetMaxY(self.contentView.bounds))];
        }
    } else {
        [path moveToPoint:CGPointMake(x, CGRectGetMaxY(slot) + 3.0)];
        [path addLineToPoint:CGPointMake(x, CGRectGetMaxY(self.contentView.bounds))];
    }
    _branch.path = path.CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    [self setNeedsLayout];
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
        [self addCreditsTo:specifiers];
        _specifiers = specifiers;
    }

    [self localizeSpecifiers:_specifiers];

    return _specifiers;
}

- (void)addCreditsTo:(NSMutableArray *)specifiers {
    PSSpecifier *credits = [PSSpecifier preferenceSpecifierNamed:@"Credits" target:self set:NULL get:NULL detail:nil cell:PSGroupCell edit:nil];
    [credits setProperty:@"© CySxL 2026" forKey:@"footerText"];
    [specifiers addObject:credits];
    // name, subtitle, link, picture, symbol; a row with a symbol is a branch of the row above it
    NSArray *rows = @[
        @[@"sergy", @"Original Developer", @"https://github.com/sergealagon", @"", @""],
        @[@"Source Code", @"", @"https://github.com/sergealagon/Immortalizer", @"", @"chevron.left.forwardslash.chevron.right"],
        @[@"Donate", @"", @"https://buymeacoffee.com/sergy", @"", @"heart"],
        @[@"CySxL", @"Maintainer · roothide Port", @"https://github.com/CySxL", @"avatar", @""],
        @[@"Tip on Ko-fi", @"", @"https://ko-fi.com/cysxl", @"", @"cup.and.saucer"]
    ];
    PSSpecifier *previous = nil;
    for (NSArray *row in rows) {
        PSSpecifier *credit = [PSSpecifier preferenceSpecifierNamed:row[0] target:self set:NULL get:NULL detail:nil cell:PSLinkCell edit:nil];
        [credit setProperty:[IPBCreditCell class] forKey:@"cellClass"];
        [credit setProperty:row[1] forKey:@"subtitle"];
        [credit setProperty:row[2] forKey:@"url"];
        NSString *picture = row[3];
        if ([row[4] length]) {
            [credit setProperty:@YES forKey:@"ipbBranch"];
            [credit setProperty:row[4] forKey:@"ipbBranchSymbol"];
            [credit setProperty:@34 forKey:@"height"];
            [previous setProperty:@YES forKey:@"ipbBranchBelow"];
        } else {
            UIImage *avatar = picture.length ? [UIImage imageNamed:picture inBundle:[NSBundle bundleForClass:[self class]] withConfiguration:nil] : nil;
            if (avatar) [credit setProperty:avatar forKey:@"ipbAvatar"];
            else [credit setProperty:IPBSymbol(@"chevron.left.forwardslash.chevron.right", kIPBAvatarSide) forKey:@"iconImage"];
        }
        credit->action = @selector(openCredit:);
        [specifiers addObject:credit];
        previous = credit;
    }
}

- (void)openCredit:(PSSpecifier *)specifier {
    NSString *link = [specifier propertyForKey:@"url"];
    NSURL *url = [link isKindOfClass:[NSString class]] ? [NSURL URLWithString:link] : nil;
    if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
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
