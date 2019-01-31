//
//  WTMovieManager.m
//  kxMovieTest
//
//  Created by wangtao on 2017/9/21.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import "WTMovieManager.h"
#import "WTMovieDecoder.h"
#import "WTAudioManager.h"
#import "WTLogger.h"

NSString * const WTMovieParameterMinBufferedDuration = @"WTMovieParameterMinBufferedDuration";
NSString * const WTMovieParameterMaxBufferedDuration = @"WTMovieParameterMaxBufferedDuration";
NSString * const WTMovieParameterDisableDeinterlacing = @"WTMovieParameterDisableDeinterlacing";

@implementation WTMovieManager{
	BOOL _decoding;//是否正在解码
	BOOL                _interrupted;
	//是否在缓冲
	BOOL                _buffered;
	BOOL				_disableUpdateHUD;
	
	
	CGFloat             _bufferedDuration;
	CGFloat             _minBufferedDuration;
	CGFloat             _maxBufferedDuration;
	
	NSTimeInterval      _tickCorrectionTime;
	NSTimeInterval      _tickCorrectionPosition;
	NSUInteger          _tickCounter;
	
	//现在正在播放显示的这一帧音频
	NSData              *_currentAudioFrame;
	//当前音频播放到的时间
	NSUInteger          _currentAudioFramePos;
#ifdef DEBUG
	NSTimeInterval      _debugStartTime;
	NSUInteger          _debugAudioStatus;
	NSDate              *_debugAudioStatusTS;
#endif
	RenderFrameBlock    _renderBlock;
	UpdatePlayeBtnBlock _updatePalyBtnBlock;
	UpdateHudBlock		_updateHudBlock;
	FinishPlayBlock		_finishPlayBlock;
}
+ (instancetype)sharedManager{
	static WTMovieManager *_sharedManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		_sharedManager = [[self alloc]init];
	});
	return _sharedManager;
}
- (instancetype)init{
	if (self == [super init]) {
		
		_decoder = [[WTMovieDecoder alloc] init];
		_audioManager = [WTAudioManager sharedManager];
		_dispatchQueue  = dispatch_queue_create("WTMovie", DISPATCH_QUEUE_SERIAL);
		_videoFrames = [NSMutableArray array];
		_audioFrames = [NSMutableArray array];
		_subtitles = [NSMutableArray array];
	}
	return self;
}
- (void)finishplay{
	
	[self pause];
	
	_buffered = NO;
//	_interrupted = YES;
	_moviePosition = 0;
	_playing = NO;
	_decoding = NO;
	_bufferedDuration = 0;
	_tickCorrectionTime = 0;
	_path = nil;
	
	
	_renderBlock = NULL;
	_updatePalyBtnBlock = NULL;
	_updateHudBlock = NULL;
	
	[self freeBufferedFrames];
	//关闭文件
	[_decoder closeFile];
	
	if (_finishPlayBlock) _finishPlayBlock();
	
	
//
//	_updatePalyBtnBlock(_playing);
//	_updateHudBlock(_disableUpdateHUD, _moviePosition);
	//	//打开空文件
//	[_decoder openFile:nil error:nil];
}
- (void)playCallBack:(void (^)(NSError *))callBack
	renderFrameBlock:(RenderFrameBlock)block
  updatePalyBtnBlock:(UpdatePlayeBtnBlock)updatePlayStatus
	  updateHudBlock:(UpdateHudBlock)updateHudBlock
	 finishPlayBlock:(FinishPlayBlock)finishPlayBlock{
	//正在播放，return
	if (_playing)
		return;
	//播放时间为0，开始播放新文件
	if (!_moviePosition) {

		__weak WTMovieManager *weakSelf = self;
		_renderBlock = block;
		_updatePalyBtnBlock = updatePlayStatus;
		_updateHudBlock = updateHudBlock;
		_finishPlayBlock = finishPlayBlock;
		_decoder.interruptCallback = ^BOOL{
			__strong WTMovieManager *strongSelf = weakSelf;
			return strongSelf ? [strongSelf interruptDecoder] : YES;
		};
	
		NSAssert(_path, @"当前decoder的path是空的！！！！");
		
		[self openFileAsyncWithFinishBlock:^(NSError *error) {
			
			callBack(error);
			
			[self setPlayParamters];
			
			[self realMoviePlay];
		}];
		return;
	}
	//播放时间不是0，继续暂停的播放
	[self realMoviePlay];
}
- (void)setPlayParamters{
	//是否为网络视频
	if (_decoder.isNetwork) {
		//最小缓存间隔
		_minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
		//最大缓存间隔
		_maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
		
	} else {//不是网络视频
		
		_minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
		_maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
	}
#pragma mark 只是音频的情况下
	if (!_decoder.validVideo)
		_minBufferedDuration *= 10.0; // increase for audio
	
	// allow to tweak some parameters at runtime
	if (_parameters.count) {
		
		id val;
		
		val = [_parameters valueForKey: WTMovieParameterMinBufferedDuration];
		if ([val isKindOfClass:[NSNumber class]])
			_minBufferedDuration = [val floatValue];
		
		val = [_parameters valueForKey: WTMovieParameterMaxBufferedDuration];
		if ([val isKindOfClass:[NSNumber class]])
			_maxBufferedDuration = [val floatValue];
		
		val = [_parameters valueForKey: WTMovieParameterDisableDeinterlacing];
		if ([val isKindOfClass:[NSNumber class]])
			_decoder.disableDeinterlacing = [val boolValue];
		
		if (_maxBufferedDuration < _minBufferedDuration)
			_maxBufferedDuration = _minBufferedDuration * 2;
	}
	
	LoggerStream(2, @"buffered limit: %.1f - %.1f", _minBufferedDuration, _maxBufferedDuration);
}
- (void)pause{
	if (!_playing)
		return;

	_playing = NO;
	//_interrupted = YES;
	//暂停音频
	[self enableAudio:NO];
	//更新播放按钮状态
	if (_updatePalyBtnBlock) _updatePalyBtnBlock(_playing);
	LoggerStream(1, @"pause movie");
}

