//
//  ChinaTeleURLProtocol.m
//  HTTPProxyDemo
//
//  Created by Mai on 2017/7/24.
//  Copyright © 2017年 babybaby. All rights reserved.
//

#import <WebKit/WebKit.h>
#import "ChinaTeleURLProtocol.h"
#import "DNCommonTool.h"
#import "ConfigMarco.h"
#import "ResultManager.h"


#define ChinaTeleURLProtocolHandledKey @"ChinaTeleURLProtocolHandledKey"


Class ChinaTele_ContextControllerClass() {
	static Class cls;
	if (!cls) {
		cls = [[[WKWebView new] valueForKey:@"browsingContextController"] class];
	}
	return cls;
}

SEL ChinaTeleWeb_RegisterSchemeSelector() {
	return NSSelectorFromString(@"registerSchemeForCustomProtocol:");
}

SEL ChinaTeleWeb_UnregisterSchemeSelector() {
	return NSSelectorFromString(@"unregisterSchemeForCustomProtocol:");
}


@interface ChinaTeleURLProtocol ()<NSURLSessionDataDelegate,NSURLSessionDelegate,NSURLSessionTaskDelegate>

@property (nonatomic, strong) NSURLSessionDataTask *managerSession;
@end


@implementation ChinaTeleURLProtocol

+ (ChinaTeleURLProtocol *)sharedInstance {
	
	static ChinaTeleURLProtocol *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc]init];
	});
	
	return sharedInstance;
}

/**
 *  定义拦截请求的URL规则
 *  这个方法主要是说明你是否打算处理对应的request，如果不打算处理，返回NO，URL Loading System会使用系统默认的行为去处理；如果打算处理，返回YES，然后你就需要处理该请求的所有东西，包括获取请求数据并返回给 URL Loading System
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
	NSLog(@"是否要进行处理");
	if (![ChinaTeleProxyManager sharedInstance].proxyStatus) {
		return NO;
	}
	
		//只处理http和https请求
	NSString *scheme = [[[request URL] scheme]lowercaseString];
	if([scheme caseInsensitiveCompare:@"http"] == NSOrderedSame
		 || [scheme caseInsensitiveCompare:@"https"] == NSOrderedSame)
	{
			//看看是否已经处理过了，防止无限循环 也可以设置为yes  目的只是标记
		if ([NSURLProtocol propertyForKey:ChinaTeleURLProtocolHandledKey inRequest:request]) {
			return NO;
		}
		
		return YES;
	}
	return NO;
}


- (instancetype)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client {
	
	return [super initWithRequest:request cachedResponse:cachedResponse client:client];
}


/**
 *  可选方法，对于需要修改请求头的请求在该方法中修改
 *
 */
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
	
	
	return request;
}

/**
 *  判断两个 request 是否相同，如果相同的话可以使用缓存数据，通常只需要调用父类的实现。
 *
 *
 */
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
	return [super requestIsCacheEquivalent:a toRequest:b];
}
	//根据运营商平台调用处理方式来实现http/https代理访问
- (void)reviseRequestHeaderAndTransmitRequest:(NSURLRequest *)request {
	
		//根据电信代理后台的认证规则修改对应的请求头实现代理连接
	NSMutableURLRequest *mutableRequest = [request mutableCopy];
	[self chinaTelecomConnectToHttpProxyWithRequest:mutableRequest];
}
	//根据电信代理后台的认证规则修改对应的请求头实现代理连接
- (void)chinaTelecomConnectToHttpProxyWithRequest:(NSMutableURLRequest *)mutableRequest {
	NSString *original_host = mutableRequest.URL.host;
	
	
		//根据http/https协议 分别设置请求头
	NSString *scheme = [[[mutableRequest URL] scheme]lowercaseString];
	if([scheme caseInsensitiveCompare:@"http"] == NSOrderedSame) {
		
		[mutableRequest setValue:[NSString stringWithFormat:@"%@|%@",authmode, authInfo] forHTTPHeaderField:@"X-Meteorq"];
	}else {
		
		[mutableRequest setValue:[NSString stringWithFormat:@"%@|%@",authmode, authInfo] forHTTPHeaderField:@"Proxy-Authorization"];
	}
	NSLog(@"请求头 mutableRequestHeader :%@",mutableRequest.allHTTPHeaderFields);
	

	NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
	config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
	
	NSString *proxyHost = ProxyIP;
	NSNumber *proxyPort = [NSNumber numberWithInteger:[ProxyPort integerValue]];
	NSLog(@"protxyHost : %@ proxyPort :%@",proxyHost,proxyPort);
	
	NSDictionary *proxyDict = @{
															
															@"HTTPEnable" : [NSNumber numberWithInt:1],
															(NSString *)kCFStreamPropertyHTTPProxyHost : proxyHost,
															(NSString *)kCFStreamPropertyHTTPProxyPort : proxyPort,
															
															
															@"HTTPSEnable" : [NSNumber numberWithInt:1],
															(NSString *)kCFStreamPropertyHTTPSProxyHost : proxyHost,
															(NSString *)kCFStreamPropertyHTTPSProxyPort : proxyPort,
															};
	config.connectionProxyDictionary = proxyDict;
		//标示改request已经处理过了，防止无限循环
	[NSURLProtocol setProperty:@(YES) forKey:ChinaTeleURLProtocolHandledKey inRequest:mutableRequest];
	
	NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]]; //[NSOperationQueue mainQueue]
	
	self.delegate = [ChinaTeleURLProtocol sharedInstance].delegate;
	
	self.managerSession = [session dataTaskWithRequest:mutableRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (error) {
				
				NSLog(@"error = %@" , error);
				[self.client URLProtocol:self didFailWithError:error];
				
			}else {
				
				NSLog(@"--response = %@",response);
				NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
			}
		});
	}];
	[self.managerSession resume];
}

