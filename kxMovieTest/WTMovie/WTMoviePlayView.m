//
//  WTMoviePlayView.m
//  kxMovieTest
//
//  Created by wangtao on 2017/10/13.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import "WTMoviePlayView.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "WTMovieDecoder.h"
#import "WTAudioManager.h"
#import "WTMovieGLView.h"
#import "WTLogger.h"
#import "WTMovieManager.h"




static NSString * wtformatTimeInterval(CGFloat seconds, BOOL isLeft)
{
	seconds = MAX(0, seconds);
	
	NSInteger s = seconds;
	NSInteger m = s / 60;
	NSInteger h = m / 60;
	
	s = s % 60;
	m = m % 60;
	
	NSMutableString *format = [(isLeft && seconds >= 0.5 ? @"-" : @"") mutableCopy];
	if (h != 0) [format appendFormat:@"%ld:%0.2ld", (long)h, (long)m];
	else        [format appendFormat:@"%ld", (long)m];
	[format appendFormat:@":%0.2ld", (long)s];
	
	return format;
}

static NSMutableDictionary * gHistory;



@interface WTMoviePlayView()
//是否正在播放
@property (readwrite) BOOL playing;
//是否正在解码
@property (readwrite) BOOL decoding;
//封面的frame
@property (readwrite, strong) WTArtworkFrame *artworkFrame;
@end
@implementation WTMoviePlayView{

	NSString 			*_path;
	//保存的当前0.1内的视频帧的数组
	NSMutableArray      *_videoFrames;
	//保存当前0.1秒内音频帧的数组
	NSMutableArray      *_audioFrames;
	//当前电影的播放时间
	CGFloat             _moviePosition;
	//是否禁止更新HUD
	BOOL                _disableUpdateHUD;

	BOOL                _hiddenHUD;
	//显示视频的view
	WTMovieGLView       *_glView;
	//显示视频的imageview,如果不是YUV颜色组成的视频使用imageView显示视频
	UIImageView         *_imageView;
	
	UIImageView			*_coverImageView;
	
	UIView              *_topHUD;
	//上面的工具view
	UIToolbar           *_topBar;
	//下面的工具view
	UIToolbar           *_bottomBar;
	//滚动条
	UISlider            *_progressSlider;
	
	//播放按钮
	UIBarButtonItem     *_playBtn;
	//暂停按钮
	UIBarButtonItem     *_pauseBtn;
	//回放按钮
	UIBarButtonItem     *_rewindBtn;
	//前进按钮
	UIBarButtonItem     *_fforwardBtn;
	
	UIBarButtonItem     *_spaceItem;
	UIBarButtonItem     *_fixedSpaceItem;
	//ok结束按钮
	UIButton            *_doneButton;
	//滚动总时间lable
	UILabel             *_progressLabel;
	//滚动已持续的时间lable
	UILabel             *_leftLabel;
	//叹号按钮
	UIButton            *_infoButton;
	
	//加载indicator
	UIActivityIndicatorView *_activityIndicatorView;
	UILabel             *_subtitlesLabel;
	//单击手势
	UITapGestureRecognizer *_tapGestureRecognizer;
	//双击手势
	UITapGestureRecognizer *_doubleTapGestureRecognizer;
	//
	UIPanGestureRecognizer *_panGestureRecognizer;
	
#ifdef DEBUG
	UILabel             *_messageLabel;
	
#endif

	//播放器参数
	NSDictionary        *_parameters;
}
- (void)stopPlay{
	if ([WTMovieManager sharedManager].playing) {
		
		[[WTMovieManager sharedManager] finishplay];
		
	}
}
#pragma mark 初始化方法
//+ (void)initialize
//{
//	if (!gHistory)
//		gHistory = [NSMutableDictionary dictionary];
//}
+ (instancetype)movieViewControllerWithContentPath:(NSString *)path
										parameters:(NSDictionary *)parameters
											 frame:(CGRect)frame{
	[[WTMovieManager sharedManager] activateAudioSession];
	return [[WTMoviePlayView alloc] initWithContentPath:path parameters:parameters frame:frame];
}
- (id)initWithContentPath: (NSString *) path
			   parameters: (NSDictionary *) parameters
					frame:(CGRect)frame{
	
	NSAssert(path.length > 0, @"empty path");
	
	self = [super initWithFrame:frame];
	if (self) {
		
		[self createView];
		
		_path = path;
		
		_moviePosition = 0;
		
		_parameters = parameters;
		
		
	}
	return self;
}
- (void)setMovieDecoder: (WTMovieDecoder *) decoder
			  withError: (NSError *) error
{
	LoggerStream(2, @"setMovieDecoder");
	
	if (!error && decoder) {
		
		//创建视频帧数组
		_videoFrames    = [WTMovieManager sharedManager].videoFrames;
		//创建音频帧数组
		_audioFrames    = [WTMovieManager sharedManager].audioFrames;

		//设置展示视频view
		[self setupPresentView];
		
		_progressLabel.hidden   = NO;
		_progressSlider.hidden  = NO;
		_leftLabel.hidden       = NO;
		_infoButton.hidden      = NO;
	}

}
#pragma mark view相关操作方法
- (void)createView{
	
	_coverImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"7a395e9bgy1fkf52hx0jqj20go0m8acq"]];
	_coverImageView.contentMode = UIViewContentModeScaleAspectFit;
	_coverImageView.frame = self.bounds;
	[self addSubview:_coverImageView];
	
	CGFloat width = self.bounds.size.width;
	CGFloat height = self.bounds.size.height;
	
	_activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
	_activityIndicatorView.center = CGPointMake(width * 0.5, height * 0.5);
	_activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	
	[self addSubview:_activityIndicatorView];
	
	
	
