//
//  RSUpconverter.m
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolator.h"
#import "RSFrameInterpolatorDefaultCompositor.h"
#import "RSITrackHandlerPassthrough.h"
#import "RSITrackHandlerInterpolate.h"

//#define kRSDurationResolution 300
#define kRSDurationResolution NSEC_PER_SEC
//#define kRSDurationResolution 240


@interface RSFrameInterpolator ()

/*
 * Given/init vars
 */

@property (strong) AVAsset *inputAsset;
@property (strong) NSURL *outputUrl;

@end


@implementation RSFrameInterpolator

-(id)initWithAsset:(AVAsset *)asset {
    if ((self = [self init]))
    {
        self.inputAsset = asset;
    }
    return self;
}



-(void)interpolateToOutput:(NSURL *)output {

    /*
     * General variables
     */

    NSError *err = nil;

    AVAsset *inputAsset = self.inputAsset;
    NSArray *interpolationTrackIDs = @[@([[inputAsset tracksWithMediaType:AVMediaTypeVideo][0] trackID])];


    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:inputAsset error:&err];
    if (err)
    {
        [self.delegate interpolatorFailed:self withError:nil];
        return;
    }

    NSString *outputFileType = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)([output pathExtension]), NULL));
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:output fileType:outputFileType error:&err];
    if (err)
    {
        [self.delegate interpolatorFailed:self withError:nil];
        return;
    }


    NSMutableArray *trackHandlers = [NSMutableArray new];

    for (AVAssetTrack *inputTrack in inputAsset.tracks)
    {
        BOOL isInterpolationTrack = [interpolationTrackIDs containsObject:@(inputTrack.trackID)];
        RSITrackHandler *trackHandler = nil;

        if (isInterpolationTrack)
        {
            id<AVVideoCompositing> compositor = [self newCompositor];

            trackHandler = [[RSITrackHandlerInterpolate alloc] initWithInputTrack:inputTrack compositor:compositor];
        }
        else
        {
            trackHandler = [[RSITrackHandlerPassthrough alloc] initWithInputTrack:inputTrack];
        }


        // Check for adding problems
        if (![reader canAddOutput:trackHandler.readerOutput])
        {
            NSLog(@"Cannot add output to reader: %@", trackHandler.readerOutput);
        }
        if (![writer canAddInput:trackHandler.writerInput])
        {
            NSLog(@"Cannot add input to writer: %@", trackHandler.writerInput);
        }

        // Add ins/outs
        [reader addOutput:trackHandler.readerOutput];
        [writer addInput:trackHandler.writerInput];


        [trackHandlers addObject:trackHandler];
    }

    if (![reader startReading])
    {
        NSLog(@"Cannot start reading");
    }

    for (RSITrackHandler *trackHandler in trackHandlers)
    {
        // TODO
    }



    

//    NSMutableDictionary *compositorInputSettings = [[compositor requiredPixelBufferAttributesForRenderContext] mutableCopy];
//    compositorInputSettings[(NSString *)kCVPixelBufferWidthKey] = @(inputTrack.naturalSize.width);
//    compositorInputSettings[(NSString *)kCVPixelBufferHeightKey] = @(inputTrack.naturalSize.height);
//    AVAssetWriterInputPixelBufferAdaptor *writerInputAdapter = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:writerInput sourcePixelBufferAttributes:compositorInputSettings];

    /*
     * Setup compositor and render context
     *
     * When does this happen??
     */

    /*
     * Have to reimplement basics of:
     * - AVVideoCompositionRenderContext
     *   - Use AVAssetWriterInputPixelBufferAdaptor?
     *   - I don't know, use here or there?
     * - AVAsynchronousVideoCompositionRequest
     *   - Wait until look into sample buffers and isReady stuff
     */


    /*
     * Magic
     */

    if (![reader startReading])
    {
        [self.delegate interpolatorFailed:self withError:nil];
        return;
    }

//    CMSampleBufferRef sampleBuffer;
//
//    while ((sampleBuffer = [readerOutput copyNextSampleBuffer]))
//    {
//        CMItemCount samplesNum = CMSampleBufferGetNumSamples(sampleBuffer);
//        NSLog(@"GOT SAMPLEZ: %ld", samplesNum);
//    }


    [self.delegate interpolatorFinished:self];

}

#pragma mark Methods used for -interpolateToOutput:

-(id<AVVideoCompositing>)newCompositor {
    Class compositorClass = self.customCompositor;
    if (!compositorClass)
    {
        compositorClass = [RSFrameInterpolatorDefaultCompositor class];
    }
    return [compositorClass new];
}

@end
