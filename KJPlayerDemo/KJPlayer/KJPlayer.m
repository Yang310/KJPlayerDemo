//
//  KJPlayer.m
//  KJPlayerDemo
//
//  Created by 杨科军 on 2021/1/9.
//  Copyright © 2021 杨科军. All rights reserved.
//  https://github.com/yangKJ/KJPlayerDemo

#import "KJPlayer.h"
#import "KJPlayer+KJCache.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"

@interface KJPlayer()
@property (nonatomic,strong) NSObject *timeObserver;
@property (nonatomic,strong) AVPlayerLayer *playerLayer;
@property (nonatomic,strong) AVPlayerItem *playerItem;
@property (nonatomic,strong) AVPlayer *player;
@property (nonatomic,assign) NSTimeInterval currentTime,totalTime;
@property (nonatomic,assign) NSTimeInterval tryTime;
@property (nonatomic,assign) KJPlayerState state;
@property (nonatomic,assign) float progress;
@property (nonatomic,copy,readwrite) void(^tryTimeBlock)(BOOL end);
@property (nonatomic,assign) BOOL tryLooked;
@property (nonatomic,assign) BOOL buffered;
@end
@implementation KJPlayer
PLAYER_COMMON_PROPERTY
static NSString * const kStatus = @"status";
static NSString * const kLoadedTimeRanges = @"loadedTimeRanges";
static NSString * const kPresentationSize = @"presentationSize";
static NSString * const kPlaybackBufferEmpty = @"playbackBufferEmpty";
static NSString * const kPlaybackLikelyToKeepUp = @"playbackLikelyToKeepUp";
static NSString * const kTimeControlStatus = @"timeControlStatus";
- (instancetype)init{
    if (self == [super init]) {
        _cacheTime = 5.;
        _speed = 1.;
        _autoPlay = YES;
        _videoGravity = KJPlayerVideoGravityResizeAspect;
        _background = UIColor.blackColor.CGColor;
        _timeSpace = 1.;
        self.group = dispatch_group_create();
    }
    return self;
}
- (void)dealloc {
    [self kj_destroyPlayer];
    if (_playerView) [self.playerLayer removeFromSuperlayer];
}

