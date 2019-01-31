//
//  KXAudioManager.m
//  kxMovieTest
//
//  Created by wangtao on 2017/9/11.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import "WTAudioManager.h"
#import "TargetConditionals.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "WTLogger.h"
#import <AVFoundation/AVFoundation.h>

#define MAX_FRAME_SIZE 4096 //音频的最大容量
#define MAX_CHAN       2   //音频的最大通道数

#define MAX_SAMPLE_DUMPED 5

/**
 检查错误的静态方法

 @param error 传入的状态
 @param operation 提示的信息
 @return 该状态是否为错误状态
 */
static BOOL checkError(OSStatus error, const char *operation);

/**
 监听事件

 @param inClientData 这里就是WTAudioManagerImpl的对象
 @param intID 事件编号
 @param inDataSize 输入数据的大小
 @param inData 输入数据
 */
static void sessionPropertyListener(void *inClientData,
									AudioSessionPropertyID intID,
									UInt32 inDataSize,
									const void *inData);

/**
 声音被打断的监听回调

 @param inClientData 这里就是WTAudioManagerImpl的对象
 @param inInterruption 打断的类型
 kAudioSessionBeginInterruption  = 1,
 kAudioSessionEndInterruption    = 0
 */
static void sessionInterruptionListener(void *inClientData,
										UInt32 inInterruption);

/**
 解码音频的回调
 */
static OSStatus renderCallback (void *inRefCon,
								AudioUnitRenderActionFlags	*ioActionFlags,
								const AudioTimeStamp * inTimeStamp,
								UInt32 inOutputBusNumber,
								UInt32 inNumberFrames,
								AudioBufferList* ioData);

/**
 具体功能的实现类
 */
@interface WTAudioManagerImpl : WTAudioManager<WTAudioManagerProtocl>{
	BOOL                        _initialized;	//是否被初始化
	BOOL                        _activated;		//是否被激活
	float                       *_outData;		//输出的数据
	AudioUnit                   _audioUnit;		//音频单元
	AudioStreamBasicDescription _outputFormat;	//输出的格式
}
//实现protocol的属性和方法
@property (nonatomic, assign) UInt32 numOutputChannels;
@property (nonatomic, assign) Float64 samplingRate;
@property (nonatomic, assign) UInt32 numBytesPerSample;
@property (nonatomic, assign) Float32 outputVolume;
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, strong) NSString* audioRoute;
@property (nonatomic, copy) WTAudioManagerOutputBlock outputBlock;
@property (nonatomic, assign) BOOL playAfterSessionEndInterruption;
- (BOOL) activateAudioSession;
- (void) deactivateAudioSession;
- (BOOL) play;
- (void) pause;

- (BOOL) checkAudioRoute;
- (BOOL) setupAudio;
- (BOOL) checkSessionProperties;
- (BOOL) renderFrames: (UInt32) numFrames
			   ioData: (AudioBufferList *) ioData;
@end

@implementation WTAudioManagerImpl
- (instancetype)init{
	if (self == [super init]) {
		//设置输出数据的大小，大小等于音频的最大容量*音频的通道数量
		_outData = (float *)calloc(MAX_FRAME_SIZE * MAX_CHAN, sizeof(float));
		//默认声音大小为0.5
		_outputVolume = 0.5;
	}
	return self;
}

