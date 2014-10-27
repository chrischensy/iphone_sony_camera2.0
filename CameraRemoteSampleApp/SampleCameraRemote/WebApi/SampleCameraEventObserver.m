/**
 * @file  SampleCameraEventObserver.m
 * @brief CameraRemoteSampleApp
 *
 * Copyright 2014 Sony Corporation
 */

#import "SampleCameraEventObserver.h"
#import "SampleCameraApi.h"

static SampleCameraEventObserver *_instance;

@implementation SampleCameraEventObserver {
    BOOL _isStarted;
    BOOL _isFirstCall;
    id<SampleEventObserverDelegate> _eventDelegate;
}

+ (SampleCameraEventObserver *)getInstance
{
    if (!_instance) {
        _instance = [[SampleCameraEventObserver alloc] init];
    }
    return _instance;
}

- (void)start
{
    if (!_isStarted) {
        _isStarted = YES;
        _isFirstCall = YES;
        [self call];
    }
}

- (void)setDelegate:(id<SampleEventObserverDelegate>)eventDelegate
{
    _eventDelegate = eventDelegate;
}

- (void)call
{
    if (_isStarted) {
        [SampleCameraApi getEvent:self longPollingFlag:!_isFirstCall];
        _isFirstCall = NO;
    }
}

- (void)stop
{
    if (_isStarted) {
        _isStarted = NO;
        _isFirstCall = NO;
    }
}

- (void)destroy
{
    [self stop];
    _instance = nil;
}

- (BOOL)isStarted
{
    return _isStarted;
}

- (void)getCurrentState
{
    [SampleCameraApi getEvent:self longPollingFlag:NO];
}

