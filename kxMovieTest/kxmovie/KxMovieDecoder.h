//
//  KxMovieDecoder.h
//  kxmovie
//
//  Created by Kolyvan on 15.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

extern NSString * kxmovieErrorDomain;
//定义错误类型
typedef enum {
    
    kxMovieErrorNone,
    kxMovieErrorOpenFile,
    kxMovieErrorStreamInfoNotFound,
    kxMovieErrorStreamNotFound,
    kxMovieErrorCodecNotFound,
    kxMovieErrorOpenCodec,
    kxMovieErrorAllocateFrame,
    kxMovieErroSetupScaler,
    kxMovieErroReSampler,
    kxMovieErroUnsupported,
    
} kxMovieError;
//定义movieframe类型
typedef enum {
    
    KxMovieFrameTypeAudio,
    KxMovieFrameTypeVideo,
    KxMovieFrameTypeArtwork,
    KxMovieFrameTypeSubtitle,
    
} KxMovieFrameType;

//定义video的类型
typedef enum {
        
    KxVideoFrameFormatRGB,
    KxVideoFrameFormatYUV,
    
} KxVideoFrameFormat;

/**
 movieFrame基类
 */
@interface KxMovieFrame : NSObject
@property (readonly, nonatomic) KxMovieFrameType type;
@property (readonly, nonatomic) CGFloat position;
@property (readonly, nonatomic) CGFloat duration;
@end

/**
 movie的音频model，继承自KxMovieFrame
 */
@interface KxAudioFrame : KxMovieFrame
@property (readonly, nonatomic, strong) NSData *samples;
@end

/**
 movie的视频model，继承自KxMovieFrame
 */
@interface KxVideoFrame : KxMovieFrame
@property (readonly, nonatomic) KxVideoFrameFormat format;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;
@end

/**
 videoFrame的下面RGB类型的分类model
 */
@interface KxVideoFrameRGB : KxVideoFrame
@property (readonly, nonatomic) NSUInteger linesize;
@property (readonly, nonatomic, strong) NSData *rgb;
- (UIImage *) asImage;
@end
/**
 videoFrame的下面YUV类型的分类model
 */
@interface KxVideoFrameYUV : KxVideoFrame
@property (readonly, nonatomic, strong) NSData *luma;
@property (readonly, nonatomic, strong) NSData *chromaB;
@property (readonly, nonatomic, strong) NSData *chromaR;
@end

/**
 视频封面
 */
@interface KxArtworkFrame : KxMovieFrame
@property (readonly, nonatomic, strong) NSData *picture;
- (UIImage *) asImage;
@end

/**
 视频标题
 */
@interface KxSubtitleFrame : KxMovieFrame
@property (readonly, nonatomic, strong) NSString *text;
@end

typedef BOOL(^KxMovieDecoderInterruptCallback)();

@interface KxMovieDecoder : NSObject

/**
 视频地址，本地或者远程
 */
@property (readonly, nonatomic, strong) NSString *path;

/**
 视频是否结束
 */
@property (readonly, nonatomic) BOOL isEOF;

/**
 视频当前的时间点
 */
@property (readwrite,nonatomic) CGFloat position;

/**
 视频长度
 */
@property (readonly, nonatomic) CGFloat duration;

/**
 视频的帧率
 */
@property (readonly, nonatomic) CGFloat fps;

/**
 视频的
 */
@property (readonly, nonatomic) CGFloat sampleRate;

/**
 视频的宽度
 */
@property (readonly, nonatomic) NSUInteger frameWidth;

/**
 视频的高度
 */
@property (readonly, nonatomic) NSUInteger frameHeight;

/**
 <#Description#>
 */
@property (readonly, nonatomic) NSUInteger audioStreamsCount;

/**
 <#Description#>
 */
@property (readwrite,nonatomic) NSInteger selectedAudioStream;
@property (readonly, nonatomic) NSUInteger subtitleStreamsCount;
@property (readwrite,nonatomic) NSInteger selectedSubtitleStream;

/**
 当前视频是否为有效的视频
 */
@property (readonly, nonatomic) BOOL validVideo;

/**
 当前视频是否为有效的音频
 */
@property (readonly, nonatomic) BOOL validAudio;
@property (readonly, nonatomic) BOOL validSubtitles;
@property (readonly, nonatomic, strong) NSDictionary *info;
@property (readonly, nonatomic, strong) NSString *videoStreamFormatName;

/**
 视频是否为网络
 */
@property (readonly, nonatomic) BOOL isNetwork;

/**
 开始播放的时间
 */
@property (readonly, nonatomic) CGFloat startTime;
@property (readwrite, nonatomic) BOOL disableDeinterlacing;
@property (readwrite, nonatomic, strong) KxMovieDecoderInterruptCallback interruptCallback;

/**
 初始化方法

 @param path 视频地址不能为空
 @param perror 错误
 @return decoder实例
 */
+ (id) movieDecoderWithContentPath: (NSString *) path
                             error: (NSError **) perror;

- (BOOL) openFile: (NSString *) path
            error: (NSError **) perror;

-(void) closeFile;

/**
 设置视频的格式

 @param format <#format description#>
 @return <#return value description#>
 */
- (BOOL) setupVideoFrameFormat: (KxVideoFrameFormat) format;

/**
 解析当前时间点之后的持续时间的视频model

 @param minDuration 持续时间
 @return 视频model的数组
 */
- (NSArray *) decodeFrames: (CGFloat) minDuration;

@end

@interface KxMovieSubtitleASSParser : NSObject

+ (NSArray *) parseEvents: (NSString *) events;
+ (NSArray *) parseDialogue: (NSString *) dialogue
                  numFields: (NSUInteger) numFields;
+ (NSString *) removeCommandsFromEventText: (NSString *) text;

@end
