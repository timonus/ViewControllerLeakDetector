# UIViewController Leak Detector
_Automatically find leaked view controllers._

This project helps you find leaked view controllers in your app. We're all human, we all make mistakes, and leaking view controllers is an easy mistake we've all been making since the beginning of iOS. This project implements a simple view controller lifecycle tracker that's based on [this excellent blog post](https://medium.com/thumbtack-engineering/detecting-leaky-view-controllers-7f3a15dfeee1) from Thumbtack. I've implemented versions of this several times in my career and it's caught countless accidental view controller leaks.

## Use

1. Add the `UIViewController+TJLeakDetection.h`/`.m` source files to your project.
2. Call `[UIViewController tj_enableLeakDetection]` to start logging potentially leaked view controllers.

It is recommended that you only use this in `DEBUG` builds. I also recommend not even compiling this into release builds using the `Excluded Source File Names` build option.

## Advanced use

### Specify custom view controller lifecycle

Some view controllers don't fit into the traditional view controller lifecycle that this project assumes (for example: if a view controller is cached for reuse this project will assume it's being leaked). In order to opt out view controllers with bespoke lifecycle needs you can set `tj_setCustomLifecycleExtendingParentViewController`. As long as a view controller's `tj_setCustomLifecycleExtendingParentViewController` isn't being leaked it's assumed it is also not being leaked.

### Override leak handing

By default this code logs using `NSLog` when a view controller is thought to be leaked, to override this behavior you can use `tj_setViewControllerPossiblyLeakedBlock:` to set a block that's instead invoked when a leak is detected.

## Ok, what do I do next?

The address of leaked view controllers is logged when a potential leak is detected. You can find the view controller in question using the `Debug Memory Graph` tool, then you should be able to hunt down what's causing the leak.

## Notes

There's a [view controller leak in UIKit in iOS 16 when using `prefersGrabberVisible`](https://mastodon.social/@timonus/110294950761155548). If your app uses `prefersGrabberVisible` you may want to only enable the leak detector on iOS 17+ [where it was fixed](https://mastodon.social/@timonus/110516713068987111).