/**
 * @file  SampleCameraRemoteViewController.m
 * @brief CameraRemoteSampleApp
 *
 * Copyright 2014 Sony Corporation
 */
#import <AssetsLibrary/AssetsLibrary.h>

#import "SampleCameraRemoteViewController.h"
#import "SampleDateListViewController.h"
#import "SampleCameraApi.h"
#import "SampleAvContentApi.h"
#import "DeviceList.h"
#import "SensorLogger.h"

static void * RecordingContext = &RecordingContext;

@implementation SampleCameraRemoteViewController {
    NSMutableArray *_apiList;
    SampleStreamingDataManager *_streamingDataManager;
    BOOL _isPainting;
    BOOL _isViewVisible;
    BOOL _currentLiveviewStatus;
    BOOL _isSupportedVersion;
    BOOL _isNextZoomAvailable;
    BOOL _isMovieAvailable;
    BOOL _isContentAvailable;
    BOOL _isMediaAvailable;
    NSString *_currentShootMode;
    NSMutableArray *_modeArray;
    UIPickerView *_modePickerView;
}

@synthesize modeButtonText;
@synthesize actionButtonText;
@synthesize liveviewImageView;
@synthesize takePictureView;
@synthesize cameraStatusView;
@synthesize sideView;
@synthesize zoomInButton;
@synthesize zoomOutButton;
- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem.rightBarButtonItem setEnabled:NO];
    
    
    // Initialize camera
//    photoCameraSelf = [[CvPhotoCamera alloc]
//        initWithParentView:imageViewSelf];
//    photoCameraSelf.delegate = self;
//    photoCameraSelf.defaultAVCaptureDevicePosition =AVCaptureDevicePositionFront;
//    photoCameraSelf.defaultAVCaptureSessionPreset =AVCaptureSessionPresetPhoto;
//    photoCameraSelf.defaultAVCaptureVideoOrientation =AVCaptureVideoOrientationLandscapeLeft;

    //[takePhotoSelfButton setEnabled:NO];
    //NSLog(@"cameraself prepared.");
    
    //start sensors
    [SensorLogger getInstance];
    
    // Create the AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [self setSession:session];
    
    // Setup the preview view
    [[self previewView] setSession:session];
    
    // Check for device authorization
    [self checkDeviceAuthorizationStatus];
    
    // In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
    // Why not do all of this on the main queue?
    // -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue so that the main queue isn't blocked (which keeps the UI responsive).
    
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    [self setSessionQueue:sessionQueue];
    
    dispatch_async(sessionQueue, ^{
        [self setBackgroundRecordingID:UIBackgroundTaskInvalid];
        
        NSError *error = nil;
        
        AVCaptureDevice *videoDevice = [SampleCameraRemoteViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        if (error)
        {
            NSLog(@"%@", error);
        }
        
        if ([session canAddInput:videoDeviceInput])
        {
            [session addInput:videoDeviceInput];
            [self setVideoDeviceInput:videoDeviceInput];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Why are we dispatching this to the main queue?
                // Because AVCaptureVideoPreviewLayer is the backing layer for AVCamPreviewView and UIView can only be manipulated on main thread.
                // Note: As an exception to the above rule, it is not necessary to serialize video orientation changes on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                
                [[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
            });
        }
        
        AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
        AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
        
        if (error)
        {
            NSLog(@"%@", error);
        }
        
        if ([session canAddInput:audioDeviceInput])
        {
            [session addInput:audioDeviceInput];
        }
        
        AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        if ([session canAddOutput:movieFileOutput])
        {
            [session addOutput:movieFileOutput];
            AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            if ([connection isVideoStabilizationSupported])
                [connection setEnablesVideoStabilizationWhenAvailable:YES];
            [self setMovieFileOutput:movieFileOutput];
        }
        
        });

}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    _isViewVisible = YES;

    NSLog(@"SampleCameraRemoteViewController viewDidAppear");

    // initialising objects
    _apiList = [[NSMutableArray alloc] init];
    _modeArray = [[NSMutableArray alloc] init];
    _streamingDataManager = [[SampleStreamingDataManager alloc] init];
    _isPainting = NO;
    _isNextZoomAvailable = YES;
    _isMovieAvailable = NO;
    _isContentAvailable = NO;
    _isMediaAvailable = NO;

    // open initial connection for webapi
    [[SampleCameraEventObserver getInstance] setDelegate:self];
    [SampleCameraApi getMethodTypes:self];

    // initialize view properties
    [modeButtonText setHidden:YES];
    modeButtonText.tag = -1;
    [actionButtonText setHidden:YES];
    actionButtonText.tag = -1;
    
    [self setButtonView:modeButtonText];
    [self setButtonView:actionButtonText];
    //[self setButtonView:startSelfButton];
    //[self setButtonView:takePhotoSelfButton];
    self.takePictureView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGestureRecognizer =
        [[UITapGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(toggleTakePictureView:)];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    tapGestureRecognizer.numberOfTouchesRequired = 1;
    [self.takePictureView addGestureRecognizer:tapGestureRecognizer];

    UILongPressGestureRecognizer *gestureRecognizerZoomIn =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(didTapLongPressedZoomIn:)];
    [zoomInButton addGestureRecognizer:gestureRecognizerZoomIn];

    UILongPressGestureRecognizer *gestureRecognizerZoomOut =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(didTapLongPressedZoomOut:)];
    [zoomOutButton addGestureRecognizer:gestureRecognizerZoomOut];

    _modePickerView = [[UIPickerView alloc]
        initWithFrame:CGRectMake(sideView.frame.size.width, 0, 300, 200)];
    _modePickerView.showsSelectionIndicator = YES;
    [_modePickerView setBackgroundColor:[UIColor lightGrayColor]];
    _modePickerView.userInteractionEnabled = YES;
    UITapGestureRecognizer *pickerTapGesture =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(pickerTap)];
    pickerTapGesture.numberOfTapsRequired = 1;
    pickerTapGesture.numberOfTouchesRequired = 1;
    [_modePickerView addGestureRecognizer:pickerTapGesture];
    pickerTapGesture.delegate = self;
    [_modePickerView setHidden:YES];
    [self.view addSubview:_modePickerView];

    [self setButtonView:zoomInButton];
    [self setButtonView:zoomOutButton];
}