- (void)dealloc{
	if (_outData) {
		free(_outData);
		_outData = NULL;
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
#pragma mark - private

// Debug: dump the current frame data. Limited to 20 samples.

#define dumpAudioSamples(prefix, dataBuffer, samplePrintFormat, sampleCount, channelCount) \
{ \
NSMutableString *dump = [NSMutableString stringWithFormat:prefix]; \
for (int i = 0; i < MIN(MAX_SAMPLE_DUMPED, sampleCount); i++) \
{ \
for (int j = 0; j < channelCount; j++) \
{ \
[dump appendFormat:samplePrintFormat, dataBuffer[j + i * channelCount]]; \
} \
[dump appendFormat:@"\n"]; \
} \
LoggerAudio(3, @"%@", dump); \
}

#define dumpAudioSamplesNonInterleaved(prefix, dataBuffer, samplePrintFormat, sampleCount, channelCount) \
{ \
NSMutableString *dump = [NSMutableString stringWithFormat:prefix]; \
for (int i = 0; i < MIN(MAX_SAMPLE_DUMPED, sampleCount); i++) \
{ \
for (int j = 0; j < channelCount; j++) \
{ \
[dump appendFormat:samplePrintFormat, dataBuffer[j][i]]; \
} \
[dump appendFormat:@"\n"]; \
} \
LoggerAudio(3, @"%@", dump); \
}

/**
 检查是否能播放音频（没有其他音频在播放）
 */
- (BOOL) checkAudioRoute{
	//检查当前的音频线路
	
	//属性的大小
//	UInt32 propertySize = sizeof(CFStringRef);
	//传入的字符串CORE Foundation
//	CFStringRef route;
//	if (checkError(
//				   AudioSessionGetProperty(kAudioSessionProperty_AudioRoute,
//										   &propertySize,
//										   &route),
//				   "Couldn't check the audio route")) {
//		return NO;
//	}
	
	
	//上面的方法已经过时
	if ([[AVAudioSession sharedInstance] isOtherAudioPlaying]) {
		return NO;
	}
	LoggerAudio(1, @"AudioRoute: %@", _audioRoute);
	return YES;
}
- (void)AudioRouteChange{
	LoggerAudio(1, @"声音线路改变");
}
/**
 设置音频

 @return 设置是是否成功
 */
- (BOOL) setupAudio{
	// --- Audio Session Setup ---
	
	AVAudioSession *session = [AVAudioSession sharedInstance];
	
	NSError *setCategoryError = nil;
	//如果设置音频播放错误，返回no
	if (![session setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError]) {
		
		return NO;
	}
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AudioRouteChange) name:AVAudioSessionRouteChangeNotification object:nil];
	
	if (session.outputVolume) {
		
	}

	// Set the buffer size, this will affect the number of samples that get rendered every time the audio callback is fired
	// A small number will get you lower latency audio, but will make your processor work harder
	
#if !TARGET_IPHONE_SIMULATOR
	//设备不是模拟器，设置缓存大小，这个值会影响音频回调被激活时，每次解码的音频数量，这个值越小，会降低音频的延迟，但是会更加耗费资源
	Float32 preferredBufferSize = 0.0232;
	NSError *setIOBufferError = nil;
	if (![session setPreferredIOBufferDuration:preferredBufferSize error:&setIOBufferError]) {
		//just warning
	}
	
#endif
	NSError *setActiveError = nil;
//	[session setActive:YES error:&setActiveError];
	if (![session setActive:YES error:&setActiveError])
		return NO;
	
	[self checkSessionProperties];
	
	// ----- Audio Unit Setup -----
	
	// Describe the output unit.
	//音频内容描述struct
	AudioComponentDescription description = {0};
	description.componentType = kAudioUnitType_Output;
	description.componentSubType = kAudioUnitSubType_RemoteIO;
	description.componentManufacturer = kAudioUnitManufacturer_Apple;
	
	// Get component
	AudioComponent component = AudioComponentFindNext(NULL, &description);
	
	if (checkError(AudioComponentInstanceNew(component, &_audioUnit),
				   "Couldn't create the output audio unit"))
		return NO;
	
	UInt32 size;
	
	// Check the output stream format
	size = sizeof(AudioStreamBasicDescription);
	if (checkError(AudioUnitGetProperty(_audioUnit,
										kAudioUnitProperty_StreamFormat,
										kAudioUnitScope_Input,
										0,
										&_outputFormat,
										&size),
				   "Couldn't get the hardware output stream format"))
		return NO;
	
	
	_outputFormat.mSampleRate = _samplingRate;
	if (checkError(AudioUnitSetProperty(_audioUnit,
										kAudioUnitProperty_StreamFormat,
										kAudioUnitScope_Input,
										0,
										&_outputFormat,
										size),
				   "Couldn't set the hardware output stream format")) {
		
		// just warning
	}
	
	_numBytesPerSample = _outputFormat.mBitsPerChannel / 8;
	_numOutputChannels = _outputFormat.mChannelsPerFrame;
	
	LoggerAudio(2, @"Current output bytes per sample: %u", (unsigned int)_numBytesPerSample);
	LoggerAudio(2, @"Current output num channels: %u", (unsigned int)_numOutputChannels);
	
	// Slap a render callback on the unit
	AURenderCallbackStruct callbackStruct;
	callbackStruct.inputProc = renderCallback;
	callbackStruct.inputProcRefCon = (__bridge void *)(self);
	
	if (checkError(AudioUnitSetProperty(_audioUnit,
										kAudioUnitProperty_SetRenderCallback,
										kAudioUnitScope_Input,
										0,
										&callbackStruct,
										sizeof(callbackStruct)),
				   "Couldn't set the render callback on the audio unit"))
		return NO;
	
	if (checkError(AudioUnitInitialize(_audioUnit),
				   "Couldn't initialize the audio unit"))
		return NO;
	
	return YES;
}
- (BOOL) checkSessionProperties{
	//查看是否有音频正在播放
	[self checkAudioRoute];
	
	AVAudioSession *session = [AVAudioSession sharedInstance];

	LoggerAudio(2, @"We've got %u output channels", (unsigned int)session.outputNumberOfChannels);

	_samplingRate = session.sampleRate;
	LoggerAudio(2, @"Current sampling rate: %f", _samplingRate);
	
	_outputVolume = session.outputVolume;
	LoggerAudio(1, @"Current output volume: %f", _outputVolume);
	
	return YES;
}