#pragma mark - kvo
static CGSize tempSize;
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:kStatus]) {
        if (playerItem.status == AVPlayerStatusReadyToPlay) {
            if (self.totalTime <= 0) {
                NSTimeInterval sec = CMTimeGetSeconds(playerItem.duration);
                if (isnan(sec) || sec < 0) sec = 0;
                self.totalTime = sec;
                if (self.kVideoTotalTime) {
                    self.kVideoTotalTime(self.totalTime);
                }
            }
            self.state = KJPlayerStatePreparePlay;
            if (self.skipHeadTime) {
                if (self.autoPlay && self.userPause == NO) {
                    self.kVideoAdvanceAndReverse(self.skipHeadTime,nil);
                }
            }else{
                [self kj_autoPlay];
            }
        }else if (playerItem.status == AVPlayerItemStatusFailed || playerItem.status == AVPlayerItemStatusUnknown) {
            self.ecode = KJPlayerErrorCodeOtherSituations;
            self.state = KJPlayerStateFailed;
        }
    }else if ([keyPath isEqualToString:kLoadedTimeRanges]) {
        [self kj_kvoLoadedTimeRanges:playerItem];
    }else if ([keyPath isEqualToString:kPresentationSize]) {
        if (!CGSizeEqualToSize(playerItem.presentationSize, tempSize)) {
            tempSize = playerItem.presentationSize;
            if (self.kVideoSize) self.kVideoSize(tempSize);
        }
    }else if ([keyPath isEqualToString:kPlaybackBufferEmpty]) {
        if (playerItem.playbackBufferEmpty) {
//            [self kj_autoPlay];
        }
    }else if ([keyPath isEqualToString:kPlaybackLikelyToKeepUp]) {
        if (playerItem.playbackLikelyToKeepUp) {
            self.buffered = YES;
        }
    }else if ([keyPath isEqualToString:kTimeControlStatus]) {
        
    }else{
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
//监听播放器缓冲进度
- (void)kj_kvoLoadedTimeRanges:(AVPlayerItem*)playerItem{
    if (self.locality || self.cache) return;
    CMTimeRange ranges = [[playerItem loadedTimeRanges].firstObject CMTimeRangeValue];
    CGFloat start = CMTimeGetSeconds(ranges.start);
    CGFloat duration = CMTimeGetSeconds(ranges.duration);
    CGFloat totalDuration = CMTimeGetSeconds(playerItem.duration);
    self.progress = MIN((start + duration) / totalDuration, 1);
    if ((start + duration - self.cacheTime) >= self.currentTime ||
        (totalDuration - self.currentTime) <= self.cacheTime) {
        [self kj_autoPlay];
    }else{
        [self.player pause];
        self.state = KJPlayerStateBuffering;
    }
}
//自动播放
- (void)kj_autoPlay{
    if (self.autoPlay && self.userPause == NO) {
        [self kj_playerPlay];
    }
}
#pragma mark - 定时器
//监听时间变化
- (void)kj_addTimeObserver{
    if (self.player == nil) return;
    if (self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        _timeObserver = nil;
    }
    PLAYER_WEAKSELF;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(_timeSpace, NSEC_PER_SEC) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        NSTimeInterval sec = CMTimeGetSeconds(time);
        if (isnan(sec) || sec < 0) sec = 0;
        weakself.currentTime = sec;
        if (weakself.totalTime <= 0) return;
        if ((NSInteger)weakself.currentTime >= (NSInteger)weakself.totalTime) {
            [weakself.player pause];
            weakself.state = KJPlayerStatePlayFinished;
            if ([weakself.delegate respondsToSelector:@selector(kj_player:currentTime:totalTime:)]) {
                [weakself.delegate kj_player:weakself currentTime:weakself.totalTime totalTime:weakself.totalTime];
            }
            weakself.currentTime = 0;
        }else if (weakself.userPause == NO && weakself.buffered) {
            weakself.state = KJPlayerStatePlaying;
            if ([weakself.delegate respondsToSelector:@selector(kj_player:currentTime:totalTime:)]) {
                [weakself.delegate kj_player:weakself currentTime:weakself.currentTime totalTime:weakself.totalTime];
            }
        }
        if (weakself.currentTime > weakself.tryTime && weakself.tryTime) {
            [weakself kj_playerPause];
            if (!weakself.tryLooked) {
                weakself.tryLooked = YES;
                if (weakself.tryTimeBlock) weakself.tryTimeBlock(true);
            }
        }else{
            weakself.tryLooked = NO;
        }
    }];
}
#pragma mark - public method
/* 准备播放 */
- (void)kj_playerPlay{
    if (self.player == nil || self.tryLooked) return;
    [self.player play];
    self.player.muted = self.muted;
    self.player.rate = self.speed;
    self.userPause = NO;
}
/* 重播 */
- (void)kj_playerReplay{
    PLAYER_WEAKSELF;
    [self.player seekToTime:CMTimeMakeWithSeconds(self.skipHeadTime, NSEC_PER_SEC) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        if (finished) [weakself kj_playerPlay];
    }];
}
/* 继续 */
- (void)kj_playerResume{
    [self kj_playerPlay];
}
/* 暂停 */
- (void)kj_playerPause{
    if (self.player == nil) return;
    [self.player pause];
    self.state = KJPlayerStatePausing;
    self.userPause = YES;
}
/* 停止 */
- (void)kj_playerStop{
    [self kj_destroyPlayer];
    self.state = KJPlayerStateStopped;
}
/* 快进或快退 */
- (void (^)(NSTimeInterval,void (^_Nullable)(BOOL)))kVideoAdvanceAndReverse{
    PLAYER_WEAKSELF;
    return ^(NSTimeInterval seconds,void (^xxblock)(BOOL)){
        if (weakself.player) {
            [weakself.player pause];
            [weakself.player.currentItem cancelPendingSeeks];
        }
        __block NSTimeInterval time = seconds;
        dispatch_group_notify(weakself.group, dispatch_get_main_queue(), ^{
            CMTime seekTime;
            if (weakself.locality == NO && weakself.cache) {
                if (weakself.totalTime) {
                    NSTimeInterval _time = weakself.progress * weakself.totalTime;
                    if (time + weakself.cacheTime >= _time) time = _time - weakself.cacheTime;
                    seekTime = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);;
                }else{
                    seekTime = CMTimeMakeWithSeconds(weakself.currentTime, NSEC_PER_SEC);;
                }
            }else{
                seekTime = CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC);
            }
            [weakself.player seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
                if (finished) [weakself kj_playerPlay];
                if (xxblock) xxblock(finished);
            }];
        });
    };
}

