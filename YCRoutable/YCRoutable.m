//
//  YCRoutable.m
//  YCRoutableExample
//
//  Created by chenxiaosong on 2018/7/24.
//  Copyright © 2018年 chenxiaosong. All rights reserved.
//

#import "YCRoutable.h"

@implementation YCRoutable

+ (instancetype)sharedRouter {
    static YCRoutable *_sharedRouter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedRouter = [[YCRoutable alloc] init];
    });
    return _sharedRouter;
}

//really unnecessary; kept for backward compatibility.
+ (instancetype)newRouter {
    return [[self alloc] init];
}

@end

@interface RouterParams : NSObject

@property (readwrite, nonatomic, strong) UPRouterOptions *routerOptions;
@property (readwrite, nonatomic, strong) NSDictionary *openParams;
@property (readwrite, nonatomic, strong) NSDictionary *extraParams;
@property (readwrite, nonatomic, strong) NSDictionary *controllerParams;

@end

@implementation RouterParams

- (instancetype)initWithRouterOptions: (UPRouterOptions *)routerOptions openParams: (NSDictionary *)openParams extraParams: (NSDictionary *)extraParams{
    [self setRouterOptions:routerOptions];
    [self setExtraParams: extraParams];
    [self setOpenParams:openParams];
    return self;
}

- (NSDictionary *)controllerParams {
    NSMutableDictionary *controllerParams = [NSMutableDictionary dictionaryWithDictionary:self.routerOptions.defaultParams];
    [controllerParams addEntriesFromDictionary:self.extraParams];
    [controllerParams addEntriesFromDictionary:self.openParams];
    return controllerParams;
}
//fake getter. Not idiomatic Objective-C. Use accessor controllerParams instead
- (NSDictionary *)getControllerParams {
    return [self controllerParams];
}
@end

@interface UPRouterOptions ()

@property (readwrite, nonatomic, strong) Class openClass;
@property (readwrite, nonatomic, copy) RouterOpenCallback callback;
@property (readwrite, nonatomic, strong) NSArray *checkList;
@end

@implementation UPRouterOptions

//Explicit construction
+ (instancetype)routerOptionsWithPresentationStyle: (UIModalPresentationStyle)presentationStyle
                                   transitionStyle: (UIModalTransitionStyle)transitionStyle
                                     defaultParams: (NSDictionary *)defaultParams
                                            isRoot: (BOOL)isRoot
                                           isModal: (BOOL)isModal
                                        launchMode: (UILaunchMode)launchMode
{
    UPRouterOptions *options = [[UPRouterOptions alloc] init];
    options.presentationStyle = presentationStyle;
    options.transitionStyle = transitionStyle;
    options.defaultParams = defaultParams;
    options.shouldOpenAsRootViewController = isRoot;
    options.modal = isModal;
    options.launchMode = launchMode;
    return options;
}
//Default construction; like [NSArray array]
+ (instancetype)routerOptions {
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:nil
                                             isRoot:NO
                                            isModal:NO
                                         launchMode:UILaunchStandard];
}

//Custom class constructors, with heavier Objective-C accent
+ (instancetype)routerOptionsAsSingleTask {
    
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:nil
                                             isRoot:NO
                                            isModal:NO
                                         launchMode:UILaunchSingleTask];
}

+ (instancetype)routerOptionsAsModal {
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:nil
                                             isRoot:NO
                                            isModal:YES
                                         launchMode:UILaunchStandard];
}
+ (instancetype)routerOptionsWithPresentationStyle:(UIModalPresentationStyle)style {
    return [self routerOptionsWithPresentationStyle:style
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:nil
                                             isRoot:NO
                                            isModal:NO
                                         launchMode:UILaunchStandard];
}
+ (instancetype)routerOptionsWithTransitionStyle:(UIModalTransitionStyle)style {
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:style
                                      defaultParams:nil
                                             isRoot:NO
                                            isModal:NO
                                         launchMode:UILaunchStandard];
}
+ (instancetype)routerOptionsForDefaultParams:(NSDictionary *)defaultParams {
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:defaultParams
                                             isRoot:NO
                                            isModal:NO
                                         launchMode:UILaunchStandard];
}
+ (instancetype)routerOptionsAsRoot {
    return [self routerOptionsWithPresentationStyle:UIModalPresentationNone
                                    transitionStyle:UIModalTransitionStyleCoverVertical
                                      defaultParams:nil
                                             isRoot:YES
                                            isModal:NO
                                         launchMode:UILaunchStandard];
}