- (void)realMoviePlay{
	//当前的电影解码器检测音频和视频都不是有效的return
	if (!_decoder.validVideo &&
		!_decoder.validAudio) {
		
		return;
	}
	//如果被打断return
	if (_interrupted)
		return;
	
	_playing = YES;
	_interrupted = NO;
	_disableUpdateHUD = NO;
	_tickCorrectionTime = 0;
	_tickCounter = 0;
	
#ifdef DEBUG
	_debugStartTime = -1;
#endif
	//异步解码视频frame
	[self asyncDecodeFrames];
	//更新播放按钮状态
	if (_updatePalyBtnBlock) _updatePalyBtnBlock(_playing);
	//开始定时更新ui
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		[self tick];
	});
	//如果电影解码器检测音频有效，播放音频
	if (_decoder.validAudio)
		[self enableAudio:YES];
	
	LoggerStream(1, @"play movie");
}
- (void)enableUpdateHUD
{
	_disableUpdateHUD = NO;
}
- (BOOL)interruptDecoder
{
	return _interrupted;
}

- (void)activateAudioSession{
	id<WTAudioManagerProtocl> audioManager = [WTMovieManager sharedManager].audioManager;
	[audioManager activateAudioSession];
}
- (void)setParameters:(NSDictionary *)parameters{
	_parameters = parameters;
}
- (void)openFileAsyncWithFinishBlock:(void (^)(NSError *))openFileBlock{
	dispatch_async(dispatch_get_global_queue(0, 0), ^{
		NSError *error = nil;
		
		[_decoder openFile:_path error:&error];

			dispatch_async(dispatch_get_main_queue(), ^{
				
				openFileBlock(error);
				
			});
	});
}
- (void)asyncDecodeFramesFinishBlock:(void (^)(NSArray *))finishBlock{
	if (_decoding)
		return;
	
	__weak WTMovieManager *weakSelf = self;
	__weak WTMovieDecoder *weakDecoder = [WTMovieManager sharedManager].decoder;
	
	const CGFloat duration = [WTMovieManager sharedManager].decoder.isNetwork ? .0f : 0.1f;
	
	_decoding = YES;
	
	dispatch_async([WTMovieManager sharedManager].dispatchQueue, ^{
		
//		{
//			__strong WTMovieManager *strongSelf = weakSelf;
//			if (!strongSelf.playing)
//				return;
//		}
		
		BOOL good = YES;
		while (good) {
			
			good = NO;
			
			@autoreleasepool {
			
				__strong WTMovieDecoder *decoder = weakDecoder;
				
				if (decoder && (decoder.validVideo || decoder.validAudio)) {
					
					NSArray *frames = [decoder decodeFrames:duration];
					
					
					if (frames.count) {
						
						__strong WTMovieManager *strongSelf = weakSelf;
						
						if (strongSelf)
							good = [strongSelf addFrames:frames];
							//good = finishBlock(frames);
						
					}
				}
			}
		}
		
		{
			
			_decoding = NO;
		}
	});
}
- (BOOL)addFrames: (NSArray *)frames
{
	if (_decoder.validVideo) {
		
		@synchronized(_videoFrames) {
			
			for (WTMovieFrame *frame in frames)
				if (frame.type == WTMovieFrameTypeVideo) {
					[_videoFrames addObject:frame];
					_bufferedDuration += frame.duration;
				}
		}
	}
	
	if (_decoder.validAudio) {
		
		@synchronized(_audioFrames) {
			
			for (WTMovieFrame *frame in frames)
				if (frame.type == WTMovieFrameTypeAudio) {
					[_audioFrames addObject:frame];
					if (![WTMovieManager sharedManager].decoder.validVideo)
						_bufferedDuration += frame.duration;
				}
		}
		
		if (!_decoder.validVideo) {
			
			for (WTMovieFrame *frame in frames)
				if (frame.type == WTMovieFrameTypeArtwork)
					self.artworkFrame = (WTArtworkFrame *)frame;
		}
	}
	
	if (_decoder.validSubtitles) {
		
		@synchronized(_subtitles) {
			
			for (WTMovieFrame *frame in frames)
				if (frame.type == WTMovieFrameTypeSubtitle) {
					[_subtitles addObject:frame];
				}
		}
	}
	
	return _playing && _bufferedDuration < _maxBufferedDuration;
}
- (void)asyncDecodeFrames
{
	[[WTMovieManager sharedManager] asyncDecodeFramesFinishBlock:^(NSArray *frames) {
		{
			
		}
	}];
}
- (void)tick
{
	if (_path == nil) return;
	if (_buffered && ((_bufferedDuration > _minBufferedDuration) || [WTMovieManager sharedManager].decoder.isEOF)) {
		
		_tickCorrectionTime = 0;
		_buffered = NO;
//		[_activityIndicatorView stopAnimating];
	}
	
	CGFloat interval = 0;
	if (!_buffered)
		interval = [self presentFrame];
	
	if (_playing) {

		const NSUInteger leftFrames =
		(_decoder.validVideo ? _videoFrames.count : 0) +
		(_decoder.validAudio ? _audioFrames.count : 0);
		
		if (0 == leftFrames) {
			
			if ([WTMovieManager sharedManager].decoder.isEOF) {
//				[self finishPlay];
				[self pause];
				NSLog(@"播放完了");
				if (_updateHudBlock) _updateHudBlock(_disableUpdateHUD, _moviePosition);
				return;
			}
			
			if (_minBufferedDuration > 0 && !_buffered) {
				
				_buffered = YES;
//				[_activityIndicatorView startAnimating];
			}
		}
		
		if (!leftFrames ||
			!(_bufferedDuration > _minBufferedDuration)) {
			
			[self asyncDecodeFrames];
		}
		
		const NSTimeInterval correction = [self tickCorrection];
		const NSTimeInterval time = MAX(interval + correction, 0.01);
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
			
			[self tick];
		});
	
		
	}
	
	if ((_tickCounter++ % 3) == 0) {

		if (_updateHudBlock) _updateHudBlock(_disableUpdateHUD, _moviePosition);
	}
}