#pragma mark - private method
/// 销毁播放（名字不能乱改，KJCache当中有使用）
- (void)kj_destroyPlayer{
    [self kj_playerConfig];
    [self kj_removePlayerItem];
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem.asset cancelLoading];
    [self.player removeTimeObserver:self.timeObserver];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    _timeObserver = nil;
    _player = nil;
    self.asset = nil;
}
/// 播放准备（名字不能乱改，KJCache当中有使用）
- (void)kj_initPreparePlayer{
    [self kj_playerConfig];
    [self kj_removePlayerItem];
    if (self.player) {
        [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
    }else{
        self.player = [[AVPlayer alloc] initWithPlayerItem:self.playerItem];
        if (@available(iOS 10.0, *)) {
            if ([self.player respondsToSelector:@selector(automaticallyWaitsToMinimizeStalling)]) {
                self.player.automaticallyWaitsToMinimizeStalling = NO;
            }
        }
        self.player.usesExternalPlaybackWhileExternalScreenIsActive = YES;
    }
    [self kj_addTimeObserver];
    PLAYER_WEAKSELF;
    kGCD_player_main(^{
        weakself.playerLayer.player = weakself.player;
    });
}
//初始化配置信息
- (void)kj_playerConfig{
    if (self.player && [self isPlaying]) [self.player pause];
    tempSize = CGSizeZero;
    self.currentTime = self.totalTime = 0;
    self.userPause = NO;
    self.tryLooked = NO;
    self.buffered = NO;
}
// 获取视频显示模式
NS_INLINE NSString * kPlayerVideoGravity(KJPlayerVideoGravity videoGravity){
    switch (videoGravity) {
        case KJPlayerVideoGravityResizeAspect:return AVLayerVideoGravityResizeAspect;
        case KJPlayerVideoGravityResizeAspectFill:return AVLayerVideoGravityResizeAspectFill;
        case KJPlayerVideoGravityResizeOriginal:return AVLayerVideoGravityResize;
        default:break;
    }
}
- (void)kj_removePlayerItem{
    if (_playerItem == nil) return;
    [self.playerItem removeObserver:self forKeyPath:kStatus];
    [self.playerItem removeObserver:self forKeyPath:kLoadedTimeRanges];
    [self.playerItem removeObserver:self forKeyPath:kPresentationSize];
    [self.playerItem removeObserver:self forKeyPath:kPlaybackBufferEmpty];
    [self.playerItem removeObserver:self forKeyPath:kPlaybackLikelyToKeepUp];
    [self.playerItem removeObserver:self forKeyPath:kTimeControlStatus];
    _playerItem = nil;
}

#pragma mark - setter
- (void)setVideoURL:(NSURL *)videoURL{
    KJPlayerVideoFromat fromat = kPlayerFromat(videoURL);
    if (self.kVideoURLFromat) self.kVideoURLFromat(fromat);
    if (fromat == KJPlayerVideoFromat_none) {
        _videoURL = videoURL;
        self.ecode = KJPlayerErrorCodeVideoURLFault;
        if (self.player) [self kj_playerStop];
        return;
    }
    PLAYER_WEAKSELF;
    self.cache = NO;
    self.progress = 0.0;
    __block NSURL *tempURL = videoURL;
    dispatch_group_async(self.group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [weakself kj_judgeHaveCacheWithVideoURL:&tempURL];
        if (![tempURL.absoluteString isEqualToString:self->_videoURL.absoluteString]) {
            self->_videoURL = tempURL;
            [weakself kj_initPreparePlayer];
        }else{
            [weakself kj_playerReplay];
        }
    });
}
- (void)setVolume:(float)volume{
    _volume = MIN(MAX(0, volume), 1);
    if (self.player) self.player.volume = volume;
}
- (void)setMuted:(BOOL)muted{
    if (self.player && _muted != muted) {
        self.player.muted = muted;
    }
    _muted = muted;
}
- (void)setSpeed:(float)speed{
    if (self.player && fabsf(_player.rate) > 0.00001f && _speed != speed) {
        self.player.rate = speed;
    }
    _speed = speed;
}
- (void)setVideoGravity:(KJPlayerVideoGravity)videoGravity{
    if (_playerLayer && _videoGravity != videoGravity) {
        _playerLayer.videoGravity = kPlayerVideoGravity(videoGravity);
    }
    _videoGravity = videoGravity;
}
- (void)setBackground:(CGColorRef)background{
    if (_playerLayer && _background != background) {
        _playerLayer.backgroundColor = background;
    }
    _background = background;
}
- (void)setTimeSpace:(NSTimeInterval)timeSpace{
    if (_timeSpace != timeSpace) {
        _timeSpace = timeSpace;
        [self kj_addTimeObserver];
    }
}
- (void)setPlayerView:(UIView *)playerView{
    _playerView = playerView;
    self.playerLayer.frame = playerView.bounds;
    [playerView.layer addSublayer:_playerLayer];
}

