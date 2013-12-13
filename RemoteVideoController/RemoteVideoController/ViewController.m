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
<MCSessionDelegate>
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCAdvertiserAssistant *advertiserAssistant;
@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // start advertising
    
    _peerID = [[MCPeerID alloc] initWithDisplayName:@"Advertiser #1"];
    _session = [[MCSession alloc] initWithPeer:_peerID];
    _session.delegate = self;
    _advertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:kServiceName
                                                                discoveryInfo:nil
                                                                      session:_session];
    [_advertiserAssistant start];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


// =============================================================================
#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch (state) {
        case MCSessionStateConnected: {
            NSLog(@"MCSessionStateConnected");
//            dispatch_async(dispatch_get_main_queue(), ^{
//                _messageTextField.hidden = NO;
//                _sendMessageButton.hidden = NO;
//                _activityView.hidden = YES;
//            });
            
            // This line only necessary for the advertiser. We want to stop advertising our services
            // to other browsers when we successfully connect to one.
            [_advertiserAssistant stop];
            break;
        }
        case MCSessionStateNotConnected: {
            NSLog(@"MCSessionStateNotConnected");
//            dispatch_async(dispatch_get_main_queue(), ^{
//                _launchAdvertiserButton.hidden = NO;
//                _launchBrowserButton.hidden = NO;
//                _messageTextField.hidden = YES;
//                _sendMessageButton.hidden = YES;
//            });
            break;
        }
        default:
            break;
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


@end
