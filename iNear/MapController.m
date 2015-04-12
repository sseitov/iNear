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
}

@property (strong, nonatomic) UILabel* titleLabel;

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

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                           target:self
                                                                                           action:@selector(refresh)];
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 600, 44)];
    _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _titleLabel.text = @"";
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.numberOfLines = 0;
    _titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:14];

    self.navigationItem.titleView = _titleLabel;
    
    GMSMarker *peer = [self markerForUser:_user];
    if (peer) {
        GMSCameraPosition *camera = [GMSCameraPosition cameraWithTarget:peer.position zoom:16];
        _mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
        _mapView.myLocationEnabled = NO;
        self.view = _mapView;
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
    } else {
        [self refresh];
    }
}

- (GMSMarker*)markerForUser:(PFUser*)user
{
    NSDictionary *locObject = user[@"location"];
    if (locObject) {
        GMSMarker *marker = [[GMSMarker alloc] init];
        
        double latitude = [[locObject objectForKey:@"latitude"] doubleValue];
        double longitude = [[locObject objectForKey:@"longitude"] doubleValue];
        double time = [[locObject objectForKey:@"time"] doubleValue];
        
        marker.position = CLLocationCoordinate2DMake(latitude, longitude);
        marker.title = user[@"displayName"];
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setTimeStyle:NSDateFormatterShortStyle];
        [format setDateStyle:NSDateFormatterLongStyle];
        marker.snippet = [format stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
        
        UIImage* image = [UIImage imageWithData:user[@"photo"]];
        marker.icon = [MapController circularScaleAndCropImage:image frame:CGRectMake(0, 0, 60, 60)];
        return marker;
    } else {
        return nil;
    }
}

- (void)refresh
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [_user fetchInBackgroundWithBlock:^(PFObject* user, NSError* error) {
        GMSMarker *peer = [self markerForUser:(PFUser*)user];
        if (peer) {
            [_mapView clear];
            GMSMarker *myMarker = [self markerForUser:[PFUser currentUser]];
            myMarker.map = _mapView;
            peer.map = _mapView;
            
            GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:myMarker.position coordinate:peer.position];
            GMSCameraUpdate *update = [GMSCameraUpdate fitBounds:bounds withPadding:100.];
            [_mapView moveCamera:update];
            
            [[GMSGeocoder geocoder] reverseGeocodeCoordinate:peer.position completionHandler:^(GMSReverseGeocodeResponse *response, NSError *error)
            {
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                GMSAddress *address = response.firstResult;
                if (address) {
                    _titleLabel.text = address.thoroughfare;
                    [self createDirectionFrom:myMarker.position to:peer.position];
                } else {
                    _titleLabel.text = @"";
                }
            }];
        } else {
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        }
    }];
}

- (void)createDirectionFrom:(CLLocationCoordinate2D)from to:(CLLocationCoordinate2D)to
{
    NSString *respStr = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/directions/json?origin=%f,%f&destination=%f,%f&sensor=true", from.latitude, from.longitude, to.latitude, to.longitude];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:respStr] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *jsonData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (jsonData) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
        NSArray *routes = [json objectForKey:@"routes"];
        GMSPath *path = [GMSPath pathFromEncodedPath:routes[0][@"overview_polyline"][@"points"]];
        GMSPolyline *polyline = [GMSPolyline polylineWithPath:path];
        polyline.strokeColor = [UIColor colorWithRed:28./255. green:79./255. blue:130./255. alpha:0.7];
        polyline.strokeWidth = 7.f;
        polyline.map = _mapView;
    } else {
        NSLog(@"%@", error);
    }
}

@end