/**
 解码音频

 @param numFrames 音频的帧数
 @param ioData 输入的数据
 @return 是否解码成功
 */
- (BOOL) renderFrames: (UInt32) numFrames
			   ioData: (AudioBufferList *) ioData
{
	//将ioData的属性mBuffers设置为空
	for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
		memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
	}
	
	if (_playing && _outputBlock ) {
		
		// Collect data to render from the callbacks
		_outputBlock(_outData, numFrames, _numOutputChannels);
		
		// Put the rendered data into the output buffer
		if (_numBytesPerSample == 4) // then we've already got floats
		{
			float zero = 0.0;
			
			for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
				
				int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
				
				for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
					vDSP_vsadd(_outData+iChannel, _numOutputChannels, &zero, (float *)ioData->mBuffers[iBuffer].mData, thisNumChannels, numFrames);
				}
			}
		}
		else if (_numBytesPerSample == 2) // then we need to convert SInt16 -> Float (and also scale)
		{
			//            dumpAudioSamples(@"Audio frames decoded by FFmpeg:\n",
			//                             _outData, @"% 12.4f ", numFrames, _numOutputChannels);
			
			float scale = (float)INT16_MAX;
			vDSP_vsmul(_outData, 1, &scale, _outData, 1, numFrames*_numOutputChannels);
			
#ifdef DUMP_AUDIO_DATA
			LoggerAudio(2, @"Buffer %u - Output Channels %u - Samples %u",
						(uint)ioData->mNumberBuffers, (uint)ioData->mBuffers[0].mNumberChannels, (uint)numFrames);
#endif
			
			for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
				
				int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
				
				for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
					vDSP_vfix16(_outData+iChannel, _numOutputChannels, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, numFrames);
				}
#ifdef DUMP_AUDIO_DATA
				dumpAudioSamples(@"Audio frames decoded by FFmpeg and reformatted:\n",
								 ((SInt16 *)ioData->mBuffers[iBuffer].mData),
								 @"% 8d ", numFrames, thisNumChannels);
#endif
			}
			
		}
	}
	
	return noErr;
}

/**
 激活音频会话
 */
- (BOOL)activateAudioSession {
	if (!_activated) {
		
		if (!_initialized) {
			
			if (checkError(AudioSessionInitialize(NULL,
												  kCFRunLoopDefaultMode,
												  sessionInterruptionListener,
												  (__bridge void *)(self)),
						   "Couldn't initialize audio session"))
				return NO;
			
			_initialized = YES;
		}
		//可以播放音频并且设置音频正确
		if ([self checkAudioRoute] &&
			[self setupAudio]) {
			
			_activated = YES;
		}
	}
	
	return _activated;
}


/**
 关闭音频会话
 */
