//
//  MapController.m
//  iNear
//
//  Created by Sergey Seitov on 11.04.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "MapController.h"
#import <GoogleMaps/GoogleMaps.h>
#import <MBProgressHUD/MBProgressHUD.h>

@interface MapController () {
    GMSMapView *_mapView;
    GMSMarker *_marker;
}

@end

@implementation MapController

+ (UIImage*)circularScaleAndCropImage:(UIImage*)image frame:(CGRect)frame
{
    // This function returns a newImage, based on image, that has been:
    // - scaled to fit in (CGRect) rect
    // - and cropped within a circle of radius: rectWidth/2
    
    //Create the bitmap graphics context
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(frame.size.width, frame.size.height), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //Get the width and heights
    CGFloat imageWidth = image.size.width;
    CGFloat imageHeight = image.size.height;
    CGFloat rectWidth = frame.size.width;
    CGFloat rectHeight = frame.size.height;
    
    //Calculate the scale factor
    CGFloat scaleFactorX = rectWidth/imageWidth;
    CGFloat scaleFactorY = rectHeight/imageHeight;
    
    //Calculate the centre of the circle
    CGFloat imageCentreX = rectWidth/2;
    CGFloat imageCentreY = rectHeight/2;
    
    // Create and CLIP to a CIRCULAR Path
    // (This could be replaced with any closed path if you want a different shaped clip)
    CGFloat radius = rectWidth/2;
    CGContextBeginPath (context);
    CGContextAddArc (context, imageCentreX, imageCentreY, radius, 0, 2*M_PI, 0);
    CGContextClosePath (context);
    CGContextClip (context);
    
    //Set the SCALE factor for the graphics context
    //All future draw calls will be scaled by this factor
    CGContextScaleCTM (context, scaleFactorX, scaleFactorY);
    
    // Draw the IMAGE
    CGRect myRect = CGRectMake(0, 0, imageWidth, imageHeight);
    [image drawInRect:myRect];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

+ (NSString*)stringTime:(double)time
{
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setTimeStyle:NSDateFormatterShortStyle];
    [format setDateStyle:NSDateFormatterMediumStyle];
    return [format stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                           target:self
                                                                                           action:@selector(refresh)];
    NSDictionary *locObject = _user[@"location"];
    if (locObject) {
        double time = [[locObject objectForKey:@"time"] doubleValue];
        self.title = [MapController stringTime:time];

        double latitude = [[locObject objectForKey:@"latitude"] doubleValue];
        double longitude = [[locObject objectForKey:@"longitude"] doubleValue];

        GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:latitude longitude:longitude zoom:16];
        _mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
        _mapView.myLocationEnabled = YES;
        self.view = _mapView;

        // Creates a marker in the center of the map.
        _marker = [[GMSMarker alloc] init];
        _marker.position = CLLocationCoordinate2DMake(latitude, longitude);
        _marker.title = _user[@"displayName"];
        UIImage* image = [UIImage imageWithData:_user[@"photo"]];
        _marker.icon = [MapController circularScaleAndCropImage:image frame:CGRectMake(0, 0, 60, 60)];
        _marker.map = _mapView;
    } else {
        _mapView = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:YES animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:NO animated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (!_mapView) {
        UIAlertController * alert=   [UIAlertController
                                      alertControllerWithTitle:@"No data"
                                      message:@"User not published his location."
                                      preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* ok = [UIAlertAction
                             actionWithTitle:@"Ok"
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action)
                             {
                                 [self.navigationController popViewControllerAnimated:YES];
                             }];
        [alert addAction:ok];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)refresh
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [[PFUser currentUser] fetchInBackgroundWithBlock:^(PFObject* user, NSError* error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        NSDictionary *locObject = user[@"location"];
        if (locObject) {
            double time = [[locObject objectForKey:@"time"] doubleValue];
            self.title = [MapController stringTime:time];
            
            double latitude = [[locObject objectForKey:@"latitude"] doubleValue];
            double longitude = [[locObject objectForKey:@"longitude"] doubleValue];
            _marker.position = CLLocationCoordinate2DMake(latitude, longitude);
            [_mapView moveCamera:[GMSCameraUpdate setTarget:_marker.position]];
        }
    }];
}

@end
