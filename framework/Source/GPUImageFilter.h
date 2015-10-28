#import "GPUImageFilterInput.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

#define GPUImageHashIdentifier #
#define GPUImageWrappedLabel(x) x
#define GPUImageEscapedHashIdentifier(a) GPUImageWrappedLabel(GPUImageHashIdentifier)a

extern NSString *const kGPUImageVertexShaderString;
extern NSString *const kGPUImagePassthroughFragmentShaderString;

/** GPUImage's base filter class
 
 Filters and other subsequent elements in the chain conform to the GPUImageInput protocol, which lets them take in the supplied or processed texture from the previous link in the chain and do something with it. Objects one step further down the chain are considered targets, and processing can be branched by adding multiple targets to a single output or filter.
 */
@interface GPUImageFilter : GPUImageOutput <GPUImageInput>

@property (nonatomic, strong) NSMutableDictionary *uniformStateRestorationBlocks;

@property (nonatomic, strong) GLProgram *filterProgram;
@property (nonatomic, assign) GLuint filterPositionAttribute;

@property (nonatomic, assign) GLuint numberOfInputs;
@property (nonatomic, strong) NSMutableArray *inputs;

@property (nonatomic, assign) GLfloat backgroundColorRed;
@property (nonatomic, assign) GLfloat backgroundColorGreen;
@property (nonatomic, assign) GLfloat backgroundColorBlue;
@property (nonatomic, assign) GLfloat backgroundColorAlpha;

@property (nonatomic, strong) dispatch_semaphore_t imageCaptureSemaphore;

@property (readonly) CVPixelBufferRef renderTarget;
@property (readwrite, nonatomic) BOOL preventRendering;

- (BOOL)isFilterReady;

- (BOOL)preRender;

- (void)unlockBuffers;

- (void)dropFrames;

- (void)configGL;
/// @name Initialization and teardown

/**
 Initialize with vertex and fragment shaders
 
 You make take advantage of the SHADER_STRING macro to write your shaders in-line.
 @param vertexShaderString Source code of the vertex shader to use
 @param fragmentShaderString Source code of the fragment shader to use
 */
- (id)initWithVertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString;

/**
 Initialize with a fragment shader
 
 You may take advantage of the SHADER_STRING macro to write your shader in-line.
 @param fragmentShaderString Source code of fragment shader to use
 */
- (id)initWithFragmentShaderFromString:(NSString *)fragmentShaderString;
/**
 Initialize with a fragment shader
 @param fragmentShaderFilename Filename of fragment shader to load
 */
- (id)initWithFragmentShaderFromFile:(NSString *)fragmentShaderFilename;
- (void)initializeAttributes;
- (void)setupFilterForSize:(CGSize)filterFrameSize;

#pragma mark - Inputs

- (GPUImageFramebuffer *)getInputFramebuffer:(NSUInteger)index;

- (GLuint)getInputVertexBuffer:(NSUInteger)index;
- (void)setInputVertexBuffer:(GLuint)value index:(NSUInteger)index;

- (GLuint)getInputIndexBuffer:(NSUInteger)index;
- (void)setInputIndexBuffer:(GLuint)value index:(NSUInteger)index;

- (GLuint)getInputTextureCoordinateAttribute:(NSUInteger)index;
- (void)setInputTextureCoordinateAttribute:(GLuint)value index:(NSUInteger)index;

- (GLuint)getInputTextureUniform:(NSUInteger)index;
- (void)setInputTextureUniform:(GLuint)value index:(NSUInteger)index;

- (GPUImageRotationMode)getInputRotation:(NSUInteger)index;
- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index;

- (CGSize)getInputSize:(NSUInteger)index;
- (void)setInputSize:(CGSize)value index:(NSUInteger)index;

#pragma mark - Buffers management

- (CGSize)outputFrameSize;
- (CGSize)maximumOutputSize;

- (CGSize)sizeOfFBO;

/// @name Input parameters
- (void)setBackgroundColorRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent alpha:(GLfloat)alphaComponent;
- (void)setInteger:(GLint)newInteger forUniformName:(NSString *)uniformName;
- (void)setFloat:(GLfloat)newFloat forUniformName:(NSString *)uniformName;
- (void)setSize:(CGSize)newSize forUniformName:(NSString *)uniformName;
- (void)setPoint:(CGPoint)newPoint forUniformName:(NSString *)uniformName;
- (void)setFloatVec3:(GPUVector3)newVec3 forUniformName:(NSString *)uniformName;
- (void)setFloatVec4:(GPUVector4)newVec4 forUniform:(NSString *)uniformName;
- (void)setFloatArray:(GLfloat *)array length:(GLsizei)count forUniform:(NSString*)uniformName;

- (void)setMatrix3f:(GPUMatrix3x3)matrix forUniform:(GLint)uniform program:(GLProgram *)shaderProgram;
- (void)setMatrix4f:(GPUMatrix4x4)matrix forUniform:(GLint)uniform program:(GLProgram *)shaderProgram;
- (void)setFloat:(GLfloat)floatValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram;
- (void)setPoint:(CGPoint)pointValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram;
- (void)setSize:(CGSize)sizeValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram;
- (void)setVec3:(GPUVector3)vectorValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram;
- (void)setVec4:(GPUVector4)vectorValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram;
- (void)setFloatArray:(GLfloat *)arrayValue length:(GLsizei)arrayLength forUniform:(GLint)uniform program:(GLProgram *)shaderProgram;
- (void)setInteger:(GLint)intValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram;

- (void)setAndExecuteUniformStateCallbackAtIndex:(GLint)uniform forProgram:(GLProgram *)shaderProgram toBlock:(dispatch_block_t)uniformStateBlock;
- (void)setUniformsForProgramAtIndex:(NSUInteger)programIndex;

@end
