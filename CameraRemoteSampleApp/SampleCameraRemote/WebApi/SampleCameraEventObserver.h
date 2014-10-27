/**
 * @file  SampleCameraEventObserver.h
 * @brief CameraRemoteSampleApp
 *
 * Copyright 2014 Sony Corporation
 */

#import "HttpAsynchronousRequest.h"

@protocol SampleEventObserverDelegate <NSObject>

@optional

/**
 * Delegate function called when available API lists changes.
 */
- (void)didApiListChanged:(NSArray *)API_CAMERA_list;

/**
 * Delegate function called when camera status is changed.
 */
- (void)didCameraStatusChanged:(NSString *)status;

/**
 * Delegate function called when camera function is changed.
 */
- (void)didCameraFunctionChanged:(NSString *)function;

/**
 * Delegate function called when liveview status is changed.
 */
- (void)didLiveviewStatusChanged:(BOOL)status;

/**
 * Delegate function called when shoot mode is chnaged.
 */
- (void)didShootModeChanged:(NSString *)shootMode;

/**
 * Delegate function called when zoom position is changed.
 */
- (void)didZoomPositionChanged:(int)zoomPosition;

/**
 * Delegate function called when storage information is changed.
 */
- (void)didStorageInformationChanged:(NSArray *)storages;

/**
 * Delegate function called when parsing message error occurred.
 */
- (void)didFailParseMessageWithError:(NSError *)error;

@end

// It is a singleton class.
@interface SampleCameraEventObserver
    : NSObject <HttpAsynchronousRequestParserDelegate>

/**
 * get the instance of Event observer
 */
+ (SampleCameraEventObserver *)getInstance;

/**
 * Start the getEvent API if not already started. The API continues using long polling.
 */
- (void)start;

/**
 * To set delegate to receive event notification
 */
- (void)setDelegate:(id<SampleEventObserverDelegate>)eventDelegate;

/**
 * Stop the polling of getEvent API
 */
- (void)stop;

/**
 * get status of event observer
 */
- (BOOL)isStarted;

/**
 * get current server status
 */
- (void)getCurrentState;

/**
 * To destroy the instance of this class.
 */
- (void)destroy;

@end
