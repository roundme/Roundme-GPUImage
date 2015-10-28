#import "GPUImageCannyEdgeDetectionFilter.h"

#import "GPUImageGrayscaleFilter.h"
#import "GPUImageDirectionalSobelEdgeDetectionFilter.h"
#import "GPUImageDirectionalNonMaximumSuppressionFilter.h"
#import "GPUImageWeakPixelInclusionFilter.h"
#import "GPUImageSingleComponentGaussianBlurFilter.h"

@implementation GPUImageCannyEdgeDetectionFilter

@synthesize upperThreshold;
@synthesize lowerThreshold;
@synthesize blurRadiusInPixels;
@synthesize blurTexelSpacingMultiplier;
@synthesize texelWidth;
@synthesize texelHeight;

- (id)init;
{
    if (!(self = [super init]))
    {
		return nil;
    }
    
    // First pass: convert image to luminance
    luminanceFilter = [[GPUImageGrayscaleFilter alloc] init];
    [self addFilter:luminanceFilter];
    
    // Second pass: apply a variable Gaussian blur
    blurFilter = [[GPUImageSingleComponentGaussianBlurFilter alloc] init];
    [self addFilter:blurFilter];
    
    // Third pass: run the Sobel edge detection, with calculated gradient directions, on this blurred image
    edgeDetectionFilter = [[GPUimageDirectionalSobelEdgeDetectionFilter alloc] init];
    [self addFilter:edgeDetectionFilter];
    
    // Fourth pass: apply non-maximum suppression    
    nonMaximumSuppressionFilter = [[GPUImageDirectionalNonMaximumSuppressionFilter alloc] init];
    [self addFilter:nonMaximumSuppressionFilter];
    
    // Fifth pass: include weak pixels to complete edges
    weakPixelInclusionFilter = [[GPUImageWeakPixelInclusionFilter alloc] init];
    [self addFilter:weakPixelInclusionFilter];
    
    [luminanceFilter addTarget:blurFilter];
    [blurFilter addTarget:edgeDetectionFilter];
    [edgeDetectionFilter addTarget:nonMaximumSuppressionFilter];
    [nonMaximumSuppressionFilter addTarget:weakPixelInclusionFilter];
    
    self.initialFilters = [NSArray arrayWithObject:luminanceFilter];
//    self.terminalFilter = nonMaximumSuppressionFilter;
    self.terminalFilter = weakPixelInclusionFilter;
    
    self.blurRadiusInPixels = 2.0f;
    self.blurTexelSpacingMultiplier = 1.0f;
    self.upperThreshold = 0.4f;
    self.lowerThreshold = 0.1f;
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setBlurRadiusInPixels:(GLfloat)newValue;
{
    blurFilter.blurRadiusInPixels = newValue;
}

- (GLfloat)blurRadiusInPixels;
{
    return blurFilter.blurRadiusInPixels;
}

- (void)setBlurTexelSpacingMultiplier:(GLfloat)newValue;
{
    blurFilter.texelSpacingMultiplier = newValue;
}

- (GLfloat)blurTexelSpacingMultiplier;
{
    return blurFilter.texelSpacingMultiplier;
}

- (void)setTexelWidth:(GLfloat)newValue;
{
    edgeDetectionFilter.texelWidth = newValue;
}

- (GLfloat)texelWidth;
{
    return edgeDetectionFilter.texelWidth;
}

- (void)setTexelHeight:(GLfloat)newValue;
{
    edgeDetectionFilter.texelHeight = newValue;
}

- (GLfloat)texelHeight;
{
    return edgeDetectionFilter.texelHeight;
}

- (void)setUpperThreshold:(GLfloat)newValue;
{
    nonMaximumSuppressionFilter.upperThreshold = newValue;
}

- (GLfloat)upperThreshold;
{
    return nonMaximumSuppressionFilter.upperThreshold;
}

- (void)setLowerThreshold:(GLfloat)newValue;
{
    nonMaximumSuppressionFilter.lowerThreshold = newValue;
}

- (GLfloat)lowerThreshold;
{
    return nonMaximumSuppressionFilter.lowerThreshold;
}

@end
