//
//  WTMoviePlayView.h
//  kxMovieTest
//
//  Created by wangtao on 2017/10/13.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WTLogger.h"
extern NSString * const WTMovieParameterMinBufferedDuration;    // Float
extern NSString * const WTMovieParameterMaxBufferedDuration;    // Float
extern NSString * const WTMovieParameterDisableDeinterlacing;   // BOOL
@interface WTMoviePlayView : UIView
+ (instancetype) movieViewControllerWithContentPath: (NSString *) path
										 parameters: (NSDictionary *) parameters frame:(CGRect)frame;

@property (readonly) BOOL playing;
//重播
- (void)replay;
- (void)stopPlay;
@end
