//
//  EimNotificationCenter.m
//  QQMSFContact
//
//  Created by Jason Qian on 12/1/14.
//
//

#import "EimNotificationCenter.h"
#import "EimNotificationCenterUtil.h"
#import <mach/mach_time.h>

#define EIMUINT_BIT  (CHAR_BIT * sizeof(NSUInteger))
#define EIMUINTROTATE(val, howmuch) \
((((NSUInteger)val) << howmuch) | (((NSUInteger)val) >> (EIMUINT_BIT - howmuch)))

#define EIMNOTIFICATIONCENTER_TIMECONSUMING_INVOKE_TRACE    0 // invoke time-consuming trace
#define EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE           0 // handle postNotification time-consuming trace

static BOOL IsEqualObject(id aObj, id bObj)
{
    if(!aObj && !bObj) {
        return YES;
    }
    else if(!aObj || !bObj) {
        return NO;
    }
    
    return [aObj isEqual: bObj];
}

double EimMachTimeToSecond(uint64_t time)
{
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    
    return (double)time * (double)timebase.numer /
    (double)timebase.denom /1e9;
}

#pragma mark -
#pragma mark EimNotification
@implementation EimNotification
- (instancetype)initWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo {
    self = [super init];
    if (self)
    {
        //name
        _name = nil;
        if (name) {
            _name = [name retain];
        }
        
        //object
        if (object) {
            _object = [object retain];
        }
        
        //userInfo
        _userInfo = nil;
        if (userInfo) {
            _userInfo = [userInfo retain];
        }
    }
    
    return self;
}

- (void)dealloc
{
    _RELEASE(_name);
    _RELEASE(_userInfo);
    _RELEASE(_object);
    
    [super dealloc];
}

- (BOOL)isEqual:(id)object
{
    eimMethod;
    if (!object || ![object isKindOfClass:[EimNotification class]]) {
        return NO;
    }
    
    EimNotification *aNotification = object;
    return IsEqualObject(self.name, aNotification.name) &&
    (self.object == aNotification.object) &&
    (self.userInfo == aNotification.userInfo);
}

- (NSString *)description
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    return [NSString stringWithFormat:
            @"EimNotification: [%"PRIuPTR"]\n<Name: %@>\n<Sender: %"PRIuPTR">\n<UserInfo: %@>",
            (uintptr_t)self,
            (_name ?: @"null"),
            ((_object != nil) ? (uintptr_t)_object: 0),
            (_userInfo ?: @"null")
            ];
#pragma clang diagnostic pop
}

@end


@implementation EimNotification (EimNotificationCreation)
+ (instancetype)notificationWithName:(NSString *)aName
                              object:(id)anObject
                            userInfo:(NSDictionary *)aUserInfo
{
    return [[[EimNotification alloc] initWithName:aName
                                           object:anObject
                                         userInfo:aUserInfo] autorelease];
}
@end

#pragma mark -
#pragma mark EimNotificationKey
//The Key for EimNotificationCenter map
//sender + name
@interface EimNotificationKey : NSObject <NSCopying> {
}
@property (nonatomic, copy)     NSString    *name;
@property (nonatomic, assign)   id          sender;

- (id)initWithSender:(id)aNotificationSender name:(NSString *)aNotificationName NS_DESIGNATED_INITIALIZER;
+ (EimNotificationKey *)keyForSender:(id)aNotificationSender name:(NSString *)aNotificationName;
@end

@implementation EimNotificationKey

#pragma mark ▇▇ Life Cycle
- (id)initWithSender:(id)aNotificationSender name:(NSString *)aNotificationName {
    eimMethod;
    if((self = [super init])) {
        _name   = [aNotificationName copy];
        _sender = aNotificationSender;
    }
    
    return self;
}

- (void)dealloc {
    eimMethod;
    _RELEASE(_name);
    _sender = nil;
    
    [super dealloc];
}

#pragma mark ▇▇ Interface
+ (EimNotificationKey *)keyForSender:(id)aNotificationSender name:(NSString *)aNotificationName {
    eimMethod;
    return [[[[self class] alloc] initWithSender:aNotificationSender name:aNotificationName] autorelease];
}

#pragma mark ▇▇ Override For KeyOfDictionary
//If the object plays the role of "key in dictionary"
//we should implement "copyWithZone", "isEqual:" and "hash"
- (id)copyWithZone:(NSZone *)zone {
    eimMethod;
    return [self retain];
}

- (NSUInteger)hash {
    eimMethod;
    return EIMUINTROTATE([_name hash], EIMUINT_BIT / 2) ^ (uintptr_t)_sender;
}

- (BOOL)isEqual:(id)object
{
    eimMethod;
    if (!object || ![object isKindOfClass:[EimNotificationKey class]]) {
        return NO;
    }
    
    EimNotificationKey *aKey = object;
    return IsEqualObject(self.name, aKey.name) && (self.sender == aKey.sender);
}

