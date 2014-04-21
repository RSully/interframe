//
//  RSExampleInterpolator.m
//  interframe
//
//  Created by Ryan Sullivan on 4/8/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSExampleInterpolator.h"
#import <Accelerate/Accelerate.h>
#import "RSFrameInterpolatorDefaultCompositor.h"

@interface RSExampleInterpolator ()

@property (nonatomic, strong) RSFrameInterpolator *interpolator;

@end


@implementation RSExampleInterpolator

-(id)initWithInput:(NSURL *)input output:(NSURL *)output {
    if ((self = [super init]))
    {
        self.interpolator = [[RSFrameInterpolator alloc] initWithInput:input output:output];
        self.interpolator.delegate = self;
    }
    return self;
}

-(void)interpolate {
    [self.interpolator interpolateAsynchronously];
}

-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator {
    NSLog(@"Finished!");
    exit(0);
}

-(void)interpolatorFailed:(RSFrameInterpolator *)interpolator withError:(NSError *)error {
    NSLog(@"Failed! %@", error);
    exit(0);
}

@end