- (void)setButtonView:(UIButton *)button
{
    [[button layer] setCornerRadius:8.0f];
    [[button layer] setMasksToBounds:YES];
    [[button layer] setBorderWidth:1.0f];
}

- (void)viewDidDisappear:(BOOL)animated
{
    NSLog(@"SampleCameraRemoteViewController viewDidDisappear");
    _isViewVisible = NO;
    [self.takePictureView setHidden:YES];
    [self closeConnection];
    [super viewDidDisappear:animated];
    //[photoCameraSelf stop];
}

- (void)toggleTakePictureView:(UITapGestureRecognizer *)tapGestureRecognizer
{
    [self.takePictureView setHidden:YES];
}

- (void)progressIndicator:(BOOL)isVisible
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible =
        isVisible;
}

/*
 * UI event implementation
 */

- (IBAction)modeButton:(id)sender
{
    [modeButtonText setEnabled:NO];
    [actionButtonText setEnabled:NO];
    _modePickerView.delegate = self;
    _modePickerView.dataSource = self;
    [_modePickerView setHidden:NO];
    [_modePickerView selectRow:[_modeArray indexOfObject:_currentShootMode]
                   inComponent:0
                      animated:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:
        (UIGestureRecognizer *)otherGestureRecognizer
{
    return true;
}

- (IBAction)actionButton:(id)sender
{
    if (actionButtonText.tag == 1) {
        // start record video
        [SampleCameraApi startMovieRec:self];
        
        //start write Sensor data.
        [[SensorLogger getInstance]startLogging];
        
        // start record video with iphone camera
        if ([[UIDevice currentDevice] isMultitaskingSupported])
        {
            // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error: after the recorded file has been saved.
            [self setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil]];
        }
        
        // Update the orientation on the movie file output video connection before starting recording.
        [[[self movieFileOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] videoOrientation]];
        
        // Turning OFF flash for video recording
        [SampleCameraRemoteViewController setFlashMode:AVCaptureFlashModeOff forDevice:[[self videoDeviceInput] device]];
        
        // Start recording to a temporary file.
        NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"movie" stringByAppendingPathExtension:@"mov"]];
        [[self movieFileOutput] startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
    }
    if (actionButtonText.tag == 2) {
        // stop record video
        [SampleCameraApi stopMovieRec:self];
        
        //stop write Sensor data.
        [[SensorLogger getInstance]stopLogging];
        [[SensorLogger getInstance]writeToFile:@"sensor"];
        
        // stop record video with iphone camera
        [[self movieFileOutput] stopRecording];
    }
    if (actionButtonText.tag == 3) { // take picture
        [SampleCameraApi actTakePicture:self];
        [self progressIndicator:YES];
    }
}

- (IBAction)didTapZoomIn:(id)sender
{
    [SampleCameraApi actZoom:self direction:@"in" movement:@"1shot"];
}

- (IBAction)didTapZoomOut:(id)sender
{
    [SampleCameraApi actZoom:self direction:@"out" movement:@"1shot"];
}

- (void)didTapLongPressedZoomIn:
            (UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state) {
    case UIGestureRecognizerStateBegan:
        [SampleCameraApi actZoom:self direction:@"in" movement:@"start"];
        break;
    case UIGestureRecognizerStateEnded:
        [SampleCameraApi actZoom:self direction:@"in" movement:@"stop"];
        break;
    default:
        break;
    }
}

- (void)didTapLongPressedZoomOut:
            (UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state) {
    case UIGestureRecognizerStateBegan:
        [SampleCameraApi actZoom:self direction:@"out" movement:@"start"];
        break;
    case UIGestureRecognizerStateEnded:
        [SampleCameraApi actZoom:self direction:@"out" movement:@"stop"];
        break;
    default:
        break;
    }
}

/*
 * Picker view delegate
 */

- (void)pickerTap
{
    long row = [_modePickerView selectedRowInComponent:0];
    // Handle the selection
    if ([_modeArray[row] isEqualToString:@""]) {
        [self openUnsupportedShootModeErrorDialog];
    } else if (![_modeArray[row] isEqualToString:_currentShootMode]) {
        [SampleCameraApi setShootMode:self shootMode:_modeArray[row]];
    }
    [_modePickerView setHidden:YES];
    [modeButtonText setEnabled:YES];
    [actionButtonText setEnabled:YES];
    //[startSelfButton setEnabled:YES];
    //[takePhotoSelfButton setEnabled:YES];
}

- (void)pickerView:(UIPickerView *)pickerView
      didSelectRow:(NSInteger)row
       inComponent:(NSInteger)component
{
}

