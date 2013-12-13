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


@interface ViewController ()
<SCCameraDelegate, MCBrowserViewControllerDelegate, MCSessionDelegate>
@property (nonatomic, strong) SCCamera *camera;

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCBrowserViewController *browserView;

@property (nonatomic, weak) IBOutlet UIView *previewView;
@property (nonatomic, weak) IBOutlet UILabel *timeRecordedLabel;
@property (nonatomic, weak) IBOutlet UIButton *launchBrowserButton;
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
}

//- (void)viewDidAppear:(BOOL)animated {
//    
//    [super viewDidAppear:animated];
//
//	if (self.camera.isReady && ![self.camera.session isRunning]) {
//		NSLog(@"Start running");
//		[self.camera startRunningSession];
//	} else {
//		NSLog(@"Not prepared yet");
//	}
//}
//
//- (void)viewDidDisappear:(BOOL)animated {
//    
//	[super viewDidDisappear:animated];
//	
//    [self.camera stopRunningSession];
//	[self.camera cancel];
//}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


// =============================================================================
#pragma mark - Private

- (void) updateLabelForSecond:(Float64)totalRecorded {
    
    self.timeRecordedLabel.text = [NSString stringWithFormat:@"Recorded - %.2f sec", totalRecorded];
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
	
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        
        // save in background
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        [assetLibrary writeVideoAtPathToSavedPhotosAlbum:recordedFile
                                         completionBlock:^(NSURL *assetURL, NSError *error) {
                                             DLog(@"Saved video to the camera roll.");
                                         }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self prepareCamera];
//            self.loadingView.hidden = YES;
//            self.downBar.userInteractionEnabled = YES;
            
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
    });
}

- (void)camera:(SCCamera *)camera didFailWithError:(NSError *)error {
    NSLog(@"error : %@", error.description);
}



// =============================================================================
#pragma mark - MCBrowserViewControllerDelegate

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    [self dismissViewControllerAnimated:YES completion:^{
        [_browserView.browser stopBrowsingForPeers];
    }];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
    [self dismissViewControllerAnimated:YES completion:^{
        [_browserView.browser stopBrowsingForPeers];
        _launchBrowserButton.hidden = NO;
    }];
}


// =============================================================================
#pragma mark - MCSessionDelegate

// MCSessionDelegate methods are called on a background queue, if you are going to update UI
// elements you must perform the actions on the main queue.

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch (state) {
        case MCSessionStateConnected: {
            dispatch_async(dispatch_get_main_queue(), ^{
//                _messageTextField.hidden = NO;
//                _sendMessageButton.hidden = NO;
//                _activityView.hidden = YES;
            });

            break;
        }
        case MCSessionStateNotConnected: {
            dispatch_async(dispatch_get_main_queue(), ^{
                _launchBrowserButton.hidden = NO;
//                _messageTextField.hidden = YES;
//                _sendMessageButton.hidden = YES;
            });
            break;
        }
        default:
            break;
    }
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
//            UIAlertView *messageAlert = [[UIAlertView alloc] initWithTitle:@"Received message"
//                                                                   message:message
//                                                                  delegate:self
//                                                         cancelButtonTitle:@"OK"
//                                                         otherButtonTitles:nil];
//            [messageAlert show];
            
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
        
        NSLog(@"==== PAUSING RECORDING ====");
        [self.camera pause];
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

- (IBAction)launchBrowserTapped {
    
    _peerID = [[MCPeerID alloc] initWithDisplayName:@"Browser Name"];
    _session = [[MCSession alloc] initWithPeer:_peerID];
    _session.delegate = self;
    _browserView = [[MCBrowserViewController alloc] initWithServiceType:kServiceName
                                                                session:_session];
    _browserView.delegate = self;
    [self presentViewController:_browserView animated:YES completion:nil];

    _launchBrowserButton.hidden = YES;
}

@end
