//
//  WTMovieManager.h
//  kxMovieTest
//
//  Created by wangtao on 2017/9/21.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
@class WTArtworkFrame;
@class WTMovieDecoder;
@class WTAudioManager;
@class WTVideoFrame;

#define LOCAL_MIN_BUFFERED_DURATION   0.2
#define LOCAL_MAX_BUFFERED_DURATION   0.4
#define NETWORK_MIN_BUFFERED_DURATION 2.0
#define NETWORK_MAX_BUFFERED_DURATION 4.0

typedef void(^RenderFrameBlock)(WTVideoFrame *frame);
typedef void(^UpdatePlayeBtnBlock)(BOOL playing);
//参数是禁止更新时间lable
typedef void(^UpdateHudBlock)(BOOL disable, CGFloat moviePosition);
typedef void(^FinishPlayBlock)(void);
@interface WTMovieManager : NSObject
+ (instancetype)sharedManager;
@property (nonatomic, strong, readonly) WTMovieDecoder	*decoder;//电影解码器
@property (nonatomic, strong, readonly) WTAudioManager 	*audioManager;
@property (nonatomic, strong, readonly) dispatch_queue_t  dispatchQueue;
@property (nonatomic, strong, readonly) NSMutableArray *videoFrames;
@property (nonatomic, strong, readonly) NSMutableArray *audioFrames;
@property (nonatomic, strong, readonly) NSMutableArray *subtitles;
@property (nonatomic, assign, readonly) NSUInteger   currentAudioFramePos;
@property (nonatomic, assign, readonly) CGFloat       moviePosition;//当前电影的播放时间
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSDictionary *parameters;


@property (readwrite, strong) WTArtworkFrame *artworkFrame;
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, copy) void (^updateBottomBarBlock)(void);
//@property (nonatomic, copy, readonly) RenderFrameBlock renderFrameBlock;
- (void)playCallBack:(void (^) (NSError *error))callBack
	renderFrameBlock:(RenderFrameBlock)block
  updatePalyBtnBlock:(UpdatePlayeBtnBlock)updatePlayStatus
	  updateHudBlock:(UpdateHudBlock)updateHudBlock
	 finishPlayBlock:(FinishPlayBlock)finishPlayBlock;
- (void)pause;
- (void)activateAudioSession;
- (void)openFileAsyncWithFinishBlock:(void (^) (NSError *))openFileBlock;
- (void)asyncDecodeFramesFinishBlock:(void (^) (NSArray *frames))finishBlock;
- (void)setMoviePosition: (CGFloat) position;
- (void)finishplay;
@end
