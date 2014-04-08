//
//  RSExampleInterpolator.m
//  interframe
//
//  Created by Ryan Sullivan on 4/8/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSExampleInterpolator.h"

@implementation RSExampleInterpolator

-(id)init {
    if ((self = [super init]))
    {

    }
    return self;
}

-(CGImageRef)createInterpolatedImageForInterpolator:(RSFrameInterpolator *)interpolator
                                          withState:(RSFrameInterpolationState *)state {
    return CGImageCreateCopy(state.priorImage);
}

@end
