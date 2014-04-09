//
//  RSFrameInterpolatorDefaultCompositor.m
//  interframe
//
//  Created by Ryan Sullivan on 4/9/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolatorDefaultCompositor.h"
#import "ANImageBitmapRep.h"
#import "RSFrameInterpolatorInterpolationInstruction.h"
#import "RSFrameInterpolatorPassthroughInstruction.h"

@interface RSFrameInterpolatorDefaultCompositor () {
    dispatch_queue_t _renderingQueue;
}
@end

@implementation RSFrameInterpolatorDefaultCompositor

-(id)init {
    if ((self = [super init]))
    {
        _renderingQueue = dispatch_queue_create("me.rsullivan.apps.interframe.renderingQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

-(void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)asyncVideoCompositionRequest {
    @autoreleasepool {
        dispatch_async(_renderingQueue, ^{
            id currentInstruction = asyncVideoCompositionRequest.videoCompositionInstruction;
            if (![currentInstruction isKindOfClass:[RSFrameInterpolatorInterpolationInstruction class]])
            {
                [asyncVideoCompositionRequest finishWithError:[NSError errorWithDomain:@"me.rsullivan.apps.interframe" code:0 userInfo:nil]];
                return;
            }

            NSLog(@"Rendering interpolation frame");

            AVVideoCompositionRenderContext *renderContext = asyncVideoCompositionRequest.renderContext;
            CVPixelBufferRef inbetweenPixelBuffer = [renderContext newPixelBuffer];


            // TODO
            [asyncVideoCompositionRequest finishWithError:[NSError errorWithDomain:@"me.rsullivan.apps.interframe" code:1 userInfo:nil]];


            // Cleanup
            CVPixelBufferRelease(inbetweenPixelBuffer);
        });
    }
}

-(void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {
    // Umm.
}

/**
 * Pixel format and options
 */

-(NSDictionary *)requiredPixelBufferAttributesForRenderContext {
    return @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @[@(kCVPixelFormatType_32BGRA)]
    };
}

-(NSDictionary *)sourcePixelBufferAttributes {
    return self.requiredPixelBufferAttributesForRenderContext;
}

/**
 * Old image interpolator implementation
 */

+(CGImageRef)newInterpolatedImageWithPrior:(CGImageRef)priorImage andNext:(CGImageRef)nextImage {
    NSLog(@"-newInterpolatedImage");

    ANImageBitmapRep *prior = [[ANImageBitmapRep alloc] initWithCGImage:priorImage];
    ANImageBitmapRep *next = [[ANImageBitmapRep alloc] initWithCGImage:nextImage];

    BMPoint dims = prior.bitmapSize;
    ANImageBitmapRep *dest = [[ANImageBitmapRep alloc] initWithSize:dims];

    float *dspInput = malloc(sizeof(float) * (4 * 2 * dims.x * dims.y));
    float *dspOutput = malloc(sizeof(float) * (4 * dims.x * dims.y));

    NSUInteger sampleCount = 4 * dest.bitmapSize.x * dest.bitmapSize.y;

    // cast data
    vDSP_vfltu8(prior.bitmapData, 1, dspInput, 1, sampleCount);
    vDSP_vfltu8(next.bitmapData, 1, &dspInput[sampleCount], 1, sampleCount);

    // compute averages
    float leftMatrix[] = {0.5f, 0.5f};
    vDSP_mmul(leftMatrix, 1, dspInput, 1, dspOutput, 1, 1, sampleCount, 2);
    vDSP_vfixu8(dspOutput, 1, dest.bitmapData, 1, sampleCount);

    // return image
    [dest setNeedsUpdate:YES];
    return CGImageRetain(dest.CGImage);
}

@end
