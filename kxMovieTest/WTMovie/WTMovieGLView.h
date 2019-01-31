//
//  WTMovieGLView.h
//  kxMovieTest
//
//  Created by wangtao on 2017/9/19.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import <UIKit/UIKit.h>
@class WTVideoFrame;
@class WTMovieDecoder;
@interface WTMovieGLView : UIView
- (instancetype)initWithFrame:(CGRect)frame
					  decoder:(WTMovieDecoder *)decoder;
- (void) render:(WTVideoFrame *)frame;
@end
