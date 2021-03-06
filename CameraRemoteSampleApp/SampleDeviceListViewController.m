/**
 * @file  SampleDeviceListViewController.m
 * @brief CameraRemoteSampleApp
 *
 * Copyright 2014 Sony Corporation
 */

#import "SampleDeviceListViewController.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import "SampleDeviceDiscovery.h"
#import "SampleCameraEventObserver.h"
#import "DeviceInfo.h"
#import "DeviceList.h"

@interface SampleDeviceListViewController () {
}
@end

@implementation SampleDeviceListViewController {
}

@synthesize wifiOutlet;
@synthesize discoveryOutlet;
@synthesize deviceListOutlet;

- (void)viewDidLoad
{
    [super viewDidLoad];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = FALSE;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.wifiOutlet setText:[self fetchSSIDInfo]];
    [discoveryOutlet
        setTitle:NSLocalizedString(@"DD_TEXT_START", @"DD_TEXT_START")
        forState:UIControlStateNormal];
    [discoveryOutlet setEnabled:YES];
    [deviceListOutlet setDelegate:self];
    [deviceListOutlet setDataSource:self];
    [[SampleCameraEventObserver getInstance] destroy];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)discoveryButton:(id)sender
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = TRUE;
    [self.wifiOutlet setText:[self fetchSSIDInfo]];
    [DeviceList reset];
    [discoveryOutlet
        setTitle:NSLocalizedString(@"DD_TEXT_SEARCHING", @"DD_TEXT_SEARCHING")
        forState:UIControlStateNormal];
    [discoveryOutlet setEnabled:NO];
    [deviceListOutlet reloadData];
    SampleDeviceDiscovery *deviceDiscovery =
        [[SampleDeviceDiscovery alloc] init];
    [deviceDiscovery performSelectorInBackground:@selector(discover:)
                                      withObject:self];
}

/*
 * fetch Wifi information
 */
- (NSString *)fetchSSIDInfo
{
    NSString *currentSSID = @"<<NONE>>";

    NSArray *supportedInterfaces =
        CFBridgingRelease(CNCopySupportedInterfaces());
    id info = nil;
    for (NSString *interfaceName in supportedInterfaces) {
        info = CFBridgingRelease(
            CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName));
        if (info && [info count]) {
            break;
        }
        info = nil;
    }
    if (info) {
        currentSSID = [[NSString alloc]
            initWithString:(NSString *)info[(id)kCNNetworkInfoKeySSID]];
    }

    return currentSSID;
}

/*
 * Device list table view control functions
 *
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section
{
    return [DeviceList getSize];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *MyIdentifier = @"deviceListCell";
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        cell =
            [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:MyIdentifier];
    }
    DeviceInfo *deviceInfo = [DeviceList getDeviceAt:indexPath.row];
    cell.textLabel.text = [deviceInfo getFriendlyName];
    cell.detailTextLabel.text = [deviceInfo findActionListUrl:@"camera"];

    return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [DeviceList selectDeviceAt:indexPath.row];
    [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow]
                             animated:YES];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = TRUE;
}

/**
 * Delegate implementation for receiving device list
 */

- (void)didReceiveDeviceList:(BOOL)isReceived
{
    NSLog(@"SampleDeviceListViewController didReceiveDeviceList: %@",
          isReceived ? @"YES" : @"NO");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isReceived) {
            [deviceListOutlet reloadData];
        }
        [discoveryOutlet
            setTitle:NSLocalizedString(@"DD_TEXT_START", @"DD_TEXT_START")
            forState:UIControlStateNormal];
        [discoveryOutlet setEnabled:YES];
        [UIApplication sharedApplication].networkActivityIndicatorVisible =
            FALSE;
    });
}

@end