- (NSInteger)pickerView:(UIPickerView *)pickerView
    numberOfRowsInComponent:(NSInteger)component
{
    return [_modeArray count];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component
{
    return [NSString stringWithFormat:@"Shoot mode : %@", _modeArray[row]];
}

/*
 * Initialize client to setup liveview, camera controls and start listening to
 * camera events.
 */
- (void)initialize
{
    NSLog(@"SampleCameraRemoteViewController initialize");
    _isSupportedVersion = NO;

    // check available API list
    NSData *response = [SampleCameraApi getAvailableApiList:self isSync:YES];
    if (response != nil) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self parseMessage:response apiName:API_CAMERA_getAvailableApiList];
        });
    } else {
        NSLog(@"SampleCameraRemoteViewController initialize : "
              @"getAvailableApiList error");
        dispatch_async(dispatch_get_main_queue(),
                       ^{ [self openNetworkErrorDialog]; });
        return;
    }

    // check if the version of the server is supported or not
    if ([self isApiAvailable:API_CAMERA_getApplicationInfo]) {
        response = [SampleCameraApi getApplicationInfo:self isSync:YES];
        if (response != nil) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self parseMessage:response
                           apiName:API_CAMERA_getApplicationInfo];
            });
            if (!_isSupportedVersion) {
                // popup not supported version
                NSLog(@"SampleCameraRemoteViewController initialize is not "
                      @"supported version");
                dispatch_async(dispatch_get_main_queue(),
                               ^{ [self openUnsupportedErrorDialog]; });
                return;
            } else {
                NSLog(@"SampleCameraRemoteViewController initialize is "
                      @"supported version");
            }
        } else {
            NSLog(@"SampleCameraRemoteViewController initialize error");
            dispatch_async(dispatch_get_main_queue(),
                           ^{ [self openNetworkErrorDialog]; });
            return;
        }
    }

    // startRecMode if necessary
    if ([self isApiAvailable:API_CAMERA_startRecMode]) {
        response = [SampleCameraApi startRecMode:self isSync:YES];
        if (response != nil) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self parseMessage:response apiName:API_CAMERA_startRecMode];
            });
        } else {
            NSLog(@"SampleCameraRemoteViewController initialize error");
            dispatch_async(dispatch_get_main_queue(),
                           ^{ [self openNetworkErrorDialog]; });
            return;
        }
    }

    // update available API list
    response = [SampleCameraApi getAvailableApiList:self isSync:YES];
    if (response != nil) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self parseMessage:response apiName:API_CAMERA_getAvailableApiList];
        });
    } else {
        NSLog(@"SampleCameraRemoteViewController initialize error");
        dispatch_async(dispatch_get_main_queue(),
                       ^{ [self openNetworkErrorDialog]; });
        return;
    }

    // check available shoot mode to update mode button
    if ([self isApiAvailable:API_CAMERA_getAvailableShootMode]) {
        dispatch_sync(dispatch_get_main_queue(),
                      ^{ [SampleCameraApi getAvailableShootMode:self]; });
    }

    // check method types of avContent service to update availability of movie
    if ([[DeviceList getSelectedDevice] findActionListUrl:@"avContent"] !=
        NULL) {
        dispatch_sync(dispatch_get_main_queue(),
                      ^{ [SampleAvContentApi getMethodTypes:self]; });
    }
}

/*
 * Closing the webAPI connection from the client.
 */
- (void)closeConnection
{
    NSLog(@"SampleCameraRemoteViewController closeConnection");

    [_streamingDataManager stop];
    if ([self isApiAvailable:API_CAMERA_stopRecMode]) {
        [SampleCameraApi stopRecMode:self];
    }
}

/*
 * Function to check if apiName is available at any moment.
 */
- (BOOL)isApiAvailable:(NSString *)apiName
{
    BOOL ret = NO;
    if (_apiList != nil && _apiList.count > 0 &&
        [_apiList containsObject:apiName]) {
        ret = YES;
    }
    return ret;
}

/**
 * SampleEventObserverDelegate function implementation
 */

- (void)didApiListChanged:(NSMutableArray *)API_CAMERA_list
{
    NSLog(@"SampleCameraRemoteViewController didApiListChanged:%@",
          [API_CAMERA_list componentsJoinedByString:@","]);
    _apiList = API_CAMERA_list;

    // start liveview if available
    if ([self isApiAvailable:API_CAMERA_startLiveview]) {
        if (![_streamingDataManager isStarted] && _isSupportedVersion) {
            [SampleCameraApi startLiveview:self];
        }
    }

    // getEvent start if available
    if ([self isApiAvailable:API_CAMERA_getEvent] && _isSupportedVersion) {
        if (![[SampleCameraEventObserver getInstance] isStarted]) {
            [[SampleCameraEventObserver getInstance] start];
        }
    }

    if ([self isApiAvailable:API_CAMERA_actZoom] && _isSupportedVersion) {
        [zoomInButton setHidden:NO];
        [zoomOutButton setHidden:NO];
    } else {
        [zoomInButton setHidden:YES];
        [zoomOutButton setHidden:YES];
    }
}