- (CGFloat)tickCorrection
{
	if (_buffered)
		return 0;
	
	const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	
	if (!_tickCorrectionTime) {
		
		_tickCorrectionTime = now;
		_tickCorrectionPosition = _moviePosition;
		return 0;
	}
	
	NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
	NSTimeInterval dTime = now - _tickCorrectionTime;
	NSTimeInterval correction = dPosition - dTime;
	
	//if ((_tickCounter % 200) == 0)
	//    LoggerStream(1, @"tick correction %.4f", correction);
	
	if (correction > 1.f || correction < -1.f) {
		
		LoggerStream(1, @"tick correction reset %.2f", correction);
		correction = 0;
		_tickCorrectionTime = 0;
	}
	
	return correction;
}
- (CGFloat)presentFrame
{
	CGFloat interval = 0;
	
	if ([WTMovieManager sharedManager].decoder.validVideo) {
		
		WTVideoFrame *frame;
		
		@synchronized(_videoFrames) {
			
			if (_videoFrames.count > 0) {
				
				frame = _videoFrames[0];
				[_videoFrames removeObjectAtIndex:0];
				_bufferedDuration -= frame.duration;
			}
		}
		
		if (frame)
			interval = [self presentVideoFrame:frame];
		
	} else if ([WTMovieManager sharedManager].decoder.validAudio) {
		
		interval = _bufferedDuration * 0.5;
		
		if (self.artworkFrame) {
#pragma mark artworkFrame
//			_imageView.image = [self.artworkFrame asImage];
			self.artworkFrame = nil;
		}
	}
	
	if ([WTMovieManager sharedManager].decoder.validSubtitles)
		[self presentSubtitles];
	
#ifdef DEBUG
	if (self.playing && _debugStartTime < 0)
		_debugStartTime = [NSDate timeIntervalSinceReferenceDate] - _moviePosition;
#endif
	
	return interval;
}
- (CGFloat)presentVideoFrame: (WTVideoFrame *) frame
{
	if (_renderBlock) _renderBlock(frame);

	
	_moviePosition = frame.position;
	
	return frame.duration;
}
//处理外挂字幕，未完成
- (void)presentSubtitles
{
	NSArray *actual, *outdated;

	if ([self subtitleForPosition:_moviePosition
						   actual:&actual
						 outdated:&outdated]){

		if (outdated.count) {
			@synchronized(_subtitles) {
				[_subtitles removeObjectsInArray:outdated];
			}
		}

//		if (actual.count) {
//
//			NSMutableString *ms = [NSMutableString string];
//			for (WTSubtitleFrame *subtitle in actual.reverseObjectEnumerator) {
//				if (ms.length) [ms appendString:@"\n"];
//				[ms appendString:subtitle.text];
//			}
//
//			if (![_subtitlesLabel.text isEqualToString:ms]) {
//
//				CGSize viewSize = self.bounds.size;
//				CGSize size = [ms sizeWithFont:_subtitlesLabel.font
//							 constrainedToSize:CGSizeMake(viewSize.width, viewSize.height * 0.5)
//								 lineBreakMode:NSLineBreakByTruncatingTail];
//				_subtitlesLabel.text = ms;
//				_subtitlesLabel.frame = CGRectMake(0, viewSize.height - size.height - 10,
//												   viewSize.width, size.height);
//				_subtitlesLabel.hidden = NO;
//			}
//
//		} else {
//
//			_subtitlesLabel.text = nil;
//			_subtitlesLabel.hidden = YES;
//		}
	}
}
- (BOOL)subtitleForPosition: (CGFloat) position
					 actual: (NSArray **) pActual
				   outdated: (NSArray **) pOutdated
{
	if (!_subtitles.count)
		return NO;
	
	NSMutableArray *actual = nil;
	NSMutableArray *outdated = nil;
	
	for (WTSubtitleFrame *subtitle in _subtitles) {
		
		if (position < subtitle.position) {
			
			break; // assume what subtitles sorted by position
			
		} else if (position >= (subtitle.position + subtitle.duration)) {
			
			if (pOutdated) {
				if (!outdated)
					outdated = [NSMutableArray array];
				[outdated addObject:subtitle];
			}
			
		} else {
			
			if (pActual) {
				if (!actual)
					actual = [NSMutableArray array];
				[actual addObject:subtitle];
			}
		}
	}
	
	if (pActual) *pActual = actual;
	if (pOutdated) *pOutdated = outdated;
	
	return actual.count || outdated.count;
}
- (void)enableAudio: (BOOL) on
{
	id<WTAudioManagerProtocl> audioManager = [WTAudioManager sharedManager];
	
	if (on && _decoder.validAudio) {
		
		audioManager.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
			
			[self audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
		};
		
		[audioManager play];
		
		LoggerAudio(2, @"audio device smr: %d fmt: %d chn: %d",
					(int)audioManager.samplingRate,
					(int)audioManager.numBytesPerSample,
					(int)audioManager.numOutputChannels);
		
	} else {
		
		[audioManager pause];
		audioManager.outputBlock = nil;
	}
}
- (void)audioCallbackFillData: (float *) outData
					numFrames: (UInt32) numFrames
				  numChannels: (UInt32) numChannels
{
	//fillSignalF(outData,numFrames,numChannels);
	//return;
	
	if (_buffered) {
		memset(outData, 0, numFrames * numChannels * sizeof(float));
		return;
	}
	
	@autoreleasepool {
		
		while (numFrames > 0) {
			
			if (!_currentAudioFrame) {
				
				@synchronized(_audioFrames) {
					
					NSUInteger count = _audioFrames.count;
					
					if (count > 0) {
						
						WTAudioFrame *frame = _audioFrames[0];
						
#ifdef DUMP_AUDIO_DATA
						LoggerAudio(2, @"Audio frame position: %f", frame.position);
#endif
						if ([WTMovieManager sharedManager].decoder.validVideo) {
							
							const CGFloat delta = _moviePosition - frame.position;
							
							if (delta < -0.1) {
								
								memset(outData, 0, numFrames * numChannels * sizeof(float));
#ifdef DEBUG
								LoggerStream(0, @"desync audio (outrun) wait %.4f %.4f", _moviePosition, frame.position);
								_debugAudioStatus = 1;
								_debugAudioStatusTS = [NSDate date];
#endif
								break; // silence and exit
							}
							
							[_audioFrames removeObjectAtIndex:0];
							
							if (delta > 0.1 && count > 1) {
								
#ifdef DEBUG
								LoggerStream(0, @"desync audio (lags) skip %.4f %.4f", _moviePosition, frame.position);
								_debugAudioStatus = 2;
								_debugAudioStatusTS = [NSDate date];
#endif
								continue;
							}
							
						} else {
							
							[_audioFrames removeObjectAtIndex:0];
							_moviePosition = frame.position;
							_bufferedDuration -= frame.duration;
						}
						
						_currentAudioFramePos = 0;
						_currentAudioFrame = frame.samples;
					}
				}
			}
			
			if (_currentAudioFrame) {
				
				const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
				const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
				const NSUInteger frameSizeOf = numChannels * sizeof(float);
				const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
				const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
				
				memcpy(outData, bytes, bytesToCopy);
				numFrames -= framesToCopy;
				outData += framesToCopy * numChannels;
				
				if (bytesToCopy < bytesLeft)
					_currentAudioFramePos += bytesToCopy;
				else
					_currentAudioFrame = nil;
				
			} else {
				
				memset(outData, 0, numFrames * numChannels * sizeof(float));
				//LoggerStream(1, @"silence audio");
#ifdef DEBUG
				_debugAudioStatus = 3;
				_debugAudioStatusTS = [NSDate date];
#endif
				break;
			}
		}
	}
}
#pragma mark 视频操作方法
- (void)setDecoderPosition: (CGFloat) position
{
	[WTMovieManager sharedManager].decoder.position = position;
}
- (void)updatePosition: (CGFloat) position
			  playMode: (BOOL) playMode
{
	[self freeBufferedFrames];
	
	position = MIN([WTMovieManager sharedManager].decoder.duration - 1, MAX(0, position));
	
	__weak WTMovieManager *weakSelf = self;
	
	dispatch_async([WTMovieManager sharedManager].dispatchQueue, ^{
		
		if (playMode) {
			
			{
				__strong WTMovieManager *strongSelf = weakSelf;
				if (!strongSelf) return;
				[strongSelf setDecoderPosition: position];
			}
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				__strong WTMovieManager *strongSelf = weakSelf;
				if (strongSelf) {
					[strongSelf setMoviePositionFromDecoder];
					[strongSelf realMoviePlay];
				}
			});
			
		} else {
			
			{
				__strong WTMovieManager *strongSelf = weakSelf;
				if (!strongSelf) return;
				[strongSelf setDecoderPosition: position];
				[strongSelf decodeFrames];
			}
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				__strong WTMovieManager *strongSelf = weakSelf;
				if (strongSelf) {
					
					[strongSelf enableUpdateHUD];
					[strongSelf setMoviePositionFromDecoder];
					[strongSelf presentFrame];
					if (_updateHudBlock) _updateHudBlock(_disableUpdateHUD, _moviePosition);
				}
			});
		}
	});
}
- (void)setMoviePositionFromDecoder
{
	_moviePosition = [WTMovieManager sharedManager].decoder.position;
}
- (void)setMoviePosition: (CGFloat) position
{
	BOOL playMode = self.playing;
	
	self.playing = NO;
	_disableUpdateHUD = YES;
	[self enableAudio:NO];
	
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		
		[self updatePosition:position playMode:playMode];
	});
}
- (BOOL)decodeFrames
{
	//NSAssert(dispatch_get_current_queue() == _dispatchQueue, @"bugcheck");
	
	NSArray *frames = nil;
	
	if ([WTMovieManager sharedManager].decoder.validVideo ||
		[WTMovieManager sharedManager].decoder.validAudio) {
		
		frames = [[WTMovieManager sharedManager].decoder decodeFrames:0];
	}
	
	if (frames.count) {
		//		return [self addFrames: frames];
	}
	return NO;
}
#pragma mark 视频资源释放
- (void)freeBufferedFrames
{
	@synchronized(_videoFrames) {
		[_videoFrames removeAllObjects];
	}
	
	@synchronized(_audioFrames) {
		
		[_audioFrames removeAllObjects];
		_currentAudioFrame = nil;
	}
	
	if (_subtitles) {
		@synchronized(_subtitles) {
			[_subtitles removeAllObjects];
		}
	}
	
	_bufferedDuration = 0;
}
@end
