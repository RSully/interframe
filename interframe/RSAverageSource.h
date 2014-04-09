//
//  RSAverageSource.h
//  interframe
//
//  Created by Alex Nichol on 4/8/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import "ANImageBitmapRep.h"
#import "RSFrameInterpolator.h"

@interface RSAverageSource : NSObject <RSFrameInterpolatorSource> {
    ANImageBitmapRep * dest;
    NSOperationQueue * queue;
    NSInteger threads;
    
    float * input;
    float * output;
}

- (id)initWithThreads:(NSUInteger)count;

@end
