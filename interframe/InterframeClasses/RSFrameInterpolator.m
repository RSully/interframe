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
#import "RSIAsynchronousVideoInterpolationRequest.h"

//#define kRSDurationResolution 300
#define kRSDurationResolution NSEC_PER_SEC
//#define kRSDurationResolution 240


@interface RSFrameInterpolator ()

/*
 * Given/init vars
 */
@property (strong) AVAsset *inputAsset;
@property (strong) NSURL *outputUrl;

@property (strong) dispatch_queue_t interpolationQueue;

@end


@implementation RSFrameInterpolator

-(id)init
{
    if ((self = [super init]))
    {
        self.interpolationQueue = dispatch_queue_create("me.rsullivan.apps.interframe.interpolationQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

-(id)initWithInput:(NSURL *)input output:(NSURL *)output {
    if ((self = [self init]))
    {
        self.inputAsset = [[AVURLAsset alloc] initWithURL:input options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @(YES)}];
        self.outputUrl = output;
    }
    return self;
}



-(void)interpolateAsynchronously {
    dispatch_async(self.interpolationQueue, ^{
        [self _interpolate];
    });
}
-(void)_interpolate {

    /*
     * General variables
     */

    NSError *err = nil;

    AVAsset *inputAsset = self.inputAsset;
    NSURL *output = self.outputUrl;
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
            id<RSIInterpolationCompositing> compositor = [self newCompositor];

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
        return;
    }
    if (![writer startWriting])
    {
        NSLog(@"Cannot start writing");
        return;
    }

    [writer startSessionAtSourceTime:kCMTimeZero];


    dispatch_group_t trackHandlerGroup = dispatch_group_create();

    for (RSITrackHandler *trackHandler in trackHandlers)
    {
        dispatch_group_enter(trackHandlerGroup);

        [trackHandler startHandlingWithCompletionHandler:^{
            dispatch_group_leave(trackHandlerGroup);
        }];
    }


    dispatch_group_wait(trackHandlerGroup, DISPATCH_TIME_FOREVER);

    [writer finishWritingWithCompletionHandler:^{
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"-finishWritingWithCompletionHandler %ld", writer.status);
            [self.delegate interpolatorFinished:self];
        });
    }];

}

#pragma mark Methods used for -interpolateToOutput:

-(id<RSIInterpolationCompositing>)newCompositor {
    Class compositorClass = self.customCompositor;
    if (!compositorClass)
    {
        compositorClass = [RSFrameInterpolatorDefaultCompositor class];
    }
    return [compositorClass new];
}

@end
