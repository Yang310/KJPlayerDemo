//
//  KJMidiPlayer.h
//  KJPlayerDemo
//
//  Created by 杨科军 on 2021/2/2.
//  Copyright © 2021 杨科军. All rights reserved.
//  https://github.com/yangKJ/KJPlayerDemo
//  midi音乐播放器内核

#import <Foundation/Foundation.h>
#import "KJCommonPlayer.h"
NS_ASSUME_NONNULL_BEGIN
@interface KJMidiPlayer : KJCommonPlayer
@property (nonatomic,assign,readonly) MusicPlayer musicPlayer;

@end

NS_ASSUME_NONNULL_END