- (void)parseMessage:(NSData *)response apiName:(NSString *)apiName
{
    NSString *responseText =
        [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    NSLog(@"SampleCameraEventObserver parseMessage = %@, apiname=%@",
          responseText, apiName);
    if (_isStarted) {
        NSError *e = nil;
        NSDictionary *jsonDict = [NSJSONSerialization
            JSONObjectWithData:response
                       options:NSJSONReadingMutableContainers
                         error:&e];
        if (!e) {
            if ([jsonDict[@"error"] isKindOfClass:[NSArray class]]) {
                // For developer : check for error codes and restart event if
                // necessary

                NSArray *error = jsonDict[@"error"];
                if (error.count >= 1) {
                    if ([error[0] isKindOfClass:[NSNumber class]]) {
                        // This error is created in HttpAsynchronousRequest
                        if ([error[0] intValue] == 16) {
                            [self stop];
                            if ([_eventDelegate
                                    respondsToSelector:
                                        @selector(
                                            didFailParseMessageWithError:)]) {
                                [_eventDelegate didFailParseMessageWithError:e];
                            }
                        }
                    }
                }
            }
            if ([jsonDict[@"result"] isKindOfClass:[NSArray class]]) {
                NSArray *result = jsonDict[@"result"];
                // check for all event callbacks required by the application.
                if ([_eventDelegate
                        respondsToSelector:@selector(didApiListChanged:)]) {
                    [self findAvailableApiList:result];
                }
                if ([_eventDelegate
                        respondsToSelector:@selector(
                                               didCameraStatusChanged:)]) {
                    [self findCameraStatus:result];
                }
                if ([_eventDelegate
                        respondsToSelector:@selector(
                                               didCameraFunctionChanged:)]) {
                    [self findCameraFunction:result];
                }
                if ([_eventDelegate
                        respondsToSelector:@selector(
                                               didLiveviewStatusChanged:)]) {
                    [self findLiveviewStatus:result];
                }
                if ([_eventDelegate
                        respondsToSelector:@selector(didShootModeChanged:)]) {
                    [self findShootMode:result];
                }
                if ([_eventDelegate
                        respondsToSelector:@selector(
                                               didZoomPositionChanged:)]) {
                    [self findZoomInformation:result];
                }
                if ([_eventDelegate
                        respondsToSelector:
                            @selector(didStorageInformationChanged:)]) {
                    [self findStorageInformation:result];
                }
            }
            [self call];
        } else {
            [self stop];
            if ([_eventDelegate
                    respondsToSelector:@selector(
                                           didFailParseMessageWithError:)]) {
                [_eventDelegate didFailParseMessageWithError:e];
            }
        }
    }
}

// Finds and extracts a list of available APIs from reply JSON data.
// As for getEvent v1.0, results[0] => "availableApiList"
- (void)findAvailableApiList:(NSArray *)response
{
    int indexOfAvailableApiList = 0;
    if (indexOfAvailableApiList < response.count &&
        [response[indexOfAvailableApiList]
            isKindOfClass:[NSDictionary class]]) {
        NSDictionary *typeObj = response[indexOfAvailableApiList];
        if ([typeObj[@"type"] isKindOfClass:[NSString class]]) {
            if ([typeObj[@"type"] isEqualToString:@"availableApiList"]) {
                if ([typeObj[@"names"] isKindOfClass:[NSArray class]]) {
                    NSArray *availableApiList = typeObj[@"names"];
                    [_eventDelegate didApiListChanged:availableApiList];
                }
            }
        }
    }
}

// Finds and extracts a value of Camera Status from reply JSON data.
// As for getEvent v1.0, results[1] => "cameraStatus"
- (void)findCameraStatus:(NSArray *)response
{
    int indexOfCameraStatus = 1;
    if (indexOfCameraStatus < response.count &&
        [response[indexOfCameraStatus] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *typeObj = response[indexOfCameraStatus];
        if ([typeObj[@"type"] isKindOfClass:[NSString class]]) {
            if ([typeObj[@"type"] isEqualToString:@"cameraStatus"]) {
                if ([typeObj[@"cameraStatus"] isKindOfClass:[NSString class]]) {
                    NSString *cameraStatus = typeObj[@"cameraStatus"];
                    [_eventDelegate didCameraStatusChanged:cameraStatus];
                }
            }
        }
    }
}

// Finds and extracts a value of Camera Function from reply JSON data.
// As for getEvent v1.0, results[12] => "cameraFunction"
- (void)findCameraFunction:(NSArray *)response
{
    int indexOfCameraStatus = 12;
    if (indexOfCameraStatus < response.count &&
        [response[indexOfCameraStatus] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *typeObj = response[indexOfCameraStatus];
        if ([typeObj[@"type"] isKindOfClass:[NSString class]]) {
            if ([typeObj[@"type"] isEqualToString:@"cameraFunction"]) {
                if ([typeObj[@"currentCameraFunction"]
                        isKindOfClass:[NSString class]]) {
                    NSString *cameraFunction =
                        typeObj[@"currentCameraFunction"];
                    [_eventDelegate didCameraFunctionChanged:cameraFunction];
                }
            }
        }
    }
}

// Finds and extracts a value of Liveview Status from reply JSON data.
// As for getEvent v1.0, results[3] => "liveviewStatus"
- (void)findLiveviewStatus:(NSArray *)response
{
    int indexOfLiveviewStatus = 3;
    if (indexOfLiveviewStatus < response.count &&
        [response[indexOfLiveviewStatus] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *typeObj = response[indexOfLiveviewStatus];
        if ([typeObj[@"type"] isKindOfClass:[NSString class]]) {
            if ([typeObj[@"type"] isEqualToString:@"liveviewStatus"]) {
                if ([typeObj[@"liveviewStatus"]
                        isKindOfClass:[NSNumber class]] &&
                    strcmp([typeObj[@"liveviewStatus"] objCType], "c") == 0) {
                    BOOL liveviewStatus = FALSE;
                    if ([typeObj[@"liveviewStatus"] isEqual:nil]) {
                        liveviewStatus = FALSE;
                    }else{
                        liveviewStatus = TRUE;
                    }
                    [_eventDelegate didLiveviewStatusChanged:liveviewStatus];
                }
            }
        }
    }
}

// Finds and extracts a value of Zoom Information from reply JSON data.
// As for getEvent v1.0, results[2] => "zoomInformation"
- (void)findZoomInformation:(NSArray *)response
{
    int indexOfZoomInformation = 2;
    if (indexOfZoomInformation < response.count &&
        [response[indexOfZoomInformation] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *typeObj = response[indexOfZoomInformation];
        if ([typeObj[@"type"] isKindOfClass:[NSString class]]) {
            if ([typeObj[@"type"] isEqualToString:@"zoomInformation"]) {
                if ([typeObj[@"zoomPosition"] isKindOfClass:[NSNumber class]]) {
                    NSNumber *zoomPosition =
                        (NSNumber *)typeObj[@"zoomPosition"];
                    [_eventDelegate
                        didZoomPositionChanged:[zoomPosition intValue]];
                }
            }
        }
    }
}

// Finds and extracts a value of Camera Status from reply JSON data.
// As for getEvent v1.0, results[21] => "cameraStatus"
- (void)findShootMode:(NSArray *)response
{
    int indexOfShootMode = 21;
    if (indexOfShootMode < response.count &&
        [response[indexOfShootMode] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *typeObj = response[indexOfShootMode];
        if ([typeObj[@"type"] isKindOfClass:[NSString class]]) {
            if ([typeObj[@"type"] isEqualToString:@"shootMode"]) {
                if ([typeObj[@"currentShootMode"]
                        isKindOfClass:[NSString class]]) {
                    NSString *shootMode = typeObj[@"currentShootMode"];
                    [_eventDelegate didShootModeChanged:shootMode];
                }
            }
        }
    }
}

// Finds and extracts a value of Camera Status from reply JSON data.
// As for getEvent v1.0, results[10] => "storageInformation"
- (void)findStorageInformation:(NSArray *)response
{
    int indexOfStorageInformation = 10;
    if (indexOfStorageInformation < response.count &&
        [response[indexOfStorageInformation] isKindOfClass:[NSArray class]]) {
        NSArray *storages = response[indexOfStorageInformation];
        if (storages.count > 0) {
            [_eventDelegate didStorageInformationChanged:storages];
        }
    }
}

@end
