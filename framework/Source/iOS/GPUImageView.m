#import "GPUImageView.h"
#import <OpenGLES/EAGLDrawable.h>
#import <QuartzCore/QuartzCore.h>
#import "GPUImageContext.h"
#import "GPUImageFilter.h"
#import <AVFoundation/AVFoundation.h>

#pragma mark -
#pragma mark Private methods and instance variables

@interface GPUImageView () 
{
    GLuint displayRenderbuffer;
    GLuint displayFramebuffer;
}

@property (nonatomic, assign) NSUInteger aspectRatio;

@property (nonatomic, strong) GPUImageFramebuffer *inputFramebufferForDisplay;

@property (nonatomic, strong) GLProgram *displayProgram;

@property (nonatomic, assign) GLuint verticesBuffer;
@property (nonatomic, assign) GLint displayPositionAttribute;
@property (nonatomic, assign) GLint displayTextureCoordinateAttribute;
@property (nonatomic, assign) GLint displayInputTextureUniform;

@property (nonatomic, assign) CGSize inputImageSize;

@property (nonatomic, assign) GLfloat backgroundColorRed;
@property (nonatomic, assign) GLfloat backgroundColorGreen;
@property (nonatomic, assign) GLfloat backgroundColorBlue;
@property (nonatomic, assign) GLfloat backgroundColorAlpha;

@property (nonatomic, assign) CGSize boundsSizeAtFrameBufferEpoch;

@end

@implementation GPUImageView

@synthesize aspectRatio;
@synthesize sizeInPixels = _sizeInPixels;
@synthesize fillMode = _fillMode;

#pragma mark -
#pragma mark Initialization and teardown

+ (Class)layerClass {
	return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)coder {
	if ((self = [super initWithCoder:coder])) {
        [self commonInit];
	}
	return self;
}

- (void)commonInit {
  // Set scaling to account for Retina display
  if ([self respondsToSelector:@selector(setContentScaleFactor:)]) {
    self.contentScaleFactor = [[UIScreen mainScreen] scale];
  }

  self.inputRotation = kGPUImageNoRotation;
  self.opaque = YES;
  self.hidden = NO;
  CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
  eaglLayer.opaque = YES;
  eaglLayer.shadowOpacity = 0.0;
  eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];

  runSynchronouslyOnVideoProcessingQueue(^{
    [GPUImageContext useImageProcessingContext];
    self.displayProgram = [[GLProgram alloc] initWithVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
    if (!self.displayProgram.initialized) {
      [self initializeAttributes];
      [self.displayProgram link];
    }

    [self configGL];

    [self setBackgroundColorRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    self.fillMode = kGPUImageFillModePreserveAspectRatio;
    [self createDisplayFramebuffer];
  });
}

- (void)initializeAttributes {
    [self.displayProgram addAttribute:@"position"];
	[self.displayProgram addAttribute:@"inputTextureCoordinate"];
    // Override this, calling back to this super method, in order to add new attributes to your vertex shader
}

- (void)configGL {
  [GPUImageContext setActiveShaderProgram:self.displayProgram];

  self.displayPositionAttribute = [self.displayProgram attributeIndex:@"position"];
  glEnableVertexAttribArray(self.displayPositionAttribute);

  self.displayTextureCoordinateAttribute = [self.displayProgram attributeIndex:@"inputTextureCoordinate"];
  glEnableVertexAttribArray(self.displayTextureCoordinateAttribute);

  self.displayInputTextureUniform = [self.displayProgram uniformIndex:@"inputImageTexture"]; // This does assume a name of "inputTexture" for the fragment shader
  glUniform1i(self.displayInputTextureUniform, 4);
}

- (void)setupVerticesAndTextureCoordinates {
    CGSize viewSize = self.bounds.size;
    CGSize imageSize = self.inputImageSize;
    if ((viewSize.width * viewSize.height > 0) && (imageSize.width * imageSize.height > 0)) {
        CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(imageSize, self.bounds);
        GLfloat widthScaling = 1.0;
        GLfloat heightScaling = 1.0;
        switch(self.fillMode) {
            case kGPUImageFillModeStretch:
                widthScaling = 1.0;
                heightScaling = 1.0;
                break;
            case kGPUImageFillModePreserveAspectRatio:
                widthScaling = insetRect.size.width / viewSize.width;
                heightScaling = insetRect.size.height / viewSize.height;
                break;
            case kGPUImageFillModePreserveAspectRatioAndFill:
                widthScaling = viewSize.height / insetRect.size.height;
                heightScaling = viewSize.width / insetRect.size.width;
                break;
        }
        NSAssert(!isnan(widthScaling) && !isnan(heightScaling), @"Invalid scaling");
        [self clearVerticesAndTextureCoordinates];
        runSynchronouslyOnVideoProcessingQueue(^{
            GLuint verticesBuffer;
            glGenBuffers(1, &verticesBuffer);
            glBindBuffer(GL_ARRAY_BUFFER, verticesBuffer);
            glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(Vertex2D), verticesAndTextureCoordinatesForRotationWithScale(self.inputRotation, widthScaling, heightScaling), GL_STATIC_DRAW);
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            self.verticesBuffer = verticesBuffer;
        });
    }
}

