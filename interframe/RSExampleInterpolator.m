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

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output {
    if ((self = [super init]))
    {
        self.interpolator = [[RSFrameInterpolator alloc] initWithAsset:asset output:output];
        self.interpolator.delegate = self;
        self.interpolator.compositor = [RSFrameInterpolatorDefaultCompositor class];
    }
    return self;
}

-(void)interpolate {
    [self.interpolator interpolate];
}

-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator {
    NSLog(@"Finished!");
    exit(0);
}

@end
