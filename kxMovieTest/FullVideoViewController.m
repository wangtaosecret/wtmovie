//
//  FullVideoViewController.m
//  kxMovieTest
//
//  Created by wangtao on 2017/10/26.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import "FullVideoViewController.h"
#import "WTMoviePlayView.h"
#import "AppDelegate.h"
@interface FullVideoViewController ()

@end

@implementation FullVideoViewController
{
	WTMoviePlayView *_moviePlayView;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)loadView{
	self.view = [[UIView alloc]initWithFrame:[UIScreen mainScreen].bounds];
	self.view.backgroundColor = [UIColor whiteColor];
//	NSString *path = BundlePath(@"1.mp4");
	
	NSString *path = @"http://hc.dewmobile.net/v8/share/show?uid=1000348&resId=42982";
	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	
	// increase buffering for .wmv, it solves problem with delaying audio frames
	if ([path.pathExtension isEqualToString:@"wmv"])
		parameters[WTMovieParameterMinBufferedDuration] = @(5.0);
	
	// disable deinterlacing for iPhone, because it's complex operation can cause stuttering
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
		parameters[WTMovieParameterDisableDeinterlacing] = @(YES);
	_moviePlayView = [WTMoviePlayView movieViewControllerWithContentPath:path parameters:parameters frame:self.view.bounds];
	//	_moviePlayView.transform =
	_moviePlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
	[self.view addSubview:_moviePlayView];
	
	
	UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeContactAdd];
	[closeBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
	closeBtn.center = CGPointMake(40, 40);
	[self.view addSubview:closeBtn];
	
	
//	[self begainFullScreen];
	
}
- (void)close{
	[self dismissViewControllerAnimated:YES completion:NULL];
	[_moviePlayView stopPlay];
	//强制取消旋转
	if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
		SEL selector = NSSelectorFromString(@"setOrientation:");
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
		[invocation setSelector:selector];
		[invocation setTarget:[UIDevice currentDevice]];
		int val =UIInterfaceOrientationPortrait;
		[invocation setArgument:&val atIndex:2];
		[invocation invoke];
	}
//	[self endFullScreen];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
	return  UIInterfaceOrientationMaskLandscapeRight|
	UIInterfaceOrientationMaskLandscapeLeft;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
