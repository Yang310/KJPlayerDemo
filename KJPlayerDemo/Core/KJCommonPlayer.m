//
//  KJCommonPlayer.m
//  KJPlayerDemo
//
//  Created by 杨科军 on 2021/2/10.
//  Copyright © 2021 杨科军. All rights reserved.
//  https://github.com/yangKJ/KJPlayerDemo

#import "KJCommonPlayer.h"

@implementation KJCommonPlayer
PLAYER_COMMON_PROPERTY
static KJCommonPlayer *_instance = nil;
static dispatch_once_t onceToken;
+ (instancetype)kj_sharedInstance{
    dispatch_once(&onceToken, ^{
        if (_instance == nil) {
            _instance = [[self alloc] init];
        }
    });
    return _instance;
}
+ (void)kj_attempDealloc{
    onceToken = 0;
    _instance = nil;
}

- (instancetype)init{
    if (self == [super init]) {
        NSNotificationCenter * defaultCenter = [NSNotificationCenter defaultCenter];
        [defaultCenter addObserver:self selector:@selector(kj_playerAppDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [defaultCenter addObserver:self selector:@selector(kj_playerAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        //kvo
        NSKeyValueObservingOptions options = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
        [self addObserver:self forKeyPath:@"state" options:options context:nil];
        [self addObserver:self forKeyPath:@"progress" options:options context:nil];
        [self addObserver:self forKeyPath:@"loadState" options:options context:nil];
    }
    return self;
}
- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - NSNotification
//进入后台
- (void)kj_playerAppDidEnterBackground:(NSNotification *)notification{
    if (self.backgroundPause) {
        [self kj_playerPause];
    }else{
//        AVAudioSession * session = [AVAudioSession sharedInstance];
//        [session setCategory:AVAudioSessionCategoryPlayback error:nil];
//        [session setActive:YES error:nil];
    }
}
//进入前台
- (void)kj_playerAppWillEnterForeground:(NSNotification *)notification{
    if (self.roregroundResume && self.userPause == NO && ![self isPlaying]) {
        [self kj_playerResume];
    }
}

#pragma mark - kvo
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
//    NSLog(@"监听到%@对象的%@属性发生了改变， %@", object, keyPath, change);
    if ([keyPath isEqualToString:@"state"]) {
        if (change[@"new"] != change[@"old"]) {
            if ([self.delegate respondsToSelector:@selector(kj_player:state:)]) {
                KJPlayerState st = (KJPlayerState)[change[@"new"] intValue];
                [self.delegate kj_player:self state:st];
            }
        }
    }else if ([keyPath isEqualToString:@"loadState"]) {
        if (change[@"new"] != change[@"old"]) {
            if ([self.delegate respondsToSelector:@selector(kj_player:loadstate:)]) {
                KJPlayerLoadState st = (KJPlayerLoadState)[change[@"new"] intValue];
                [self.delegate kj_player:self loadstate:st];
            }
        }
    }else if ([keyPath isEqualToString:@"progress"]) {
        if (change[@"new"] != change[@"old"]) {
            if ([self.delegate respondsToSelector:@selector(kj_player:loadProgress:)]) {
                [self.delegate kj_player:self loadProgress:[change[@"new"] floatValue]];
            }
        }
    }else{
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
#pragma mark - public method
/* 准备播放 */
- (void)kj_playerPlay{ }
/* 重播 */
- (void)kj_playerReplay{ }
/* 继续 */
- (void)kj_playerResume{ }
/* 暂停 */
- (void)kj_playerPause{ }
/* 停止 */
- (void)kj_playerStop{ }

#pragma mark - private method
// 获取当前的旋转状态
NS_INLINE CGAffineTransform kPlayerDeviceOrientation(void){
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (orientation == UIInterfaceOrientationPortrait) {
        return CGAffineTransformIdentity;
    }else if (orientation == UIInterfaceOrientationLandscapeLeft) {
        return CGAffineTransformMakeRotation(-M_PI_2);
    }else if (orientation == UIInterfaceOrientationLandscapeRight) {
        return CGAffineTransformMakeRotation(M_PI_2);
    }
    return CGAffineTransformIdentity;
}
// 寻找响应者
NS_INLINE __kindof UIResponder * kPlayerLookupResponder(Class clazz, UIView *view){
    __kindof UIResponder *_Nullable next = view.nextResponder;
    while (next != nil && [next isKindOfClass:clazz] == NO) {
        next = next.nextResponder;
    }
    return next;
}

@end