//Exposed methods previously supported
+ (instancetype)singleTask {
    return [self routerOptionsAsSingleTask];
}
+ (instancetype)modal {
    return [self routerOptionsAsModal];
}
+ (instancetype)withPresentationStyle:(UIModalPresentationStyle)style {
    return [self routerOptionsWithPresentationStyle:style];
}
+ (instancetype)withTransitionStyle:(UIModalTransitionStyle)style {
    return [self routerOptionsWithTransitionStyle:style];
}
+ (instancetype)forDefaultParams:(NSDictionary *)defaultParams {
    return [self routerOptionsForDefaultParams:defaultParams];
}
+ (instancetype)root {
    return [self routerOptionsAsRoot];
}

//Wrappers around setters (to continue DSL-like syntax)
- (UPRouterOptions *)modal {
    [self setModal:YES];
    return self;
}
- (UPRouterOptions *)withPresentationStyle:(UIModalPresentationStyle)style {
    [self setPresentationStyle:style];
    return self;
}
- (UPRouterOptions *)withTransitionStyle:(UIModalTransitionStyle)style {
    [self setTransitionStyle:style];
    return self;
}
- (UPRouterOptions *)forDefaultParams:(NSDictionary *)defaultParams {
    [self setDefaultParams:defaultParams];
    return self;
}
- (UPRouterOptions *)root {
    [self setShouldOpenAsRootViewController:YES];
    return self;
}
@end

@interface UPRouter ()

// Map of URL format NSString -> RouterOptions
// i.e. "users/:id"
@property (readwrite, nonatomic, strong) NSMutableDictionary *routes;

// Map of URL format NSString -> RouterOptions
// i.e. "users/:id"
@property (readwrite, nonatomic, strong) NSMutableDictionary *checks;

// Map of final URL NSStrings -> RouterParams
// i.e. "users/16"
@property (readwrite, nonatomic, strong) NSMutableDictionary *cachedRoutes;

@end

#define ROUTE_NOT_FOUND_FORMAT @"No route found for URL %@"
#define INVALID_CONTROLLER_FORMAT @"Your controller class %@ needs to implement either the static method %@ or the instance method %@"

@implementation UPRouter

