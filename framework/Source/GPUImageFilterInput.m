//
//  GPUImageFilterInput.m
//  GPUImage
//
//  Created by Илья Гречухин on 17.09.14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import "GPUImageFilterInput.h"
#import "GPUImageSupport.h"

@implementation GPUImageFilterInput

- (instancetype)init {
    if ((self = [super init])) {
        self.framebuffer = nil;
        self.vertexbuffer = 0;
        self.indexbuffer = 0;

        self.receivedFlag = FREE;
        self.textureCoordinateAttribute = 0;
        self.textureUniform = 0;

        self.rotation = kGPUImageNoRotation;
        self.size = CGSizeZero;
    }
    return self;
}

@end
