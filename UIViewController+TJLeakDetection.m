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

static char *const kCustomLifecycleExtendingParentViewControllerKey = "tjvcld_clepvc";

- (void)tj_setCustomLifecycleExtendingParentViewController:(UIViewController *)viewController
{
    objc_setAssociatedObject(self, kCustomLifecycleExtendingParentViewControllerKey, [NSValue valueWithNonretainedObject:viewController], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIViewController *)tj_customLifecycleExtendingParentViewController
{
    return [objc_getAssociatedObject(self, kCustomLifecycleExtendingParentViewControllerKey) nonretainedObjectValue];
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
    [NSObject cancelPreviousPerformRequestsWithTarget:[self class] selector:@selector(_tjvcld_auditAllViewControllerLeaks) object:nil];
    [[self class] performSelector:@selector(_tjvcld_auditAllViewControllerLeaks) withObject:nil afterDelay:1.5];
    
    [self _tjvcld_viewDidDisappear:animated];
}

+ (void)_tjvcld_auditAllViewControllerLeaks {
    NSMutableOrderedSet<UIViewController *> *const viewControllers = [NSMutableOrderedSet orderedSetWithArray:_tjvcld_trackedViewControllers.allObjects];
    
    NSMutableArray<UIViewController *> *const rootViewControllers = [NSMutableArray new];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *window in [(UIWindowScene *)scene windows]) {
                    if (window.rootViewController) {
                        [rootViewControllers addObject:window.rootViewController];
                    }
                }
            }
        }
    } else {
        for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
            if (window.rootViewController) {
                [rootViewControllers addObject:window.rootViewController];
            }
        }
    }
    
    NSMutableOrderedSet<UIViewController *> *const possiblyLeakedViewControllers = [NSMutableOrderedSet new];
    
    for (NSUInteger i = 0; i < viewControllers.count; i++) {
        UIViewController *const viewController = [viewControllers objectAtIndex:i];
        
        UIViewController *parent = viewController.parentViewController;
        parent = parent ?: viewController.navigationController;
        parent = parent ?: viewController.presentingViewController;
        parent = parent ?: viewController.tabBarController;
        parent = parent ?: viewController.tj_customLifecycleExtendingParentViewController;
        
        if (!parent && [viewController isKindOfClass:[UISearchController class]] && [[(UISearchController *)viewController delegate] isKindOfClass:[UIViewController class]]) {
            parent = (UIViewController *)[(UISearchController *)viewController delegate];
        }
        
        if (parent) {
            [viewControllers addObject:parent];
        } else {
            // If we have no "parent", our view isn't in a window, and we aren't a "root view controller" of any window we're probably being leaked.
            if (!viewController.view.window
                && ![rootViewControllers containsObject:viewController]
                // Internal classes that seem to hang around related to keyboard input.
                && ![NSStringFromClass([viewController class]) isEqualToString:@"UISystemInputAssistantViewController"]
                && ![NSStringFromClass([viewController class]) isEqualToString:@"UICompatibilityInputViewController"]) {
                [possiblyLeakedViewControllers addObject:viewController];
            }
        }
    }
    
    if (possiblyLeakedViewControllers.count) {
        _tjvcld_viewControllerPossiblyLeakedBlock(possiblyLeakedViewControllers);
    }
}

@end
