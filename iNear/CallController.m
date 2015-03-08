//
//  CallController.m
//  iNear
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "CallController.h"
#import "DragView.h"
#import "Camera.h"
#import "VTEncoder.h"
#import "VTDecoder.h"

@interface CallController () <AVCaptureVideoDataOutputSampleBufferDelegate, VTEncoderDelegate, VTDecoderDelegate> {
    
    dispatch_queue_t _captureQueue;
}

@property (weak, nonatomic) IBOutlet DragView *selfView;
@property (weak, nonatomic) IBOutlet VideoLayerView *peerView;

- (IBAction)switchCamera:(id)sender;

@property (strong, nonatomic) VTEncoder* encoder;
@property (strong, nonatomic) VTDecoder* decoder;

@end

@implementation CallController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _captureQueue = dispatch_queue_create("com.vchannel.DirectVideo", DISPATCH_QUEUE_SERIAL);
    [[Camera shared].output setSampleBufferDelegate:self queue:_captureQueue];

    _encoder = [[VTEncoder alloc] init];
    _encoder.delegate = self;
    
    _decoder = [[VTDecoder alloc] init];
    _decoder.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [self updateFotOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation]];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopCapture];
}

- (void)updateFotOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    CGRect frame = _selfView.frame;
    if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation) ) {
        frame.size.width = 100;
        frame.size.height = 140;
    } else {
        frame.size.width = 140;
        frame.size.height = 100;
    }
    _selfView.frame = frame;
    [self startPreview];
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self updateFotOrientation:toInterfaceOrientation];
}

- (void) startPreview
{
    [self stopCapture];
    
    AVCaptureVideoPreviewLayer* preview = [[Camera shared] getPreviewLayer];
    [preview removeFromSuperlayer];
    preview.frame = _selfView.bounds;
    [[preview connection] setVideoOrientation:(AVCaptureVideoOrientation)[[UIDevice currentDevice] orientation]];
    
    [self startCapture];
}

- (void)startCapture
{
    [_encoder openForWidth:640 height:320];
}

- (void)stopCapture
{
    [_encoder close];
    [_decoder close];
    [_selfView clear];
    [_peerView clear];
}

- (IBAction)switchCamera:(id)sender
{
    [self stopCapture];
    [[Camera shared] switchCamera];
    [self startCapture];
}

#pragma mark - AVCaptureVideoDataOutput delegate

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    [_selfView drawBuffer:sampleBuffer];
    
    [connection setVideoOrientation:(AVCaptureVideoOrientation)[[UIDevice currentDevice] orientation]];
    CVImageBufferRef pixelBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    [_encoder encodeBuffer:pixelBuffer];
}

#pragma mark - VTEncoder delegare

- (void)encoder:(VTEncoder*)encoder encodedData:(NSData*)data
{
    if (!_decoder.isOpened) {
        [_decoder openForWidth:_selfView.frame.size.width height:_selfView.frame.size.height sps:_encoder.sps pps:_encoder.pps];
    }
    if (_decoder.isOpened) {
        [_decoder decodeData:data];
    }
}

#pragma mark - VTDeccoder delegare

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
    [_peerView drawBuffer:buffer];
    CFRelease(buffer);
}

@end
