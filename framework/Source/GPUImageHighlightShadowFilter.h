#import "GPUImageFilter.h"

@interface GPUImageHighlightShadowFilter : GPUImageFilter
{
    GLint shadowsUniform, highlightsUniform;
}

/**
 * 0 - 1, increase to lighten shadows.
 * @default 0
 */
@property(readwrite, nonatomic) GLfloat shadows;

/**
 * 0 - 1, decrease to darken highlights.
 * @default 1
 */
@property(readwrite, nonatomic) GLfloat highlights;

@end
