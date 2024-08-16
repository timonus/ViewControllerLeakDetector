//
//  UIViewController+TJLeakDetection.m
//
//  Created by Tim Johnsen on 12/2/23.
//

#import "UIViewController+TJLeakDetection.h"

#import <objc/runtime.h>

static void _tjvcld_swizzle(Class class, SEL originalSelector, SEL swizzledSelector)
{
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

@implementation UIViewController (TJLeakDetection)

NSMapTable *_customLifecycleExtendingParentViewControllers;

- (void)tj_setCustomLifecycleExtendingParentViewController:(UIViewController *)viewController
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _customLifecycleExtendingParentViewControllers = [NSMapTable strongToWeakObjectsMapTable];
    });
    [_customLifecycleExtendingParentViewControllers setObject:viewController forKey:self];
}

- (UIViewController *)tj_customLifecycleExtendingParentViewController
{
    return [_customLifecycleExtendingParentViewControllers objectForKey:self];
}

static void (^_tjvcld_viewControllerPossiblyLeakedBlock)(NSOrderedSet<UIViewController *> *);

+ (void)tj_setViewControllerPossiblyLeakedBlock:(void (^)(NSOrderedSet<UIViewController *> *))block
{
    _tjvcld_viewControllerPossiblyLeakedBlock = block;
}

static NSHashTable *_tjvcld_trackedViewControllers;

+ (void)tj_enableLeakDetection
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _tjvcld_trackedViewControllers = [NSHashTable weakObjectsHashTable];
        _tjvcld_viewControllerPossiblyLeakedBlock = ^(NSOrderedSet<UIViewController *> *const viewControllers) {
            for (UIViewController *const viewController in viewControllers) {
                NSLog(@"[POSSIBLE VIEW CONTROLLER LEAK] %p %@", viewController, NSStringFromClass([viewController class]));
            }
        };
        
        _tjvcld_swizzle([UIViewController class], @selector(viewDidDisappear:), @selector(_tjvcld_viewDidDisappear:));
        _tjvcld_swizzle([UIViewController class], @selector(viewDidAppear:), @selector(_tjvcld_viewDidAppear:));
    });
}

- (void)_tjvcld_viewDidAppear:(BOOL)animated
{
    [_tjvcld_trackedViewControllers addObject:self];
    [self _tjvcld_viewDidAppear:animated];
}

- (void)_tjvcld_viewDidDisappear:(BOOL)animated
{
    [NSObject cancelPreviousPerformRequestsWithTarget:[UIViewController class] selector:@selector(_tjvcld_auditAllViewControllerLeaks) object:nil];
    [[UIViewController class] performSelector:@selector(_tjvcld_auditAllViewControllerLeaks) withObject:nil afterDelay:1.5];
    
    [self _tjvcld_viewDidDisappear:animated];
}

+ (void)_tjvcld_auditAllViewControllerLeaks {
    NSMutableOrderedSet<UIViewController *> *const viewControllers = [NSMutableOrderedSet orderedSetWithArray:_tjvcld_trackedViewControllers.allObjects];
    
    NSMutableArray<UIViewController *> *const rootViewControllers = [NSMutableArray new];
#if !defined(__IPHONE_13_0) || __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
#endif
        for (UIScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *window in [(UIWindowScene *)scene windows]) {
                    if (window.rootViewController) {
                        [rootViewControllers addObject:window.rootViewController];
                    }
                }
            }
        }
#if !defined(__IPHONE_13_0) || __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_13_0
    } else {
        for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
            if (window.rootViewController) {
                [rootViewControllers addObject:window.rootViewController];
            }
        }
    }
#endif
    
    NSMutableOrderedSet<UIViewController *> *const possiblyLeakedViewControllers = [NSMutableOrderedSet new];
    
    for (NSUInteger i = 0; i < viewControllers.count; i++) {
        UIViewController *const viewController = [viewControllers objectAtIndex:i];
        
        UIViewController *parent = viewController.parentViewController;
        parent = parent ?: viewController.navigationController;
        parent = parent ?: viewController.presentingViewController;
        parent = parent ?: viewController.tabBarController;
        if (!parent && [viewController isKindOfClass:[UISearchController class]] && [[(UISearchController *)viewController searchResultsUpdater] isKindOfClass:[UIViewController class]]) {
            parent = (UIViewController *)[(UISearchController *)viewController searchResultsUpdater];
        }
        parent = parent ?: viewController.tj_customLifecycleExtendingParentViewController;
        
        if (!parent && [viewController isKindOfClass:[UISearchController class]] && [[(UISearchController *)viewController delegate] isKindOfClass:[UIViewController class]]) {
            parent = (UIViewController *)[(UISearchController *)viewController delegate];
        }
        
        if (parent) {
            [viewControllers addObject:parent];
        } else {
            // If we have no "parent", our view isn't in a window, and we aren't a "root view controller" of any window we're probably being leaked.
            NSString *const className = NSStringFromClass([viewController class]);
            if (!viewController.view.window
                && ![rootViewControllers containsObject:viewController]
                // Internal classes that seem to hang around related to keyboard input.
                && ![className isEqualToString:@"UISystemInputAssistantViewController"]
                && ![className isEqualToString:@"UICompatibilityInputViewController"]
                && ![className isEqualToString:@"_UICursorAccessoryViewController"]
                && ![className isEqualToString:@"TUIEmojiSearchInputViewController"]
                && ![className isEqualToString:@"UIPredictionViewController"]
                && ![className hasPrefix:@"FLEX"]) {
                [possiblyLeakedViewControllers addObject:viewController];
            }
        }
    }
    
    if (possiblyLeakedViewControllers.count) {
        _tjvcld_viewControllerPossiblyLeakedBlock(possiblyLeakedViewControllers);
    }
}

@end
