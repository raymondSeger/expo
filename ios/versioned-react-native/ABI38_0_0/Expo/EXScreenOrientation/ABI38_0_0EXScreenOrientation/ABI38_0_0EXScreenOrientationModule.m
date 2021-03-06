// Copyright 2019-present 650 Industries. All rights reserved.

#import <ABI38_0_0UMCore/ABI38_0_0UMAppLifecycleService.h>
#import <ABI38_0_0UMCore/ABI38_0_0UMDefines.h>
#import <ABI38_0_0UMCore/ABI38_0_0UMEventEmitterService.h>
#import <ABI38_0_0UMCore/ABI38_0_0UMModuleRegistryProvider.h>

#import <ABI38_0_0EXScreenOrientation/ABI38_0_0EXScreenOrientationModule.h>
#import <ABI38_0_0EXScreenOrientation/ABI38_0_0EXScreenOrientationUtilities.h>
#import <ABI38_0_0EXScreenOrientation/ABI38_0_0EXScreenOrientationRegistry.h>

#import <UIKit/UIKit.h>

static NSString *const ABI38_0_0EXScreenOrientationDidUpdateDimensions = @"expoDidUpdateDimensions";

@interface ABI38_0_0EXScreenOrientationModule ()

@property (nonatomic, weak) ABI38_0_0EXScreenOrientationRegistry *screenOrientationRegistry;
@property (nonatomic, weak) id<ABI38_0_0UMEventEmitterService> eventEmitter;

@end

@implementation ABI38_0_0EXScreenOrientationModule

ABI38_0_0UM_EXPORT_MODULE(ExpoScreenOrientation);

-(void)dealloc
{
  [self stopObserving];
  [_screenOrientationRegistry moduleWillDeallocate:self];
}

- (void)setModuleRegistry:(ABI38_0_0UMModuleRegistry *)moduleRegistry
{
  [[moduleRegistry getModuleImplementingProtocol:@protocol(ABI38_0_0UMAppLifecycleService)] registerAppLifecycleListener:self];
  _eventEmitter = [moduleRegistry getModuleImplementingProtocol:@protocol(ABI38_0_0UMEventEmitterService)];
  
  _screenOrientationRegistry = [moduleRegistry getSingletonModuleForName:@"ScreenOrientationRegistry"];
}

ABI38_0_0UM_EXPORT_METHOD_AS(lockAsync,
                    lockAsync:(NSNumber *)orientationLock
                    resolver:(ABI38_0_0UMPromiseResolveBlock)resolve
                    rejecter:(ABI38_0_0UMPromiseRejectBlock)reject)
{
  UIInterfaceOrientationMask orientationMask = [ABI38_0_0EXScreenOrientationUtilities importOrientationLock:orientationLock];
  
  if (!orientationMask) {
    return reject(@"ERR_SCREEN_ORIENTATION_INVALID_ORIENTATION_LOCK", [NSString stringWithFormat:@"Invalid screen orientation lock %@", orientationLock], nil);
  }
  if (![ABI38_0_0EXScreenOrientationUtilities doesDeviceSupportOrientationMask:orientationMask]) {
    return reject(@"ERR_SCREEN_ORIENTATION_UNSUPPORTED_ORIENTATION_LOCK", [NSString stringWithFormat:@"This device does not support the requested orientation %@", orientationLock], nil);
  }
  
  [_screenOrientationRegistry setMask:orientationMask forModule:self];
  resolve(nil);
}

ABI38_0_0UM_EXPORT_METHOD_AS(lockPlatformAsync,
                    lockPlatformAsync:(NSArray <NSNumber *> *)allowedOrientations
                    resolver:(ABI38_0_0UMPromiseResolveBlock)resolve
                    rejecter:(ABI38_0_0UMPromiseRejectBlock)reject)
{
  // combine all the allowedOrientations into one bitmask
  UIInterfaceOrientationMask allowedOrientationsMask = 0;
  for (NSNumber *allowedOrientation in allowedOrientations) {
    UIInterfaceOrientation orientation = [ABI38_0_0EXScreenOrientationUtilities importOrientation:allowedOrientation];
    UIInterfaceOrientationMask orientationMask = [ABI38_0_0EXScreenOrientationUtilities maskFromOrientation:orientation];
    if (!orientationMask) {
      return reject(@"ERR_SCREEN_ORIENTATION_INVALID_ORIENTATION_LOCK", @"Invalid screen orientation lock.", nil);
    }
                                                                         
    allowedOrientationsMask = allowedOrientationsMask | orientationMask;
  }
  
  if (![ABI38_0_0EXScreenOrientationUtilities doesDeviceSupportOrientationMask:allowedOrientationsMask]) {
    return reject(@"ERR_SCREEN_ORIENTATION_UNSUPPORTED_ORIENTATION_LOCK", @"This device does not support the requested orientation.", nil);
  }
  
  [_screenOrientationRegistry setMask:allowedOrientationsMask forModule:self];
  resolve(nil);
}

