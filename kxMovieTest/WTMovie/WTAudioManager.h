//
//  WTAudioManager.h
//  kxMovieTest
//
//  Created by wangtao on 2017/9/11.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

typedef void (^WTAudioManagerOutputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

@protocol WTAudioManagerProtocl <NSObject>

/**
 声音的频道数量
 */
@property (nonatomic, assign, readonly) UInt32 numOutputChannels;
/**
 声音样品的码率
 */
@property (nonatomic, assign, readonly) Float64 samplingRate;

/**
 每个声音样品的大小
 */
@property (nonatomic, assign, readonly) UInt32 numBytesPerSample;

/**
 声音的大小
 */
@property (nonatomic, assign, readonly) Float32 outputVolume;

/**
 是否正在播放
 */
@property (nonatomic, assign, readonly) BOOL playing;

/**
 声音的线路
 */
@property (nonatomic, strong, readonly) NSString* audioRoute;

/**
 输出回调
 */
@property (nonatomic, copy) WTAudioManagerOutputBlock outputBlock;
/**
 激活音频
 */
- (BOOL) activateAudioSession;

/**
 关闭音频
 */
- (void) deactivateAudioSession;

/**
 播放音频
 */
- (BOOL) play;
/**
 关闭音频
 */
- (void) pause;
@end

@interface WTAudioManager : NSObject
+ (id<WTAudioManagerProtocl>)sharedManager;
@end