#ifdef DEBUG
	_messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20,40,width-40,40)];
	_messageLabel.backgroundColor = [UIColor clearColor];
	_messageLabel.textColor = [UIColor redColor];
	_messageLabel.hidden = YES;
	_messageLabel.font = [UIFont systemFontOfSize:14];
	_messageLabel.numberOfLines = 2;
	_messageLabel.textAlignment = NSTextAlignmentCenter;
	_messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self addSubview:_messageLabel];
#endif
	
	CGFloat topH = 50;
	CGFloat botH = 50;
	
	_topHUD    = [[UIView alloc] initWithFrame:CGRectMake(0,0,0,0)];
	_topBar    = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, width, topH)];
	_bottomBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, height-botH, width, botH)];
	_bottomBar.tintColor = [UIColor blackColor];
	
	_topHUD.frame = CGRectMake(0,0,width,_topBar.frame.size.height);
	
	_topHUD.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_bottomBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
	
	[self addSubview:_topBar];
	[self addSubview:_topHUD];
	[self addSubview:_bottomBar];
	
	// top hud
	
	_doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_doneButton.frame = CGRectMake(0, 1, 50, topH);
	_doneButton.backgroundColor = [UIColor clearColor];
	//    _doneButton.backgroundColor = [UIColor redColor];
	[_doneButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
	[_doneButton setTitle:NSLocalizedString(@"OK", nil) forState:UIControlStateNormal];
	_doneButton.titleLabel.font = [UIFont systemFontOfSize:18];
	_doneButton.showsTouchWhenHighlighted = YES;
	[_doneButton addTarget:self action:@selector(doneDidTouch:)
		  forControlEvents:UIControlEventTouchUpInside];
	//    [_doneButton setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
	
	_progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(46, 1, 50, topH)];
	_progressLabel.backgroundColor = [UIColor clearColor];
	_progressLabel.opaque = NO;
	_progressLabel.adjustsFontSizeToFitWidth = NO;
	_progressLabel.textAlignment = NSTextAlignmentRight;
	_progressLabel.textColor = [UIColor blackColor];
	_progressLabel.text = @"progress";
	_progressLabel.font = [UIFont systemFontOfSize:12];
	
	_progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(100, 2, width-197, topH)];
	_progressSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_progressSlider.continuous = NO;
	_progressSlider.value = 0;
	//    [_progressSlider setThumbImage:[UIImage imageNamed:@"kxmovie.bundle/sliderthumb"]
	//                          forState:UIControlStateNormal];
	
	_leftLabel = [[UILabel alloc] initWithFrame:CGRectMake(width-92, 1, 60, topH)];
	_leftLabel.backgroundColor = [UIColor clearColor];
	_leftLabel.opaque = NO;
	_leftLabel.adjustsFontSizeToFitWidth = NO;
	_leftLabel.textAlignment = NSTextAlignmentLeft;
	_leftLabel.textColor = [UIColor blackColor];
	_leftLabel.text = @"leftLabel";
	_leftLabel.font = [UIFont systemFontOfSize:12];
	_leftLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	
	
	
	[_topHUD addSubview:_doneButton];
	[_topHUD addSubview:_progressLabel];
	[_topHUD addSubview:_progressSlider];
	[_topHUD addSubview:_leftLabel];
	
	
	// bottom hud
	
	_spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
															   target:nil
															   action:nil];
	
	_fixedSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
																	target:nil
																	action:nil];
	_fixedSpaceItem.width = 30;
	
	_rewindBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind
															   target:self
															   action:@selector(rewindDidTouch:)];
	
	_playBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
															 target:self
															 action:@selector(playDidTouch:)];
	_playBtn.width = 50;
	
	_pauseBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
															  target:self
															  action:@selector(playDidTouch:)];
	_pauseBtn.width = 50;
	
	_fforwardBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward
																 target:self
																 action:@selector(forwardDidTouch:)];
	
	
	
	
	[self updateBottomBar];
	
	
	//测试释放播放资源
	UIButton *btn = [UIButton buttonWithType:UIButtonTypeContactAdd];
	[btn addTarget:self action:@selector(releaseresource) forControlEvents:UIControlEventTouchUpInside];
	btn.center = CGPointMake(100, 80);
	[self addSubview:btn];

}
- (void)releaseresource{
	
	[[WTMovieManager sharedManager] finishplay];
}
- (UIView *)frameView
{
	return _glView ? _glView : _imageView;
}
- (void)setupPresentView
{
	_coverImageView.hidden = YES;
	CGRect bounds = self.bounds;
	//如果视频是有效的视频，创建视频展示view
	if ([WTMovieManager sharedManager].decoder.validVideo) {
		_glView = [[WTMovieGLView alloc] initWithFrame:bounds decoder:[WTMovieManager sharedManager].decoder];
		
	}
	//如果创建视频view失败，那么使用imageview来展示视频帧
	if (!_glView) {
		
		LoggerVideo(0, @"fallback to use RGB video frame and UIKit");
		[[WTMovieManager sharedManager].decoder setupVideoFrameFormat:WTVideoFrameFormatRGB];
		_imageView = [[UIImageView alloc] initWithFrame:bounds];
		_imageView.backgroundColor = [UIColor blackColor];
	}
	//设置创建出来的显示视频帧的view
	UIView *frameView = [self frameView];
	frameView.contentMode = UIViewContentModeScaleAspectFit;
	//	frameView.frame = CGRectMake(0, 200, 375, 200);
	frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
	//将视频展示vie添加到self.view
	[self insertSubview:frameView atIndex:0];
	//视频有效设置交互点击
	if ([WTMovieManager sharedManager].decoder.validVideo) {
		
		[self setupUserInteraction];
		
	} else {
		//视频无效设置展位图
		_imageView.image = [UIImage imageNamed:@"kxmovie.bundle/music_icon.png"];
		_imageView.contentMode = UIViewContentModeCenter;
	}
	
	self.backgroundColor = [UIColor clearColor];
	//如果视频长度无限长，现在也就是直播类的视频，那么设置最大长度是∞
	if ([WTMovieManager sharedManager].decoder.duration == MAXFLOAT) {
		
		_leftLabel.text = @"\u221E"; // infinity
		_leftLabel.font = [UIFont systemFontOfSize:14];
		
		CGRect frame;
		
		frame = _leftLabel.frame;
		frame.origin.x += 40;
		frame.size.width -= 40;
		_leftLabel.frame = frame;
		
		frame =_progressSlider.frame;
		frame.size.width += 40;
		_progressSlider.frame = frame;
		
	} else {
		//视频长度不是无限的，设置slider可以滚动
		[_progressSlider addTarget:self
							action:@selector(progressDidChange:)
				  forControlEvents:UIControlEventValueChanged];
	}
	
	if ([WTMovieManager sharedManager].decoder.subtitleStreamsCount) {
		
		CGSize size = self.bounds.size;
		
		_subtitlesLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, size.height, size.width, 0)];
		_subtitlesLabel.numberOfLines = 0;
		_subtitlesLabel.backgroundColor = [UIColor clearColor];
		_subtitlesLabel.opaque = NO;
		_subtitlesLabel.adjustsFontSizeToFitWidth = NO;
		_subtitlesLabel.textAlignment = NSTextAlignmentCenter;
		_subtitlesLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_subtitlesLabel.textColor = [UIColor whiteColor];
		_subtitlesLabel.font = [UIFont systemFontOfSize:16];
		_subtitlesLabel.hidden = YES;
		
		[self addSubview:_subtitlesLabel];
	}
}
- (void)setupUserInteraction
{
	UIView * view = [self frameView];
	view.userInteractionEnabled = YES;
	
	_tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
	_tapGestureRecognizer.numberOfTapsRequired = 1;
	
	_doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
	_doubleTapGestureRecognizer.numberOfTapsRequired = 2;
	
	[_tapGestureRecognizer requireGestureRecognizerToFail: _doubleTapGestureRecognizer];
	
	[view addGestureRecognizer:_doubleTapGestureRecognizer];
	[view addGestureRecognizer:_tapGestureRecognizer];
	
}
- (void)updatePlayButton
{
	[self updateBottomBar];
}
- (void)updateBottomBar
{
	UIBarButtonItem *playPauseBtn = self.playing ? _pauseBtn : _playBtn;
	[_bottomBar setItems:@[_spaceItem, _rewindBtn, _fixedSpaceItem, playPauseBtn,
						   _fixedSpaceItem, _fforwardBtn, _spaceItem] animated:NO];
}
#pragma mark ui操作action
- (void)handlePan: (UIPanGestureRecognizer *) sender
{
	if (sender.state == UIGestureRecognizerStateEnded) {
		
		const CGPoint vt = [sender velocityInView:self];
		const CGPoint pt = [sender translationInView:self];
		const CGFloat sp = MAX(0.1, log10(fabs(vt.x)) - 1.0);
		const CGFloat sc = fabs(pt.x) * 0.33 * sp;
		if (sc > 10) {
			
			const CGFloat ff = pt.x > 0 ? 1.0 : -1.0;
			[[WTMovieManager sharedManager] setMoviePosition: _moviePosition + ff * MIN(sc, 600.0)];
		}
		//LoggerStream(2, @"pan %.2f %.2f %.2f sec", pt.x, vt.x, sc);
	}
}
- (void)handleTap: (UITapGestureRecognizer *) sender
{
	if (sender.state == UIGestureRecognizerStateEnded) {
		//单击隐藏
		if (sender == _tapGestureRecognizer) {
			
			[self showHUD: _hiddenHUD];
			
		} else if (sender == _doubleTapGestureRecognizer) {
			//双击放大
			UIView *frameView = [self frameView];
			
			if (frameView.contentMode == UIViewContentModeScaleAspectFit)
				frameView.contentMode = UIViewContentModeScaleAspectFill;
			else
				frameView.contentMode = UIViewContentModeScaleAspectFit;
			
		}
	}
}
- (void)showHUD: (BOOL) show
{
	_hiddenHUD = !show;
	_panGestureRecognizer.enabled = _hiddenHUD;
	
	[[UIApplication sharedApplication] setIdleTimerDisabled:_hiddenHUD];
	
	[UIView animateWithDuration:0.2
						  delay:0.0
						options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
					 animations:^{
						 
						 CGFloat alpha = _hiddenHUD ? 0 : 1;
						 _topBar.alpha = alpha;
						 _topHUD.alpha = alpha;
						 _bottomBar.alpha = alpha;
					 }
					 completion:nil];
	
}
- (void)enableUpdateHUD
{
	_disableUpdateHUD = NO;
}
- (void)playDidTouch: (id) sender
{
	if (self.playing)
		[self pause];
	else
		[self play];
}
- (void)forwardDidTouch: (id) sender
{
	if (_moviePosition == 0 && !_playing) return;
	[[WTMovieManager sharedManager] setMoviePosition: _moviePosition + 10];
	
}
- (void)rewindDidTouch: (id) sender
{
	if (_moviePosition == 0 && !_playing) return;
	[[WTMovieManager sharedManager] setMoviePosition: _moviePosition - 10];
}
- (void)progressDidChange: (id) sender
{
	NSAssert([WTMovieManager sharedManager].decoder.duration != MAXFLOAT, @"bugcheck");
	UISlider *slider = sender;
	[[WTMovieManager sharedManager] setMoviePosition:slider.value * [WTMovieManager sharedManager].decoder.duration];
}
- (void)updateHUD
{
	if (_disableUpdateHUD)
		return;
	
	const CGFloat duration = [WTMovieManager sharedManager].decoder.duration;
	const CGFloat position = _moviePosition - [WTMovieManager sharedManager].decoder.startTime;
	
	if (_progressSlider.state == UIControlStateNormal)
		_progressSlider.value = position / duration;
	_progressLabel.text = wtformatTimeInterval(position, NO);
	
	if ([WTMovieManager sharedManager].decoder.duration != MAXFLOAT)
		_leftLabel.text = wtformatTimeInterval(duration - position, YES);
	
}
#pragma mark 视频播放处理
- (void)play
{
	//给manager赋值path
	if (!_moviePosition) {
		
		if ([WTMovieManager sharedManager].playing) {
			
			[[WTMovieManager sharedManager] finishplay];
			
			
		}
		
		[WTMovieManager sharedManager].path = _path;
		[WTMovieManager sharedManager].parameters = _parameters;
	}
	
	
	[_activityIndicatorView startAnimating];
	
	[[WTMovieManager sharedManager] playCallBack:^(NSError *error) {
		
		[self setMovieDecoder:[WTMovieManager sharedManager].decoder withError:error];
		
	} renderFrameBlock:^(WTVideoFrame *frame) {
		
		if (_activityIndicatorView.isAnimating) {
			[_activityIndicatorView stopAnimating];
		}
		if (_glView) {

			[_glView render:frame];

		} else {

			WTVideoFrameRGB *rgbFrame = (WTVideoFrameRGB *)frame;
			_imageView.image = [rgbFrame asImage];
		}
	} updatePalyBtnBlock:^(BOOL playing){
		
		_playing = playing;
		[self updatePlayButton];
		
	} updateHudBlock:^(BOOL disableUpdateHUD, CGFloat moviePosition){
		
		_disableUpdateHUD = disableUpdateHUD;
		_moviePosition = moviePosition;
		[self updateHUD];
	} finishPlayBlock:^{
		
		_videoFrames = nil;
		_audioFrames = nil;
		
		_moviePosition = 0;
		
		[self updateHUD];
		
		_coverImageView.hidden = NO;
		
		UIView *frameView = [self frameView];
		[frameView removeFromSuperview];
		frameView = nil;
		[_glView removeFromSuperview];
		_glView = nil;
	}];

}
- (void)replay{
	[[WTMovieManager sharedManager] setMoviePosition: -1];
}
- (void)pause
{
	[[WTMovieManager sharedManager] pause];
}
@end