- (id)init {
    if ((self = [super init])) {
        self.routes = [NSMutableDictionary dictionary];
        self.checks = [NSMutableDictionary dictionary];
        self.cachedRoutes = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)map:(NSString *)format toCallback:(RouterOpenCallback)callback {
    [self map:format toCallback:callback withOptions:nil];
}

- (void)map:(NSString *)format toCallback:(RouterOpenCallback)callback withOptions:(UPRouterOptions *)options {
    if (!format) {
        @throw [NSException exceptionWithName:@"RouteNotProvided"
                                       reason:@"Route #format is not initialized"
                                     userInfo:nil];
        return;
    }
    if (!options) {
        options = [UPRouterOptions routerOptions];
    }
    options.callback = callback;
    [self.routes setObject:options forKey:format];
}

- (void)map:(NSString *)format toController:(Class)controllerClass {
    [self map:format toController:controllerClass withOptions:nil andCheckList:nil];
}

- (void)map:(NSString *)format
toController:(Class)controllerClass
withOptions:(UPRouterOptions *)options
andCheckList:(NSArray*)checkList
{
    if (!format) {
        @throw [NSException exceptionWithName:@"RouteNotProvided"
                                       reason:@"Route #format is not initialized"
                                     userInfo:nil];
        return;
    }
    if (!options) {
        options = [UPRouterOptions routerOptions];
    }
    
    options.openClass = controllerClass;
    options.checkList = checkList;
    
    [self.routes setObject:options forKey:format];
}

- (void)checkMap:(NSString *)name
    toController:(Class)controllerClass
     withOptions:(UPRouterOptions *)options
{
    if (!name) {
        @throw [NSException exceptionWithName:@"RouteNotProvided"
                                       reason:@"Route #format is not initialized"
                                     userInfo:nil];
        return;
    }
    if (!options) {
        options = [UPRouterOptions routerOptions];
    }
    
    options.openClass = controllerClass;
    
    [self.checks setObject:options forKey:name];
}

- (void)openExternal:(NSString *)url {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

- (void)open:(NSString *)url {
    [self open:url animated:YES];
}

- (void)open:(NSString *)url animated:(BOOL)animated {
    [self open:url animated:animated extraParams:nil];
}

- (BOOL)guarantee:(NSArray*)checkList
{
    RouterParams *checkParams = [self checkForList:checkList];
    
    if(checkParams) {
        [self doIt:checkParams animated:YES];
        return NO;
    } else {
        return YES;
    }
    
}

- (void)doIt:(RouterParams *)params animated:(BOOL)animated
{
    UPRouterOptions *options = params.routerOptions;
    
    if (options.callback) {
        RouterOpenCallback callback = options.callback;
        callback([params controllerParams]);
        return;
    }
    
    if (!self.navigationController) {
        if (_ignoresExceptions) {
            return;
        }
        
        @throw [NSException exceptionWithName:@"NavigationControllerNotProvided"
                                       reason:@"Router#navigationController has not been set to a UINavigationController instance"
                                     userInfo:nil];
    }
    
    UIViewController *controller = [self controllerForRouterParams:params];
    
    if (self.navigationController.presentedViewController) {
        [self.navigationController dismissViewControllerAnimated:animated completion:nil];
    }
    
    if ([options isModal]) {
        if ([controller.class isSubclassOfClass:UINavigationController.class]) {
            [self.navigationController presentViewController:controller
                                                    animated:animated
                                                  completion:nil];
        }
        else {
            [self.navigationController presentViewController:controller
                                                    animated:animated
                                                  completion:nil];
        }
    }
    else if (options.shouldOpenAsRootViewController) {
        [self.navigationController setViewControllers:@[controller] animated:animated];
    }
    else {
        
        if(options.launchMode == UILaunchSingleTask) {
            for(UIViewController *childVC in self.navigationController.viewControllers) {
                NSString *nameOfChildVC  = [NSString stringWithUTF8String:object_getClassName(childVC)];
                NSString *nameOfTargetVC = [NSString stringWithUTF8String:object_getClassName(controller)];
                if([nameOfChildVC isEqualToString:nameOfTargetVC]){
                    [self.navigationController popToViewController:childVC animated:YES];
                    return;
                }
            }
        }
        
        [self.navigationController pushViewController:controller animated:animated];
    }
}

- (void)open:(NSString *)url
    animated:(BOOL)animated
 extraParams:(NSDictionary *)extraParams
{
    RouterParams *params = [self routerParamsForUrl:url extraParams: extraParams];
    
    [self doIt:params animated:animated];
    
}
- (NSDictionary*)paramsOfUrl:(NSString*)url {
    return [[self routerParamsForUrl:url] controllerParams];
}

//Stack operations
- (void)popViewControllerFromRouterAnimated:(BOOL)animated {
    if (self.navigationController.presentedViewController) {
        [self.navigationController dismissViewControllerAnimated:animated completion:nil];
    }
    else {
        [self.navigationController popViewControllerAnimated:animated];
    }
}
- (void)pop {
    [self popViewControllerFromRouterAnimated:YES];
}
- (void)pop:(BOOL)animated {
    [self popViewControllerFromRouterAnimated:animated];
}

///////
- (RouterParams *)checkForList:(NSArray *)checkList
{
    if(!checkList)
        return nil;
    
    for(NSString *itemKey in checkList) {
        UPRouterOptions *checkOptions = self.checks[itemKey];
        
        if(!checkOptions)
            continue;
        
        id checkRlt = [checkOptions.openClass performSelector:NSSelectorFromString(itemKey)];
        
        if([checkRlt boolValue]) {
            continue;
        } else {
            
            NSDictionary *givenParams = @{@"suc_route_block":^{}};
            
            RouterParams *openParams = [[RouterParams alloc] initWithRouterOptions:checkOptions
                                                                        openParams:givenParams
                                                                       extraParams:nil];
            return openParams;
        }
        
    }
    
    return nil;
}

- (RouterParams *)checkForList:(NSArray *)checkList withTargetUrl:(NSString*)targetUrl extraParams:(NSDictionary*)extraParams
{
    if(!checkList)
        return nil;
    
    for(NSString *itemKey in checkList) {
        UPRouterOptions *checkOptions = self.checks[itemKey];
        
        if(!checkOptions)
            continue;
        
        id checkRlt = [checkOptions.openClass performSelector:NSSelectorFromString(itemKey)];
        
        if([checkRlt boolValue]) {
            continue;
        } else {
            
            NSDictionary *givenParams = @{@"suc_route_block":^{
                [[YCRoutable sharedRouter] open:targetUrl
                                       animated:YES
                                    extraParams:extraParams];
            }};
            
            RouterParams *openParams = [[RouterParams alloc] initWithRouterOptions:checkOptions
                                                                        openParams:givenParams
                                                                       extraParams:nil];
            return openParams;
        }
        
    }
    
    return nil;
}

- (RouterParams *)routerParamsForUrl:(NSString *)url extraParams: (NSDictionary *)extraParams {
    if (!url) {
        //if we wait, caching this as key would throw an exception
        if (_ignoresExceptions) {
            return nil;
        }
        @throw [NSException exceptionWithName:@"RouteNotFoundException"
                                       reason:[NSString stringWithFormat:ROUTE_NOT_FOUND_FORMAT, url]
                                     userInfo:nil];
    }
    
    NSString *extractedPath  = [self extractPath:url];
    
    __block RouterParams *openParams = nil;
    [self.routes enumerateKeysAndObjectsUsingBlock:
     ^(NSString *routerUrl, UPRouterOptions *routerOptions, BOOL *stop) {
         
         if ([extractedPath isEqualToString:routerUrl]) {
             
             RouterParams *checkParams = [self checkForList:routerOptions.checkList
                                              withTargetUrl:url
                                                extraParams:extraParams];
             if(checkParams){
                 openParams = checkParams;
                 
             } else {
                 NSDictionary *givenParams = [self extractQueryParams:url];
                 openParams = [[RouterParams alloc] initWithRouterOptions:routerOptions openParams:givenParams extraParams: extraParams];
                 
             }
             
             *stop = YES;
         }
     }];
    
    if (!openParams) {
        if (_ignoresExceptions) {
            return nil;
        } else if (_notFoundPage) {
            UPRouterOptions *redirectOptions = [UPRouterOptions routerOptions];
            redirectOptions.openClass        = _notFoundPage;
            
            RouterParams *redirectParams = [[RouterParams alloc] initWithRouterOptions:redirectOptions
                                                                            openParams:nil
                                                                           extraParams: nil];
            return redirectParams;
        }
        @throw [NSException exceptionWithName:@"RouteNotFoundException"
                                       reason:[NSString stringWithFormat:ROUTE_NOT_FOUND_FORMAT, url]
                                     userInfo:nil];
    }
    
    return openParams;
}

- (NSString*)extractPath:(NSString*)url
{
    NSString *separatedPath = [url componentsSeparatedByString:@"?"][0];
    
    return [separatedPath stringByReplacingOccurrencesOfString:@"/" withString:@""];
}

- (NSDictionary*)extractQueryParams:(NSString*)url
{
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    
    // Extract Params From Query.
    NSRange firstRange = [url rangeOfString:@"?"];
    if (firstRange.location == NSNotFound && url.length <= firstRange.location + firstRange.length)
        return nil;
    
    NSString *paramsString = [url substringFromIndex:firstRange.location + firstRange.length];
    NSArray *paramStringArr = [paramsString componentsSeparatedByString:@"&"];
    for (NSString *paramString in paramStringArr) {
        NSArray *paramArr = [paramString componentsSeparatedByString:@"="];
        if (paramArr.count > 1) {
            NSString *key = [paramArr objectAtIndex:0];
            NSString *value = [paramArr objectAtIndex:1];
            params[key] = value;
        }
    }
    
    return params;
}

- (RouterParams *)routerParamsForUrl:(NSString *)url {
    return [self routerParamsForUrl:url extraParams: nil];
}

- (NSDictionary *)paramsForUrlComponents:(NSArray *)givenUrlComponents
                     routerUrlComponents:(NSArray *)routerUrlComponents {
    
    __block NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [routerUrlComponents enumerateObjectsUsingBlock:
     ^(NSString *routerComponent, NSUInteger idx, BOOL *stop) {
         
         NSString *givenComponent = givenUrlComponents[idx];
         if ([routerComponent hasPrefix:@":"]) {
             NSString *key = [routerComponent substringFromIndex:1];
             [params setObject:givenComponent forKey:key];
         }
         else if (![routerComponent isEqualToString:givenComponent]) {
             params = nil;
             *stop = YES;
         }
     }];
    return params;
}

- (UIViewController *)controllerForRouterParams:(RouterParams *)params {
    SEL CONTROLLER_CLASS_SELECTOR = sel_registerName("allocWithRouterParams:");
    SEL CONTROLLER_SELECTOR = sel_registerName("initWithRouterParams:");
    UIViewController *controller = nil;
    Class controllerClass = params.routerOptions.openClass;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([controllerClass respondsToSelector:CONTROLLER_CLASS_SELECTOR]) {
        controller = [controllerClass performSelector:CONTROLLER_CLASS_SELECTOR withObject:[params controllerParams]];
    }
    else if ([params.routerOptions.openClass instancesRespondToSelector:CONTROLLER_SELECTOR]) {
        controller = [[params.routerOptions.openClass alloc] performSelector:CONTROLLER_SELECTOR withObject:[params controllerParams]];
    }
#pragma clang diagnostic pop
    if (!controller) {
        if (_ignoresExceptions) {
            return controller;
        }
        @throw [NSException exceptionWithName:@"RoutableInitializerNotFound"
                                       reason:[NSString stringWithFormat:INVALID_CONTROLLER_FORMAT, NSStringFromClass(controllerClass), NSStringFromSelector(CONTROLLER_CLASS_SELECTOR),  NSStringFromSelector(CONTROLLER_SELECTOR)]
                                     userInfo:nil];
    }
    
    controller.modalTransitionStyle = params.routerOptions.transitionStyle;
    return controller;
}

@end


