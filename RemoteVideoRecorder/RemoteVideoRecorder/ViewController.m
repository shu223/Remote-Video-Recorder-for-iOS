//
//  ViewController.m
//  RemoteVideoRecorder
//
//  Created by shuichi on 12/13/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "ViewController.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <AVFoundation/AVFoundation.h>
#import "RVConstants.h"
#import "SVProgressHUD.h"


@interface ViewController ()
<AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, MCSessionDelegate>
{
    BOOL isRecording;
    BOOL isNeededToSave;
    NSTimeInterval startTime;
    CMTime defaultVideoMaxFrameDuration;
}
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureMovieFileOutput *fileOutput;
@property (nonatomic, strong) AVCaptureDeviceFormat *defaultFormat;
@property (nonatomic, assign) NSTimer *timer;

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCAdvertiserAssistant *advertiserAssistant;

@property (nonatomic, weak) IBOutlet UIView *previewView;
@property (nonatomic, weak) IBOutlet UILabel *timeRecordedLabel;
@property (nonatomic, weak) IBOutlet UIButton *advertiseBtn;
@property (nonatomic, weak) IBOutlet UISegmentedControl *fpsControl;
@property (nonatomic, weak) IBOutlet UIButton *retakeBtn;
@property (nonatomic, weak) IBOutlet UIButton *stopBtn;
@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.retakeBtn.hidden = YES;
    self.stopBtn.hidden = YES;
    self.fpsControl.hidden = NO;
    
    [self initVideo];
    
    [self startAdvertising];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


// =============================================================================
#pragma mark - Private

- (void)initVideo {

    NSError *error;

    self.captureSession = [[AVCaptureSession alloc] init];
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];

    if (error) {
        
        NSLog(@"Video input creation failed");
        return;
    }

    if ([self.captureSession canAddInput:videoIn]) {
        [self.captureSession addInput:videoIn];
    }
    else {
        NSLog(@"Video input add-to-session failed");
    }


    // save the default format
    self.defaultFormat = videoDevice.activeFormat;
    defaultVideoMaxFrameDuration = videoDevice.activeVideoMaxFrameDuration;
    

    AVCaptureDevice *audioDevice= [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    [self.captureSession addInput:audioIn];
    
    self.fileOutput = [[AVCaptureMovieFileOutput alloc] init];
    [self.captureSession addOutput:self.fileOutput];
    

    AVCaptureVideoPreviewLayer * previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    previewLayer.frame = self.previewView.bounds;
    previewLayer.contentsGravity = kCAGravityResizeAspectFill;
	[self.previewView.layer addSublayer:previewLayer];

    [self.captureSession startRunning];
}

- (void)setupFormatForVideoDevice:(AVCaptureDevice *)videoDevice
                       desiredFPS:(CGFloat)desiredFPS
{
    // search for a Full Range video + n fps combo
    for (AVCaptureDeviceFormat *format in videoDevice.formats)
    {
        NSString *compoundStr = @"";
        
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@"'%@'", format.mediaType]];
        
        CMFormatDescriptionRef myCMFormatDescriptionRef= format.formatDescription;
        FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(myCMFormatDescriptionRef);
        BOOL fullRange = NO;
        if (mediaSubType==kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
            compoundStr = [compoundStr stringByAppendingString:@"/'420v'"];
        else if (mediaSubType==kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        {
            compoundStr = [compoundStr stringByAppendingString:@"/'420f'"];
            fullRange = YES;
        }
        else [compoundStr stringByAppendingString:@"'UNKNOWN'"];
        
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(myCMFormatDescriptionRef);
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@" %ix %i", dimensions.width, dimensions.height]];
        
        float maxFramerate = ((AVFrameRateRange*)[format.videoSupportedFrameRateRanges objectAtIndex:0]).maxFrameRate;
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@", { %.0f- %.0f fps}", ((AVFrameRateRange*)[format.videoSupportedFrameRateRanges objectAtIndex:0]).minFrameRate,
                                                            maxFramerate]];
        
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@", fov: %.3f", format.videoFieldOfView]];
        compoundStr = [compoundStr stringByAppendingString:
                       (format.videoBinned ? @", binned" : @"")];
        
        compoundStr = [compoundStr stringByAppendingString:
                       (format.videoStabilizationSupported ? @", supports vis" : @"")];
        
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@", max zoom: %.2f", format.videoMaxZoomFactor]];
        
        compoundStr = [compoundStr stringByAppendingString:[NSString stringWithFormat:@" (upscales @%.2f)", format.videoZoomFactorUpscaleThreshold]];

        if (fullRange && maxFramerate >= desiredFPS)
        {
            NSLog(@"Found %.0f fps mode: %@", desiredFPS, compoundStr);
            [videoDevice lockForConfiguration:nil];
            videoDevice.activeFormat = format;
            videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1, (int32_t)desiredFPS);
            [videoDevice unlockForConfiguration];
        }
    }
}

