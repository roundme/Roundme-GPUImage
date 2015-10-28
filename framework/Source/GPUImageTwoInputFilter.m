#import "GPUImageTwoInputFilter.h"

static const GLuint NUMBER_OF_INPUT_FRAME_BUFFERS = 2;

NSString *const kGPUImageTwoInputTextureVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 attribute vec4 inputTextureCoordinate2;

 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2;

 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
     textureCoordinate2 = inputTextureCoordinate2.xy;
 }
);

@implementation GPUImageTwoInputFilter

#pragma mark - Initialization and teardown

- (id)initWithFragmentShaderFromString:(NSString *)fragmentShaderString {
  self = [super initWithVertexShaderFromString:kGPUImageTwoInputTextureVertexShaderString fragmentShaderFromString:fragmentShaderString];
  return self;
}

- (void)initNumberOfInputs {
  self.numberOfInputs = NUMBER_OF_INPUT_FRAME_BUFFERS;
}

- (void)initializeAttributes {
  [super initializeAttributes];
  [self.filterProgram addAttribute:@"inputTextureCoordinate2"];
}

#pragma mark - Setup

- (void)configGL {
  [super configGL];

  GLuint textureCoordinateAttribute = [self.filterProgram attributeIndex:@"inputTextureCoordinate2"];
  [self setInputTextureCoordinateAttribute:textureCoordinateAttribute index:1];
  glEnableVertexAttribArray(textureCoordinateAttribute);

  GLuint textureUniform = [self.filterProgram uniformIndex:@"inputImageTexture2"];
  [self setInputTextureUniform:textureUniform index:1];
  glUniform1i(textureUniform, 3);
}

@end
