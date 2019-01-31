//
//  KxAudioManager.h
//  kxmovie
//
//  Created by Kolyvan on 23.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt


#import <CoreFoundation/CoreFoundation.h>

typedef void (^KxAudioManagerOutputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

//定义protocol
@protocol KxAudioManager <NSObject>

/**
 音频输出的通道数量
 */
@property (readonly) UInt32             numOutputChannels;

/**
 音频的频率
 */
@property (readonly) Float64            samplingRate;

/**
 每帧音频的大小
 */
@property (readonly) UInt32             numBytesPerSample;

/**
 输出的声音的大小
 */
@property (readonly) Float32            outputVolume;

/**
 是否正在播放
 */
@property (readonly) BOOL               playing;

/**
 
 */
@property (readonly, strong) NSString   *audioRoute;

@property (readwrite, copy) KxAudioManagerOutputBlock outputBlock;

/**
 激活音频会话
 */
- (BOOL) activateAudioSession;

/**
 关闭音频会话
 */
- (void) deactivateAudioSession;

/**
 播放音频
 */
- (BOOL) play;

/**
 暂停音频播放
 */
- (void) pause;

@end

@interface KxAudioManager : NSObject
+ (id<KxAudioManager>) audioManager;
@end