- (void)startVideoRecording {
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *dateTimePrefix = [formatter stringFromDate:[NSDate date]];
    
    int fileNamePostfix = 0;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = nil;
    do
        filePath =[NSString stringWithFormat:@"/%@/%@-%i.mp4", documentsDirectory, dateTimePrefix, fileNamePostfix++];
    while ([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    
    NSURL *fileURL = [NSURL URLWithString:[@"file://" stringByAppendingString:filePath]];
    [self.fileOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
}

- (void)updateLabelForSecond:(Float64)totalRecorded {
    
    self.timeRecordedLabel.text = [NSString stringWithFormat:@"Recording: %.2f sec",
                                   totalRecorded];
    
    [self sendMessage:self.timeRecordedLabel.text];
}

- (void)sendMessage:(NSString *)message {

    NSDictionary *dataDict = @{ kMessageKey : message };
    
    [self sendDataWithPropertyList:dataDict];
}

- (void)sendDataWithPropertyList:(NSDictionary *)propertyList {

    NSData *data = [NSPropertyListSerialization dataWithPropertyList:propertyList
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:NULL];
    NSError *error;
    [self.session sendData:data
                   toPeers:[_session connectedPeers]
                  withMode:MCSessionSendDataReliable
                     error:&error];
}

- (void)saveRecordedFile:(NSURL *)recordedFile {
    
    if (!isNeededToSave) {
        return;
    }
    
    [SVProgressHUD showWithStatus:@"Saving..."
                         maskType:SVProgressHUDMaskTypeGradient];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        [assetLibrary writeVideoAtPathToSavedPhotosAlbum:recordedFile
                                         completionBlock:
         ^(NSURL *assetURL, NSError *error) {
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 [SVProgressHUD dismiss];
                 
                 NSString *title;
                 NSString *message;
                 
                 if (error != nil) {
                     
                     title = @"Failed to save video";
                     message = [error localizedDescription];
                 }
                 else {
                     title = @"Saved!";
                     message = nil;
                 }
                 
//                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
//                                                                 message:message
//                                                                delegate:nil
//                                                       cancelButtonTitle:@"OK"
//                                                       otherButtonTitles:nil];
//                 [alert show];
                 self.timeRecordedLabel.text = title;
             });
         }];
    });
}



// =============================================================================
#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)                 captureOutput:(AVCaptureFileOutput *)captureOutput
    didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                       fromConnections:(NSArray *)connections
{
}

- (void)                 captureOutput:(AVCaptureFileOutput *)captureOutput
   didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                       fromConnections:(NSArray *)connections error:(NSError *)error
{
    NSLog(@"==== STOP RECORDING ====");

    [self saveRecordedFile:outputFileURL];
    isRecording = NO;
}



// =============================================================================
#pragma mark - Timer Handler

- (void)timerHandler:(NSTimer *)timer {

    NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
    [self updateLabelForSecond:current - startTime];
}



// =============================================================================
#pragma mark - MCSessionDelegate

// MCSessionDelegate methods are called on a background queue, if you are going to update UI
// elements you must perform the actions on the main queue.

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch (state) {
        case MCSessionStateConnected: {
            NSLog(@"MCSessionStateConnected");
            [_advertiserAssistant stop];
            break;
        }
        case MCSessionStateNotConnected: {
            NSLog(@"MCSessionStateNotConnected");
            break;
        }
        default:
            break;
    }
    
    // 接続が切れたらstart advertiseボタンを再度出す
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (![self.session.connectedPeers count]) {
            
            self.advertiseBtn.hidden = NO;
        }
    });
}