@end

#pragma mark -
#pragma mark EimNotificationObj
//The Object for EimNotificationCenter map
//observer + selector
@interface EimNotificationObj : NSObject {
    NSInvocation    *_invocation;
    
}
@property (nonatomic, copy)     NSString    *selectorString;
@property (nonatomic, assign)   id          observer;
@property (nonatomic, assign)   BOOL        exeOnMainThread;

- (BOOL)executeWithNotification:(EimNotification *)aEimNotification
                    willExecute:(void (^)())willExecuteBlock
                     didExecute:(void (^)())didExecuteBlock
                 otherArguments:(id)arg,...;

@end

@implementation EimNotificationObj

#pragma mark ▇▇ Life Cycle
- (instancetype)init {
    eimMethod;
    self = [super init];
    if (self) {
        _selectorString   = nil;
        _observer         = nil;
        _invocation       = nil;
    }
    return self;
}

- (id)initWithObserver:(id)aNotificationObserver selector:(NSString *)aSelectorName {
    eimMethod;
    
    return [self initWithObserver:aNotificationObserver
                         selector:aSelectorName executeOnMainThread:YES];
}

- (id)initWithObserver:(id)aNotificationObserver selector:(NSString *)aSelectorName
   executeOnMainThread:(BOOL)exeOnMainThread
{
    eimMethod;
    if((self = [self init])) {
        _selectorString     = [aSelectorName copy];
        _observer           = aNotificationObserver;
        _exeOnMainThread    = exeOnMainThread;
        
        NSInvocation *invocation = [[self class] invocationWithTarget:aNotificationObserver
                                                       selectorString:aSelectorName];
        if (invocation) {
            _invocation = [invocation retain];
        }
    }
    
    return self;
}

- (void)dealloc {
    eimMethod;
    
    _RELEASE(_invocation);
    _RELEASE(_selectorString);
    _observer = nil;
    
    [super dealloc];
}

#pragma mark ▇▇ Interface
+ (EimNotificationObj *)objForObserver:(id)aNotificationObserver
                              selector:(NSString *)aSelectorName
                   executeOnMainThread:(BOOL)execOnMainThread
{
    eimMethod;
    return [[[[self class] alloc] initWithObserver:aNotificationObserver
                                          selector:aSelectorName
                               executeOnMainThread:execOnMainThread] autorelease];
}

- (NSString *)description
{
    eimMethod;
    return [NSString stringWithFormat:@"pt:[%"PRIuPTR"]\nselector:[%@]\nobserver:[%@]\n",
            (uintptr_t)self,
            self.selectorString == nil ? @"null": self.selectorString,
            self.observer == nil ? @"null": self.observer];
}

- (void)setSelectorString:(NSString *)selectorString
{
    if (_selectorString == selectorString) {
        return;
    }
    
    @synchronized(self) {
        _selectorString = [selectorString retain];
        if (_invocation) {
            _RELEASE(_invocation);
        }
    }
}

- (void)setObserver:(id)observer
{
    if (_observer == observer) {
        return;
    }
    
    @synchronized(self) {
        _observer = observer;
        if (_invocation) {
            _RELEASE(_invocation);
        }
    }
}

#pragma mark ▇▇ Utility
+ (NSInvocation *)invocationWithTarget:(id)aTarget selectorString:(NSString *)aSelectorString
{
    if (!aTarget || !aSelectorString) {
        return nil;
    }
    
    NSMethodSignature   *sig        = nil;
    NSInvocation        *invocation = nil;
    SEL                 selector    = NULL;
    
    //convert selectorString to SEL
    selector = NSSelectorFromString(aSelectorString);
    if (selector == NULL) {
        eimLog(@"selectorString error");
        return nil;
    }
    
    //check SEL if valid
    if (![aTarget respondsToSelector:selector]) {
        eimLog(@"selector invalid");
        return nil;
    }
    
    //create sig
    sig = [[aTarget class] instanceMethodSignatureForSelector:selector];
    if (!sig) {
        eimLog(@"selectorString of observer invalid");
        return nil;
    }
    
    //create invocation
    invocation = [NSInvocation invocationWithMethodSignature:sig];
    if (!invocation) {
        eimLog(@"method sig invalid");
        return nil;
    }
    
    //configure invocation
    [invocation setTarget:aTarget];
    [invocation setSelector:selector];
    
    return invocation;
}