/**
 *  对于拦截的请求，系统创建一个NSURLProtocol对象执行startLoading方法开始加载请求
 */
- (void)startLoading {
	NSLog(@"代理服务器开始加载请求");
	
		//修改请求头UA并转发请求
	[self reviseRequestHeaderAndTransmitRequest:self.request];
}


/**
 *  对于拦截的请求，NSURLProtocol对象在停止加载时调用该方法
 */
- (void)stopLoading {
	
	NSLog(@"代理服务停止加载请求");
	
	[self.managerSession cancel];
	self.managerSession = nil;
	
}
	//抽取成功回调的方法
- (void)callBackWhenDidLoadSuccessWithErrCode:(NSUInteger)code Message:(NSString *)message {
	
	NSLog(@"抽取成功回调的方法");
	ResultManager *result = [[ResultManager alloc]init];
	result.errCode = code;
	result.message = message;
	
	if (self.delegate && [self.delegate respondsToSelector:@selector(urlLoadSuccessWithResult:)]) {
		
		[self.delegate urlLoadSuccessWithResult:result];
	}
}
	//抽取失败回调的方法
- (void)callBackWhenDidLoadFailWithErrCode:(NSUInteger)code Message:(NSString *)message {
	
	ResultManager *result = [[ResultManager alloc]init];
	result.errCode = code;
	result.message = message;
	
	if (self.delegate && [self.delegate respondsToSelector:@selector(urlLoadFailedWithResult:)]) {
		
		[self.delegate urlLoadFailedWithResult:result];
	}
}
#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self.client URLProtocol:self didLoadData:data];
	});
	
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
	
	NSLog(@"response=%@",response);
	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
	self.delegate = [ChinaTeleURLProtocol sharedInstance].delegate;
	
	if (httpResponse.statusCode >= DNHTTPProxySuccess && httpResponse.statusCode < 300 ) {
		
		[self callBackWhenDidLoadSuccessWithErrCode:httpResponse.statusCode Message:@"成功连接HTTP代理服务"];
		
		NSLog(@"成功连接HTTP代理服务");
		dispatch_async(dispatch_get_main_queue(), ^{
			
			[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
			completionHandler(NSURLSessionResponseAllow);
		});
	}
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
	
	NSLog(@"出现错误：%@", error);
	if (!error || error.code == NSURLErrorCancelled) {
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			[self.client URLProtocolDidFinishLoading:self];
		});
		
	}else {
		
		NSLog(@"errorCode = %ld",error.code);
		self.delegate = [ChinaTeleURLProtocol sharedInstance].delegate;
		[self callBackWhenDidLoadFailWithErrCode:error.code Message:@"NSURLError"];
		
		[self.client URLProtocol:self didFailWithError:error];
	}
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse * _Nullable))completionHandler {
	
	completionHandler(proposedResponse);
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
	
	[self.client URLProtocol:self didFailWithError:error];
}

- (void)URLSession:(NSURLSession *)session task:(nonnull NSURLSessionTask *)task willPerformHTTPRedirection:(nonnull NSHTTPURLResponse *)response newRequest:(nonnull NSURLRequest *)request completionHandler:(nonnull void (^)(NSURLRequest * _Nullable))completionHandler {
	
	NSLog(@"NSURLSessionTaskDelegate");
	NSMutableURLRequest *newrequest = request.mutableCopy;
	[NSURLProtocol removePropertyForKey:ChinaTeleURLProtocolHandledKey inRequest:newrequest];
	[self.client URLProtocol:self wasRedirectedToRequest:request redirectResponse:response];
	[task cancel];
	[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
}


@end

@implementation NSURLProtocol (WKWebViewSupport)

	//通过反射的方式来实现WKWebView代理
+ (void)ChinaTeleWeb_RegisterScheme:(NSString *)scheme {
	Class cls = ChinaTele_ContextControllerClass();
	SEL sel = ChinaTeleWeb_RegisterSchemeSelector();
	if ([(id)cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[(id)cls performSelector:sel withObject:scheme];
#pragma clang diagnostic pop
	}
}

+ (void)ChinaTeleWeb_UnregisterScheme:(NSString *)scheme {
	Class cls = ChinaTele_ContextControllerClass();
	SEL sel = ChinaTeleWeb_UnregisterSchemeSelector();
	if ([(id)cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[(id)cls performSelector:sel withObject:scheme];
#pragma clang diagnostic pop
	}
}


@end



