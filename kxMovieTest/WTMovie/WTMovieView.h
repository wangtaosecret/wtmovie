//
//  WTMovieView.h
//  kxMovieTest
//
//  Created by wangtao on 2017/9/21.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import <UIKit/UIKit.h>
@interface WTMovieView : UIView
- (instancetype) initWithContentPath: (NSString *) path
						  parameters: (NSDictionary *) parameters
							   frame:(CGRect)frame;

@property (nonatomic, assign) BOOL playing;
- (void) play;
- (void) pause;
@end
