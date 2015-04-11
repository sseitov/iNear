//
//  MapController.m
//  iNear
//
//  Created by Sergey Seitov on 11.04.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "MapController.h"
#import <GoogleMaps/GoogleMaps.h>
#import <Parse/Parse.h>

@interface MapController (){
    GMSMapView *mapView_;
}


@end

@implementation MapController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"On Map";
    
    NSDictionary *locObject = [PFUser currentUser][@"location"];
    if (locObject) {
        double latitude = [[locObject objectForKey:@"latitude"] doubleValue];
        double longitude = [[locObject objectForKey:@"longitude"] doubleValue];
        NSLog(@"%f latitude, %f longitude", latitude, longitude);
        GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:latitude
                                                                longitude:longitude
                                                                     zoom:16];
        mapView_ = [GMSMapView mapWithFrame:CGRectZero camera:camera];
        mapView_.myLocationEnabled = YES;
        self.view = mapView_;

        // Creates a marker in the center of the map.
        GMSMarker *marker = [[GMSMarker alloc] init];
        marker.position = CLLocationCoordinate2DMake(latitude, longitude);
        marker.title = @"Sydney";
        marker.snippet = @"Australia";
        marker.map = mapView_;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:YES animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:NO animated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