// リモコンからの信号受信
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    NSPropertyListFormat format;
    NSDictionary *receivedData = [NSPropertyListSerialization propertyListWithData:data
                                                                           options:0
                                                                            format:&format
                                                                             error:NULL];
    NSString *message = receivedData[kMessageKey];
    if ([message length]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSLog(@"Received message: %@", message);
            
            // START
            if ([message isEqualToString:kCommandStart]) {
                
                [self startButtonTapped:nil];
            }
            // RETAKE
            else if ([message isEqualToString:kCommandRetake]) {
                
                [self retakeButtonTapped:nil];
            }
            // STOP
            else if ([message isEqualToString:kCommandStop]) {
                
                [self stopButtonTapped:nil];
            }
        });
    }
}

// Required MCSessionDelegate protocol methods but are unused in this application.

- (void)                      session:(MCSession *)session
    didStartReceivingResourceWithName:(NSString *)resourceName
                             fromPeer:(MCPeerID *)peerID
                         withProgress:(NSProgress *)progress {
    
}

- (void)     session:(MCSession *)session
    didReceiveStream:(NSInputStream *)stream
            withName:(NSString *)streamName
            fromPeer:(MCPeerID *)peerID {
    
}

- (void)                       session:(MCSession *)session
    didFinishReceivingResourceWithName:(NSString *)resourceName
                              fromPeer:(MCPeerID *)peerID
                                 atURL:(NSURL *)localURL
                             withError:(NSError *)error {
    
}



// =============================================================================
#pragma mark - IBAction

- (IBAction)startButtonTapped:(id)sender {
    
    if (!isRecording) {

        NSLog(@"==== STARTING RECORDING ====");

        isRecording = YES;
        
        self.stopBtn.hidden = NO;
        self.retakeBtn.hidden = NO;
        self.fpsControl.hidden = YES;
        
        [self startVideoRecording];
    }

    // 時間経過取得用
    startTime = [[NSDate date] timeIntervalSince1970];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01
                                                  target:self
                                                selector:@selector(timerHandler:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (IBAction)stopButtonTapped:(id)sender {
    
    isNeededToSave = YES;
    [self.fileOutput stopRecording];
    
    [self.timer invalidate];
    self.timer = nil;

    self.stopBtn.hidden = YES;
    self.retakeBtn.hidden = YES;
    self.fpsControl.hidden = NO;
}

- (IBAction)retakeButtonTapped:(id)sender {
    
    isNeededToSave = NO;
    [self.fileOutput stopRecording];

    [self.timer invalidate];
    self.timer = nil;

    [self updateLabelForSecond:0];
}

- (IBAction)startAdvertising {
    
    self.advertiseBtn.hidden = YES;
    
    _peerID = [[MCPeerID alloc] initWithDisplayName:@"Advertiser #1"];
    _session = [[MCSession alloc] initWithPeer:_peerID];
    _session.delegate = self;
    _advertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:kServiceName
                                                                discoveryInfo:nil
                                                                      session:_session];
    [_advertiserAssistant start];
}

- (IBAction)fpsChanged:(UISegmentedControl *)sender {

    // Switch the FPS
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    CGFloat desiredFps;
    switch (self.fpsControl.selectedSegmentIndex) {
        case 0:
        default:
        {
            [videoDevice lockForConfiguration:nil];
            videoDevice.activeFormat = self.defaultFormat;
            videoDevice.activeVideoMaxFrameDuration = defaultVideoMaxFrameDuration;
            [videoDevice unlockForConfiguration];

            return;
        }
        case 1:
            desiredFps = 60.0;
            break;
        case 2:
            desiredFps = 120.0;
            break;
    }
    
    
    [SVProgressHUD showWithStatus:@"Switching..."
                         maskType:SVProgressHUDMaskTypeGradient];
    
    [self.captureSession stopRunning];

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{

        [self setupFormatForVideoDevice:videoDevice
                             desiredFPS:desiredFps];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [SVProgressHUD dismiss];
            
            [self.captureSession startRunning];
        });
    });
}

@end
