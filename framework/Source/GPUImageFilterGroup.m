#import "GPUImageFilterGroup.h"
#import "GPUImagePicture.h"

@interface GPUImageFilterGroup()

@property (nonatomic, strong) NSMutableArray *filters;
@property (nonatomic, assign) BOOL isEndProcessing;

@end

@implementation GPUImageFilterGroup

- (id)init {
    if ((self = [super init])) {
        self.filters = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Filter management

- (void)addFilter:(GPUImageOutput<GPUImageInput> *)newFilter {
    [self.filters addObject:newFilter];
}

- (GPUImageOutput<GPUImageInput> *)filterAtIndex:(NSUInteger)filterIndex {
    return [self.filters objectAtIndex:filterIndex];
}

- (NSUInteger)filterCount {
    return [self.filters count];
}

#pragma mark - Still image processing

- (void)useNextFrameForImageCapture {
    [self.terminalFilter useNextFrameForImageCapture];
}

- (CGImageRef)newCGImageFromCurrentlyProcessedOutput {
    return [self.terminalFilter newCGImageFromCurrentlyProcessedOutput];
}

#pragma mark - GPUImageOutput overrides

- (void)setTargetToIgnoreForUpdates:(id<GPUImageInput>)targetToIgnoreForUpdates {
    [self.terminalFilter setTargetToIgnoreForUpdates:targetToIgnoreForUpdates];
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation {
    [self.terminalFilter addTarget:newTarget atTextureLocation:textureLocation];
}

- (void)removeTarget:(id<GPUImageInput>)targetToRemove {
    [self.terminalFilter removeTarget:targetToRemove];
}

- (void)removeAllTargets {
    [self.terminalFilter removeAllTargets];
}

- (void)setFrameProcessingCompletionBlock:(void (^)(GPUImageOutput *, CMTime))frameProcessingCompletionBlock {
    [self.terminalFilter setFrameProcessingCompletionBlock:frameProcessingCompletionBlock];
}

- (void (^)(GPUImageOutput *, CMTime))frameProcessingCompletionBlock {
    return [self.terminalFilter frameProcessingCompletionBlock];
}

#pragma mark - GPUImageInput protocol

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters) {
        if (currentFilter != self.inputFilterToIgnoreForUpdates) {
            [currentFilter newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }
    }
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)value index:(NSUInteger)index {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters) {
        [currentFilter setInputFramebuffer:value index:index];
    }
}

- (NSInteger)nextAvailableTextureIndex;
{
//    if ([self.initialFilters count] > 0)
//    {
//        return [[self.initialFilters objectAtIndex:0] nextAvailableTextureIndex];
//    }
    
    return 0;
}

- (void)setInputSize:(CGSize)value index:(NSUInteger)index {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters) {
        [currentFilter setInputSize:value index:index];
    }
}

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters) {
        [currentFilter setInputRotation:value index:index];
    }
}

- (void)forceProcessingAtSize:(CGSize)frameSize {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.filters) {
        [currentFilter forceProcessingAtSize:frameSize];
    }
}

- (void)forceProcessingAtSizeRespectingAspectRatio:(CGSize)frameSize {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.filters) {
        [currentFilter forceProcessingAtSizeRespectingAspectRatio:frameSize];
    }
}

- (CGSize)maximumOutputSize {
    // I'm temporarily disabling adjustments for smaller output sizes until I figure out how to make this work better
    return CGSizeZero;

    /*
    if (CGSizeEqualToSize(cachedMaximumOutputSize, CGSizeZero))
    {
        for (id<GPUImageInput> currentTarget in self.initialFilters)
        {
            if ([currentTarget maximumOutputSize].width > cachedMaximumOutputSize.width)
            {
                cachedMaximumOutputSize = [currentTarget maximumOutputSize];
            }
        }
    }
    
    return cachedMaximumOutputSize;
     */
}

- (void)endProcessing {
    if (!self.isEndProcessing) {
        self.isEndProcessing = YES;
        for (id<GPUImageInput> currentTarget in self.initialFilters)
        {
            [currentTarget endProcessing];
        }
    }
}

@end
