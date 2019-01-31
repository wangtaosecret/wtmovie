//
//  ViewController.m
//  kxMovieTest
//
//  Created by wangtao on 2017/9/11.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#import "ViewController.h"
#import "KxMovieViewController.h"
#import "WTMoviePlayView.h"
#import "FullVideoViewController.h"

#include "libavutil/timestamp.h"
#include <libavformat/avformat.h>

#define DocumentDir [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]
#define BundlePath(res) [[NSBundle mainBundle] pathForResource:res ofType:nil]
#define DocumentPath(res) [DocumentDir stringByAppendingPathComponent:res]

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt, const char *tag)
{
	AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;
	
	printf("%s: pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s stream_index:%d\n",
		   tag,
		   av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
		   av_ts2str(pkt->dts), av_ts2timestr(pkt->dts, time_base),
		   av_ts2str(pkt->duration), av_ts2timestr(pkt->duration, time_base),
		   pkt->stream_index);
}

/**
 截取本地或者网络视频

 @param from_seconds 开始截取的时间点
 @param end_seconds 截取截止的时间点
 @param in_filename 本地文件路径或网络地址
 @param out_filename 输出到的路径
 @return 0成功，其他失败
 */
int cut_video(double from_seconds, double end_seconds, const char* in_filename, const char* out_filename) {
	AVOutputFormat *ofmt = NULL;
	AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
	AVPacket pkt;
	int ret, i;
	
	av_register_all();
	
	if ((ret = avformat_open_input(&ifmt_ctx, in_filename, 0, 0)) < 0) {
		fprintf(stderr, "Could not open input file '%s'", in_filename);
		goto end;
	}
	
	if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
		fprintf(stderr, "Failed to retrieve input stream information");
		goto end;
	}
	
	av_dump_format(ifmt_ctx, 0, in_filename, 0);
	
	avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_filename);
	if (!ofmt_ctx) {
		fprintf(stderr, "Could not create output context\n");
		ret = AVERROR_UNKNOWN;
		goto end;
	}
	
	ofmt = ofmt_ctx->oformat;
	
	for (i = 0; i < ifmt_ctx->nb_streams; i++) {
		AVStream *in_stream = ifmt_ctx->streams[i];
		AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
		if (!out_stream) {
			fprintf(stderr, "Failed allocating output stream\n");
			ret = AVERROR_UNKNOWN;
			goto end;
		}
		
		ret = avcodec_copy_context(out_stream->codec, in_stream->codec);
		if (ret < 0) {
			fprintf(stderr, "Failed to copy context from input to output stream codec context\n");
			goto end;
		}
		out_stream->codec->codec_tag = 0;
		//		if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
		//			out_stream->codec->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
	}
	av_dump_format(ofmt_ctx, 0, out_filename, 1);
	
	if (!(ofmt->flags & AVFMT_NOFILE)) {
		ret = avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE);
		if (ret < 0) {
			fprintf(stderr, "Could not open output file '%s'", out_filename);
			goto end;
		}
	}
	
	ret = avformat_write_header(ofmt_ctx, NULL);
	if (ret < 0) {
		fprintf(stderr, "Error occurred when opening output file\n");
		goto end;
	}
	
	//    int indexs[8] = {0};
	
	
	//    int64_t start_from = 8*AV_TIME_BASE;
	ret = av_seek_frame(ifmt_ctx, -1, from_seconds*AV_TIME_BASE, AVSEEK_FLAG_ANY);
	if (ret < 0) {
		fprintf(stderr, "Error seek\n");
		goto end;
	}
	
	int64_t *dts_start_from = malloc(sizeof(int64_t) * ifmt_ctx->nb_streams);
	memset(dts_start_from, 0, sizeof(int64_t) * ifmt_ctx->nb_streams);
	int64_t *pts_start_from = malloc(sizeof(int64_t) * ifmt_ctx->nb_streams);
	memset(pts_start_from, 0, sizeof(int64_t) * ifmt_ctx->nb_streams);
	
	while (1) {
		AVStream *in_stream, *out_stream;
		
		ret = av_read_frame(ifmt_ctx, &pkt);
		if (ret < 0)
			break;
		
		in_stream  = ifmt_ctx->streams[pkt.stream_index];
		out_stream = ofmt_ctx->streams[pkt.stream_index];
		
		log_packet(ifmt_ctx, &pkt, "in");
		
		if (av_q2d(in_stream->time_base) * pkt.pts > end_seconds) {
			av_free_packet(&pkt);
			break;
		}
		
		if (dts_start_from[pkt.stream_index] == 0) {
			dts_start_from[pkt.stream_index] = pkt.dts;
			printf("dts_start_from: %s\n", av_ts2str(dts_start_from[pkt.stream_index]));
		}
		if (pts_start_from[pkt.stream_index] == 0) {
			pts_start_from[pkt.stream_index] = pkt.pts;
			printf("pts_start_from: %s\n", av_ts2str(pts_start_from[pkt.stream_index]));
		}
		
		/* copy packet */
		pkt.pts = av_rescale_q_rnd(pkt.pts - pts_start_from[pkt.stream_index], in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
		pkt.dts = av_rescale_q_rnd(pkt.dts - dts_start_from[pkt.stream_index], in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
		if (pkt.pts < 0) {
			pkt.pts = 0;
		}
		if (pkt.dts < 0) {
			pkt.dts = 0;
		}
		pkt.duration = (int)av_rescale_q((int64_t)pkt.duration, in_stream->time_base, out_stream->time_base);
		pkt.pos = -1;
		log_packet(ofmt_ctx, &pkt, "out");
		printf("\n");
		
		ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
		if (ret < 0) {
			fprintf(stderr, "Error muxing packet\n");
			break;
		}
		av_free_packet(&pkt);
	}
	free(dts_start_from);
	free(pts_start_from);
	
	av_write_trailer(ofmt_ctx);
end:
	
	avformat_close_input(&ifmt_ctx);
	
	/* close output */
	if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
		avio_closep(&ofmt_ctx->pb);
	avformat_free_context(ofmt_ctx);
	
	if (ret < 0 && ret != AVERROR_EOF) {
		fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
		return 1;
	}
	
	return 0;
}


@interface ViewController ()

@end

@implementation ViewController
{
//	WTMovieView *_movieView;
	WTMoviePlayView *_moviePlayView;
	WTMoviePlayView *_moviePlayView1;
}
- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
//	NSString *path = @"http://hdl.9158.com/live/0553cef17fee7798c362e229da3b341c.flv";
	NSString *path = @"http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4";
//	NSString *path = BundlePath(@"chuanqi.wav");
//	NSString *path = BundlePath(@"testflv.flv");
	
	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	
	// increase buffering for .wmv, it solves problem with delaying audio frames
	if ([path.pathExtension isEqualToString:@"wmv"])
		parameters[WTMovieParameterMinBufferedDuration] = @(5.0);
	
	// disable deinterlacing for iPhone, because it's complex operation can cause stuttering
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
		parameters[WTMovieParameterDisableDeinterlacing] = @(YES);
	_moviePlayView = [WTMoviePlayView movieViewControllerWithContentPath:path parameters:parameters frame:CGRectMake(0, 100, 375, 200)];
//	_moviePlayView.transform = 
	[self.view addSubview:_moviePlayView];
	
	
	NSString *path1 = BundlePath(@"launch.mp4");
	_moviePlayView1 = [WTMoviePlayView movieViewControllerWithContentPath:path1 parameters:parameters frame:CGRectMake(0, 400, 375, 200)];
	//	_moviePlayView.transform =
	[self.view addSubview:_moviePlayView1];
	
	
	
	
	
//	_movieView = [[WTMovieView alloc] initWithContentPath:path parameters:parameters frame:CGRectMake(0, 200, 375, 200)];
//
//	[self.view addSubview:_movieView];
	
	
	UIButton *btn = [UIButton buttonWithType:UIButtonTypeContactAdd];
	btn.center = CGPointMake(150, 100);
	[btn addTarget:self action:@selector(showPlayer) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:btn];
	
	

	
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}
- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	
	
	
//	NSLog(@"%@", [NSThread callStackSymbols]);
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return NO;
}
- (BOOL)shouldAutorotate{
	return NO;
}
- (void)showPlayer{
//	FullVideoViewController *f = [[FullVideoViewController alloc]init];
//	[self presentViewController:f animated:YES completion:NULL];
	
//	[_moviePlayView removeFromSuperview];
//	_moviePlayView = nil;
//	[_moviePlayView replay];
	
	//测试直播地址
//	NSString *path = @"http://hdl.9158.com/live/0553cef17fee7798c362e229da3b341c.flv";
	//测试远程地址
	    NSString *path = @"http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4";
//	NSString *path = @"http://f.kuaiya.cn/92a12a2264584c84e58c09469630353a_t.mp4";
	//测试本地视频
//	NSString *path = BundlePath(@"input.mp4");
//	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
//
//	// increase buffering for .wmv, it solves problem with delaying audio frames
//	if ([path.pathExtension isEqualToString:@"wmv"])
//		parameters[KxMovieParameterMinBufferedDuration] = @(5.0);
//
//	// disable deinterlacing for iPhone, because it's complex operation can cause stuttering
//	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
//		parameters[KxMovieParameterDisableDeinterlacing] = @(YES);
//
//	KxMovieViewController *vc = [KxMovieViewController movieViewControllerWithContentPath:path
//																			   parameters:parameters];
//	[self presentViewController:vc animated:YES completion:nil];
	
	
	//测试截取网络视频
	int code = cut_video(20, 40, [@"http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4" UTF8String], [DocumentPath(@"cut.mp4")  UTF8String]);
	if (code == 0) {
		NSLog(@"截取视频成功");
	}
}
@end
