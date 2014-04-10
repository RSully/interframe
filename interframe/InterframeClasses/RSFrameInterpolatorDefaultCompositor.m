//
//  RSFrameInterpolatorDefaultCompositor.m
//  interframe
//
//  Created by Ryan Sullivan on 4/9/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolatorDefaultCompositor.h"
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
        NSLog(@"-init compositor");
        _renderingQueue = dispatch_queue_create("me.rsullivan.apps.interframe.renderingQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

-(void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)asyncVideoCompositionRequest {
    NSLog(@"-startVideoCompositionRequest");

    @autoreleasepool {
        dispatch_async(_renderingQueue, ^{
            RSFrameInterpolatorInterpolationInstruction *currentInstruction = (RSFrameInterpolatorInterpolationInstruction *)asyncVideoCompositionRequest.videoCompositionInstruction;
            if (![currentInstruction isKindOfClass:[RSFrameInterpolatorInterpolationInstruction class]])
            {
                NSLog(@"Failed compositor because non-interpolation");
                [asyncVideoCompositionRequest finishWithError:[NSError errorWithDomain:@"me.rsullivan.apps.interframe" code:1 userInfo:nil]];
                return;
            }

            NSLog(@"Rendering interpolation frame");

            AVVideoCompositionRenderContext *renderContext = asyncVideoCompositionRequest.renderContext;
            CVPixelBufferRef inbetweenPixelBuffer = [renderContext newPixelBuffer];
            if (!inbetweenPixelBuffer)
            {
                NSLog(@"Didnt get pixel buffer to write to");
                [asyncVideoCompositionRequest finishWithError:[NSError errorWithDomain:@"com.rsullivan.apps.interframe" code:2 userInfo:nil]];
                return;
            }
            CVImageBufferRef priorPixelBuffer = [asyncVideoCompositionRequest sourceFrameByTrackID:currentInstruction.priorID];
            CVImageBufferRef nextPixelBuffer = [asyncVideoCompositionRequest sourceFrameByTrackID:currentInstruction.nextID];


            [[self class] fillPixelBuffer:inbetweenPixelBuffer byInterpolatingPrior:priorPixelBuffer andNext:nextPixelBuffer];


            NSLog(@"going to finish frame");
            // Return the pixel buffer
//            [asyncVideoCompositionRequest finishWithComposedVideoFrame:priorPixelBuffer];
            [asyncVideoCompositionRequest finishWithComposedVideoFrame:inbetweenPixelBuffer];
            NSLog(@"finished frame");

            // Cleanup
            CVPixelBufferRelease(inbetweenPixelBuffer);
        });
    }
}

-(void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {
    NSLog(@"-renderContextChanged");
    // Umm.
}

/**
 * Pixel format and options
 */

-(NSDictionary *)defaultPixelBufferAttributes {
    return @{
             (NSString *)kCVPixelBufferPixelFormatTypeKey: @[@(kCVPixelFormatType_32BGRA)],
//             (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @(YES),
//             (NSString *)kCVPixelBufferCGImageCompatibilityKey: @(YES),
             };
}

-(NSDictionary *)requiredPixelBufferAttributesForRenderContext {
    NSLog(@"-requiredPixelBufferAttributesForRenderContext");
    return [self defaultPixelBufferAttributes];
}

-(NSDictionary *)sourcePixelBufferAttributes {
    NSLog(@"-sourcePixelBufferAttributes");
    return [self defaultPixelBufferAttributes];
}


/**
 * Interpolation logic
 */


+(void)fillPixelBuffer:(CVPixelBufferRef)pixelBuffer byInterpolatingPrior:(CVPixelBufferRef)prior andNext:(CVPixelBufferRef)next {
    NSLog(@"-fillPixelBuffer:byInterpolatingPrior:andNext:");

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CVPixelBufferLockBaseAddress(prior, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(next, kCVPixelBufferLock_ReadOnly);

    size_t dataSize = CVPixelBufferGetBytesPerRow(prior) * CVPixelBufferGetHeight(prior);
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    void *priorBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    void *nextBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);


    float *dspInput = malloc(sizeof(float) * (2 * dataSize));
    float *dspOutput = malloc(sizeof(float) * (dataSize));

    // cast data
    vDSP_vfltu8(priorBaseAddress, 1, dspInput, 1, dataSize);
    vDSP_vfltu8(nextBaseAddress, 1, &dspInput[dataSize], 1, dataSize);

    // compute averages
    float leftMatrix[] = {0.5f, 0.5f};
    vDSP_mmul(leftMatrix, 1, dspInput, 1, dspOutput, 1, 1, dataSize, 2);
    vDSP_vfixu8(dspOutput, 1, baseAddress, 1, dataSize);

    free(dspInput);
    free(dspOutput);



    NSLog(@"PRIOR width: %zu, height: %zu, bpr: %zu", CVPixelBufferGetWidth(prior), CVPixelBufferGetHeight(prior), CVPixelBufferGetBytesPerRow(prior));
    NSLog(@"PRIOR dataSize: %zu, actual size: %zu", dataSize, CVPixelBufferGetDataSize(prior));
    NSLog(@"DEST width: %zu, height: %zu, bpr: %zu", CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), CVPixelBufferGetBytesPerRow(pixelBuffer));
    NSLog(@"DEST dataSize: %zu, actual size: %zu", dataSize, CVPixelBufferGetDataSize(pixelBuffer));


    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferUnlockBaseAddress(prior, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferUnlockBaseAddress(next, kCVPixelBufferLock_ReadOnly);
}


@end
