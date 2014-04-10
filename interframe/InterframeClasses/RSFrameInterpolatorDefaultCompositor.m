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


            // TODO: get rid of all context/cgimage stuff and work with bytes directly
            {
                // Get images to pass to old interpolation function
                CGImageRef priorImage = [[self class] newCGImageFromPixelBuffer:priorPixelBuffer];
                CGImageRef nextImage = [[self class] newCGImageFromPixelBuffer:nextPixelBuffer];
                CGImageRef inbetweenImage = [[self class] newInterpolatedImageWithPrior:priorImage
                                                                                andNext:nextImage];
                CGImageRelease(priorImage);
                CGImageRelease(nextImage);
                NSLog(@"Got interpolated image");

                // Write to the pixel buffer from the interpolated image
                [[self class] fillPixelBuffer:inbetweenPixelBuffer withCGImage:inbetweenImage];
                CGImageRelease(inbetweenImage);
            }

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



/**
 * Old image interpolator implementation
 *
 * This will be removed eventually
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

    free(dspInput);
    free(dspOutput);

    // return image
    [dest setNeedsUpdate:YES];
    return CGImageRetain(dest.CGImage);
}

/**
 * Create a CGImage from a CVPixelBuffer
 * This may only work on 32BGRA sources
 *
 * Some logic from: http://stackoverflow.com/questions/3305862/uiimage-created-from-cmsamplebufferref-not-displayed-in-uiimageview
 */
+(CGImageRef)newCGImageFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    CGContextRef context = [self newContextFromPixelBuffer:pixelBuffer];

    // Fetch the image
    CGImageRef image = CGBitmapContextCreateImage(context);

    // Cleanup
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    return image;
}
/**
 * Create a CVPixelBuffer from a CGImage
 */
+(void)fillPixelBuffer:(CVPixelBufferRef)pixelBuffer withCGImage:(CGImageRef)image {
    NSLog(@"-fillPixelBuffer:withCGImage:");

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    CGContextRef context = [self newContextFromPixelBuffer:pixelBuffer];

    // Draw the image onto pixelBuffer
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);

    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}
/**
 * Create a context from a given pixel buffer
 * Pixel buffer should be locked before calling
 */
+(CGContextRef)newContextFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    // Get info about image
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

    // Using device RGB - is this best?
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, (kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst));

    // Cleanup
    CGColorSpaceRelease(colorSpace);

    return context;
}


@end
