//
//  UIViewController+TJLeakDetection.h
//
//  Created by Tim Johnsen on 12/2/23.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Somewhat automatic view controller leak detection based on this excellent blog post: https://medium.com/thumbtack-engineering/detecting-leaky-view-controllers-7f3a15dfeee1
@interface UIViewController (TJLeakDetection)

+ (void)tj_enableLeakDetection;

@property (nonatomic, nullable, weak, setter=tj_setCustomLifecycleExtendingParentViewController:) UIViewController *tj_customLifecycleExtendingParentViewController;

+ (void)tj_setViewControllerPossiblyLeakedBlock:(void (^)(NSOrderedSet<UIViewController *> *))block;

@end

NS_ASSUME_NONNULL_END
