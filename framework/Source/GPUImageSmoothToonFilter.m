#import "GPUImageSmoothToonFilter.h"
#import "GPUImageGaussianBlurFilter.h"
#import "GPUImageToonFilter.h"

@implementation GPUImageSmoothToonFilter

@synthesize threshold;
@synthesize blurRadiusInPixels;
@synthesize quantizationLevels;
@synthesize texelWidth;
@synthesize texelHeight;

- (id)init;
{
    if (!(self = [super init]))
    {
		return nil;
    }
    
    // First pass: apply a variable Gaussian blur
    blurFilter = [[GPUImageGaussianBlurFilter alloc] init];
    [self addFilter:blurFilter];
    
    // Second pass: run the Sobel edge detection on this blurred image, along with a posterization effect
    toonFilter = [[GPUImageToonFilter alloc] init];
    [self addFilter:toonFilter];
    
    // Texture location 0 needs to be the sharp image for both the blur and the second stage processing
    [blurFilter addTarget:toonFilter];
    
    self.initialFilters = [NSArray arrayWithObject:blurFilter];
    self.terminalFilter = toonFilter;
    
    self.blurRadiusInPixels = 2.0;
    self.threshold = 0.2;
    self.quantizationLevels = 10.0;
    
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

- (void)setTexelWidth:(GLfloat)newValue;
{
    toonFilter.texelWidth = newValue;
}

- (GLfloat)texelWidth;
{
    return toonFilter.texelWidth;
}

- (void)setTexelHeight:(GLfloat)newValue;
{
    toonFilter.texelHeight = newValue;
}

- (GLfloat)texelHeight;
{
    return toonFilter.texelHeight;
}

- (void)setThreshold:(GLfloat)newValue;
{
    toonFilter.threshold = newValue;
}

- (GLfloat)threshold;
{
    return toonFilter.threshold;
}

- (void)setQuantizationLevels:(GLfloat)newValue;
{
    toonFilter.quantizationLevels = newValue;
}

- (GLfloat)quantizationLevels;
{
    return toonFilter.quantizationLevels;
}

@end