- (void)didCameraStatusChanged:(NSString *)status
{
    NSLog(@"SampleCameraRemoteViewController didCameraStatusChanged:%@",
          status);

    // CameraStatus TextView
    self.cameraStatusView.text = status;

    // if status is streaming
    if ([PARAM_CAMERA_cameraStatus_streaming isEqualToString:status]) {
        [SampleAvContentApi stopStreaming:self];
    }

    // Recording Start/Stop Button
    if ([PARAM_CAMERA_cameraStatus_movieRecording isEqualToString:status]) {
        [actionButtonText setHidden:NO];
        [actionButtonText setEnabled:YES];
        [actionButtonText setBackgroundColor:[UIColor whiteColor]];
        [actionButtonText
            setTitle:NSLocalizedString(@"STR_RECORD_STOP", @"STR_RECORD_STOP")
            forState:UIControlStateNormal];
        actionButtonText.tag = 2;
    }

    if ([PARAM_CAMERA_cameraStatus_contentsTransfer isEqualToString:status]) {
        [SampleCameraApi
            setCameraFunction:self
                     function:PARAM_CAMERA_cameraFunction_remoteShooting];
    }

    if ([PARAM_CAMERA_cameraStatus_idle isEqualToString:status] &&
        [@"movie" isEqualToString:_currentShootMode]) {
        [actionButtonText setHidden:NO];
        [actionButtonText setEnabled:YES];
        [actionButtonText setBackgroundColor:[UIColor whiteColor]];
        [actionButtonText
            setTitle:NSLocalizedString(@"STR_RECORD_START", @"STR_RECORD_START")
            forState:UIControlStateNormal];
        actionButtonText.tag = 1;
    }

    if ([PARAM_CAMERA_cameraStatus_idle isEqualToString:status] &&
        [@"still" isEqualToString:_currentShootMode]) {
        [actionButtonText setHidden:NO];
        [actionButtonText setEnabled:YES];
        [actionButtonText setBackgroundColor:[UIColor whiteColor]];
        [actionButtonText
            setTitle:NSLocalizedString(@"STR_TAKE_PICTURE", @"STR_TAKE_PICTURE")
            forState:UIControlStateNormal];
        actionButtonText.tag = 3;
    }

    if ([PARAM_CAMERA_cameraStatus_stillCapturing isEqualToString:status] &&
        [@"still" isEqualToString:_currentShootMode]) {
        [actionButtonText setEnabled:NO];
        [actionButtonText setBackgroundColor:[UIColor grayColor]];
    }

    if ([PARAM_CAMERA_cameraStatus_notReady isEqualToString:status]) {
        [actionButtonText setEnabled:NO];
        [actionButtonText setBackgroundColor:[UIColor grayColor]];
    }
}

- (void)didCameraFunctionChanged:(NSString *)function
{
    NSLog(@"SampleCameraRemoteViewController didCameraFunctionChanged:%@",
          function);

    if ([PARAM_CAMERA_cameraFunction_contentsTransfer
            isEqualToString:function]) {
        [SampleCameraApi
            setCameraFunction:self
                     function:PARAM_CAMERA_cameraFunction_remoteShooting];
    }

    if ([PARAM_CAMERA_cameraFunction_remoteShooting isEqualToString:function]) {
        [self performSelectorInBackground:@selector(initialize)
                               withObject:NULL];
    }
}

- (void)didLiveviewStatusChanged:(BOOL)status
{
    NSLog(@"SampleCameraRemoteViewController didLiveviewStatusChanged:%d",
          status);
    _currentLiveviewStatus = status;
}

- (void)didShootModeChanged:(NSString *)shootMode
{
    NSLog(@"SampleCameraRemoteViewController didShootModeChanged:%@",
          shootMode);
    if ([shootMode isEqualToString:@"movie"] ||
        [shootMode isEqualToString:@"still"]) {
        _currentShootMode = shootMode;
    } else {
        _currentShootMode = @"";
    }
    if (_modeArray.count > 0) {
        [self setInitialShootModeUI];
    }
}

- (void)didZoomPositionChanged:(int)zoomPosition
{
    NSLog(@"SampleCameraRemoteViewController didZoomPositionChanged:%d",
          zoomPosition);
    _isNextZoomAvailable = YES;

    if (zoomPosition == 0) {
        [zoomInButton setEnabled:YES];
        [zoomOutButton setEnabled:NO];

    } else if (zoomPosition == 100) {
        [zoomInButton setEnabled:NO];
        [zoomOutButton setEnabled:YES];

    } else {
        [zoomInButton setEnabled:YES];
        [zoomOutButton setEnabled:YES];
    }
}

