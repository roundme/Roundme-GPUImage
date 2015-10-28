//
//  GPUImageSupport.h
//  Pods
//
//  Created by Илья Гречухин on 04.09.14.
//
//

#import <Foundation/Foundation.h>

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#define GPUImageRotationSwapsWidthAndHeight(rotation) ((rotation) == kGPUImageRotateLeft || (rotation) == kGPUImageRotateRight || (rotation) == kGPUImageRotateRightFlipVertical || (rotation) == kGPUImageRotateRightFlipHorizontal || (rotation) == kGPUImageRotateLeftFlipHorizontal)

typedef NS_ENUM(NSUInteger, GPUImageRotationMode) {
    kGPUImageNoRotation,
    kGPUImageRotateLeft,
    kGPUImageRotateRight,
    kGPUImageFlipVertical,
    kGPUImageFlipHorizonal,
    kGPUImageRotateRightFlipVertical,
    kGPUImageRotateRightFlipHorizontal,
    kGPUImageRotateLeftFlipHorizontal,
    kGPUImageRotate180
};

typedef struct {
    GLfloat x;
    GLfloat y;
    GLfloat z;
    GLfloat u;
    GLfloat v;
} Vertex3D;

typedef struct {
    GLfloat x;
    GLfloat y;
    GLfloat u;
    GLfloat v;
} Vertex2D;

typedef struct {
    GLfloat one;
    GLfloat two;
    GLfloat three;
    GLfloat four;
} GPUVector4;

typedef struct GPUVector3 {
    GLfloat one;
    GLfloat two;
    GLfloat three;
} GPUVector3;

typedef struct GPUMatrix4x4 {
    GPUVector4 one;
    GPUVector4 two;
    GPUVector4 three;
    GPUVector4 four;
} GPUMatrix4x4;

typedef struct GPUMatrix3x3 {
    GPUVector3 one;
    GPUVector3 two;
    GPUVector3 three;
} GPUMatrix3x3;

Vertex2D *verticesAndTextureCoordinatesForRotation(GPUImageRotationMode rotation);
Vertex2D *verticesAndTextureCoordinatesForRotationWithScale(GPUImageRotationMode rotation, GLfloat widthScaling, GLfloat heightScaling);

void bufferVerticesAndTextureCoordinatesForMultipleRotations(NSArray *rotations);

CGSize rotatedSize(CGSize sizeToRotate, GPUImageRotationMode rotation);
CGPoint rotatedPoint(CGPoint pointToRotate, GPUImageRotationMode rotation);
