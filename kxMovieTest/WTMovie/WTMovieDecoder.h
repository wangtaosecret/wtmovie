//
//  WTMovieDecoder.h
//  kxMovieTest
//
//  Created by wangtao on 2017/9/18.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
extern NSString * wtmovieErrorDomain;
//定义错误
typedef enum {
	WTMovieErrorNone,	//无错误
	WTMovieErrorOpenFile, //打开文件错误
	WTMovieErrorStreamInfoNotFound, //流信息错误
	WTMovieErrorStreamNotFound,	//视频流不存在
	WTMovieErrorCodecNotFound, //解码器不存在
	WTMovieErrorOpenCodec,	//打开解码器错误
	WTMovieErrorAllocateFrame, //分配帧错误
	WTMovieErrorSetupScaler, //
	WTMovieErrorReSampler,
	WTMovieErrorUnsupported,
}WTMovieError;
//定义movie的帧类型 类型
typedef enum {
	WTMovieFrameTypeAudio, //音频
	WTMovieFrameTypeVideo,	//视频
	WTMovieFrameTypeArtwork, //艺术品
	WTMovieFrameTypeSubtitle, //字幕
}WTMovieFrameType;
//定义video的类别
typedef enum {
	WTVideoFrameFormatRGB,
	WTVideoFrameFormatYUV,
}WTVideoFrameFormat;
//定义视频帧的基类，包括音、视频帧
@interface WTMovieFrame : NSObject
//类型
@property (nonatomic, assign, readonly) WTMovieFrameType type;
//当前的时间
@property (nonatomic, assign, readonly) CGFloat position;
//持续的时间
@property (nonatomic, assign, readonly) CGFloat duration;
@end

/**
 视频的音频帧model，继承自基础帧model WTMovieFrame
 */
@interface WTAudioFrame : WTMovieFrame

/**
 声音样本的数据
 */
@property (nonatomic, strong, readonly) NSData *samples;
@end
@interface WTVideoFrame : WTMovieFrame

/**
 视频帧的类型YUV 或者 RGB
 */
@property (nonatomic, assign, readonly) WTVideoFrameFormat format;

/**
 视频帧的宽度
 */
@property (nonatomic, assign, readonly) NSUInteger width;

/**
 视频帧的高度
 */
@property (nonatomic, assign, readonly) NSUInteger height;
@end

/**
 视频帧RGB类型的帧model
 */
@interface WTVideoFrameRGB : WTVideoFrame
@property (nonatomic, readonly, assign) NSUInteger linesize;
@property (nonatomic, readonly, strong) NSData *rgb;
- (UIImage *) asImage;
@end
@interface WTVideoFrameYUV : WTVideoFrame
@property (readonly, nonatomic, strong) NSData *luma;
@property (readonly, nonatomic, strong) NSData *chromaB;
@property (readonly, nonatomic, strong) NSData *chromaR;
@end
@interface WTArtworkFrame : WTMovieFrame
@property (readonly, nonatomic, strong) NSData *picture;
- (UIImage *) asImage;
@end

/**
 字幕帧model
 */
@interface WTSubtitleFrame : WTMovieFrame
@property (readonly, nonatomic, strong) NSString *text;
@end
typedef BOOL(^WTMovieDecoderInterruptCallback)(void);
@interface WTMovieDecoder : NSObject

/**
 视频地址，本地或者远程
 */
@property (nonatomic, strong, readonly) NSString* path;

/**
 视频是否到达末尾
 */
@property (nonatomic, assign, readonly) BOOL isEOF;

/**
 视频当前的时间
 */
@property (nonatomic, assign) CGFloat position;

/**
 视频的总时间
 */
@property (nonatomic, assign, readonly) CGFloat duration;

/**
 视频的帧率
 */
@property (nonatomic, assign, readonly) CGFloat fps;

/**
 视频的采样率
 */
@property (nonatomic, assign, readonly) CGFloat sampleRate;
/**
 视频的宽度
 */
@property (nonatomic, assign, readonly) NSUInteger frameWidth;

/**
 视频的高度
 */
@property (nonatomic, assign, readonly) NSUInteger frameHeight;
/**
 <#Description#>
 */
@property (nonatomic, assign, readonly) NSUInteger audioStreamsCount;

/**
 <#Description#>
 */
@property (nonatomic, assign) NSInteger selectedAudioStream;
@property (nonatomic, assign) NSUInteger subtitleStreamsCount;
@property (nonatomic, assign) NSInteger selectedSubtitleStream;
/**
 当前视频是否为有效的视频
 */
@property (nonatomic, assign, readonly) BOOL validVideo;

/**
 当前视频是否为有效的音频
 */
@property (nonatomic, assign, readonly) BOOL validAudio;
@property (nonatomic, assign, readonly) BOOL validSubtitles;
@property (nonatomic, strong, readonly) NSDictionary *info;
@property (nonatomic, strong, readonly) NSString *videoStreamFormatName;
/**
 视频是否为网络
 */
@property (nonatomic, assign, readonly) BOOL isNetwork;

/**
 开始播放的时间
 */
@property (nonatomic, assign, readonly) CGFloat startTime;

/**
 是否允许去除隔行
 */
@property (nonatomic, assign) BOOL disableDeinterlacing;

/**
 被打断的回调
 */
@property (nonatomic, copy) WTMovieDecoderInterruptCallback interruptCallback;

/**
 创建当前对象

 @param path 视频的地址，本地或者远程
 @param perror 创建错误
 */
+ (id) movieDecoderWithContentPath: (NSString *) path
							 error: (NSError **) perror;

/**
 打开文件

 @param path 文件路径
 @param perror 打开错误
 @return 是否正确打开
 */
- (BOOL) openFile: (NSString *) path
			error: (NSError **) perror;

/**
 关闭文件
 */
- (void) closeFile;

/**
 设置视频帧格式

 @param format WTVideoFrameFormat
 @return 是否设置成功
 */
- (BOOL) setupVideoFrameFormat: (WTVideoFrameFormat) format;
- (NSArray *) decodeFrames: (CGFloat) minDuration;
@end

/**
 字幕解析
 */
@interface WTMovieSubtitleASSParser : NSObject

+ (NSArray *) parseEvents: (NSString *) events;
+ (NSArray *) parseDialogue: (NSString *) dialogue
				  numFields: (NSUInteger) numFields;
+ (NSString *) removeCommandsFromEventText: (NSString *) text;

@end
