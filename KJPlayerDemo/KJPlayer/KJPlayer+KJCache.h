//
//  KJPlayer+KJCache.h
//  KJPlayerDemo
//
//  Created by 杨科军 on 2021/2/10.
//  Copyright © 2021 杨科军. All rights reserved.
//  https://github.com/yangKJ/KJPlayerDemo
//  边播边缓存分支

#import "KJPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface KJPlayer (KJCache)
/* 本地资源 */
@property (nonatomic,assign,readonly) BOOL locality;
/*  */
@property (nonatomic,strong) AVURLAsset *_Nullable asset;

/* 判断当前资源文件是否有缓存，修改为指定链接地址 */
- (void)kj_judgeHaveCacheWithVideoURL:(NSURL * _Nonnull __strong * _Nonnull)videoURL;

/* ****************** 内部属性，可以获取但别乱改 ******************/
/* 线程队列组 */
@property (nonatomic,retain) dispatch_group_t group;
/* 是否使用缓存功能 */
@property (nonatomic,assign) BOOL cache;

@end

NS_ASSUME_NONNULL_END
