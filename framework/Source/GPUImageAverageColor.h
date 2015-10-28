#import "GPUImageFilter.h"

extern NSString *const kGPUImageColorAveragingVertexShaderString;

@interface GPUImageAverageColor : GPUImageFilter
{
    GLint texelWidthUniform, texelHeightUniform;
    
    NSUInteger numberOfStages;
    
    GLubyte *rawImagePixels;
    CGSize finalStageSize;
}

// This block is called on the completion of color averaging for a frame
@property(nonatomic, copy) void(^colorAverageProcessingFinishedBlock)(GLfloat redComponent, GLfloat greenComponent, GLfloat blueComponent, GLfloat alphaComponent, CMTime frameTime);

- (void)extractAverageColorAtFrameTime:(CMTime)frameTime;

@end
