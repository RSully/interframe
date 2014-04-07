//
//  RSFrameInterpolationState.h
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSFrameInterpolationState : NSObject

/**
 * The image of the previous frame
 */
@property (readonly) CGImageRef priorImage;
/**
 The image of the next frame
 */
@property (readonly) CGImageRef nextImage;

/**
 * The frame number this state is interpolating for
 */
@property (readonly) NSUInteger frame;
/**
 * The total number of frames expected in the final output
 */
@property (readonly) NSUInteger frameCount;

/**
 * The only way to initialize
 */
-(id)initWithPriorImage:(CGImageRef)priorImage
              nextImage:(CGImageRef)nextImage
                  frame:(NSUInteger)frame
             frameCount:(NSUInteger)frameCount;

@end
