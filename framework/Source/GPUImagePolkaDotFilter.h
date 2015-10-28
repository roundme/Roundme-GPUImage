#import "GPUImagePixellateFilter.h"

@interface GPUImagePolkaDotFilter : GPUImagePixellateFilter
{
    GLint dotScalingUniform;
}

@property(readwrite, nonatomic) GLfloat dotScaling;

@end