- (void)didStorageInformationChanged:(NSArray *)storages
{
    NSLog(@"SampleCameraRemoteViewController didStorageInformationChanged");
    if ([storages[0] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *storageInfo = storages[0];
        if ([storageInfo[@"storageID"] isKindOfClass:[NSString class]]) {
            NSString *storageId = storageInfo[@"storageID"];
            if ([storageId isEqualToString:PARAM_CAMERA_storageId_noMedia]) {
                _isMediaAvailable = NO;
                [self.navigationItem.rightBarButtonItem setEnabled:NO];
            } else {
                _isMediaAvailable = YES;
                if (_isContentAvailable) {
                    [self.navigationItem.rightBarButtonItem setEnabled:YES];
                }
            }
        }
    }
}

- (void)didFailParseMessageWithError:(NSError *)error
{
    NSLog(@"SampleCameraRemoteViewController didFailParseMessageWithError "
          @"error parsing JSON string");
    [self openNetworkErrorDialog];
}

/**
 * SampleStreamingDataDelegate implementation
 */
- (void)didFetchImage:(UIImage *)image
{
//    CGPoint imgCenter =
//        CGPointMake(self.view.center.x + sideView.center.x, sideView.center.y);
//
//    float scale = [self getScale:image.size];
//    UIImage *scaledImage = [UIImage imageWithCGImage:image.CGImage
//                                               scale:scale
//                                         orientation:image.imageOrientation];
//    [self.liveviewImageView setFrame:CGRectMake(0, 0, scaledImage.size.width,
//                                                scaledImage.size.height)];
//    [self.liveviewImageView setCenter:imgCenter];
    [self paintLiveviewImage:image];
}

- (void)didStreamingStopped
{
    [SampleCameraApi startLiveview:self];
}

/*
 * get the scale of the image with regard to the screen size
 */
- (float)getScale:(CGSize)imageSize
{
    NSInteger imageHeight = imageSize.height;
    NSInteger imageWidth = imageSize.width;
    float hRatio = imageHeight / sideView.frame.size.height;
    float wRatio =
        imageWidth / (self.view.frame.size.width - sideView.frame.size.width);
    if (hRatio > wRatio) {
        return hRatio;
    } else {
        return wRatio;
    }
}

- (void)paintLiveviewImage:(UIImage *)image
{
    [self.liveviewImageView setImage:image];
    image = NULL;
}

/**
 * Parses response of WebAPI requests.
 */

/*
 * Parser of actTakePicture response
 */
- (void)parseActTakePicture:(NSArray *)resultArray
                  errorCode:(NSInteger)errorCode
               errorMessage:(NSString *)errorMessage
{
    if (resultArray.count > 0 && errorCode < 0) {
        NSArray *pictureList = resultArray[0];
        [self didTakePicture:pictureList[0]];
    }
    // For developer : if errorCode>=0, handle the error according to
    // requirement.
}

/*
 * Get the taken picture and show
 */
- (void)didTakePicture:(NSString *)url
{
    NSLog(@"SampleCameraRemoteViewController didTakePicture:%@", url);
    UIImage *downloadedImage = [self download:url];
    if (downloadedImage) {
        float scale = [self getScaleForTakenImage:downloadedImage.size];
        UIImage *scaledImage =
            [UIImage imageWithCGImage:downloadedImage.CGImage
                                scale:scale
                          orientation:downloadedImage.imageOrientation];
        [self.takePictureView
            setFrame:CGRectMake(self.view.frame.size.width -
                                    scaledImage.size.width - 5,
                                self.view.frame.size.height -
                                    scaledImage.size.height - 5,
                                scaledImage.size.width,
                                scaledImage.size.height)];

        self.takePictureView.image = downloadedImage;
        [self.takePictureView setHidden:NO];
    }

    [NSTimer scheduledTimerWithTimeInterval:5.0f
                                     target:self
                                   selector:@selector(takePictureTimer)
                                   userInfo:nil
                                    repeats:NO];
    [self progressIndicator:NO];
}

/*
 * get the scale of the taken image
 */
- (float)getScaleForTakenImage:(CGSize)imageSize
{
    NSInteger imageHeight = imageSize.height;
    NSInteger imageWidth = imageSize.width;
    float hRatio = imageHeight / (self.view.frame.size.height * 0.2);
    float wRatio = imageWidth / (self.view.frame.size.width * 0.2);
    if (hRatio > wRatio) {
        return hRatio;
    } else {
        return wRatio;
    }
}

/**
 * Download image from the received URL
 */
- (UIImage *)download:(NSString *)requestURL
{
    NSLog(@"SampleCameraRemoteViewController download URL = %@", requestURL);
    NSURL *downoadUrl = [NSURL URLWithString:requestURL];
    NSData *urlData = [NSData dataWithContentsOfURL:downoadUrl];
    if (urlData) {
        UIImage *imageToPost = [UIImage imageWithData:urlData];
        return imageToPost;
    }
    return nil;
}

/*
 * Timer used for erasing the taken picture view after 5 seconds
 */
- (void)takePictureTimer
{
    if (_isViewVisible) {
        [self.takePictureView setHidden:YES];
        self.takePictureView.image = NULL;
    }
}

/*
 * Parser of getAvailableApiList response
 */
- (void)parseGetAvailableApiList:(NSArray *)resultArray
                       errorCode:(NSInteger)errorCode
                    errorMessage:(NSString *)errorMessage
{
    if (resultArray.count > 0 && errorCode < 0) {
        NSArray *availableApiList = resultArray[0];
        if (availableApiList != nil) {
            [self didApiListChanged:availableApiList];
        }
    }
    // For developer : if errorCode>=0, handle the error according to
    // requirement.
}

/*
 * Parser of getApplicationInfo response
 */
- (void)parseGetApplicationInfo:(NSArray *)resultArray
                      errorCode:(NSInteger)errorCode
                   errorMessage:(NSString *)errorMessage
{
    if (resultArray.count > 0 && errorCode < 0) {
        NSString *serverName = resultArray[0];
        NSString *serverVersion = resultArray[1];
        NSLog(@"SampleCameraRemoteViewController parseGetApplicationInfo "
              @"serverName = %@",
              serverName);
        NSLog(@"SampleCameraRemoteViewController parseGetApplicationInfo "
              @"serverVersion = %@",
              serverVersion);
        if (serverVersion != nil) {
            _isSupportedVersion = [self isSupportedServerVersion:serverVersion];
        }
    }
    // For developer : if errorCode>=0, handle the error according to
    // requirement.
}

- (BOOL)isSupportedServerVersion:(NSString *)version
{
    NSArray *versionModeList = [version componentsSeparatedByString:@"."];
    if (versionModeList.count > 0) {
        long major = [versionModeList[0] integerValue];
        if (2 <= major) {
            NSLog(@"SampleCameraRemoteViewController isSupportedServerVersion "
                  @"YES");
            return YES;
        } else {
            NSLog(@"SampleCameraRemoteViewController isSupportedServerVersion "
                  @"NO");
        }
    }
    return NO;
}

/*
 * Parser of getAvailableShootMode response
 */
- (void)parseGetAvailableShootMode:(NSArray *)resultArray
                         errorCode:(NSInteger)errorCode
                      errorMessage:(NSString *)errorMessage
{
    if (resultArray.count > 0 && errorCode < 0) {
        if ([resultArray[0] isEqualToString:@"movie"] ||
            [resultArray[0] isEqualToString:@"still"]) {
            _currentShootMode = resultArray[0];
        } else {
            _currentShootMode = @"";
        }

        _modeArray = [[NSMutableArray alloc] init];
        NSArray *shootModeList = resultArray[1];

        for (int i = 0; i < shootModeList.count; i++) {
            NSLog(@"SampleCameraRemoteViewController "
                  @"parseGetAvailableShootMode shootMode = %@",
                  shootModeList[i]);

            NSString *shootMode = shootModeList[i];
            if ([shootMode isEqualToString:@"movie"] ||
                [shootMode isEqualToString:@"still"]) {
                [_modeArray addObject:shootMode];
            } else {
                [_modeArray addObject:@""];
            }
        }
        // set initial shoot mode
        [self setInitialShootModeUI];
    }
    // For developer : if errorCode>=0, handle the error according to
    // requirement.
    [self progressIndicator:NO];
}

// set initial shoot mode
- (void)setInitialShootModeUI
{
    //[startSelfButton setHidden:NO];
    //[startSelfButton setEnabled:YES];
    //[startSelfButton setBackgroundColor:[UIColor whiteColor]];
    
    //[takePhotoSelfButton setHidden:NO];
    //[takePhotoSelfButton setEnabled:YES];
    //[takePhotoSelfButton setBackgroundColor:[UIColor whiteColor]];
    
    [actionButtonText setHidden:NO];
    [actionButtonText setEnabled:YES];
    [actionButtonText setBackgroundColor:[UIColor whiteColor]];

    [modeButtonText setHidden:NO];
    [modeButtonText setEnabled:YES];
    [modeButtonText setBackgroundColor:[UIColor whiteColor]];
    [modeButtonText
        setTitle:[NSString stringWithFormat:@"Mode:%@", _currentShootMode]
        forState:UIControlStateNormal];

    if ([@"movie" isEqualToString:_currentShootMode]) {
        if (![NSLocalizedString(@"STR_RECORD_STOP", @"STR_RECORD_STOP")
                isEqualToString:[actionButtonText currentTitle]]) {
            [actionButtonText setTitle:NSLocalizedString(@"STR_RECORD_START",
                                                         @"STR_RECORD_START")
                              forState:UIControlStateNormal];
            actionButtonText.tag = 1;
        }
    } else if ([@"still" isEqualToString:_currentShootMode]) {
        [actionButtonText
            setTitle:NSLocalizedString(@"STR_TAKE_PICTURE", @"STR_TAKE_PICTURE")
            forState:UIControlStateNormal];
        actionButtonText.tag = 3;
    } else {
        [actionButtonText setTitle:@"" forState:UIControlStateNormal];
        [actionButtonText setEnabled:NO];
        [actionButtonText setBackgroundColor:[UIColor grayColor]];
        actionButtonText.tag = -1;
    }
    [modeButtonText
        setTitle:[NSString stringWithFormat:@"Mode:%@", _currentShootMode]
        forState:UIControlStateNormal];
}

/*
 * Parser of startLiveview response
 */
- (void)parseStartLiveView:(NSArray *)resultArray
                 errorCode:(NSInteger)errorCode
              errorMessage:(NSString *)errorMessage
{
    if (resultArray.count > 0 && errorCode < 0) {
        NSString *liveviewUrl = resultArray[0];
        NSLog(@"SampleCameraRemoteViewController parseStartLiveView liveview = "
              @"%@",
              liveviewUrl);
        [_streamingDataManager start:liveviewUrl viewDelegate:self];
    }
}

/*
 * Parser of Camera getmethodTypes response
 */
- (void)parseCameraGetMethodTypes:(NSArray *)resultArray
                        errorCode:(NSInteger)errorCode
                     errorMessage:(NSString *)errorMessage
{
    NSLog(@"SampleCameraRemoteViewController parseCameraGetMethodTypes");
    if (resultArray.count > 0 && errorCode < 0) {
        BOOL isSetCameraFunctionAvailable = NO;
        BOOL isGetEventAvailable = NO;

        // check setCameraFunction and getEvent
        for (int i = 0; i < resultArray.count; i++) {
            NSArray *result = resultArray[i];
            if ([(NSString *)result[0]
                    isEqualToString:API_CAMERA_setCameraFunction] &&
                [(NSString *)result[3] isEqualToString:@"1.0"]) {
                isSetCameraFunctionAvailable = YES;
            }
            if ([(NSString *)result[0] isEqualToString:API_CAMERA_getEvent] &&
                [(NSString *)result[3] isEqualToString:@"1.0"]) {
                isGetEventAvailable = YES;
            }
        }

        if (isSetCameraFunctionAvailable) {
            if (!isGetEventAvailable) {
                NSLog(@"SampleCameraRemoteViewController "
                      @"parseCameraGetMethodTypes getEvent is not available.");
                return;
            }
            if ([[SampleCameraEventObserver getInstance] isStarted]) {
                [[SampleCameraEventObserver getInstance] getCurrentState];
            } else {
                [[SampleCameraEventObserver getInstance] start];
            }
        } else {
            [self performSelectorInBackground:@selector(initialize)
                                   withObject:NULL];
        }
    }
}

/*
 * Parser of AvContent getmethodTypes response
 */
- (void)parseAvContentGetMethodTypes:(NSArray *)resultArray
                           errorCode:(NSInteger)errorCode
                        errorMessage:(NSString *)errorMessage
{
    NSLog(@"SampleCameraRemoteViewController parseAvContentGetMethodTypes");
    BOOL isContentValid = NO;
    if (resultArray.count > 0 && errorCode < 0) {
        // check getSchemeList
        for (int i = 0; i < resultArray.count; i++) {
            NSArray *result = resultArray[i];
            if ([(NSString *)result[0]
                    isEqualToString:API_AVCONTENT_getSchemeList] &&
                [(NSString *)result[3] isEqualToString:@"1.0"]) {
                isContentValid = YES;
            }
        }
        // check getSourceList
        if (isContentValid) {
            isContentValid = NO;
            for (int i = 0; i < resultArray.count; i++) {
                NSArray *result = resultArray[i];
                if ([(NSString *)result[0]
                        isEqualToString:API_AVCONTENT_getSourceList] &&
                    [(NSString *)result[3] isEqualToString:@"1.0"]) {
                    isContentValid = YES;
                }
            }
        }
        // check getContentList
        if (isContentValid) {
            isContentValid = NO;
            for (int i = 0; i < resultArray.count; i++) {
                NSArray *result = resultArray[i];
                if ([(NSString *)result[0]
                        isEqualToString:API_AVCONTENT_getContentList] &&
                    [(NSString *)result[3] isEqualToString:@"1.3"]) {
                    isContentValid = YES;
                }
            }
        }
        if (isContentValid) {
            // Content is available
            _isContentAvailable = YES;
            if (_isMediaAvailable) {
                [self.navigationItem.rightBarButtonItem setEnabled:YES];
            }
            isContentValid = NO;

            // check for video : setStreamingContent

            for (int i = 0; i < resultArray.count; i++) {
                NSArray *result = resultArray[i];
                if ([(NSString *)result[0]
                        isEqualToString:API_AVCONTENT_setStreamingContent] &&
                    [(NSString *)result[3] isEqualToString:@"1.0"]) {
                    isContentValid = YES;
                }
            }
            // check startStreaming
            if (isContentValid) {
                isContentValid = NO;
                for (int i = 0; i < resultArray.count; i++) {
                    NSArray *result = resultArray[i];
                    if ([(NSString *)result[0]
                            isEqualToString:API_AVCONTENT_startStreaming] &&
                        [(NSString *)result[3] isEqualToString:@"1.0"]) {
                        isContentValid = YES;
                    }
                }
            }
            // check stopStreaming
            if (isContentValid) {
                isContentValid = NO;
                for (int i = 0; i < resultArray.count; i++) {
                    NSArray *result = resultArray[i];
                    if ([(NSString *)result[0]
                            isEqualToString:API_AVCONTENT_stopStreaming] &&
                        [(NSString *)result[3] isEqualToString:@"1.0"]) {
                        isContentValid = YES;
                    }
                }
            }
            if (isContentValid) {
                // video is available
                _isMovieAvailable = YES;
            }
        }
    }
}

/*
 * Delegate parser implementation for WebAPI requests
 */
- (void)parseMessage:(NSData *)response apiName:(NSString *)apiName
{
    NSString *responseText =
        [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    NSLog(@"SampleCameraRemoteViewController parseMessage = %@ apiName = %@",
          responseText, apiName);

    NSError *e;
    NSDictionary *dict =
        [NSJSONSerialization JSONObjectWithData:response
                                        options:NSJSONReadingMutableContainers
                                          error:&e];
    if (e) {
        NSLog(@"SampleCameraRemoteViewController parseMessage error parsing "
              @"JSON string");
        [self openNetworkErrorDialog];
        return;
    }

    NSArray *resultArray = [[NSArray alloc] init];
    if ([dict[@"result"] isKindOfClass:[NSArray class]]) {
        resultArray = dict[@"result"];
    }

    NSArray *resultsArray = [[NSArray alloc] init];
    if ([dict[@"results"] isKindOfClass:[NSArray class]]) {
        resultsArray = dict[@"results"];
    }

    NSArray *errorArray = nil;
    NSString *errorMessage = @"";
    NSInteger errorCode = -1;
    if ([dict[@"error"] isKindOfClass:[NSArray class]]) {
        errorArray = dict[@"error"];
    }
    if (errorArray != nil && errorArray.count >= 2) {
        errorCode = [(NSNumber *)errorArray[0] intValue];
        errorMessage = errorArray[1];
        NSLog(@"SampleCameraRemoteViewController parseMessage API=%@, "
              @"errorCode=%ld, errorMessage=%@",
              apiName, (long)errorCode, errorMessage);

        // This error is created in HttpAsynchronousRequest
        if (errorCode == 16) {
            [self openNetworkErrorDialog];
            return;
        }
    }

    if ([apiName isEqualToString:API_CAMERA_getAvailableApiList]) {
        [self parseGetAvailableApiList:resultArray
                             errorCode:errorCode
                          errorMessage:errorMessage];
    } else if ([apiName isEqualToString:API_CAMERA_getApplicationInfo]) {
        [self parseGetApplicationInfo:resultArray
                            errorCode:errorCode
                         errorMessage:errorMessage];
    } else if ([apiName isEqualToString:API_CAMERA_getShootMode]) {

    } else if ([apiName isEqualToString:API_CAMERA_setShootMode]) {

    } else if ([apiName isEqualToString:API_CAMERA_getAvailableShootMode]) {
        [self parseGetAvailableShootMode:resultArray
                               errorCode:errorCode
                            errorMessage:errorMessage];
    } else if ([apiName isEqualToString:API_CAMERA_getSupportedShootMode]) {

    } else if ([apiName isEqualToString:API_CAMERA_startLiveview]) {
        [self parseStartLiveView:resultArray
                       errorCode:errorCode
                    errorMessage:errorMessage];
    } else if ([apiName isEqualToString:API_CAMERA_stopLiveview]) {

    } else if ([apiName isEqualToString:API_CAMERA_startRecMode]) {

    } else if ([apiName isEqualToString:API_CAMERA_stopRecMode]) {

    } else if ([apiName isEqualToString:API_CAMERA_actTakePicture]) {
        [self parseActTakePicture:resultArray
                        errorCode:errorCode
                     errorMessage:errorMessage];
    } else if ([apiName isEqualToString:API_CAMERA_startMovieRec]) {

    } else if ([apiName isEqualToString:API_CAMERA_stopMovieRec]) {

    } else if ([apiName isEqualToString:API_CAMERA_getMethodTypes]) {
        [self parseCameraGetMethodTypes:resultsArray
                              errorCode:errorCode
                           errorMessage:errorMessage];
    } else if ([apiName isEqualToString:API_CAMERA_actZoom]) {

    } else if ([apiName isEqualToString:API_AVCONTENT_getMethodTypes]) {
        [self parseAvContentGetMethodTypes:resultsArray
                                 errorCode:errorCode
                              errorMessage:errorMessage];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    SampleDateListViewController *viewController =
        [segue destinationViewController];
    viewController.isMovieAvailable = _isMovieAvailable;
}

- (void)openNetworkErrorDialog
{
    UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:NSLocalizedString(@"NETWORK_ERROR_HEADING",
                                            @"NETWORK_ERROR_HEADING")
                  message:NSLocalizedString(@"NETWORK_ERROR_MESSAGE",
                                            @"NETWORK_ERROR_MESSAGE")
                 delegate:nil
        cancelButtonTitle:@"OK"
        otherButtonTitles:nil];
    [alert show];
    [self progressIndicator:NO];
}

- (void)openUnsupportedErrorDialog
{
    UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:NSLocalizedString(@"UNSUPPORTED_HEADING",
                                            @"UNSUPPORTED_HEADING")
                  message:NSLocalizedString(@"UNSUPPORTED_MESSAGE",
                                            @"UNSUPPORTED_MESSAGE")
                 delegate:nil
        cancelButtonTitle:@"OK"
        otherButtonTitles:nil];
    [alert show];
    [self progressIndicator:NO];
}

- (void)openUnsupportedShootModeErrorDialog
{
    UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:NSLocalizedString(@"UNSUPPORTED_HEADING",
                                            @"UNSUPPORTED_HEADING")
                  message:NSLocalizedString(@"UNSUPPORTED_SHOOT_MODE_MESSAGE",
                                            @"UNSUPPORTED_SHOOT_MODE_MESSAGE")
                 delegate:nil
        cancelButtonTitle:@"OK"
        otherButtonTitles:nil];
    [alert show];
}

