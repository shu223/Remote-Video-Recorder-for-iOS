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


@interface ViewController ()
<MCSessionDelegate, MCBrowserViewControllerDelegate>
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCBrowserViewController *browserView;

@property (nonatomic, weak) IBOutlet UIButton *launchBrowserButton;
@property (nonatomic, weak) IBOutlet UIButton *startBtn;
@property (nonatomic, weak) IBOutlet UIButton *retakeBtn;
@property (nonatomic, weak) IBOutlet UIButton *stopBtn;
@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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
        
        self.startBtn.enabled = enabled;
        self.retakeBtn.enabled = enabled;
        self.stopBtn.enabled = enabled;
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

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
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

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    NSPropertyListFormat format;
    NSDictionary *receivedData = [NSPropertyListSerialization propertyListWithData:data
                                                                           options:0
                                                                            format:&format
                                                                             error:NULL];
    NSString *message = receivedData[kMessageKey];
    if ([message length]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *messageAlert = [[UIAlertView alloc] initWithTitle:@"Received message"
                                                                   message:message
                                                                  delegate:self
                                                         cancelButtonTitle:@"OK"
                                                         otherButtonTitles:nil];
            [messageAlert show];
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

- (IBAction)sendMessageButtonPressed:(UIButton *)sender {
    
    NSString *message;
    
    switch (sender.tag) {
        case 0:
        default:
            message = @"unknown";
            break;
        case 1:
            message = kCommandStart;
            break;
        case 2:
            message = kCommandRetake;
            break;
        case 3:
            message = kCommandStop;
            break;
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
