//
//  WTMovieView.m
//  kxMovieTest
//
//  Created by wangtao on 2017/9/21.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import "WTMovieView.h"
#import "WTMovieGLView.h"
#import "WTMovieManager.h"
#import "WTLogger.h"
#import "WTMovieDecoder.h"
@interface WTMovieView()
@property (readwrite) BOOL decoding;
@end
@implementation WTMovieView
{
	WTMovieManager		*_movieManager;
	WTMovieDecoder		*_decoder;
	NSString			*_path;
	//显示视频的view
	WTMovieGLView       *_glView;
	//显示视频的imageview,如果不是YUV颜色组成的视频使用imageView显示视频
	UIImageView         *_imageView;
	
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
	//叹号按钮点击出现的tableview
	UITableView         *_tableView;
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
	NSTimeInterval      _debugStartTime;
	NSUInteger          _debugAudioStatus;
	NSDate              *_debugAudioStatusTS;
#endif
	
	
	BOOL                _buffered;
	
	BOOL                _savedIdleTimer;
	
	NSDictionary        *_parameters;
	BOOL                _hiddenHUD;
	BOOL                _interrupted;
	BOOL                _disableUpdateHUD;
	
	NSTimeInterval      _tickCorrectionTime;
	NSTimeInterval      _tickCorrectionPosition;
	NSUInteger          _tickCounter;
	
	CGFloat             _bufferedDuration;
}

- (instancetype)init{
	return [self initWithFrame:CGRectZero];
}
- (instancetype)initWithFrame:(CGRect)frame{
	if (self == [super initWithFrame:frame]) {
		_movieManager = [WTMovieManager sharedManager];
		_decoder = _movieManager.decoder;
		
		[self createView];
		
	}
	return self;
}
- (instancetype)initWithContentPath:(NSString *)path
						 parameters:(NSDictionary *)parameters
							  frame:(CGRect)frame{
	_path = path;
	_parameters = parameters;

	return [self initWithFrame:frame];
}
- (void)createView{
	
	CGRect bounds = self.bounds;
	_activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
	_activityIndicatorView.center = self.center;
	_activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	
	[self addSubview:_activityIndicatorView];
	
	CGFloat width = bounds.size.width;
	CGFloat height = bounds.size.height;
	
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
	//movie decoder存在，设置底部的操作按钮
	if (_decoder) {

		[self setupPresentView];

	} else {
	
		_progressLabel.hidden = YES;
		_progressSlider.hidden = YES;
		_leftLabel.hidden = YES;
		_infoButton.hidden = YES;
	}
	
	
	if (_path) {
			
		[self setupUserInteraction];
	}else{
		//视频无效设置展位图
		_imageView.image = [UIImage imageNamed:@"kxmovie.bundle/music_icon.png"];
		_imageView.contentMode = UIViewContentModeCenter;
	}
}
- (void) updateBottomBar
{
	UIBarButtonItem *playPauseBtn = self.playing ? _pauseBtn : _playBtn;
	[_bottomBar setItems:@[_spaceItem, _rewindBtn, _fixedSpaceItem, playPauseBtn,
						   _fixedSpaceItem, _fforwardBtn, _spaceItem] animated:NO];
}
- (void)setupPresentView{
	
	CGRect bounds = self.bounds;
	
	_glView = [[WTMovieGLView alloc] initWithFrame:bounds decoder:_decoder];
	
	if (!_glView) {
		
		LoggerVideo(0, @"fallback to use RGB video frame and UIKit");
		[_decoder setupVideoFrameFormat:WTVideoFrameFormatRGB];
		_imageView = [[UIImageView alloc] initWithFrame:bounds];
		_imageView.backgroundColor = [UIColor blackColor];
	}
	
	UIView *frameView = [self frameView];
	frameView.contentMode = UIViewContentModeScaleAspectFit;
	frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
	//将视频展示vie添加到self.view
	[self insertSubview:frameView atIndex:0];
	
	self.backgroundColor = [UIColor clearColor];
	//如果视频长度无限长，现在也就是直播类的视频，那么设置最大长度是∞
	if (_decoder.duration == MAXFLOAT) {
		
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
	
	if (_decoder.subtitleStreamsCount) {
		
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
- (UIView *) frameView
{
	return _glView ? _glView : _imageView;
}

- (void) playDidTouch: (id) sender
{
	
	_movieManager.parameters = _parameters;
	_movieManager.renderFrameBlock = ^(WTVideoFrame *frame) {
		
		if (_glView) {

			[_glView render:frame];

		} else {

			WTVideoFrameRGB *rgbFrame = (WTVideoFrameRGB *)frame;
			_imageView.image = [rgbFrame asImage];
		}
	};
	_movieManager.path = _path;

}
- (void) setupUserInteraction
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

- (void) handleTap: (UITapGestureRecognizer *) sender
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
- (void) showHUD: (BOOL) show
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

- (void) forwardDidTouch: (id) sender
{
//	[self setMoviePosition: _moviePosition + 10];
}
//后退
- (void) rewindDidTouch: (id) sender
{
//	[self setMoviePosition: _moviePosition - 10];
}

- (void) progressDidChange: (id) sender
{
//	NSAssert(_decoder.duration != MAXFLOAT, @"bugcheck");
//	UISlider *slider = sender;
//	[self setMoviePosition:slider.value * _decoder.duration];
}
- (void) doneDidTouch: (id) sender
{
	
//	if (self.presentingViewController || !self.navigationController)
//		[self dismissViewControllerAnimated:YES completion:nil];
//	else
//		[self.navigationController popViewControllerAnimated:YES];
}


@end
