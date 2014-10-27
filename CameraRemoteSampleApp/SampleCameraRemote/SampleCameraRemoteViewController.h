/**
 * @file  SampleCameraRemoteViewController.h
 * @brief CameraRemoteSampleApp
 *
 * Copyright 2014 Sony Corporation
 */

#import "SampleCameraEventObserver.h"
#import "SampleStreamingDataManager.h"
#import "AVCamPreviewView.h"
#import <AVFoundation/AVFoundation.h>
@interface SampleCameraRemoteViewController
    : UIViewController <SampleEventObserverDelegate,
                        HttpAsynchronousRequestParserDelegate,
                        SampleStreamingDataDelegate, UIPickerViewDelegate,
                        UIPickerViewDataSource, UIGestureRecognizerDelegate,AVCaptureFileOutputRecordingDelegate>
- (IBAction)modeButton:(id)sender;
- (IBAction)actionButton:(id)sender;
- (IBAction)didTapZoomIn:(id)sender;
- (IBAction)didTapZoomOut:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *modeButtonText;
@property (weak, nonatomic) IBOutlet UIButton *actionButtonText;
@property (weak, nonatomic) IBOutlet UIImageView *liveviewImageView;
@property (weak, nonatomic) IBOutlet UIImageView *takePictureView;
@property (weak, nonatomic) IBOutlet UILabel *cameraStatusView;
@property (weak, nonatomic) IBOutlet UIView *sideView;
@property (weak, nonatomic) IBOutlet UIButton *zoomInButton;
@property (weak, nonatomic) IBOutlet UIButton *zoomOutButton;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (weak, nonatomic) IBOutlet AVCamPreviewView *previewView;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position;
@end
