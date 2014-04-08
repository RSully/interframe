//
//  RSFrameInterpolationState.m
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolationState.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation RSFrameInterpolationState

-(id)initWithPriorImage:(CGImageRef)priorImage
              nextImage:(CGImageRef)nextImage
                  frame:(NSUInteger)frame
             frameCount:(NSUInteger)frameCount {
    if ((self = [self init]))
    {
        _nextImage = CGImageRetain(nextImage);
        _priorImage = CGImageRetain(priorImage);
        _frame = frame;
        _frameCount = frameCount;
    }
    return self;
}

-(void)dealloc {
    CGImageRelease(_nextImage);
    CGImageRelease(_priorImage);
}

@end
