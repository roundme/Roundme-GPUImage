//
//  GPUImageFilterInput.h
//  GPUImage
//
//  Created by Илья Гречухин on 17.09.14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import "GPUImageOutput.h"

typedef NS_ENUM(NSInteger, BufferState) {
    FREE,
    RESERVED,
    SET
};

@interface GPUImageFilterInput : NSObject

@property (nonatomic, strong) GPUImageFramebuffer *framebuffer;
@property (nonatomic, assign) GLuint vertexbuffer;
@property (nonatomic, assign) GLuint indexbuffer;

@property (nonatomic, assign) BufferState receivedFlag;
@property (nonatomic, assign) GLuint textureCoordinateAttribute;
@property (nonatomic, assign) GLuint textureUniform;

@property (nonatomic, assign) GPUImageRotationMode rotation;
@property (nonatomic, assign) CGSize size;

@end
