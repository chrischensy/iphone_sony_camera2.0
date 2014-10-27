/**
 * @file  SampleGalleryViewController.m
 * @brief CameraRemoteSampleApp
 *
 * Copyright 2014 Sony Corporation
 */

#import "SampleGalleryViewController.h"
#import "SampleContentCell.h"
#import "SampleCameraApi.h"
#import "SampleAvContentApi.h"
#import "SampleContentViewController.h"

@implementation SampleGalleryViewController {
    NSMutableArray *_contents_fileName;
    NSMutableArray *_contents_kind;
    NSMutableArray *_contents_uri;
    NSMutableArray *_contents_thumbnailUrl;
    NSMutableArray *_contents_largeUrl;
}

@synthesize galleryView = _galleryView;
@synthesize isMovieAvailable = _isMovieAvailable;
@synthesize dateUri = _dateUri;
@synthesize dateTitle = _dateTitle;

- (void)viewDidLoad
{
    [super viewDidLoad];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    _contents_fileName = [[NSMutableArray alloc] init];
    _contents_kind = [[NSMutableArray alloc] init];
    _contents_uri = [[NSMutableArray alloc] init];
    _contents_thumbnailUrl = [[NSMutableArray alloc] init];
    _contents_largeUrl = [[NSMutableArray alloc] init];
    [_galleryView setDelegate:self];
    [_galleryView setDataSource:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.navigationItem.title = _dateTitle;
    [[SampleCameraEventObserver getInstance] setDelegate:self];
    [[SampleCameraEventObserver getInstance] start];
    [SampleCameraApi getEvent:self longPollingFlag:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (void)fetchContentsList
{
    if (_isMovieAvailable) {
        [SampleAvContentApi getContentList:self
                                       uri:_dateUri
                                      view:@"date"
                                      type:@[
                                              @"\"still\"",
                                              @"\"movie_mp4\"",
                                              @"\"movie_xavcs\""
                                           ]];
    } else {
        [SampleAvContentApi getContentList:self
                                       uri:_dateUri
                                      view:@"date"
                                      type:@[ @"\"still\"" ]];
    }
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return [_contents_thumbnailUrl count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"SampleGalleryViewController cellForItemAtIndexPath = %ld",
          (long)indexPath.row);
    SampleContentCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"contentCell"
                                                  forIndexPath:indexPath];
    if (!cell) {
        cell = [[SampleContentCell alloc]
            initWithFrame:CGRectMake(0, 0, cell.frame.size.width,
                                     cell.frame.size.height)];
    }
    cell.layer.borderWidth = 1.0f;
    cell.layer.borderColor = [UIColor whiteColor].CGColor;
    NSDictionary *args = @{
        @"requestURL" : _contents_thumbnailUrl[indexPath.row],
        @"imageView" : cell.thumbnailView
    };
    cell.thumbnailView.image = nil;
    [self performSelectorInBackground:@selector(fetchThumbnail:)
                           withObject:args];
    if ([_contents_kind[indexPath.row] isEqualToString:@"still"]) {
        cell.contentType.text = @"still";
    } else {
        cell.contentType.text = @"movie";
    }
    return cell;
}

// the user tapped a collection item, load and set the image on the detail view
// controller
//
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath =
        [self.collectionView indexPathsForSelectedItems][0];
    NSLog(@"SampleGalleryViewController prepareForSegue = %ld",
          (long)indexPath.row);
    SampleContentViewController *viewController =
        [segue destinationViewController];
    viewController.contentFileName = _contents_fileName[indexPath.row];
    viewController.contentKind = _contents_kind[indexPath.row];
    viewController.contentUri = _contents_uri[indexPath.row];
    if ([_contents_kind[indexPath.row] isEqualToString:@"movie_mp4"] ||
        [_contents_kind[indexPath.row] isEqualToString:@"movie_xavcs"]) {
        viewController.contentUrl = nil;
    } else if ([_contents_kind[indexPath.row] isEqualToString:@"still"]) {
        viewController.contentUrl = _contents_largeUrl[indexPath.row];
    }
}

/**
 * Download image from the received URL
 */
- (void)fetchThumbnail:(NSDictionary *)dict
{
    NSString *requestURL = dict[@"requestURL"];
    UIImageView *imageView = dict[@"imageView"];
    NSLog(@"SampleGalleryViewController download URL = %@", requestURL);
    NSURL *downoadUrl = [NSURL URLWithString:requestURL];
    NSData *urlData = [NSData dataWithContentsOfURL:downoadUrl];
    if (urlData) {
        UIImage *imageToPost = [UIImage imageWithData:urlData];
        [imageView setImage:imageToPost];
    }
}

/**
 * SampleEventObserverDelegate function implementation
 */

- (void)didCameraStatusChanged:(NSString *)status
{
    NSLog(@"SampleGalleryViewController didCameraStatusChanged = %@", status);
    if ([status isEqualToString:PARAM_CAMERA_cameraStatus_contentsTransfer]) {
        [self fetchContentsList];
    }
}

- (void)didFailParseMessageWithError:(NSError *)error
{
    NSLog(@"SampleGalleryViewController didFailParseMessageWithError error "
          @"parsing JSON string");
    [self openNetworkErrorDialog];
}

/*
 * Parser of getEvent response
 */
- (void)parseGetEvent:(NSArray *)resultArray
            errorCode:(NSInteger)errorCode
         errorMessage:(NSString *)errorMessage
{
    if (resultArray.count > 0 && errorCode < 0) {
        NSLog(@"SampleGalleryViewController getEvent = %@", resultArray[1]);
        int indexOfCameraStatus = 1;
        if (indexOfCameraStatus < resultArray.count &&
            [resultArray[indexOfCameraStatus]
                isKindOfClass:[NSDictionary class]]) {
            NSDictionary *typeObj = resultArray[indexOfCameraStatus];
            if ([typeObj[@"type"] isKindOfClass:[NSString class]]) {
                if ([typeObj[@"type"] isEqualToString:@"cameraStatus"]) {
                    if ([typeObj[@"cameraStatus"]
                            isKindOfClass:[NSString class]]) {
                        NSString *cameraStatus = typeObj[@"cameraStatus"];
                        if ([PARAM_CAMERA_cameraStatus_contentsTransfer
                                isEqualToString:cameraStatus]) {
                            [self fetchContentsList];
                        }
                    }
                }
            }
        }
    } else {
        [self openNetworkErrorDialog];
    }
}

/*
 * Parser of getContentList response
 */
- (void)parseGetContentList:(NSArray *)resultArray
                  errorCode:(NSInteger)errorCode
               errorMessage:(NSString *)errorMessage
{
    if (resultArray.count > 0 && errorCode < 0) {
        NSArray *result = resultArray[0];
        _contents_fileName = [[NSMutableArray alloc] init];
        _contents_kind = [[NSMutableArray alloc] init];
        _contents_uri = [[NSMutableArray alloc] init];
        _contents_thumbnailUrl = [[NSMutableArray alloc] init];
        _contents_largeUrl = [[NSMutableArray alloc] init];
        for (int i = 0; i < result.count; i++) {
            if (![result[i] isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSDictionary *dict = result[i];
            NSLog(@"SampleGalleryViewController parseGetContentList = %@",
                  dict[@"uri"]);
            if (![dict[@"isBrowsable"] isKindOfClass:[NSString class]]) {
                continue;
            }
            NSString *isBrowsable = dict[@"isBrowsable"];
            if ([@"false" isEqualToString:isBrowsable]) {
                [_contents_kind addObject:dict[@"contentKind"]];
                [_contents_uri addObject:dict[@"uri"]];
                if (![dict[@"content"] isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSDictionary *content = dict[@"content"];
                if (![content[@"original"] isKindOfClass:[NSArray class]]) {
                    continue;
                }
                NSArray *original = content[@"original"];
                if (original.count > 0) {
                    if (![original[0] isKindOfClass:[NSDictionary class]]) {
                        continue;
                    }
                    [_contents_fileName addObject:original[0][@"fileName"]];
                }
                [_contents_thumbnailUrl addObject:content[@"thumbnailUrl"]];
                [_contents_largeUrl addObject:content[@"largeUrl"]];
                NSLog(@"SampleGalleryViewController parseGetContentList "
                      @"thumbnail = %@",
                      content[@"thumbnailUrl"]);
            }
        }
        [UIApplication sharedApplication].networkActivityIndicatorVisible =
            FALSE;
        [_galleryView reloadData];
    } else {
        [self openNetworkErrorDialog];
    }
}

/*
 * Delegate parser implementation for WebAPI requests
 */
- (void)parseMessage:(NSData *)response apiName:(NSString *)apiName
{
    NSString *responseText =
        [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
    NSLog(@"SampleGalleryViewController parseMessage = %@ apiName = %@",
          responseText, apiName);

    NSError *e;
    NSDictionary *dict =
        [NSJSONSerialization JSONObjectWithData:response
                                        options:NSJSONReadingMutableContainers
                                          error:&e];
    if (e) {
        NSLog(@"SampleGalleryViewController parseMessage error parsing JSON "
              @"string");
        [self openNetworkErrorDialog];
        return;
    }

    NSArray *resultArray = [[NSArray alloc] init];
    if ([dict[@"result"] isKindOfClass:[NSArray class]]) {
        resultArray = dict[@"result"];
    }

    NSArray *errorArray = nil;
    NSString *errorMessage = @"";
    NSInteger errorCode = -1;
    if ([dict[@"error"] isKindOfClass:[NSArray class]]) {
        errorArray = dict[@"error"];
    }
    if (errorArray != nil && errorArray.count >= 2) {
        errorCode = (NSInteger)errorArray[0];
        errorMessage = errorArray[1];
        NSLog(@"SampleGalleryViewController parseMessage API=%@, "
              @"errorCode=%ld, errorMessage=%@",
              apiName, (long)errorCode, errorMessage);
    }

    if ([apiName isEqualToString:API_CAMERA_getEvent]) {
        [self parseGetEvent:resultArray
                  errorCode:errorCode
               errorMessage:errorMessage];
    }
    if ([apiName isEqualToString:API_AVCONTENT_getContentList]) {
        [self parseGetContentList:resultArray
                        errorCode:errorCode
                     errorMessage:errorMessage];
    }
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
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

@end
