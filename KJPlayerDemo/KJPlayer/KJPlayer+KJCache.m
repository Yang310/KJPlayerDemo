//
//  KJPlayer+KJCache.m
//  KJPlayerDemo
//
//  Created by 杨科军 on 2021/2/10.
//  Copyright © 2021 杨科军. All rights reserved.
//  https://github.com/yangKJ/KJPlayerDemo

#import "KJPlayer+KJCache.h"
#import "KJResourceLoader.h"
@interface KJPlayer ()
@property (nonatomic,assign) KJPlayerVideoFromat fromat;
@property (nonatomic,strong) KJResourceLoader *connection;
@property (nonatomic,assign) KJPlayerState state;
@property (nonatomic,assign) KJPlayerLoadState loadState;
@property (nonatomic,assign) float progress;
@property (nonatomic,assign) BOOL locality;
@end
@implementation KJPlayer (KJCache)
/* 判断当前资源文件是否有缓存，修改为指定链接地址 */
- (void)kj_judgeHaveCacheWithVideoURL:(NSURL * _Nonnull __strong * _Nonnull)videoURL{
    self.locality = NO;
    self.asset = nil;
    NSString *dbid = kPlayerIntactName(*videoURL);
    NSArray<DBPlayerData*>*temps = [DBPlayerDataInfo kj_checkData:dbid];
    if (temps.count) {
        NSString * path = kPlayerIntactSandboxPath(temps.firstObject.sandboxPath);
        self.locality = [[NSFileManager defaultManager] fileExistsAtPath:path];
        if (self.locality) {
            kGCD_player_main(^{self.progress = 1.0;});
            *videoURL = [NSURL fileURLWithPath:path];
        }else{
            kGCD_player_main(^{self.progress = 0.0;});
            [DBPlayerDataInfo kj_deleteData:dbid];
        }
    }else{
        kGCD_player_main(^{self.progress = 0.0;});
        self.state = KJPlayerStateBuffering;
    }
}
/* 使用边播边缓存，m3u8暂不支持 */
- (bool (^)(NSURL * _Nonnull, BOOL))kVideoCanCacheURL{
    return ^bool(NSURL * videoURL, BOOL cache){
        self.fromat = kPlayerFromat(videoURL);
        if (self.kVideoURLFromat) self.kVideoURLFromat(self.fromat);
        if (self.fromat == KJPlayerVideoFromat_m3u8) {
            return NO;
        }
        if (objc_getAssociatedObject(self, &connectionKey)) {
            objc_setAssociatedObject(self, &connectionKey, nil, OBJC_ASSOCIATION_RETAIN);
        }
        PLAYER_WEAKSELF;
        self.cache = cache;
        self.progress = 0.0;
        __block NSURL *tempURL = videoURL;
        dispatch_group_async(weakself.group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [weakself kj_judgeHaveCacheWithVideoURL:&tempURL];
            if (!kPlayerHaveTracks(tempURL, ^(AVURLAsset * asset) {
                if (weakself.cache && weakself.locality == NO) {
                    weakself.state = KJPlayerStateBuffering;
                    weakself.loadState = KJPlayerLoadStateNone;
                    NSURL * URL = weakself.connection.kj_createSchemeURL(tempURL);
                    weakself.asset = [AVURLAsset URLAssetWithURL:URL options:weakself.requestHeader];
                    [weakself.asset.resourceLoader setDelegate:weakself.connection queue:dispatch_get_main_queue()];
                }else{
                    weakself.asset = asset;
                }
            }, self.requestHeader)) {
                self.ecode = KJPlayerErrorCodeVideoURLFault;
                self.state = KJPlayerStateFailed;
                [self kj_performSelString:@"kj_destroyPlayer"];
            }else{
                [self kj_performSelString:@"kj_initPreparePlayer"];
            }
        });
        return YES;
    };
}

#pragma mark - private method
// 隐式调用
- (void)kj_performSelString:(NSString*)name{
    SEL sel = NSSelectorFromString(name);
    if ([self respondsToSelector:sel]) {
        ((void(*)(id, SEL))(void*)objc_msgSend)((id)self, sel);
    }
}
// 判断是否含有视频轨道
NS_INLINE bool kPlayerHaveTracks(NSURL *videoURL, void(^assetblock)(AVURLAsset *), NSDictionary *requestHeader){
    if (videoURL == nil) return false;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:requestHeader];
    if (assetblock) assetblock(asset);
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    return [tracks count] > 0;
}

#pragma mark - associated
- (BOOL)locality{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}
- (void)setLocality:(BOOL)locality{
    objc_setAssociatedObject(self, @selector(locality), @(locality), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)cache{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}
- (void)setCache:(BOOL)cache{
    objc_setAssociatedObject(self, @selector(cache), @(cache), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (dispatch_group_t)group{
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setGroup:(dispatch_group_t)group{
    objc_setAssociatedObject(self, @selector(group), group, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (AVURLAsset *)asset{
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setAsset:(AVURLAsset *)asset{
    objc_setAssociatedObject(self, @selector(asset), asset, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (KJPlayerLoadState)loadState{
    return (KJPlayerLoadState)[objc_getAssociatedObject(self, _cmd) intValue];
}
- (void)setLoadState:(KJPlayerLoadState)loadState{
    objc_setAssociatedObject(self, @selector(loadState), @(loadState), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (KJPlayerVideoFromat)fromat{
    return (KJPlayerVideoFromat)[objc_getAssociatedObject(self, _cmd) intValue];
}
- (void)setFromat:(KJPlayerVideoFromat)fromat{
    objc_setAssociatedObject(self, @selector(fromat), @(fromat), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (float)progress{
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}
- (void)setProgress:(float)progress{
    objc_setAssociatedObject(self, @selector(progress), @(progress), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
#pragma mark - lazy
static char connectionKey;
- (KJResourceLoader *)connection{
    KJResourceLoader *connection = objc_getAssociatedObject(self, &connectionKey);
    if (connection == nil) {
        connection = [[KJResourceLoader alloc] init];
        objc_setAssociatedObject(self, &connectionKey, connection, OBJC_ASSOCIATION_RETAIN);
        connection.maxCacheRange = 300 * 1024;
        connection.videoFromat = self.fromat;
        PLAYER_WEAKSELF;
        connection.kURLConnectionDidReceiveDataBlcok = ^(NSData * data, NSUInteger downOffect, NSUInteger totalOffect) {
            if (weakself.cache) {
                weakself.progress = (float)downOffect/totalOffect;
            }
        };
        connection.kURLConnectionDidFinishLoadingAndSaveFileBlcok = ^(BOOL saveSuccess) {
            if (saveSuccess) {
                weakself.loadState = KJPlayerLoadStateComplete;
            }else{
                weakself.loadState = KJPlayerLoadStateError;
            }
            weakself.locality = saveSuccess;
        };
        connection.kURLConnectiondidFailWithErrorCodeBlcok = ^(NSInteger code) {
            switch (code) {
                case -1001:weakself.ecode = KJPlayerErrorCodeNetworkOvertime;break;
                case -1003:weakself.ecode = KJPlayerErrorCodeServerNotFound;break;
                case -1004:weakself.ecode = KJPlayerErrorCodeServerInternalError;break;
                case -1005:weakself.ecode = KJPlayerErrorCodeNetworkInterruption;break;
                case -1009:weakself.ecode = KJPlayerErrorCodeNetworkNoConnection;break;
                default:   weakself.ecode = KJPlayerErrorCodeOtherSituations;break;
            }
            weakself.state = KJPlayerStateFailed;
        };
    }
    return connection;
}

@end
