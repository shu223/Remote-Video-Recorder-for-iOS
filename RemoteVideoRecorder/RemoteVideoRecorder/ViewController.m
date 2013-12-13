//
//  ViewController.m
//  RemoteVideoRecorder
//
//  Created by shuichi on 12/13/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "ViewController.h"

#import "SCCamera.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import "RVConstants.h"
#import "SVProgressHUD.h"


@interface ViewController ()
<SCCameraDelegate, MCSessionDelegate>
@property (nonatomic, strong) SCCamera *camera;

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCAdvertiserAssistant *advertiserAssistant;

@property (nonatomic, weak) IBOutlet UIView *previewView;
@property (nonatomic, weak) IBOutlet UILabel *timeRecordedLabel;
@property (nonatomic, weak) IBOutlet UIButton *advertiseBtn;
@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.camera = [[SCCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh];
    self.camera.delegate = self;
    self.camera.enableSound = YES;
    self.camera.previewVideoGravity = SCVideoGravityResizeAspectFill;
    self.camera.previewView = self.previewView;
	self.camera.videoOrientation = AVCaptureVideoOrientationPortrait;
//	self.camera.recordingDurationLimit = CMTimeMakeWithSeconds(10, 1);

    [self.camera initialize:^(NSError * audioError, NSError * videoError) {
		[self prepareCamera];
    }];
    
    
    [self startAdvertising];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


// =============================================================================
#pragma mark - Private

- (void) updateLabelForSecond:(Float64)totalRecorded {
    
    self.timeRecordedLabel.text = [NSString stringWithFormat:@"Recorded - %.2f sec",
                                   totalRecorded];
}

- (void) prepareCamera {
    
	if (![self.camera isPrepared]) {
        
		NSError * error;
		[self.camera prepareRecordingOnTempDir:&error];
		
		if (error != nil) {
            
			NSLog(@"%@", error);

            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to start camera"
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
		}
        else {
            
			NSLog(@"- CAMERA READY -");
            [self.camera startRunningSession];
		}
	}
}



// =============================================================================
#pragma mark - SCAudioVideoRecorderDelegate

- (void)audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordVideoFrame:(CMTime)frameTime {
    [self updateLabelForSecond:CMTimeGetSeconds(frameTime)];
}

// error
- (void)audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeVideoEncoder:(NSError *)error {
    NSLog(@"Failed to initialize VideoEncoder");
}

- (void)audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeAudioEncoder:(NSError *)error {
    NSLog(@"Failed to initialize AudioEncoder");
}

- (void)audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder willFinishRecordingAtTime:(CMTime)frameTime {
//	self.loadingView.hidden = NO;
//    self.downBar.userInteractionEnabled = NO;
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFinishRecordingAtUrl:(NSURL *)recordedFile error:(NSError *)error {

    [self prepareCamera];
    
    if (error) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to record"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];

        return;
    }

    
    // save to camera roll
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
                 
                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                                 message:message
                                                                delegate:nil
                                                       cancelButtonTitle:@"OK"
                                                       otherButtonTitles:nil];
                 [alert show];
             });
         }];
    });
}

- (void)camera:(SCCamera *)camera didFailWithError:(NSError *)error {
    NSLog(@"error : %@", error.description);
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
    
    if ([self.camera isRecording]) {
        
//        NSLog(@"==== PAUSING RECORDING ====");
//        [self.camera pause];
    }
    else {
        
        NSLog(@"==== STARTING RECORDING ====");
        [self.camera record];
    }
}

- (IBAction)stopButtonTapped:(id)sender {
    
    [self.camera stop];
}

- (IBAction)retakeButtonTapped:(id)sender {
    
    [self.camera cancel];
	[self prepareCamera];
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

@end