#pragma mark - getter
- (BOOL)isPlaying{
    if (@available(iOS 10.0, *)) {
        return self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying;
    }else{
        return self.player.currentItem.status == AVPlayerStatusReadyToPlay;
    }
}
- (UIImage * _Nonnull (^)(NSTimeInterval))kVideoTimeImage{
    return ^(NSTimeInterval time) {
        if (self.asset == nil) return self.placeholder;
        AVAssetImageGenerator *assetGen = [[AVAssetImageGenerator alloc] initWithAsset:self.asset];
        assetGen.appliesPreferredTrackTransform = YES;
        CMTime actualTime;
        CGImageRef cgimage = [assetGen copyCGImageAtTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC) actualTime:&actualTime error:nil];
        UIImage *videoImage = [[UIImage alloc] initWithCGImage:cgimage];
        CGImageRelease(cgimage);
        assetGen = nil;
        return videoImage?:self.placeholder;
    };
}
- (void (^)(void (^ _Nonnull)(bool), NSTimeInterval))kVideoTryLookTime{
    return ^(void (^xxblock)(bool), NSTimeInterval time){
        self.tryTime = time;
        self.tryTimeBlock = xxblock;
    };
}

#pragma mark - lazy loading
- (AVPlayerItem *)playerItem{
    if (!_playerItem) {
        if (self.asset) {
            NSTimeInterval sec = ceil(self.asset.duration.value/self.asset.duration.timescale);
            if (isnan(sec) || sec < 0) sec = 0;
            self.totalTime = sec;
            kGCD_player_main(^{
                if (self.kVideoTotalTime) self.kVideoTotalTime(self.totalTime);
            });
            _playerItem = [AVPlayerItem playerItemWithAsset:self.asset];
        }else{
            _playerItem = [AVPlayerItem playerItemWithURL:self.videoURL];
            self.asset = [_playerItem.asset copy];
        }
        [_playerItem addObserver:self forKeyPath:kStatus options:NSKeyValueObservingOptionNew context:nil];
        [_playerItem addObserver:self forKeyPath:kLoadedTimeRanges options:NSKeyValueObservingOptionNew context:nil];
        [_playerItem addObserver:self forKeyPath:kPresentationSize options:NSKeyValueObservingOptionNew context:nil];
        [_playerItem addObserver:self forKeyPath:kPlaybackBufferEmpty options:NSKeyValueObservingOptionNew context:nil];
        [_playerItem addObserver:self forKeyPath:kPlaybackLikelyToKeepUp options:NSKeyValueObservingOptionNew context:nil];
        [_playerItem addObserver:self forKeyPath:kTimeControlStatus options:NSKeyValueObservingOptionNew context:nil];
        if (@available(iOS 9.0, *)) {
            _playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = NO;
        }
        if (@available(iOS 10.0, *)) {
            _playerItem.preferredForwardBufferDuration = 5;
        }
    }
    return _playerItem;
}
- (AVPlayerLayer *)playerLayer{
    if (!_playerLayer) {
        _playerLayer = [[AVPlayerLayer alloc] init];
        _playerLayer.videoGravity = kPlayerVideoGravity(_videoGravity);
        _playerLayer.backgroundColor = _background;
        _playerLayer.anchorPoint = CGPointMake(0.5, 0.5);
    }
    return _playerLayer;
}

@end

#pragma clang diagnostic pop