- (void)clearVerticesAndTextureCoordinates {
    runSynchronouslyOnVideoProcessingQueue(^{
        if (self.verticesBuffer) {
            glDeleteBuffers(1, &_verticesBuffer);
            self.verticesBuffer = 0;
        }
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // The frame buffer needs to be trashed and re-created when the view size changes.
    if (!CGSizeEqualToSize(self.bounds.size, self.boundsSizeAtFrameBufferEpoch) &&
        !CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
        runSynchronouslyOnVideoProcessingQueue(^{
            [self destroyDisplayFramebuffer];
            [self createDisplayFramebuffer];
            [self setupVerticesAndTextureCoordinates];
        });
    }
}

- (void)dealloc {
    [GPUImageContext useImageProcessingContext];
    runSynchronouslyOnVideoProcessingQueue(^{
        [self clearVerticesAndTextureCoordinates];
        [self destroyDisplayFramebuffer];
    });
}

#pragma mark -
#pragma mark Managing the display FBOs

- (void)createDisplayFramebuffer {
  [GPUImageContext useImageProcessingContext];

  glGenFramebuffers(1, &displayFramebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER, displayFramebuffer);

  glGenRenderbuffers(1, &displayRenderbuffer);
  glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);

  [[[GPUImageContext sharedImageProcessingContext] context] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];

  GLint backingWidth, backingHeight;

  glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
  glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);

  if ( (backingWidth == 0) || (backingHeight == 0) ) {
    [self destroyDisplayFramebuffer];
    return;
  }

  _sizeInPixels.width = (GLfloat)backingWidth;
  _sizeInPixels.height = (GLfloat)backingHeight;

  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, displayRenderbuffer);

  NSAssert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, @"Failure with display framebuffer generation for display of size: %f, %f", self.bounds.size.width, self.bounds.size.height);
  self.boundsSizeAtFrameBufferEpoch = self.bounds.size;

  glViewport(0, 0, (GLint)_sizeInPixels.width, (GLint)_sizeInPixels.height);
}

- (void)destroyDisplayFramebuffer {
    [GPUImageContext useImageProcessingContext];

    if (displayFramebuffer) {
		glDeleteFramebuffers(1, &displayFramebuffer);
		displayFramebuffer = 0;
	}
	
	if (displayRenderbuffer) {
		glDeleteRenderbuffers(1, &displayRenderbuffer);
		displayRenderbuffer = 0;
	}
}

- (void)setDisplayFramebuffer {
  if (!displayFramebuffer) {
    [self createDisplayFramebuffer];
  }
  glBindFramebuffer(GL_FRAMEBUFFER, displayFramebuffer);
}

- (void)presentFramebuffer {
  glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
  [[GPUImageContext sharedImageProcessingContext] presentBufferForDisplay];
}

#pragma mark - Handling fill mode

- (void)setBackgroundColorRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent alpha:(GLfloat)alphaComponent {
    self.backgroundColorRed = redComponent;
    self.backgroundColorGreen = greenComponent;
    self.backgroundColorBlue = blueComponent;
    self.backgroundColorAlpha = alphaComponent;
}


#pragma mark - GPUInput protocol

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex {
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext setActiveShaderProgram:self.displayProgram];
        [self setDisplayFramebuffer];

        glClearColor(self.backgroundColorRed, self.backgroundColorGreen, self.backgroundColorBlue, self.backgroundColorAlpha);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D, [self.inputFramebufferForDisplay texture]);

        [self bindVerticesAndIndices];

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        [self unbindVerticesAndIndices];

        [self presentFramebuffer];
        [self.inputFramebufferForDisplay unlock];
        self.inputFramebufferForDisplay = nil;
    });
}

#pragma mark - Vertices & Indices

-(void)bindVerticesAndIndices {
  glBindBuffer(GL_ARRAY_BUFFER, self.verticesBuffer);
  glVertexAttribPointer(self.displayPositionAttribute, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex2D), 0);

  glVertexAttribPointer(self.displayTextureCoordinateAttribute, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex2D), (GLvoid*)(sizeof(GLfloat) * 2));
}

-(void)unbindVerticesAndIndices {
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

- (NSInteger)nextAvailableTextureIndex {
    return 0;
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)value index:(NSUInteger)index {
    self.inputFramebufferForDisplay = value;
    [value lock];
}

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
    self.inputRotation = value;
}

- (void)setInputSize:(CGSize)value index:(NSUInteger)index {
    runSynchronouslyOnVideoProcessingQueue(^{
        CGSize rotatedSize = value;
        if (GPUImageRotationSwapsWidthAndHeight(self.inputRotation)) {
            rotatedSize.width = value.height;
            rotatedSize.height = value.width;
        }
        if (!CGSizeEqualToSize(self.inputImageSize, rotatedSize)) {
            self.inputImageSize = rotatedSize;
            [self setupVerticesAndTextureCoordinates];
        }
    });
}

- (CGSize)maximumOutputSize {
    if ([self respondsToSelector:@selector(setContentScaleFactor:)]) {
        CGSize pointSize = self.bounds.size;
        return CGSizeMake(self.contentScaleFactor * pointSize.width, self.contentScaleFactor * pointSize.height);
    } else {
        return self.bounds.size;
    }
}

- (void)endProcessing {
}

- (BOOL)shouldIgnoreUpdatesToThisTarget {
    return NO;
}

#pragma mark - Accessors

- (CGSize)sizeInPixels {
    if (CGSizeEqualToSize(_sizeInPixels, CGSizeZero)) {
        return [self maximumOutputSize];
    } else {
        return _sizeInPixels;
    }
}

- (void)setFillMode:(GPUImageFillModeType)newValue {
    runSynchronouslyOnVideoProcessingQueue(^{
        _fillMode = newValue;
        [self setupVerticesAndTextureCoordinates];
    });
}

@end
