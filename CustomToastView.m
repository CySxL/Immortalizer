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

#import "CustomToastView.h"

@implementation CustomToastView

// Borrowing a system window means the toast is torn down with it, which is what
// happens on the way out of the switcher.
+(UIWindow *)toastWindow {
    static UIWindow *window = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        window.windowLevel = UIWindowLevelAlert + 1000;
        window.backgroundColor = [UIColor clearColor];
        window.userInteractionEnabled = NO;
        window.rootViewController = [[UIViewController alloc] init];
    });
    return window;
}

+(void)hideWindowIfEmpty {
    UIWindow *window = [self toastWindow];
    for (UIView *subview in window.subviews) {
        if ([subview isKindOfClass:[CustomToastView class]]) return;
    }
    window.hidden = YES;
}

-(instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon autoHide:(int)seconds {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.containerView = [[UIView alloc] init];
        self.containerView.backgroundColor = [UIColor colorWithRed:0.125 green:0.125 blue:0.125 alpha:1.0];
        self.containerView.layer.cornerRadius = 25;
        self.containerView.layer.masksToBounds = YES;
        self.containerView.layer.shadowColor = [UIColor blackColor].CGColor;
        self.containerView.layer.shadowOpacity = 0.18;
        self.containerView.layer.shadowOffset = CGSizeMake(0, 8);
        self.containerView.layer.shadowRadius = 10;
        self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.containerView];

        self.hStack = [[UIStackView alloc] init];
        self.hStack.axis = UILayoutConstraintAxisHorizontal;
        self.hStack.alignment = UIStackViewAlignmentCenter;
        self.hStack.spacing = 2.0;
        self.hStack.translatesAutoresizingMaskIntoConstraints = NO;
        [self.containerView addSubview:self.hStack];

        if (icon) {
            UIImageView *iconView = [[UIImageView alloc] initWithImage:icon];
            iconView.contentMode = UIViewContentModeScaleAspectFit;
            iconView.translatesAutoresizingMaskIntoConstraints = NO;
            [self.hStack addArrangedSubview:iconView];
            
            [NSLayoutConstraint activateConstraints:@[
                [iconView.widthAnchor constraintEqualToConstant:24],
                [iconView.heightAnchor constraintEqualToConstant:24]
            ]];
            
            [self.hStack setLayoutMargins:UIEdgeInsetsMake(0, 20, 0, 20)];
            self.hStack.layoutMarginsRelativeArrangement = YES;
        }

        self.vStack = [[UIStackView alloc] init];
        self.vStack.axis = UILayoutConstraintAxisVertical;
        self.vStack.alignment = UIStackViewAlignmentCenter;
        self.vStack.spacing = 2.0;
        self.vStack.translatesAutoresizingMaskIntoConstraints = NO;
        [self.hStack addArrangedSubview:self.vStack];

        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:12];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.text = title;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.vStack addArrangedSubview:titleLabel];

        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.textColor = [UIColor lightGrayColor];
        subtitleLabel.font = [UIFont boldSystemFontOfSize:12];
        subtitleLabel.textAlignment = NSTextAlignmentCenter;
        subtitleLabel.text = subtitle;
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.vStack addArrangedSubview:subtitleLabel];

        [self.vStack setLayoutMargins:UIEdgeInsetsMake(4, 0, 4, 0)];
        self.vStack.layoutMarginsRelativeArrangement = YES;

        [NSLayoutConstraint activateConstraints:@[
            [self.containerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
            [self.containerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [self.containerView.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
            [self.containerView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10]
        ]];

        [NSLayoutConstraint activateConstraints:@[
            [self.hStack.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
            [self.hStack.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
            [self.hStack.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
            [self.hStack.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor]
        ]];

        self.autoHideDelay = seconds;
    }
    return self;
}

-(void)presentToast {
    UIWindow *window = [CustomToastView toastWindow];

    for (UIView *subview in [window.subviews copy]) {
        if ([subview isKindOfClass:[CustomToastView class]]) {
            [(CustomToastView *)subview hideWithAnimation];
        }
    }

    window.frame = UIScreen.mainScreen.bounds;
    window.hidden = NO;
    [window addSubview:self];

    self.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
        [self.topAnchor constraintEqualToAnchor:window.topAnchor constant:40],
        [self.widthAnchor constraintEqualToConstant:MAX(window.bounds.size.width - 190, 180)],
        [self.heightAnchor constraintEqualToConstant:70]
    ]];

    [window layoutIfNeeded];

    self.transform = CGAffineTransformMakeTranslation(0, -self.bounds.size.height);

    [UIView animateWithDuration:0.3 animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];

    if (self.autoHideDelay > 0) [self hideAfter:self.autoHideDelay];
}

-(void)hideWithAnimation {
    [UIView animateWithDuration:0.2  animations:^{
        self.transform = CGAffineTransformMakeTranslation(0, -self.bounds.size.height - 30);
    } completion:^(BOOL finished) {
        // Not conditional on finished, an interrupted animation would strand the toast.
        [self removeFromSuperview];
        [CustomToastView hideWindowIfEmpty];
    }];
}

-(void)hideAfter:(NSTimeInterval)time {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
        [weakSelf hideWithAnimation];
    });
}
@end
