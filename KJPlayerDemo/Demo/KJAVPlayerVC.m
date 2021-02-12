//
//  KJAVPlayerVC.m
//  KJPlayerDemo
//
//  Created by 杨科军 on 2021/1/31.
//  Copyright © 2021 杨科军. All rights reserved.
//

#import "KJAVPlayerVC.h"
#import "KJPlayer.h"
@interface KJAVPlayerVC ()<KJPlayerDelegate>
@property(nonatomic,strong)KJPlayer *player;
@property(nonatomic,strong)UISlider *slider;
@property(nonatomic,strong)UIProgressView *progressView;
@property(nonatomic,assign)NSInteger index;
@property(nonatomic,strong)NSArray *temps;
@end

@implementation KJAVPlayerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = UIColor.whiteColor;
    
    UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView = progressView;
    progressView.frame = CGRectMake(10, self.view.bounds.size.height-35, self.view.bounds.size.width-20, 30);
    progressView.progressTintColor = [UIColor.redColor colorWithAlphaComponent:0.8];
    [progressView setProgress:0.0 animated:NO];
    [self.view addSubview:progressView];
    
    UISlider *slider = [[UISlider alloc]initWithFrame:CGRectMake(7, 0, self.view.bounds.size.width-14, 30)];
    self.slider = slider;
    slider.backgroundColor = UIColor.clearColor;
    slider.center = _progressView.center;
    slider.minimumValue = 0.0;
    [self.view addSubview:slider];
    [slider addTarget:self action:@selector(sliderValueChanged:forEvent:) forControlEvents:UIControlEventValueChanged];
    
    UIView *backview = [[UIView alloc]initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height-128)];
    backview.center = self.view.center;
    [self.view addSubview:backview];
    
    self.temps = @[@"https://mp4.vjshi.com/2018-03-30/1f36dd9819eeef0bc508414494d34ad9.mp4",
                   @"http://appit.winpow.com/attached/media/MP4/1567585643618.mp4",
                   @"https://mp4.vjshi.com/2020-07-02/c411973c6c8628e94c40cb4e2689e56b.mp4"
    ];
    
    KJPlayer *player = [[KJPlayer alloc]init];
    self.player = player;
    player.playerView = backview;
    player.delegate = self;
    player.roregroundResume = YES;
    player.kVideoTotalTime = ^(NSTimeInterval time) {
        slider.maximumValue = time;
        NSLog(@"time:%@",kPlayerConvertTime(time));
    };
    player.kVideoURLFromat = ^(KJPlayerVideoFromat fromat) {
        NSLog(@"fromat:%@",KJPlayerVideoFromatStringMap[fromat]);
    };
    player.videoURL = [NSURL URLWithString:self.temps[self.index]];
//    UIImage *image = KJPlayer.shared.kVideoTimeImage(0);
    player.kVideoSize = ^(CGSize size) {
        NSLog(@"%.2f,%.2f",size.width,size.height);
    };
}
- (void)dealloc{
//    [KJPlayer kj_attempDealloc];
}
///进度条的拖拽事件 监听UISlider拖动状态
- (void)sliderValueChanged:(UISlider*)slider forEvent:(UIEvent*)event {
    UITouch *touchEvent = [[event allTouches]anyObject];
    switch(touchEvent.phase) {
        case UITouchPhaseBegan:
            [self.player kj_playerPause];
            break;
        case UITouchPhaseMoved:
            break;
        case UITouchPhaseEnded:{
            CGFloat second = slider.value;
            [slider setValue:second animated:YES];
            self.player.kVideoAdvanceAndReverse(second,nil);
        }
            break;
        default:
            break;
    }
}

#pragma mark - KJPlayerDelegate
/* 当前播放器状态 */
- (void)kj_player:(id<KJBasePlayer>)player state:(KJPlayerState)state{
    NSLog(@"---当前播放器状态:%@",KJPlayerStateStringMap[state]);
    if (state == KJPlayerStatePlayFinished) {
        if (self.index++ >= self.temps.count) {
            self.index = 0;
        }
        NSURL *video = [NSURL URLWithString:self.temps[self.index]];
        if (self.index == 0) {
            player.skipHeadTime = 100;
            player.timeSpace = 2.5;
            player.speed = 1.25;
            player.kVideoTryLookTime(nil, 0);
            player.videoURL = video;
        }else if (self.index == 1) {
            player.skipHeadTime = 0;
            player.timeSpace = 1.;
            player.speed = 1.;
            player.kVideoCanCacheURL(video, YES);
            player.videoGravity = KJPlayerVideoGravityResizeAspect;
        }else{
            player.skipHeadTime = 50;
            player.videoURL = video;
            player.kVideoTryLookTime(^(BOOL end) {
                if (end) {
                    NSLog(@"试看时间已到");
                }
            }, 150);
        }
    }
}
/* 播放进度 */
- (void)kj_player:(id<KJBasePlayer>)player currentTime:(CGFloat)time totalTime:(CGFloat)total{
//    NSLog(@"---播放进度:%.2f,%.2f",time,total);
    self.slider.value = time;
}
/* 缓存状态 */
- (void)kj_player:(id<KJBasePlayer>)player loadstate:(KJPlayerLoadState)state{
    NSLog(@"-----缓存状态:%@",KJPlayerLoadStateStringMap[state]);
}
/* 缓存进度 */
- (void)kj_player:(id<KJBasePlayer>)player loadProgress:(CGFloat)progress{
    NSLog(@"---缓存进度:%f",progress);
    [self.progressView setProgress:progress animated:YES];
}

@end