ABI38_0_0UM_EXPORT_METHOD_AS(getOrientationLockAsync,
                    getOrientationLockAsyncWithResolver:(ABI38_0_0UMPromiseResolveBlock)resolve
                    rejecter:(ABI38_0_0UMPromiseRejectBlock)reject)
{
  resolve([ABI38_0_0EXScreenOrientationUtilities exportOrientationLock:[_screenOrientationRegistry currentOrientationMask]]);
}

ABI38_0_0UM_EXPORT_METHOD_AS(getPlatformOrientationLockAsync,
                    getPlatformOrientationLockAsyncResolver:(ABI38_0_0UMPromiseResolveBlock)resolve
                    rejecter:(ABI38_0_0UMPromiseRejectBlock)reject)
{
  UIInterfaceOrientationMask orientationMask = [_screenOrientationRegistry currentOrientationMask];
  NSDictionary *maskToOrienationMap = @{
    @(UIInterfaceOrientationMaskPortrait): @(UIInterfaceOrientationPortrait),
    @(UIInterfaceOrientationMaskPortraitUpsideDown): @(UIInterfaceOrientationPortraitUpsideDown),
    @(UIInterfaceOrientationMaskLandscapeLeft): @(UIInterfaceOrientationLandscapeLeft),
    @(UIInterfaceOrientationMaskLandscapeRight): @(UIInterfaceOrientationLandscapeRight)
  };
  // If the particular orientation is supported, we add it to the array of allowedOrientations
  NSMutableArray *allowedOrientations = [[NSMutableArray alloc] init];
  for (NSNumber *wrappedSingleOrientation in [maskToOrienationMap allKeys]) {
    UIInterfaceOrientationMask supportedOrientationMask = orientationMask & [wrappedSingleOrientation intValue];
    if (supportedOrientationMask) {
      UIInterfaceOrientation supportedOrientation = [maskToOrienationMap[@(supportedOrientationMask)] intValue];
      [allowedOrientations addObject:[ABI38_0_0EXScreenOrientationUtilities exportOrientation:supportedOrientation]];
    }
  }
  resolve(allowedOrientations);
}

ABI38_0_0UM_EXPORT_METHOD_AS(supportsOrientationLockAsync,
                    supportsOrientationLockAsync:(NSNumber *)orientationLock
                    resolver:(ABI38_0_0UMPromiseResolveBlock)resolve
                    rejecter:(ABI38_0_0UMPromiseRejectBlock)reject)
{
  UIInterfaceOrientationMask orientationMask = [ABI38_0_0EXScreenOrientationUtilities importOrientationLock:orientationLock];
 
  if (orientationMask && [ABI38_0_0EXScreenOrientationUtilities doesDeviceSupportOrientationMask:orientationMask]) {
    return resolve(@YES);
  }
  
  resolve(@NO);
}

ABI38_0_0UM_EXPORT_METHOD_AS(getOrientationAsync,
                    getOrientationAsyncResolver:(ABI38_0_0UMPromiseResolveBlock)resolve
                    rejecter:(ABI38_0_0UMPromiseRejectBlock)reject)
{
  resolve([ABI38_0_0EXScreenOrientationUtilities exportOrientation:[_screenOrientationRegistry currentOrientation]]);
}

// Will be called when this module's first listener is added.
- (void)startObserving
{
  [_screenOrientationRegistry registerModuleToReceiveNotification:self];
}

// Will be called when this module's last listener is removed, or on dealloc.
- (void)stopObserving
{
  [_screenOrientationRegistry unregisterModuleFromReceivingNotification:self];
}

- (void)screenOrientationDidChange:(UIInterfaceOrientation)orientation
{
  UITraitCollection * currentTraitCollection = [_screenOrientationRegistry currentTrailCollection];
  [_eventEmitter sendEventWithName:ABI38_0_0EXScreenOrientationDidUpdateDimensions body:@{
    @"orientationLock": [ABI38_0_0EXScreenOrientationUtilities exportOrientationLock:[_screenOrientationRegistry currentOrientationMask]],
    @"orientationInfo": @{
      @"orientation": [ABI38_0_0EXScreenOrientationUtilities exportOrientation:orientation],
      @"verticalSizeClass": ABI38_0_0UMNullIfNil(@(currentTraitCollection.verticalSizeClass)),
      @"horizontalSizeClass": ABI38_0_0UMNullIfNil(@(currentTraitCollection.horizontalSizeClass)),
    }
  }];
}

- (NSArray<NSString *> *)supportedEvents {
  return @[ABI38_0_0EXScreenOrientationDidUpdateDimensions];
}

- (void)onAppBackgrounded {
  [_screenOrientationRegistry moduleDidBackground:self];
}

- (void)onAppForegrounded {
  [_screenOrientationRegistry moduleDidForeground:self];
}

@end