-(void)dealloc{
    //photoCameraSelf.delegate = nil;
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
    if ([device hasFlash] && [device isFlashModeSupported:flashMode])
    {
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    }
}

#pragma mark File Output Delegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    if (error)
        NSLog(@"%@", error);
    
    [self setLockInterfaceRotation:NO];
    
    // Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.
    UIBackgroundTaskIdentifier backgroundRecordingID = [self backgroundRecordingID];
    [self setBackgroundRecordingID:UIBackgroundTaskInvalid];
    
    [[[ALAssetsLibrary alloc] init] writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error)
            NSLog(@"%@", error);
        
        [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
        
        if (backgroundRecordingID != UIBackgroundTaskInvalid)
            [[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
    }];
}
+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];
    
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position)
        {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}
- (void)checkDeviceAuthorizationStatus
{
//    NSString *mediaType = AVMediaTypeVideo;
//    
//    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
//        if (granted)
//        {
//            //Granted access to mediaType
//            [self setDeviceAuthorized:YES];
//        }
//        else
//        {
//            //Not granted access to mediaType
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [[[UIAlertView alloc] initWithTitle:@"AVCam!"
//                                            message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
//                                           delegate:self
//                                  cancelButtonTitle:@"OK"
//                                  otherButtonTitles:nil] show];
//                [self setDeviceAuthorized:NO];
//            });
//        }
//    }];
}
- (void)viewWillAppear:(BOOL)animated
{
    dispatch_async([self sessionQueue], ^{
//        [self addObserver:self forKeyPath:@"movieFileOutput.recording" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:RecordingContext];
//        ;
        [[self session] startRunning];
    });
}

@end
