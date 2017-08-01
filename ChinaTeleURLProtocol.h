//
//  ChinaTeleURLProtocol.h
//  HTTPProxyDemo
//
//  Created by Mai on 2017/7/24.
//  Copyright © 2017年 babybaby. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ResultManager;

@protocol ChinaTeleURLProtocolDelegate <NSObject>
@optional

- (void)urlLoadFailedWithResult:(ResultManager *)result;
- (void)urlLoadSuccessWithResult:(ResultManager *)result;

@end


@interface ChinaTeleURLProtocol : NSURLProtocol

@property (nonatomic,weak) id<ChinaTeleURLProtocolDelegate> delegate;

	//单利
+ (ChinaTeleURLProtocol *)sharedInstance;

@end

	//针对WKWebView不能被NSURLProtocol拦截的情况给出的处理办法
@interface NSURLProtocol (WKWebViewSupport)

+ (void)ChinaTeleWeb_RegisterScheme:(NSString *)scheme;
+ (void)ChinaTeleWeb_UnregisterScheme:(NSString *)scheme;


@end