- (BOOL)executeWithNotification:(EimNotification *)aEimNotification
                    willExecute:(void (^)())willExecuteBlock
                     didExecute:(void (^)())didExecuteBlock
                 otherArguments:(id)arg,...
{
    id              eachObject   = nil;
    NSMutableArray  *arrArguList = nil;
    va_list         argumentList;
    
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_INVOKE_TRACE
    uint64_t arguTimeStart       = mach_absolute_time();
#endif
    if (arg) {
        arrArguList = [NSMutableArray arrayWithCapacity:0];
        [arrArguList addObject:arg];
        
        va_start(argumentList, arg);
        while ((eachObject = va_arg(argumentList, id))) {
            [arrArguList addObject: eachObject];
        }
        va_end(argumentList);
    }
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_INVOKE_TRACE
    uint64_t time = mach_absolute_time() - arguTimeStart;
    NSLog(@"\n[ArguTime: %g s]\n", EimMachTimeToSecond(time));
#endif
    
    if (self.exeOnMainThread && ![NSThread isMainThread])
    {
        __block EimNotificationObj *weakSelf = self;
        [EimNotificationCenterUtil dispatchOnMainThread:^{
            willExecuteBlock();
            [weakSelf executeWithNotification:aEimNotification arguList:arrArguList];
            didExecuteBlock();
        }];
        
        return YES;
    }
    
    willExecuteBlock();
    BOOL bExeResult = [self executeWithNotification:aEimNotification arguList:arrArguList];
    didExecuteBlock();
    
    return bExeResult;
}

- (BOOL)executeWithNotification:(EimNotification *)aEimNotification
                       arguList:(NSArray *)argList
{
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_INVOKE_TRACE
    uint64_t exeTimeStart       = mach_absolute_time();
    uint64_t invocationEnsure   = exeTimeStart;
#endif
    
    @synchronized(self) {
        eimMethod;
        //param check
        if (!self.observer || !self.selectorString ) {
            eimLog(@"param error");
            return NO;
        }
        
        if (![self.observer respondsToSelector:NSSelectorFromString(self.selectorString)]) {
            eimLog(@"unrecognized selector[%@] sent to instance[%@]",
                   self.selectorString, NSStringFromClass([self.observer class]));
            return NO;
        }
        
        if (!_invocation) {
            NSInvocation *invocation = [[self class] invocationWithTarget:self.observer
                                                           selectorString:self.selectorString];
            if (!invocation) {
                return NO;
            }
            
            _invocation = [invocation retain];
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_INVOKE_TRACE
            invocationEnsure = mach_absolute_time();
#endif
        }
        
        //insert parameters
        static NSUInteger nCustomizableParamIndex = 2;
        for (NSUInteger nLoop = nCustomizableParamIndex;
             nLoop < _invocation.methodSignature.numberOfArguments; nLoop++)
        {
            if (nLoop == nCustomizableParamIndex) {
                [_invocation setArgument:(__bridge void *)(&aEimNotification)
                                 atIndex:nLoop];
                continue;
            }
            
            id aArgument = NULL;
            if (argList && (nLoop > nCustomizableParamIndex) &&
                (nLoop - nCustomizableParamIndex - 1) < argList.count) {
                aArgument = argList[(nLoop - nCustomizableParamIndex - 1)];
            }
            
            if (aArgument != nil) {
                [_invocation setArgument:&aArgument atIndex:nLoop];
                continue;
            }
            
            id emptyArgu = [NSNull null];
            [_invocation setArgument:&emptyArgu atIndex:nLoop];
        }
        
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_INVOKE_TRACE
        uint64_t arguEnd = mach_absolute_time();
#endif
        
        //as each time we insert new arguments,
        //so its not necessary to cache any arguments earlier.
        //    [_invocation retainArguments];
        
        //
        //Invoke
        [_invocation invoke];
        
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_INVOKE_TRACE
        uint64_t timeInvoke = mach_absolute_time() - arguEnd;
        uint64_t time = mach_absolute_time() - exeTimeStart;
        
        NSLog(@"\n[Time: %g s]\n[invocEnsure:%.2f%%], [argu:%.2f%%], [invoke:%.2f%%]\n",
              EimMachTimeToSecond(time),
              (float)((invocationEnsure - exeTimeStart)*100)/(float)time,
              (float)(arguEnd - invocationEnsure)*100/(float)time,
              (float)timeInvoke*100/(float)time);
#endif
        
        return YES;
    }
}

@end

#pragma mark -
#pragma mark EimNotificationBlock
//The Block for EimNotificationCenter map
//block + queue
@interface EimNotificationBlock : NSObject {
}

@property (nonatomic, copy)     void                    (^ block)(EimNotification *note);
@property (nonatomic, retain)   id<NSCopying, NSObject> notificationKey;
@property (nonatomic, assign)   BOOL        exeOnMainThread;
@end

@implementation EimNotificationBlock

#pragma mark ▇▇ Life Cycle
- (instancetype)init {
    eimMethod;
    self = [super init];
    if (self) {
        _block              = NULL;
        _notificationKey    = nil;
        _exeOnMainThread    = YES;
    }
    return self;
}

