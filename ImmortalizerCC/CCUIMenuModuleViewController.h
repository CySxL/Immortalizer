#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIContentModuleContentViewController-Protocol.h>

// Not in theos' ControlCenterUIKit headers; only the members used here.
@interface CCUIMenuModuleViewController : UIViewController <CCUIContentModuleContentViewController>
@property (nonatomic, copy) UIImage *glyphImage;
@property (nonatomic, copy) UIImage *selectedGlyphImage;
@property (nonatomic, copy) UIColor *selectedGlyphColor;
@property (assign, getter=isSelected, nonatomic) BOOL selected;
- (void)addActionWithTitle:(NSString *)title subtitle:(NSString *)subtitle glyph:(UIImage *)glyph handler:(void (^)(void))handler;
- (void)buttonTapped:(id)arg1 forEvent:(UIEvent *)event;
- (CGFloat)preferredExpandedContentWidth;
- (BOOL)shouldBeginTransitionToExpandedContentModule;
- (BOOL)_canShowWhileLocked;
@end
