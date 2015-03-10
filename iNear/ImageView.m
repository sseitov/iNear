/*
     File: ImageView.m
 Abstract: 
    This is a content view class for managing the 'image resource' type table view cells 
 
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

@import MultipeerConnectivity;

#import "ImageView.h"

#define IMAGE_VIEW_HEIGHT_MAX   (140.0)
#define IMAGE_PADDING_X         (15.0)
#define BUFFER_WHITE_SPACE      (14.0)

@interface ImageView ()

// Background image
@property (nonatomic, retain) UIImageView *imageView;

@property (nonatomic) BOOL fromMe;
@property (nonatomic) float width;
@property (nonatomic) float height;

@end

@implementation ImageView

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // Initialization the views
        _imageView = [UIImageView new];
        _imageView.layer.cornerRadius = 5.0;
        _imageView.layer.masksToBounds = YES;
        _imageView.layer.borderColor = [UIColor lightGrayColor].CGColor;
        _imageView.layer.borderWidth = 0.5;

        // Add to parent view
        [self addSubview:_imageView];
    }
    return self;
}

- (void)setMessage:(XMPPMessage *)message fromMe:(BOOL)fromMe
{
    _fromMe = fromMe;
    
    NSString* imageStr = [[message elementForName:@"attachement"] stringValue];
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:imageStr options:kNilOptions];
    UIImage *image = [UIImage imageWithData:imageData];
    
    
    _imageView.image = image;
    
    // Get the image size and scale based on our max height (if necessary)
    CGSize imageSize = image.size;
    _height = imageSize.height;
    CGFloat scale = 1.0;
    
    // Compute scale between the original image and our max row height
    scale = (IMAGE_VIEW_HEIGHT_MAX / _height);
    _height = IMAGE_VIEW_HEIGHT_MAX;
    // Scale the width
    _width = imageSize.width * scale;

    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    // Comput the X,Y origin offsets
    CGFloat xOffsetBalloon;
    CGFloat yOffset;

    if (_fromMe) {
        // Sent images appear or right of view
        xOffsetBalloon = self.frame.size.width - _width - IMAGE_PADDING_X;
        yOffset = BUFFER_WHITE_SPACE / 2;
    } else {
        // Received images appear on left of view with additional display name label
        xOffsetBalloon = IMAGE_PADDING_X;
        yOffset = (BUFFER_WHITE_SPACE / 2);
    }

    // Set the dynamic frames
    _imageView.frame = CGRectMake(xOffsetBalloon, yOffset, _width, _height);
}

#pragma - class methods for computing sizes based on strings

+ (CGFloat)viewHeightForMessage:(XMPPMessage *)message
{
    return (IMAGE_VIEW_HEIGHT_MAX + BUFFER_WHITE_SPACE);
}

@end