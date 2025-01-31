//
//  LSIMarsRoverClient.m
//  Astronomy
//
//  Created by Andrew R Madsen on 10/8/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

#import "LSIMarsRoverClient.h"
#import "LSIMarsRover.h"
#import "LSIMarsPhoto.h"

@implementation LSIMarsRoverClient

#pragma mark - Public

- (void)fetchAllMarsRoversWithCompletion:(void(^)(NSArray<NSString *> *roverNames, NSError *error))completion;
{
	NSURL *url = [[self class] roversEndpoint];
	[[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error) {
			return completion(nil, error);
		}
		
		if (!data) {
			return completion(nil, [NSError errorWithDomain:@"com.LambdaSchool.Astronomy.ErrorDomain" code:-1 userInfo:nil]);
		}
		
		NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		NSArray *roverDicts = nil;
		if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]] ||
			!(roverDicts = jsonDict[@"rovers"])) {
			NSDictionary *userInfo = nil;
			if (error) { userInfo = @{NSUnderlyingErrorKey : error}; }
			NSError *localError = [NSError errorWithDomain:@"com.LambdaSchool.Astronomy.ErrorDomain" code:-1 userInfo:userInfo];
			return completion(nil, localError);
		}
		
		NSMutableArray *roverNames = [NSMutableArray array];
		for (NSDictionary *dict in roverDicts) {
			NSString *name = dict[@"name"];
			if (name) { [roverNames addObject:name]; }
		}
		
		completion(roverNames, nil);
	}] resume];
}

- (void)fetchMissionManifestForRoverNamed:(NSString *)name completion:(void(^)(LSIMarsRover *rover, NSError *error))completion;
{
	NSURL *url = [[self class] urlForInfoForRover:name];
	[[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error) {
			return completion(nil, error);
		}
		
		if (!data) {
			return completion(nil, [NSError errorWithDomain:@"com.LambdaSchool.Astronomy.ErrorDomain" code:-1 userInfo:nil]);
		}
		
		NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		NSDictionary *manifest = nil;
		if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]] ||
			!(manifest = jsonDict[@"photo_manifest"])) {
			NSDictionary *userInfo = nil;
			if (error) { userInfo = @{NSUnderlyingErrorKey : error}; }
			NSError *localError = [NSError errorWithDomain:@"com.LambdaSchool.Astronomy.ErrorDomain" code:-1 userInfo:userInfo];
			return completion(nil, localError);
		}
		
		completion([[LSIMarsRover alloc] initWithDictionary:manifest], nil);
	}] resume];
}

- (void)fetchPhotosFromRover:(LSIMarsRover *)rover onSol:(NSInteger)sol completion:(void(^)(NSArray<LSIMarsPhoto *> *photos, NSError *error))completion;
{
	if (!rover) {
		NSLog(@"%s called with a nil rover.", __PRETTY_FUNCTION__);
		return completion(nil, [NSError errorWithDomain:@"com.LambdaSchool.Astronomy.ErrorDomain" code:-2 userInfo:nil]);
	}
	
	NSURL *url = [[self class] urlForPhotosFromRover:rover.name onSol:sol];
	[[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error) {
			return completion(nil, error);
		}
		
		if (!data) {
			return completion(nil, [NSError errorWithDomain:@"com.LambdaSchool.Astronomy.ErrorDomain" code:-1 userInfo:nil]);
		}
		
		NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) {
			NSDictionary *userInfo = nil;
			if (error) { userInfo = @{NSUnderlyingErrorKey : error}; }
			NSError *localError = [NSError errorWithDomain:@"com.LambdaSchool.Astronomy.ErrorDomain" code:-1 userInfo:userInfo];
			return completion(nil, localError);
		}

		NSArray *photoDictionaries = jsonDict[@"photos"];
		NSMutableArray *photos = [NSMutableArray array];
		for (NSDictionary *dict in photoDictionaries) {
			LSIMarsPhoto *photo = [[LSIMarsPhoto alloc] initWithDictionary:dict];
			if (!photo) { continue; }
			[photos addObject:photo];
		}
		completion(photos, nil);
	}] resume];
}

- (void)fetchImageDataForPhoto:(LSIMarsPhoto *)photo completion:(void(^)(NSData *imageData, NSError *error))completion
{
	NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:photo.imageURL resolvingAgainstBaseURL:YES];
	urlComponents.scheme = @"https";
	NSURL *imageURL = urlComponents.URL;
	
	[[[NSURLSession sharedSession] dataTaskWithURL:imageURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error) {
			return completion(nil, error);
		}
		
		if (!data) {
			return completion(nil, [NSError errorWithDomain:@"com.LambdaSchool.Astronomy.ErrorDomain" code:-1 userInfo:nil]);
		}
		
		completion(data, nil);
	}] resume];
}

#pragma mark - Private

+ (NSString *)apiKey
{
	static NSString *apiKey = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSURL *apiKeysURL = [[NSBundle mainBundle] URLForResource:@"APIKeys" withExtension:@"plist"];
		if (!apiKeysURL) {
			NSLog(@"Error! APIKeys file not found!");
			return;
		}
		NSDictionary *apiKeys = [[NSDictionary alloc] initWithContentsOfURL:apiKeysURL];
		apiKey = apiKeys[@"APIKey"];
	});
	return apiKey;
}

+ (NSURL *)baseURL
{
	return [NSURL URLWithString:@"https://api.nasa.gov/mars-photos/api/v1"];
}

+ (NSURL *)roversEndpoint
{
	NSURL *url = [[self baseURL] URLByAppendingPathComponent:@"rovers"];
	NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
	urlComponents.queryItems = @[[NSURLQueryItem queryItemWithName:@"api_key" value:[self apiKey]]];
	return urlComponents.URL;
}

+ (NSURL *)urlForInfoForRover:(NSString *)roverName
{
	NSURL *url = [self baseURL];
	url = [url URLByAppendingPathComponent:@"manifests"];
	url = [url URLByAppendingPathComponent:roverName];
	
	NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
	urlComponents.queryItems = @[[NSURLQueryItem queryItemWithName:@"api_key" value:[self apiKey]]];
	return urlComponents.URL;
}

+ (NSURL *)urlForPhotosFromRover:(NSString *)roverName onSol:(NSInteger)sol
{
	NSURL *url = [self baseURL];
	url = [url URLByAppendingPathComponent:@"rovers"];
	url = [url URLByAppendingPathComponent:roverName];
	url = [url URLByAppendingPathComponent:@"photos"];
	
	NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
	urlComponents.queryItems = @[[NSURLQueryItem queryItemWithName:@"sol" value:[@(sol) stringValue]],
								 [NSURLQueryItem queryItemWithName:@"api_key" value:[self apiKey]]];
	return urlComponents.URL;
}

#pragma mark - Properties

#pragma mark Public

#pragma mark Private

@end
