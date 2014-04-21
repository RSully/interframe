//
//  RSFrameInterpolatorDefaultCompositor.m
//  interframe
//
//  Created by Ryan Sullivan on 4/9/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolatorDefaultCompositor.h"
#import <AppKit/AppKit.h>
#import "RSFrameInterpolator.h"
#import "RSIAsynchronousVideoInterpolationRequest.h"

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

-(void)startVideoCompositionRequest:(RSIAsynchronousVideoInterpolationRequest *)asyncVideoCompositionRequest {
    NSLog(@"-startVideoCompositionRequest");

    @autoreleasepool {
        dispatch_async(_renderingQueue, ^{

            NSLog(@"Rendering interpolation frame");

            RSIRenderContext *renderContext = asyncVideoCompositionRequest.renderContext;
            CVPixelBufferRef inbetweenPixelBuffer = [renderContext newPixelBuffer];

            if (!inbetweenPixelBuffer)
            {
                NSLog(@"Didnt get pixel buffer to write to");
                [asyncVideoCompositionRequest finishWithError:[NSError errorWithDomain:@"me.rsullivan.apps.interframe.videoRequest" code:2 userInfo:nil]];
                return;
            }

            CVImageBufferRef priorPixelBuffer = [asyncVideoCompositionRequest sourceFramePrior];
            CVImageBufferRef nextPixelBuffer = [asyncVideoCompositionRequest sourceFrameNext];



            [[self class] fillPixelBuffer:inbetweenPixelBuffer byInterpolatingPrior:priorPixelBuffer andNext:nextPixelBuffer];
            CVBufferSetAttachments(inbetweenPixelBuffer, CVBufferGetAttachments(priorPixelBuffer, kCVAttachmentMode_ShouldPropagate), kCVAttachmentMode_ShouldPropagate);



            // Return the pixel buffer
            [asyncVideoCompositionRequest finishWithComposedVideoFrame:inbetweenPixelBuffer];

            // Cleanup
            CVPixelBufferRelease(inbetweenPixelBuffer);
        });
    }
}

-(void)renderContextChanged:(RSIRenderContext *)newRenderContext {
    NSLog(@"-renderContextChanged");
}

/**
 * Pixel format and options
 *
 * From http://developer.apple.com/library/mac/documentation/AVFoundation/Reference/AVAssetReaderTrackOutput_Class/Reference/Reference.html:
 * > If you need to work in the RGB domain is is recommended that on iOS the kCVPixelFormatType_32BGRA value is used, and on OS X kCVPixelFormatType_32ARGB is recommended
 */

-(NSDictionary *)defaultPixelBufferAttributes {
    return @{
             // kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
             (NSString *)kCVPixelBufferPixelFormatTypeKey: @[@(kCVPixelFormatType_32BGRA)],
//             (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @(YES),
//             (NSString *)kCVPixelBufferCGImageCompatibilityKey: @(YES),
             };
}

-(NSDictionary *)requiredPixelBufferAttributesForRenderContext {
//    NSLog(@"-requiredPixelBufferAttributesForRenderContext");
    return [self defaultPixelBufferAttributes];
}

-(NSDictionary *)sourcePixelBufferAttributes {
//    NSLog(@"-sourcePixelBufferAttributes");
    return [self defaultPixelBufferAttributes];
}


/**
 * Interpolation logic
 */


+(void)fillPixelBuffer:(CVPixelBufferRef)pixelBuffer byInterpolatingPrior:(CVPixelBufferRef)prior andNext:(CVPixelBufferRef)next {

    CVPixelBufferLockBaseAddress(prior, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(next, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    size_t dataSize = CVPixelBufferGetBytesPerRow(prior) * CVPixelBufferGetHeight(prior);
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    void *priorBaseAddress = CVPixelBufferGetBaseAddress(prior);
    void *nextBaseAddress = CVPixelBufferGetBaseAddress(next);


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



    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferUnlockBaseAddress(next, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferUnlockBaseAddress(prior, kCVPixelBufferLock_ReadOnly);
}


@end
