//
//  KJFastView.h
//  KJPlayerDemo
//
//  Created by 杨科军 on 2019/7/22.
//  Copyright © 2019 杨科军. All rights reserved.
//  快进快退view

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KJFastView : UIView
@property(nonatomic,strong) UIImageView *stateImageView;
@property(nonatomic,strong) UILabel *timeLabel;
@end

NS_ASSUME_NONNULL_END