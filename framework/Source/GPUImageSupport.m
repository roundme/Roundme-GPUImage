//
//  GPUImageSupport.m
//  Pods
//
//  Created by Илья Гречухин on 04.09.14.
//
//

#import "GPUImageSupport.h"

static const GLfloat noRotationTextureCoordinates[] = {
    0.0, 0.0,
    1.0, 0.0,
    0.0, 1.0,
    1.0, 1.0
};

static const GLfloat rotateLeftTextureCoordinates[] = {
    1.0, 0.0,
    1.0, 1.0,
    0.0, 0.0,
    0.0, 1.0
};

static const GLfloat rotateRightTextureCoordinates[] = {
    0.0, 1.0,
    0.0, 0.0,
    1.0, 1.0,
    1.0, 0.0
};

static const GLfloat verticalFlipTextureCoordinates[] = {
    0.0, 1.0,
    1.0, 1.0,
    0.0, 0.0,
    1.0, 0.0
};

static const GLfloat horizontalFlipTextureCoordinates[] = {
    1.0, 0.0,
    0.0, 0.0,
    1.0, 1.0,
    0.0, 1.0
};

static const GLfloat rotateRightVerticalFlipTextureCoordinates[] = {
    0.0, 0.0,
    0.0, 1.0,
    1.0, 0.0,
    1.0, 1.0
};

static const GLfloat rotateRightHorizontalFlipTextureCoordinates[] = {
    1.0, 1.0,
    1.0, 0.0,
    0.0, 1.0,
    0.0, 0.0
};

static const GLfloat rotateLeftHorizontalFlipTextureCoordinates[] = {
    1.0, 1.0,
    1.0, 0.0,
    0.0, 1.0,
    0.0, 0.0
};

static const GLfloat rotate180TextureCoordinates[] = {
    1.0, 1.0,
    0.0, 1.0,
    1.0, 0.0,
    0.0, 0.0
};

static Vertex2D verticesAndTextureCoordinates[4];

const GLfloat *textureCoordinatesForRotation(GPUImageRotationMode rotation) {
    switch (rotation) {
        case kGPUImageNoRotation:                   return noRotationTextureCoordinates;
        case kGPUImageRotateLeft:                   return rotateLeftTextureCoordinates;
        case kGPUImageRotateRight:                  return rotateRightTextureCoordinates;
        case kGPUImageFlipVertical:                 return verticalFlipTextureCoordinates;
        case kGPUImageFlipHorizonal:                return horizontalFlipTextureCoordinates;
        case kGPUImageRotateRightFlipVertical:      return rotateRightVerticalFlipTextureCoordinates;
        case kGPUImageRotateRightFlipHorizontal:    return rotateRightHorizontalFlipTextureCoordinates;
        case kGPUImageRotateLeftFlipHorizontal:     return rotateLeftHorizontalFlipTextureCoordinates;
        case kGPUImageRotate180:                    return rotate180TextureCoordinates;
    }
}

Vertex2D *verticesAndTextureCoordinatesForRotation(GPUImageRotationMode rotation) {
    return verticesAndTextureCoordinatesForRotationWithScale(rotation, 1.0, 1.0);
}

Vertex2D *verticesAndTextureCoordinatesForRotationWithScale(GPUImageRotationMode rotation, GLfloat widthScaling, GLfloat heightScaling) {
    GLfloat imageVertices[] = {
        -widthScaling, -heightScaling,  //    -1.0, -1.0,
         widthScaling, -heightScaling,  //     1.0, -1.0,
        -widthScaling,  heightScaling,  //    -1.0,  1.0,
         widthScaling,  heightScaling   //     1.0,  1.0
    };
    const GLfloat *textureCoordinates = textureCoordinatesForRotation(rotation);

    for (NSUInteger i = 0, j = 0; j < 4; i += 2, j++) {
        Vertex2D vx = {
            .x = imageVertices[i],
            .y = imageVertices[i + 1],
            .u = textureCoordinates[i],
            .v = textureCoordinates[i + 1]
        };
        verticesAndTextureCoordinates[j] = vx;
    }

    return verticesAndTextureCoordinates;
}

void bufferVerticesAndTextureCoordinatesForMultipleRotations(NSArray *rotations) {
    GLfloat imageVertices[] = {
        -1.0, -1.0,
         1.0, -1.0,
        -1.0,  1.0,
         1.0,  1.0
    };

    NSUInteger count = [rotations count];

    GLsizeiptr dataSize = 8 * (count + 1) * sizeof(GLfloat);
    GLfloat *data = malloc(dataSize);

    GLfloat *dPtr = data;
    for (NSUInteger i = 0, j = 0; j < 4; i += 2, j++) {
        *dPtr++ = imageVertices[i];
        *dPtr++ = imageVertices[i + 1];
        for (NSUInteger rot = 0; rot < count; rot++) {
            const GLfloat *texCoord = textureCoordinatesForRotation([rotations[rot] unsignedIntegerValue]);
            *dPtr++ = texCoord[i];
            *dPtr++ = texCoord[i + 1];
        }
    }

    glBufferData(GL_ARRAY_BUFFER, dataSize, data, GL_STATIC_DRAW);
    free(data);
}

CGSize rotatedSize(CGSize sizeToRotate, GPUImageRotationMode rotation) {
    CGSize rotatedSize = sizeToRotate;

    if (GPUImageRotationSwapsWidthAndHeight(rotation)) {
        rotatedSize.width = sizeToRotate.height;
        rotatedSize.height = sizeToRotate.width;
    }

    return rotatedSize;
}

CGPoint rotatedPoint(CGPoint pointToRotate, GPUImageRotationMode rotation) {
    CGPoint rotatedPoint;
    switch(rotation) {
        case kGPUImageNoRotation: return pointToRotate; break;
        case kGPUImageFlipHorizonal: {
            rotatedPoint.x = 1.0 - pointToRotate.x;
            rotatedPoint.y = pointToRotate.y;
        }
            break;
        case kGPUImageFlipVertical: {
            rotatedPoint.x = pointToRotate.x;
            rotatedPoint.y = 1.0 - pointToRotate.y;
        }
            break;
        case kGPUImageRotateLeft: {
            rotatedPoint.x = 1.0 - pointToRotate.y;
            rotatedPoint.y = pointToRotate.x;
        }
            break;
        case kGPUImageRotateRight: {
            rotatedPoint.x = pointToRotate.y;
            rotatedPoint.y = 1.0 - pointToRotate.x;
        }
            break;
        case kGPUImageRotateRightFlipVertical: {
            rotatedPoint.x = pointToRotate.y;
            rotatedPoint.y = pointToRotate.x;
        }
            break;
        case kGPUImageRotateRightFlipHorizontal: {
            rotatedPoint.x = 1.0 - pointToRotate.y;
            rotatedPoint.y = 1.0 - pointToRotate.x;
        }
            break;
        case kGPUImageRotateLeftFlipHorizontal: {
            rotatedPoint.x = pointToRotate.y;
            rotatedPoint.y = pointToRotate.x;
        }
            break;
        case kGPUImageRotate180: {
            rotatedPoint.x = 1.0 - pointToRotate.x;
            rotatedPoint.y = 1.0 - pointToRotate.y;
        }
            break;
    }

    return rotatedPoint;
}