- (id)initWithBlock:(void(^)(EimNotification *note))aBlock
             forKey:(id <NSCopying, NSObject>)aNotificationKey
executeOnMainThread:(BOOL)execOnMainThread
{
    eimMethod;
    if((self = [self init])) {
        if (aBlock) {
            _block = Block_copy(aBlock);
        }
        
        if (aNotificationKey) {
            _notificationKey = [aNotificationKey retain];
        }
        
        _exeOnMainThread = execOnMainThread;
    }
    
    return self;
}

- (void)dealloc {
    eimMethod;
    if (_block) {
        Block_release(_block);
        _block = NULL;
    }
    
    if (_notificationKey) {
        _RELEASE(_notificationKey);
    }
    
    [super dealloc];
}

- (void)executeWithNotification:(EimNotification *)aEimNotification
                    willExecute:(void (^)())willExecuteBlock
                     didExecute:(void (^)())didExecuteBlock

{
    if (self.exeOnMainThread && ![NSThread isMainThread]) {
        __block EimNotificationBlock *weakSelf = self;
        [EimNotificationCenterUtil dispatchOnMainThread:^{
            [weakSelf executeWithNotification:aEimNotification
                                  willExecute:willExecuteBlock
                                   didExecute:didExecuteBlock];
        }];
        
        return;
    }
    
    willExecuteBlock();
    self.block(aEimNotification);
    didExecuteBlock();
}

#pragma mark ▇▇ Interface
+ (EimNotificationBlock *)blockObjForBlock:(void(^)(EimNotification *note))aBlock
                                    forKey:(id <NSCopying, NSObject>)aNotificationKey
                       executeOnMainThread:(BOOL)execOnMainThread
{
    eimMethod;
    return [[[[self class] alloc] initWithBlock:aBlock
                                         forKey:aNotificationKey
                            executeOnMainThread:execOnMainThread] autorelease];
}

@end

#pragma mark -
#pragma mark EimNotificationRemoveObj
@interface EimNotificationRemoveObj : NSObject {
}

@property (nonatomic, assign)   id          observer;
@property (nonatomic, copy)     NSString    *name;
@property (nonatomic, assign)   id          sender;
@end

@implementation EimNotificationRemoveObj

- (void)dealloc
{
    _observer = nil;
    _sender   = nil;
    _RELEASE(_name);
    
    [super dealloc];
}

@end

#pragma mark -
#pragma mark EimNotificationCenter
typedef enum EimNotificationObjSearch: NSUInteger {
    kEimNotificationObjSearchForLoop,
    kEimNotificationObjSearchForInLoop,
    kEimNotificationObjSearchEnumerationLoop,
}EimNotificationObjSearchEnum;

@interface EimNotificationCenter() {
    // obj: nsarray with EimNotificationObj element,
    // key: EimNotificationKey obj
    NSMutableDictionary *_mainMap;
    
    // posting threads
    NSMutableSet        *_callbackThreads;
}

@end

static EimNotificationCenter *g_instance = nil;
@implementation EimNotificationCenter

