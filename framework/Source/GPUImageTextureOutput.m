#import "GPUImageTextureOutput.h"

@implementation GPUImageTextureOutput

@synthesize delegate = _delegate;
@synthesize texture = _texture;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super init]))
    {
		return nil;
    }
    
    return self;
}

- (void)doneWithTexture;
{
    [firstInputFramebuffer unlock];
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    [_delegate newFrameReadyFromTextureOutput:self];
}

- (NSInteger)nextAvailableTextureIndex;
{
    return 0;
}

// TODO: Deal with the fact that the texture changes regularly as a result of the caching
- (void)setInputFramebuffer:(GPUImageFramebuffer *)value index:(NSUInteger)index {
    firstInputFramebuffer = value;
    [value lock];
    _texture = [value texture];
}

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
}

- (void)setInputSize:(CGSize)value index:(NSUInteger)index {
}

- (CGSize)maximumOutputSize;
{
    return CGSizeZero;
}

- (void)endProcessing
{
}

- (BOOL)shouldIgnoreUpdatesToThisTarget;
{
    return NO;
}

@end
