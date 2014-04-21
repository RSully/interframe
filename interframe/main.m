//
//  main.m
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSExampleInterpolator.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {

        if (argc != 3)
        {
            printf("Usage: %s <input> <output>\n", argv[0]);
            return 0;
        }

        NSURL *inputUrl = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSURL *outputUrl = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[2]]];

        [[NSFileManager defaultManager] removeItemAtURL:outputUrl error:nil];

        RSExampleInterpolator *example = [[RSExampleInterpolator alloc] initWithInput:inputUrl output:outputUrl];
        [example interpolate];

        [[NSRunLoop currentRunLoop] run];

    }
    return 0;
}