#pragma mark ▇▇ Singleton Init
+ (EimNotificationCenter *)defaultCenter
{
    eimMethod;
    //maybe anyone alloc the object with "alloc" method
    //instead of invoking "defaultCenter"
    if (g_instance) {
        return g_instance;
    }
    
    static  dispatch_once_t           onceCenter  = 0;
    dispatch_once(&onceCenter, ^{
        g_instance = [[EimNotificationCenter alloc] init];
    });
    
    return g_instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone
{
    eimMethod;
    @synchronized(self) {
        if (!g_instance) {
            g_instance = [super allocWithZone:zone];
        }
    }
    
    return g_instance;
}

- (id)copyWithZone:(NSZone *)zone {
    eimMethod;
    return self;
}

- (id)retain {
    eimMethod;
    return self;
}

- (oneway void)release {
    eimMethod;
}

- (id)autorelease {
    eimMethod;
    return self;
}

- (NSUInteger)retainCount {
    eimMethod;
    return NSUIntegerMax;
}

- (void)reset {
    eimMethod;
    _RELEASE(_asynNotificationQueue);
    _RELEASE(_callbackThreads);
    
    _callbackThreads         = [[NSMutableSet alloc] initWithCapacity:0];
    
    //for asynNotification
    _asynNotificationQueue  = [[NSMutableArray alloc] initWithCapacity:0];
}

#pragma mark ▇▇ LifeCycle
- (id) init
{
    eimMethod;
    self = [super init];
    if (self) {
        _mainMap                = [[NSMutableDictionary alloc] initWithCapacity:0];
        [self reset];
    }
    
    return self;
}

- (void)dealloc
{
    eimMethod;
    _RELEASE(_mainMap);
    _RELEASE(_asynNotificationQueue);
    [super dealloc];
}

+ (EimNotificationObjSearchEnum)traversalNotificationObjType {
    return kEimNotificationObjSearchForInLoop;
}

#pragma mark ▇▇ Interface::Add
- (void)addObserver:(id)notificationObserver selector:(SEL)notificationSelector
               name:(NSString *)notificationName
             object:(id)notificationSender
{
    return [self addObserver:notificationObserver
                    selector:notificationSelector
                        name:notificationName
                      object:notificationSender
           forceOnMainthread:NO];
}

- (void)addObserver:(id)notificationObserver selector:(SEL)notificationSelector
               name:(NSString *)notificationName
             object:(id)notificationSender
  forceOnMainthread:(BOOL)bOnMainThread
{
    eimMethod;
    //key
    EimNotificationKey *aKey = [EimNotificationKey keyForSender:notificationSender
                                                           name:notificationName];
    if (!aKey) {
        return;
    }
    
    NSMutableArray      *arrObj     = nil;
    EimNotificationObj  *aElement   = nil;
    
    @synchronized(self) {
        //check obj for the key
        id aObj = [_mainMap objectForKey:aKey];
        if (!aObj || ![aObj isKindOfClass:[NSMutableArray class]]) {
            arrObj = [NSMutableArray arrayWithCapacity:0];
            [_mainMap setObject:arrObj forKey:aKey];
        }
        else {
            arrObj = (NSMutableArray *)aObj;
        }
        
        //element for array
        NSString *selectorName = nil;
        if (notificationSelector != NULL) {
            selectorName = NSStringFromSelector(notificationSelector);
        }
        aElement = [EimNotificationObj objForObserver:notificationObserver
                                             selector:selectorName
                                  executeOnMainThread:bOnMainThread];
        if (aElement) {
            [arrObj addObject:aElement];
        }
    }
}

- (id<NSObject>)addObserverForName:(NSString *)notificationName
                            object:(id)notificationSender
                        usingBlock:(void (^)(EimNotification *note))block
{
    return [self addObserverForName:notificationName
                             object:notificationSender
                         usingBlock:block
                  forceOnMainthread:NO];
}

- (id<NSObject>)addObserverForName:(NSString *)notificationName
                            object:(id)notificationSender
                        usingBlock:(void (^)(EimNotification *note))block
                 forceOnMainthread:(BOOL)bOnMainThread
{
    eimMethod;
    //key
    EimNotificationKey *aKey = [EimNotificationKey keyForSender:notificationSender
                                                           name:notificationName];
    if (!aKey) {
        return nil;
    }
    
    NSMutableArray          *arrObj     = nil;
    EimNotificationBlock    *aElement   = nil;
    
    @synchronized(self) {
        //check obj for the key
        id aObj = [_mainMap objectForKey:aKey];
        if (!aObj || ![aObj isKindOfClass:[NSMutableArray class]]) {
            arrObj = [NSMutableArray arrayWithCapacity:0];
            [_mainMap setObject:arrObj forKey:aKey];
        }
        else {
            arrObj = (NSMutableArray *)aObj;
        }
        
        //element for array
        aElement = [EimNotificationBlock blockObjForBlock:block
                                                   forKey:aKey
                                      executeOnMainThread:bOnMainThread];
        if (aElement) {
            [arrObj addObject:aElement];
        }
    }
    
    return aElement;
}

#pragma mark ▇▇ Interface::Remove
- (void)removeObserver:(id)notificationObserver
{
    eimMethod;
    if (!notificationObserver) {
        return;
    }
    
    [self removeObserver:notificationObserver
                    name:nil
                  object:nil];
}

- (void)removeObserver:(id)notificationObserver
                  name:(NSString *)notificationName
                object:(id)notificationSender
{
    eimMethod;
    
    EimNotificationRemoveObj *aRemoveObj = [[[EimNotificationRemoveObj alloc] init] autorelease];
    aRemoveObj.observer = notificationObserver;
    aRemoveObj.name     = notificationName;
    aRemoveObj.sender   = notificationSender;
    
    if ([self isThreadInPostingQueue:[EimNotificationCenterUtil currentThreadID]]) {
        [self performSelector:@selector(removeObserverAsyn:)
                   withObject:aRemoveObj afterDelay:0.0f];
        return;
    };
    
    [self removeObserverAsyn:aRemoveObj];
}

- (void)removeObserverAsyn:(EimNotificationRemoveObj *)aRemoveObj
{
    eimMethod;
    if (!aRemoveObj) {
        return;
    }
    
    id notificationObserver     = aRemoveObj.observer;
    id notificationSender       = aRemoveObj.sender;
    NSString *notificationName  = aRemoveObj.name;
    
    //remove for block
    if (notificationObserver && [notificationObserver isKindOfClass:[EimNotificationBlock class]]) {
        return [self removeBlockObserver:((EimNotificationBlock *)notificationObserver)];
    }
    
    //remove for obj
    [self removeObjObserver:notificationObserver
                       name:notificationName
                     object:notificationSender];
}

#pragma mark ▇▇ Interface::Post
- (void)postNotification:(EimNotification *)notificationName {
    eimMethod;
    [self postNotificationName:notificationName.name
                        object:notificationName.object
                      userInfo:notificationName.userInfo];
}

- (void)postNotificationName:(NSString *)notificationName
                      object:(id)notificationSender
{
    eimMethod;
    [self postNotificationName:notificationName
                        object:notificationSender
                      userInfo:nil];
}

- (void)postNotificationName:(NSString *)notificationName
                      object:(id)notificationSender
                    userInfo:(NSDictionary *)userInfo
{
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
    uint64_t postTimeStart = mach_absolute_time();
#endif
    eimMethod;
    if (!_mainMap || !notificationName) {
        return;
    }
    
    //key and fetch value
    id aObj = [self valueForNotificationName:notificationName object:notificationSender];
    if (!aObj || ![aObj isKindOfClass:[NSMutableArray class]] || ((NSArray *)aObj).count <= 0) {
        return;
    }
    
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
    uint64_t objTimeEnd = mach_absolute_time();
#endif
    
    __block __uint64_t              threadID    = 0;
    __block EimNotificationCenter   *weakSelf   = self;
    __block EimNotification *aNotification = [EimNotification notificationWithName:notificationName
                                                                            object:notificationSender
                                                                          userInfo:userInfo];
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
    uint64_t objEIMNotificationEnd = mach_absolute_time();
    __block uint64_t invokeSpare        = 0;
    __block uint64_t blockSpare         = 0;
    __block uint64_t findObjSpare       = 0;
    __block uint64_t findObjEnd         = 0;
    __block uint64_t findObjStart       = 0;
#endif
    switch ([[self class] traversalNotificationObjType]) {
        case kEimNotificationObjSearchEnumerationLoop:
        {
            [((NSMutableArray *)aObj) enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
             {
                 if (!obj) {
                     return;
                 }
                 
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
                 findObjEnd = mach_absolute_time();
                 if (findObjSpare == 0) {
                     findObjSpare += (findObjEnd - objEIMNotificationEnd);
                 }
                 else {
                     findObjSpare += (findObjEnd - findObjStart);
                 }
#endif
                 
                 if ([obj isKindOfClass:[EimNotificationBlock class]])
                 {
                     //
                     // block
                     [((EimNotificationBlock *)obj) executeWithNotification:aNotification
                                                                willExecute:
                      ^{
                          //add current thread to posting queue
                          //avoid remove observer while posting it
                          threadID = [EimNotificationCenterUtil currentThreadID];
                          [weakSelf addToCallbackThreadQueue:threadID];
                      }
                                                                 didExecute:
                      ^{
                          //remove current thread to posting queue
                          //means post end.
                          [weakSelf removeFromCallbackThreadQueue:threadID];
                      }];
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
                     blockSpare += (mach_absolute_time() - findObjEnd);
#endif
                 }
                 else if ([obj isKindOfClass:[EimNotificationObj class]]) { // _cmd
                     [((EimNotificationObj *)obj) executeWithNotification:aNotification
                                                              willExecute:
                      ^{
                          //add current thread to posting queue
                          //avoid remove observer while posting it
                          threadID = [EimNotificationCenterUtil currentThreadID];
                          [self addToCallbackThreadQueue:threadID];
                      }
                                                               didExecute:
                      ^{
                          //remove current thread to posting queue
                          //means post end.
                          [self removeFromCallbackThreadQueue:threadID];
                      }
                                                           otherArguments:nil];
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
                     invokeSpare += (mach_absolute_time() - findObjEnd);
#endif
                 }
                 
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
                 findObjStart = mach_absolute_time();
#endif
             }];
            
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
            findObjEnd = mach_absolute_time();
            findObjSpare += (findObjEnd - findObjStart);
#endif
            break;
        }
        case kEimNotificationObjSearchForInLoop:
        {
            int nLoopIndex = 0;
            for (id obj in ((NSMutableArray *)aObj))
            {
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
                findObjEnd = mach_absolute_time();
                if (nLoopIndex == 0) {
                    findObjSpare += (findObjEnd - objEIMNotificationEnd);
                }
                else {
                    findObjSpare += (findObjEnd - findObjStart);
                }
#endif
                if ([obj isKindOfClass:[EimNotificationBlock class]]) { // block
                    //
                    // block
                    [((EimNotificationBlock *)obj) executeWithNotification:aNotification
                                                               willExecute:
                     ^{
                         //add current thread to posting queue
                         //avoid remove observer while posting it
                         threadID = [EimNotificationCenterUtil currentThreadID];
                         [weakSelf addToCallbackThreadQueue:threadID];
                     }
                                                                didExecute:
                     ^{
                         //remove current thread to posting queue
                         //means post end.
                         [weakSelf removeFromCallbackThreadQueue:threadID];
                     }];
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
                    blockSpare += (mach_absolute_time() - findObjEnd);
#endif
                }
                else if ([obj isKindOfClass:[EimNotificationObj class]]) { // _cmd
                    [((EimNotificationObj *)obj) executeWithNotification:aNotification
                                                             willExecute:
                     ^{
                         //add current thread to posting queue
                         //avoid remove observer while posting it
                         threadID = [EimNotificationCenterUtil currentThreadID];
                         [self addToCallbackThreadQueue:threadID];
                     }
                                                              didExecute:
                     ^{
                         //remove current thread to posting queue
                         //means post end.
                         [self removeFromCallbackThreadQueue:threadID];
                     }
                                                          otherArguments:nil];
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
                    invokeSpare += (mach_absolute_time() - findObjEnd);
#endif
                }
                
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
                findObjStart = mach_absolute_time();
#endif
                nLoopIndex++;
            }
            
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
            findObjEnd = mach_absolute_time();
            findObjSpare += (findObjEnd - findObjStart);
#endif
            break;
        }
        default:
            break;
    }
    
#if EIMNOTIFICATIONCENTER_TIMECONSUMING_TRACE
    uint64_t time = mach_absolute_time() - postTimeStart;
    NSLog(@"\n[Time: %g s]\n[obj:%.2f%%], [notiobj:%.2f%%]\n[findobj:%.2f%%]\n[invoke:%.2f%%], [block:%.2f%%]\n",
          EimMachTimeToSecond(time),
          (float)(objTimeEnd - postTimeStart)*100/(float)time,
          (float)(objEIMNotificationEnd - objTimeEnd)*100/(float)time,
          (float)findObjSpare*100/(float)time,
          (float)invokeSpare*100/(float)time, (float)blockSpare*100/(float)time);
#endif
}

#pragma mark ▇▇ Util
- (void)removeBlockObserver:(EimNotificationBlock *)aNotificationBlock
{
    eimMethod;
    if (!aNotificationBlock || !_mainMap) {
        return;
    }
    
    id<NSCopying> forkey = aNotificationBlock.notificationKey;
    if (!forkey) {
        return;
    }
    
    @synchronized(self){
        id aObj = [_mainMap objectForKey:forkey];
        if (aObj && [aObj isKindOfClass:[NSMutableArray class]])
        {
            [((NSMutableArray *)aObj) removeObject:aNotificationBlock];
            
            //if empty, then clear
            if (((NSMutableArray *)aObj).count == 0) {
                [_mainMap removeObjectForKey:forkey];
            }
        }
    }
}

- (void)removeObjObserver:(id)notificationObserver
{
    eimMethod;
    if (!notificationObserver || !_mainMap) {
        return;
    }
    
    @synchronized(self)
    {
        NSMutableArray *arrKeysToRemove = [NSMutableArray arrayWithCapacity:_mainMap.count];
        [_mainMap enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent
                                          usingBlock:^(id key, id value, BOOL *stop)
         {
             if (![value isKindOfClass:[NSMutableArray class]]) {
                 return;
             }
             
             //run loop for 'arrTemp', and handle the true array.
             //to avoid the crash for "XXX was mutated while being enumerated"
             //Reference: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Collections/Articles/Enumerators.html
             NSArray *arrTemp = [NSArray arrayWithArray:((NSMutableArray *)value)];
             for (id aObj in arrTemp)
             {
                 if (![aObj isKindOfClass:[EimNotificationObj class]]) {
                     continue;
                 }
                 
                 if (((EimNotificationObj *)aObj).observer == notificationObserver) {
                     [((NSMutableArray *)value) removeObject:((EimNotificationObj *)aObj)];
                 }
             }
             
             //if empty, then need clear
             //collect all keys to remove delay.
             //to avoid the crash for "XXX was mutated while being enumerated"
             //Reference: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Collections/Articles/Enumerators.html
             if (((NSMutableArray *)value).count == 0) {
                 [arrKeysToRemove addObject:key];
                 return;
             }
         }];
        
        //remove
        if (arrKeysToRemove.count > 0) {
            [_mainMap removeObjectsForKeys:arrKeysToRemove];
        }
    }
}

- (void)removeObjObserver:(id)notificationObserver
                     name:(NSString *)notificationName
                   object:(id)notificationSender
{
    eimMethod;
    if (!notificationObserver || !_mainMap) {
        return;
    }
    
    if (!notificationName && !notificationSender) {
        [self removeObjObserver:notificationObserver];
        return;
    }
    
    //key hash
    NSUInteger          keyHash = 0;
    EimNotificationKey  *aKey   = [EimNotificationKey keyForSender:notificationSender
                                                              name:notificationName];
    if (aKey) {
        keyHash = [aKey hash];
    }
    
    if (!keyHash) {
        return;
    }
    
    //remove for obj
    @synchronized(self){
        NSMutableArray *arrKeysToRemove = [NSMutableArray arrayWithCapacity:_mainMap.count];
        [_mainMap enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent
                                          usingBlock:^(id key, id value, BOOL *stop)
         {
             if (![key isKindOfClass:[EimNotificationKey class]]) {
                 return;
             }
             
             if ([key hash] != keyHash) {
                 return;
             }
             
             //run loop for 'arrTemp', and handle the true array.
             //to avoid the crash for "XXX was mutated while being enumerated"
             //Reference: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Collections/Articles/Enumerators.html
             NSArray *arrTemp = [NSArray arrayWithArray:((NSMutableArray *)value)];
             for (id aObj in arrTemp)
             {
                 if (![aObj isKindOfClass:[EimNotificationObj class]]) {
                     continue;
                 }
                 
                 if (((EimNotificationObj *)aObj).observer == notificationObserver) {
                     [((NSMutableArray *)value) removeObject:((EimNotificationObj *)aObj)];
                 }
             }
             
             //if empty, then need clear
             //collect all keys to remove delay.
             //to avoid the crash for "XXX was mutated while being enumerated"
             //Reference: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Collections/Articles/Enumerators.html
             if (((NSMutableArray *)value).count == 0) {
                 [arrKeysToRemove addObject:key];
                 return;
             }
         }];
        
        //remove
        if (arrKeysToRemove.count > 0) {
            [_mainMap removeObjectsForKeys:arrKeysToRemove];
        }
    }
}

- (id)valueForNotificationName:(NSString *)notificationName
                        object:(id)notificationSender
{
    EimNotificationKey *fullKey     = nil;
    EimNotificationKey *senderKey   = nil;
    
    if (!notificationName) {
        return nil;
    }
    
    senderKey = [EimNotificationKey keyForSender:notificationSender
                                            name:notificationName];
    //if "sender != nil", we need get a Key for "sender == nil" situation
    if (notificationSender) {
        fullKey = [EimNotificationKey keyForSender:nil
                                              name:notificationName];
    }
    
    //avoid param invalid
    if (!senderKey && !fullKey) {
        return nil;
    }
    
    //avoid fullkey isequal to senderKey
    if (senderKey && fullKey && [senderKey isEqual:fullKey]) {
        fullKey = nil;
    }
    
    //obj get
    NSMutableArray  *arrValues  = [NSMutableArray arrayWithCapacity:0];
    @synchronized(self)
    {
        id senderObj   = nil;
        id fullObj     = nil;
        
        if (senderKey) {
            senderObj = [_mainMap objectForKey:senderKey];
        }
        
        if (fullKey) {
            fullObj = [_mainMap objectForKey:fullKey];
        }
        
        //union
        if (senderObj && [senderObj isKindOfClass:[NSArray class]] && ((NSArray *)senderObj).count > 0) {
            [arrValues addObjectsFromArray:((NSArray *)senderObj)];
        }
        if (fullObj && [fullObj isKindOfClass:[NSArray class]] && ((NSArray *)fullObj).count > 0) {
            [arrValues addObjectsFromArray:((NSArray *)fullObj)];
        }
    }
    
    return arrValues;
}

- (BOOL)isThreadInPostingQueue:(__uint64_t)aThreadID
{
    if (aThreadID <= 0) {
        return NO;
    }
    
    @synchronized(self) {
        if (!_callbackThreads) {
            return YES; //if posting queue nil, we should think it's in posting status.
        }
        
        NSString *strThreadID = [NSString stringWithFormat:@"%llu", aThreadID];
        return [_callbackThreads containsObject:strThreadID];
    }
}

- (void)addToCallbackThreadQueue:(__uint64_t)aThreadID
{
    @synchronized(self) {
        if (!_callbackThreads) {
            _callbackThreads = [[NSMutableSet alloc] initWithCapacity:0];
        }
        
        NSString *strThreadID = [NSString stringWithFormat:@"%llu", aThreadID];
        [_callbackThreads addObject:strThreadID];
    }
}

- (void)removeFromCallbackThreadQueue:(__uint64_t)aThreadID
{
    @synchronized(self) {
        if (!_callbackThreads || aThreadID <= 0) {
            return;
        }
        
        NSString *strThreadID = [NSString stringWithFormat:@"%llu", aThreadID];
        if ([_callbackThreads containsObject:strThreadID]) {
            [_callbackThreads removeObject:strThreadID];
        }
    }
}


@end
