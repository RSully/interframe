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
                [asyncVideoCompositionRequest finishWithError:[NSError errorWithDomain:@"me.rsullivan.apps.interframe" code:0 userInfo:nil]];
                return;
            }

            NSLog(@"Rendering interpolation frame");

            AVVideoCompositionRenderContext *renderContext = asyncVideoCompositionRequest.renderContext;
            CVPixelBufferRef inbetweenPixelBuffer = [renderContext newPixelBuffer];


            // TODO: get rid of all context/cgimage stuff and work with bytes directly
            CVImageBufferRef priorPixelBuffer = [asyncVideoCompositionRequest sourceFrameByTrackID:currentInstruction.priorID];
            CVImageBufferRef nextPixelBuffer = [asyncVideoCompositionRequest sourceFrameByTrackID:currentInstruction.nextID];
            CGImageRef priorImage = [[self class] newCGImageFromPixelBuffer:priorPixelBuffer];
            CGImageRef nextImage = [[self class] newCGImageFromPixelBuffer:nextPixelBuffer];
            CGImageRef inbetweenImage = [[self class] newInterpolatedImageWithPrior:priorImage
                                                                            andNext:nextImage];
            CGImageRelease(priorImage);
            CGImageRelease(nextImage);

            // Handles locks internally:
            [[self class] fillPixelBuffer:inbetweenPixelBuffer withCGImage:inbetweenImage];
            CGImageRelease(inbetweenImage);


            [asyncVideoCompositionRequest finishWithComposedVideoFrame:inbetweenPixelBuffer];

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

-(NSDictionary *)requiredPixelBufferAttributesForRenderContext {
    NSLog(@"-requiredPixelBufferAttributesForRenderContext");
    return @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @[@(kCVPixelFormatType_32BGRA)]
    };
}

-(NSDictionary *)sourcePixelBufferAttributes {
    NSLog(@"-sourcePixelBufferAttributes");
    return @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @[@(kCVPixelFormatType_32BGRA)]
    };
}



/**
 * Old image interpolator implementation
 *
 * This will be removed eventually
 */

#define kRSFIBitmapInfo (kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst)
#define kRSFIPixelFormatType kCVPixelFormatType_32BGRA


+(CGImageRef)newInterpolatedImageWithPrior:(CGImageRef)priorImage andNext:(CGImageRef)nextImage {
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
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    CGContextRef context = [self newContextFromPixelBuffer:pixelBuffer];

    // Fetch the image
    CGImageRef image = CGBitmapContextCreateImage(context);

    // Cleanup
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return image;
}
/**
 * Create a CVPixelBuffer from a CGImage
 */
+(void)fillPixelBuffer:(CVPixelBufferRef)pixelBuffer withCGImage:(CGImageRef)image {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    CGContextRef context = [self newContextFromPixelBuffer:pixelBuffer];

    // Draw the image onto pixelBuffer
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);

    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}
/**
 * Create a context from a given pixel buffer
 */
+(CGContextRef)newContextFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    // Get info about image
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

    // Using device RGB - is this best?
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kRSFIBitmapInfo);

    // Cleanup
    CGColorSpaceRelease(colorSpace);

    return context;
}


@end
