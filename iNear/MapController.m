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
    GMSMarker *_myPosition;
    GMSMarker *_peerPosition;
}

@property (strong, nonatomic) UILabel* titleLabel;
@property (strong, nonatomic) UILabel* geoInfo;
@property (strong, nonatomic) UIBarButtonItem *infoItem;

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
    [format setDateStyle:NSDateFormatterLongStyle];
    return [format stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
}

+ (UILabel*)createLabel
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 44)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.text = @"";
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor whiteColor];
    label.numberOfLines = 0;
    label.font = [UIFont fontWithName:@"HelveticaNeue" size:14];
    return label;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                           target:self
                                                                                           action:@selector(refresh)];
    _titleLabel = [MapController createLabel];
    self.navigationItem.titleView = _titleLabel;
    
    _geoInfo = [MapController createLabel];
    _infoItem = [[UIBarButtonItem alloc] initWithCustomView:_geoInfo];
    self.toolbarItems = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                          _infoItem,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
    NSDictionary *locObject = _user[@"location"];
    if (locObject) {
        double time = [[locObject objectForKey:@"time"] doubleValue];
        _titleLabel.text = [MapController stringTime:time];

        double latitude = [[locObject objectForKey:@"latitude"] doubleValue];
        double longitude = [[locObject objectForKey:@"longitude"] doubleValue];

        GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:latitude longitude:longitude zoom:16];
        _mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
        _mapView.myLocationEnabled = NO;
        self.view = _mapView;

        _peerPosition = [[GMSMarker alloc] init];
        _peerPosition.position = CLLocationCoordinate2DMake(latitude, longitude);
        _peerPosition.title = _user[@"displayName"];
        UIImage* image = [UIImage imageWithData:_user[@"photo"]];
        _peerPosition.icon = [MapController circularScaleAndCropImage:image frame:CGRectMake(0, 0, 60, 60)];
        _peerPosition.map = _mapView;
    } else {
        _mapView = nil;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _infoItem.width = self.view.frame.size.width;
}

- (void)viewWillAppear:(BOOL)animated
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

- (void)refresh
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [_user fetchInBackgroundWithBlock:^(PFObject* user, NSError* error) {
        NSDictionary *locObject = user[@"location"];
        if (locObject) {
            [_mapView clear];
            
            double time = [[locObject objectForKey:@"time"] doubleValue];
            _titleLabel.text = [MapController stringTime:time];
            _peerPosition.position = CLLocationCoordinate2DMake([[locObject objectForKey:@"latitude"] doubleValue],
                                                                [[locObject objectForKey:@"longitude"] doubleValue]);
            
            NSDictionary *myLocation = [PFUser currentUser][@"location"];
            _myPosition = [[GMSMarker alloc] init];
            _myPosition.position = CLLocationCoordinate2DMake([[myLocation objectForKey:@"latitude"] doubleValue],
                                                              [[myLocation objectForKey:@"longitude"] doubleValue]);
            _myPosition.title = [PFUser currentUser][@"displayName"];
            UIImage* image = [UIImage imageWithData:[PFUser currentUser][@"photo"]];
            _myPosition.icon = [MapController circularScaleAndCropImage:image frame:CGRectMake(0, 0, 60, 60)];
            
            _peerPosition.map = _mapView;
            _myPosition.map = _mapView;

            GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:_peerPosition.position
                                                                               coordinate:_myPosition.position];
            GMSCameraUpdate *update = [GMSCameraUpdate fitBounds:bounds withPadding:50.0f];
            [_mapView moveCamera:update];
            
            [self geocode:_peerPosition.position result:^(NSString *info) {
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                if (info) {
                    _geoInfo.text = info;
                } else {
                    _geoInfo.text = @"";
                }
                [self createDirectionFrom:_myPosition.position to:_peerPosition.position];
            }];
        } else {
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        }
    }];
}

- (void)geocode:(CLLocationCoordinate2D)location result:(void (^)(NSString* info))result
{
    [[GMSGeocoder geocoder] reverseGeocodeCoordinate:location completionHandler:^(GMSReverseGeocodeResponse *response, NSError *error) {
        GMSAddress *address = response.firstResult;
        if (address) {
            result(address.thoroughfare);
        } else {
            result(nil);
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
