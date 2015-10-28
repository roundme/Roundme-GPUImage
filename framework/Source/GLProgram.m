//  This is Jeff LaMarche's GLProgram OpenGL shader wrapper class from his OpenGL ES 2.0 book.
//  A description of this can be found at his page on the topic:
//  http://iphonedevelopment.blogspot.com/2010/11/opengl-es-20-for-ios-chapter-4.html

#import "GLProgram.h"

typedef void (*GLInfoFunction)(GLuint program, GLenum pname, GLint* params);
typedef void (*GLLogFunction) (GLuint program, GLsizei bufsize, GLsizei* length, GLchar* infolog);

@interface GLProgram()

@property (nonatomic, assign) GLuint nextAttributeIndex;;

@property (nonatomic, assign) GLuint program;
@property (nonatomic, assign) GLuint vertShader;
@property (nonatomic, assign) GLuint fragShader;

@end

#pragma mark -

@implementation GLProgram

- (id)initWithVertexShaderString:(NSString *)vShaderString fragmentShaderString:(NSString *)fShaderString {
    if ((self = [super init])) {
        self.initialized = NO;
        self.program = glCreateProgram();

        self.nextAttributeIndex = 0;
        
        if (![self compileShader:&_vertShader type:GL_VERTEX_SHADER string:vShaderString])
            NSLog(@"Failed to compile vertex shader");

        if (![self compileShader:&_fragShader type:GL_FRAGMENT_SHADER string:fShaderString])
            NSLog(@"Failed to compile fragment shader");
        
        glAttachShader(self.program, self.vertShader);
        glAttachShader(self.program, self.fragShader);
    }
    
    return self;
}

- (id)initWithVertexShaderString:(NSString *)vShaderString fragmentShaderFilename:(NSString *)fShaderFilename {
    NSString *fragShaderPathname = [[NSBundle mainBundle] pathForResource:fShaderFilename ofType:@"fsh"];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];

    self = [self initWithVertexShaderString:vShaderString fragmentShaderString:fragmentShaderString];

    return self;
}

- (id)initWithVertexShaderFilename:(NSString *)vShaderFilename  fragmentShaderFilename:(NSString *)fShaderFilename {
    NSString *vertShaderPathname = [[NSBundle mainBundle] pathForResource:vShaderFilename ofType:@"vsh"];
    NSString *vertexShaderString = [NSString stringWithContentsOfFile:vertShaderPathname encoding:NSUTF8StringEncoding error:nil];

    NSString *fragShaderPathname = [[NSBundle mainBundle] pathForResource:fShaderFilename ofType:@"fsh"];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];

    self = [self initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];

    return self;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type string:(NSString *)shaderString {
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[shaderString UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);

	if (status != GL_TRUE) {
		GLint logLength;
		glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
		if (logLength > 0) {
			GLchar *log = (GLchar *)malloc(logLength);
			glGetShaderInfoLog(*shader, logLength, &logLength, log);
			NSLog(@"Shader compile log:\n%s", log);
			free(log);
		}
	}	

    return status == GL_TRUE;
}

#pragma mark -

- (void)addAttribute:(NSString *)attributeName {
    glBindAttribLocation(self.program, self.nextAttributeIndex++, [attributeName UTF8String]);
    NSAssert(glGetError() == GL_NO_ERROR, @"program add atribute error");
}

- (GLuint)attributeIndex:(NSString *)attributeName {
    GLint attribIndex = glGetAttribLocation(self.program, [attributeName UTF8String]);
    NSAssert(glGetError() == GL_NO_ERROR && attribIndex >= 0, @"program get atribute index error");
    return attribIndex;
}

- (GLuint)uniformIndex:(NSString *)uniformName {
    return glGetUniformLocation(self.program, [uniformName UTF8String]);
}

#pragma mark -

- (void)link {
    GLint status;
    
    glLinkProgram(self.program);
    
    glGetProgramiv(self.program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        NSString *progLog = [self programLog];
        NSLog(@"Program link log: %@", progLog);
        NSString *fragLog = [self fragmentShaderLog];
        NSLog(@"Fragment shader compile log: %@", fragLog);
        NSString *vertLog = [self vertexShaderLog];
        NSLog(@"Vertex shader compile log: %@", vertLog);
        NSAssert(NO, @"Program shader link failed");
    }

    if (self.vertShader) {
        glDeleteShader(self.vertShader);
        self.vertShader = 0;
    }
    if (self.fragShader) {
        glDeleteShader(self.fragShader);
        self.fragShader = 0;
    }
    
    self.initialized = YES;
}

- (void)use {
    glUseProgram(self.program);
}

#pragma mark -

- (NSString *)logForOpenGLObject:(GLuint)object infoCallback:(GLInfoFunction)infoFunc logFunc:(GLLogFunction)logFunc {
    GLint logLength = 0, charsWritten = 0;
    
    infoFunc(object, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength < 1)
        return nil;
    
    char *logBytes = malloc(logLength);
    logFunc(object, logLength, &charsWritten, logBytes);
    NSString *log = [[NSString alloc] initWithBytes:logBytes length:logLength encoding:NSUTF8StringEncoding];
    free(logBytes);
    return log;
}

- (NSString *)vertexShaderLog {
    return [self logForOpenGLObject:self.vertShader infoCallback:(GLInfoFunction)&glGetProgramiv logFunc:(GLLogFunction)&glGetProgramInfoLog];
}

- (NSString *)fragmentShaderLog {
    return [self logForOpenGLObject:self.fragShader infoCallback:(GLInfoFunction)&glGetProgramiv logFunc:(GLLogFunction)&glGetProgramInfoLog];
}

- (NSString *)programLog {
    return [self logForOpenGLObject:self.program infoCallback:(GLInfoFunction)&glGetProgramiv logFunc:(GLLogFunction)&glGetProgramInfoLog];
}

- (void)validate {
	GLint logLength;
	
	glValidateProgram(self.program);
	glGetProgramiv(self.program, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(self.program, logLength, &logLength, log);
		NSLog(@"Program validate log:\n%s", log);
		free(log);
	}	
}

#pragma mark -

- (void)dealloc {
    if (self.vertShader)
        glDeleteShader(self.vertShader);
        
    if (self.fragShader)
        glDeleteShader(self.fragShader);


    if (self.program) {
        GLint bindedProgram;
        glGetIntegerv(GL_CURRENT_PROGRAM, &bindedProgram);

        if (self.program == bindedProgram) {
            glUseProgram(0);
        }

        glDeleteProgram(self.program);
    }
}

@end