- (void)deactivateAudioSession {
	
	if (_activated) {
		
		[self pause];
		
		checkError(AudioUnitUninitialize(_audioUnit),
				   "Couldn't uninitialize the audio unit");
		
		/*
		 fails with error (-10851) ?
		 
		 checkError(AudioUnitSetProperty(_audioUnit,
		 kAudioUnitProperty_SetRenderCallback,
		 kAudioUnitScope_Input,
		 0,
		 NULL,
		 0),
		 "Couldn't clear the render callback on the audio unit");
		 */
		
		checkError(AudioComponentInstanceDispose(_audioUnit),
				   "Couldn't dispose the output audio unit");
		AVAudioSession *session = [AVAudioSession sharedInstance];
		
		NSError *deactiveError = nil;
		
		if (![session setActive:NO error:&deactiveError]) {
			LoggerAudio(1, @"Couldn't deactivate the audio session");
		}
//		checkError(AudioSessionSetActive(NO),
//				   "Couldn't deactivate the audio session");

		checkError(AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange,
															  sessionPropertyListener,
															  (__bridge void *)(self)),
			   "Couldn't remove audio session property listener");
	
	checkError(AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_CurrentHardwareOutputVolume,
															  sessionPropertyListener,
															  (__bridge void *)(self)),
			   "Couldn't remove audio session property listener");
		
		_activated = NO;
	}
}

- (void)pause {
	if (_playing) {
		
		_playing = checkError(AudioOutputUnitStop(_audioUnit),
							  "Couldn't stop the output unit");
	}
}

- (BOOL)play {
	if (!_playing) {
		
		if ([self activateAudioSession]) {
			
			_playing = !checkError(AudioOutputUnitStart(_audioUnit),
								   "Couldn't start the output unit");
		}
	}
	
	return _playing;
}
@end
@implementation WTAudioManager
+ (id<WTAudioManagerProtocl>)sharedManager{
	static WTAudioManagerImpl *_sharedManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_sharedManager = [[WTAudioManagerImpl alloc]init];
	});
	return _sharedManager;
}
@end
static void sessionPropertyListener(void *                  inClientData,
									AudioSessionPropertyID  inID,
									UInt32                  inDataSize,
									const void *            inData)
{
	WTAudioManagerImpl *sm = (__bridge WTAudioManagerImpl *)inClientData;
	//音频线路改变
	if (inID == kAudioSessionProperty_AudioRouteChange) {
		
		if ([sm checkAudioRoute]) {
			[sm checkSessionProperties];
		}
		//音频音量改变
	} else if (inID == kAudioSessionProperty_CurrentHardwareOutputVolume) {
		
		if (inData && inDataSize == 4) {
			
			sm.outputVolume = *(float *)inData;
		}
	}
}

static void sessionInterruptionListener(void *inClientData, UInt32 inInterruption)
{
	WTAudioManagerImpl *sm = (__bridge WTAudioManagerImpl *)inClientData;
	//开始打断
	if (inInterruption == kAudioSessionBeginInterruption) {
		
		LoggerAudio(2, @"Begin interuption");
		sm.playAfterSessionEndInterruption = sm.playing;
		[sm pause];
	//结束打断
	} else if (inInterruption == kAudioSessionEndInterruption) {
		
		LoggerAudio(2, @"End interuption");
		if (sm.playAfterSessionEndInterruption) {
			sm.playAfterSessionEndInterruption = NO;
			[sm play];
		}
	}
}

static OSStatus renderCallback (void						*inRefCon,
								AudioUnitRenderActionFlags	* ioActionFlags,
								const AudioTimeStamp 		* inTimeStamp,
								UInt32						inOutputBusNumber,
								UInt32						inNumberFrames,
								AudioBufferList				* ioData)
{
	WTAudioManagerImpl *sm = (__bridge WTAudioManagerImpl *)inRefCon;
	return [sm renderFrames:inNumberFrames ioData:ioData];
}

static BOOL checkError(OSStatus error, const char *operation)
{
	if (error == noErr)
		return NO;
	
	char str[20] = {0};
	// see if it appears to be a 4-char-code
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
		str[0] = str[5] = '\'';
		str[6] = '\0';
	} else
		// no, format it as an integer
		sprintf(str, "%d", (int)error);
	
	LoggerStream(0, @"Error: %s (%s)\n", operation, str);
	
	//exit(1);
	
	return YES;
}

