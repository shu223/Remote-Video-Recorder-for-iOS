//
//  ViewController.m
//  RemoteVideoController
//
//  Created by shuichi on 12/14/13.
//  Copyright (c) 2013 Shuichi Tsutsumi. All rights reserved.
//

#import "ViewController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import "RVConstants.h"
#import "SVProgressHUD.h"


@interface ViewController ()
<MCSessionDelegate, MCBrowserViewControllerDelegate>
{
    BOOL isRecording;
}
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCBrowserViewController *browserView;

@property (nonatomic, strong) UIImage *recStartImage;
@property (nonatomic, strong) UIImage *recStopImage;
@property (nonatomic, strong) UIImage *outerImage1;
@property (nonatomic, strong) UIImage *outerImage2;

@property (nonatomic, weak) IBOutlet UIButton *launchBrowserButton;
@property (nonatomic, weak) IBOutlet UIButton *recBtn;
@property (nonatomic, weak) IBOutlet UILabel *messageLabel;
@property (nonatomic, weak) IBOutlet UIImageView *outerImageView;
@property (nonatomic, weak) IBOutlet UISegmentedControl *fpsControl;
@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Setup images for the Shutter Button
    UIImage *image;
    image = [UIImage imageNamed:@"ShutterButtonStart"];
    self.recStartImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.recBtn setImage:self.recStartImage
                 forState:UIControlStateNormal];
    
    image = [UIImage imageNamed:@"ShutterButtonStop"];
    self.recStopImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    [self.recBtn setTintColor:[UIColor colorWithRed:245./255.
                                              green:51./255.
                                               blue:51./255.
                                              alpha:1.0]];
    self.outerImage1 = [UIImage imageNamed:@"outer1"];
    self.outerImage2 = [UIImage imageNamed:@"outer2"];
    self.outerImageView.image = self.outerImage1;

    [self setControlButtonsEnabled:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


// =============================================================================
#pragma mark - Private

- (void)setControlButtonsEnabled:(BOOL)enabled {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.recBtn.enabled = enabled;
        self.launchBrowserButton.hidden = enabled;
    });
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

- (void)session:(MCSession *)session
           peer:(MCPeerID *)peerID
 didChangeState:(MCSessionState)state
{
    switch (state) {
        case MCSessionStateConnected: {
            NSLog(@"MCSessionStateConnected");
            break;
        }
        case MCSessionStateNotConnected: {
            NSLog(@"MCSessionStateNotConnected");
            break;
        }
        default:
            break;
    }
    
    if ([self.session.connectedPeers count]) {
        
        [self setControlButtonsEnabled:YES];
    }
    else {
        
        [self setControlButtonsEnabled:NO];
    }
}

- (void)session:(MCSession *)session
 didReceiveData:(NSData *)data
       fromPeer:(MCPeerID *)peerID
{
    NSPropertyListFormat format;
    NSDictionary *receivedData = [NSPropertyListSerialization propertyListWithData:data
                                                                           options:0
                                                                            format:&format
                                                                             error:NULL];
    // メッセージの処理
    NSString *message = receivedData[kMessageKey];

    if ([message length]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{

            // 録画開始
            if ([message isEqualToString:kStatusRecording]) {
                
                isRecording = YES;
                [self.recBtn setImage:self.recStopImage
                             forState:UIControlStateNormal];
            }
            // 保存開始
            else if ([message isEqualToString:kStatusSaving]) {

                [SVProgressHUD showWithStatus:@"Saving"
                                     maskType:SVProgressHUDMaskTypeGradient];
            }
            // 録画終了
            else if ([message isEqualToString:kStatusFinished]) {

                [SVProgressHUD dismiss];
                
                self.messageLabel.text = @"Saved!";
                
                isRecording = NO;
                [self.recBtn setImage:self.recStartImage
                             forState:UIControlStateNormal];
            }
            // 録画時間
            else {
                self.messageLabel.text = message;
            }
        });
    }
}

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

- (IBAction)recButtonTapped:(UIButton *)sender {
    
    NSString *message;
    
    if (!isRecording) {
        message = kCommandStart;
    }
    else {
        message = kCommandStop;
    }
    
    NSDictionary *dataDict = @{ kMessageKey : message };
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dataDict
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:NULL];
    NSError *error;
    [self.session sendData:data
                   toPeers:[_session connectedPeers]
                  withMode:MCSessionSendDataReliable
                     error:&error];
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
