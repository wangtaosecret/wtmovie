//
//  WTLogger.h
//  WTMovieTest
//
//  Created by wangtao on 2017/9/11.
//  Copyright © 2017年 dewmobile. All rights reserved.
//

#ifndef WTLogger_h
#define WTLogger_h

#ifdef DEBUG
#ifdef USE_NSLOGGER

#    import "NSLogger.h"
#    define LoggerStream(level, ...)   LogMessageF(__FILE__, __LINE__, __FUNCTION__, @"Stream", level, __VA_ARGS__)
#    define LoggerVideo(level, ...)    LogMessageF(__FILE__, __LINE__, __FUNCTION__, @"Video",  level, __VA_ARGS__)
#    define LoggerAudio(level, ...)    LogMessageF(__FILE__, __LINE__, __FUNCTION__, @"Audio",  level, __VA_ARGS__)

#else

#    define LoggerStream(level, ...)   NSLog(__VA_ARGS__)
#    define LoggerVideo(level, ...)    NSLog(__VA_ARGS__)
#    define LoggerAudio(level, ...)    NSLog(__VA_ARGS__)

#endif
#else

#    define LoggerStream(...)          while(0) {}
#    define LoggerVideo(...)           while(0) {}
#    define LoggerAudio(...)           while(0) {}
#endif

#define BundlePath(res) [[NSBundle mainBundle] pathForResource:res ofType:nil]

#endif /* KXLogger_h */
