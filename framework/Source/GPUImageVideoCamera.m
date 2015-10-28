#import "GPUImageVideoCamera.h"
#import "GPUImageMovieWriter.h"
#import "GPUImageFilter.h"

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)

// BT.601, which is the standard for SDTV.
const GLfloat kColorConversion601[] = {
    1.164,  1.164, 1.164,
    0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
const GLfloat kColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

NSString *const kGPUImageYUVVideoRangeConversionForRGFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).rg - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );

NSString *const kGPUImageYUVFullRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r;
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );

NSString *const kGPUImageYUVVideoRangeConversionForLAFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D luminanceTexture;
 uniform sampler2D chrominanceTexture;
 uniform mediump mat3 colorConversionMatrix;
 
 void main()
 {
     mediump vec3 yuv;
     lowp vec3 rgb;
     
     yuv.x = texture2D(luminanceTexture, textureCoordinate).r - (16.0/255.0);
     yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
     rgb = colorConversionMatrix * yuv;
     
     gl_FragColor = vec4(rgb, 1);
 }
 );


#pragma mark - Private methods and instance variables

@interface GPUImageVideoCamera () 

@property (nonatomic, strong, readwrite) AVCaptureSession *captureSession;

@property (nonatomic, strong, readwrite) AVCaptureDevice *inputCamera;

@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic, strong) NSDate *startingCaptureTime;

@property (nonatomic, assign) dispatch_queue_t cameraProcessingQueue;
@property (nonatomic, assign) dispatch_queue_t audioProcessingQueue;

@property (nonatomic, strong) GLProgram *yuvConversionProgram;

@property (nonatomic, assign) GLint yuvConversionPositionAttribute;
@property (nonatomic, assign) GLint yuvConversionTextureCoordinateAttribute;

@property (nonatomic, assign) GLint yuvConversionLuminanceTextureUniform;
@property (nonatomic, assign) GLint yuvConversionChrominanceTextureUniform;
@property (nonatomic, assign) GLint yuvConversionMatrixUniform;
@property (nonatomic, assign) const GLfloat *preferredConversion;

@property (nonatomic, assign) BOOL isFullYUVRange;

@property (nonatomic, assign) BOOL addedAudioInputsDueToEncodingTarget;

@property (nonatomic, assign) GLuint verticesBuffer;

@property (nonatomic, assign) CGSize inputTextureSize;

@end

@implementation GPUImageVideoCamera

#pragma mark - Initialization and teardown

- (id)init {
    self = [self initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    return self;
}

- (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition {
	if ((self = [super init])) {
        if (![self acquireCamera:cameraPosition]) {
            return nil;
        }

        self.cameraProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        self.audioProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);

        self.frameRenderingSemaphore = dispatch_semaphore_create(1);

        self.frameRate = 0; // This will not set frame rate unless this value gets set to 1 or above
        self.runBenchmark = NO;
        self.capturePaused = NO;
        self.captureAsYUV = YES;
        self.preferredConversion = kColorConversion709;

        // Create the capture session
        self.captureSession = [[AVCaptureSession alloc] init];

        [self.captureSession beginConfiguration];

        // Add the video input
        NSError *error = nil;
        self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.inputCamera error:&error];
        if ([self.captureSession canAddInput:self.videoInput]) {
            [self.captureSession addInput:self.videoInput];
        }

        // Add the video frame output
        self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [self.videoOutput setAlwaysDiscardsLateVideoFrames:NO];

        //    if (captureAsYUV && [GPUImageContext deviceSupportsRedTextures])
        if (self.captureAsYUV && [GPUImageContext supportsFastTextureUpload]) {
            BOOL supportsFullYUVRange = NO;
            NSArray *supportedPixelFormats = self.videoOutput.availableVideoCVPixelFormatTypes;
            for (NSNumber *currentPixelFormat in supportedPixelFormats) {
                if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
                    supportsFullYUVRange = YES;
                }
            }

            if (supportsFullYUVRange) {
                [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
                self.isFullYUVRange = YES;
            } else {
                [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
                self.isFullYUVRange = NO;
            }
        } else {
            [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        }

        runSynchronouslyOnVideoProcessingQueue(^{
            if (self.captureAsYUV) {
                [GPUImageContext useImageProcessingContext];
                self.yuvConversionProgram = [[GLProgram alloc] initWithVertexShaderString:kGPUImageVertexShaderString
                                                                fragmentShaderString:(self.isFullYUVRange ?
                                                                                      kGPUImageYUVFullRangeConversionForLAFragmentShaderString :
                                                                                      kGPUImageYUVVideoRangeConversionForLAFragmentShaderString)];
                if (!self.yuvConversionProgram.initialized) {
                    [self initializeAttributes];
                    [self.yuvConversionProgram link];
                }

                [self configGL];
            }
        });

        self.outputImageOrientation = UIInterfaceOrientationPortrait;

        [self.videoOutput setSampleBufferDelegate:self queue:self.cameraProcessingQueue];
        if ([self.captureSession canAddOutput:self.videoOutput]) {
            [self.captureSession addOutput:self.videoOutput];
        } else {
            NSLog(@"Couldn't add video output");
            return nil;
        }
        
        self.captureSessionPreset = sessionPreset;
        [self.captureSession setSessionPreset:self.captureSessionPreset];
        
        [self.captureSession commitConfiguration];
    }
	return self;
}

#pragma mark - Setup

- (void)initializeAttributes {
    [self.yuvConversionProgram addAttribute:@"position"];
    [self.yuvConversionProgram addAttribute:@"inputTextureCoordinate"];
    // Override this, calling back to this super method, in order to add new attributes to your vertex shader
}

- (void)configGL {
    [GPUImageContext setActiveShaderProgram:self.yuvConversionProgram];
    self.yuvConversionPositionAttribute = [self.yuvConversionProgram attributeIndex:@"position"];
    self.yuvConversionTextureCoordinateAttribute = [self.yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
    self.yuvConversionLuminanceTextureUniform = [self.yuvConversionProgram uniformIndex:@"luminanceTexture"];
    self.yuvConversionChrominanceTextureUniform = [self.yuvConversionProgram uniformIndex:@"chrominanceTexture"];
    self.yuvConversionMatrixUniform = [self.yuvConversionProgram uniformIndex:@"colorConversionMatrix"];
}

- (void)setupVerticesAndTextureCoordinates {
    [self clearVerticesAndTextureCoordinates];
    runSynchronouslyOnVideoProcessingQueue(^{
        GLuint verticesBuffer;
        glGenBuffers(1, &verticesBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, verticesBuffer);
        glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(Vertex2D), verticesAndTextureCoordinatesForRotation(self.inputRotation), GL_STATIC_DRAW);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        self.verticesBuffer = verticesBuffer;
    });
}

- (void)clearVerticesAndTextureCoordinates {
    runSynchronouslyOnVideoProcessingQueue(^{
        if (self.verticesBuffer) {
            glDeleteBuffers(1, &_verticesBuffer);
            self.verticesBuffer = 0;
        }
    });
}


- (BOOL)acquireCamera:(AVCaptureDevicePosition)cameraPosition {
    // Grab the back-facing or front-facing camera
    self.inputCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == cameraPosition) {
            self.inputCamera = device;
        }
    }
    return self.inputCamera != nil;
}

- (GPUImageFramebuffer *)framebufferForOutput {
    return self.outputFramebuffer;
}

- (void)dealloc {
    [self stopCameraCapture];
    [self.videoOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
    [self.audioOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
    
    [self removeInputsAndOutputs];
    [self clearVerticesAndTextureCoordinates];
}

- (BOOL)addAudioInputsAndOutputs
{
    if (self.audioOutput)
        return NO;
    
    [self.captureSession beginConfiguration];
    
    self.microphone = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    self.audioInput = [AVCaptureDeviceInput deviceInputWithDevice:self.microphone error:nil];
    if ([self.captureSession canAddInput:self.audioInput])
    {
        [self.captureSession addInput:self.audioInput];
    }
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    if ([self.captureSession canAddOutput:self.audioOutput])
    {
        [self.captureSession addOutput:self.audioOutput];
    }
    else
    {
        NSLog(@"Couldn't add audio output");
    }
    [self.audioOutput setSampleBufferDelegate:self queue:self.audioProcessingQueue];
    
    [self.captureSession commitConfiguration];
    return YES;
}

- (BOOL)removeAudioInputsAndOutputs
{
    if (!self.audioOutput)
        return NO;
    
    [self.captureSession beginConfiguration];
    [self.captureSession removeInput:self.audioInput];
    [self.captureSession removeOutput:self.audioOutput];
    self.audioInput = nil;
    self.audioOutput = nil;
    self.microphone = nil;
    [self.captureSession commitConfiguration];
    return YES;
}

- (void)removeInputsAndOutputs;
{
    [self.captureSession beginConfiguration];
    if (self.videoInput) {
        [self.captureSession removeInput:self.videoInput];
        [self.captureSession removeOutput:self.videoOutput];
        self.videoInput = nil;
        self.videoOutput = nil;
    }
    if (self.microphone != nil)
    {
        [self.captureSession removeInput:self.audioInput];
        [self.captureSession removeOutput:self.audioOutput];
        self.audioInput = nil;
        self.audioOutput = nil;
        self.microphone = nil;
    }
    [self.captureSession commitConfiguration];
}

#pragma mark - Manage the camera video stream

- (void)startCameraCapture {
    if (![self.captureSession isRunning]) {
        self.startingCaptureTime = [NSDate date];
		[self.captureSession startRunning];
	}
}

- (void)stopCameraCapture {
    if ([self.captureSession isRunning]) {
        [self.captureSession stopRunning];
    }
}

- (void)pauseCameraCapture {
    self.capturePaused = YES;
}

- (void)resumeCameraCapture {
    self.capturePaused = NO;
}

- (void)rotateCamera {
	if (self.frontFacingCameraPresent == YES) {
        NSError *error;
        AVCaptureDeviceInput *newVideoInput;
        AVCaptureDevicePosition currentCameraPosition = ([self cameraPosition] == AVCaptureDevicePositionBack ?
                                                         AVCaptureDevicePositionFront : AVCaptureDevicePositionBack);

        AVCaptureDevice *backFacingCamera = nil;
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if ([device position] == currentCameraPosition) {
                backFacingCamera = device;
            }
        }
        newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:backFacingCamera error:&error];

        if (newVideoInput != nil) {
            [self.captureSession beginConfiguration];

            [self.captureSession removeInput:self.videoInput];
            if ([self.captureSession canAddInput:newVideoInput]) {
                [self.captureSession addInput:newVideoInput];
                self.videoInput = newVideoInput;
            } else {
                [self.captureSession addInput:self.videoInput];
            }
            [self.captureSession commitConfiguration];
        }
        
        self.inputCamera = backFacingCamera;
        [self setOutputImageOrientation:self.outputImageOrientation];
    }
}

- (AVCaptureDevicePosition)cameraPosition {
    return [[self.videoInput device] position];
}

+ (BOOL)isBackFacingCameraPresent {
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	
	for (AVCaptureDevice *device in devices) {
		if ([device position] == AVCaptureDevicePositionBack)
			return YES;
	}
	
	return NO;
}

- (BOOL)isBackFacingCameraPresent {
    return [GPUImageVideoCamera isBackFacingCameraPresent];
}

+ (BOOL)isFrontFacingCameraPresent;
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == AVCaptureDevicePositionFront)
			return YES;
	}
	
	return NO;
}

- (BOOL)isFrontFacingCameraPresent
{
    return [GPUImageVideoCamera isFrontFacingCameraPresent];
}

- (void)setCaptureSessionPreset:(NSString *)captureSessionPreset;
{
	[self.captureSession beginConfiguration];
	
	_captureSessionPreset = captureSessionPreset;
	[self.captureSession setSessionPreset:self.captureSessionPreset];
	
	[self.captureSession commitConfiguration];
}

- (void)setFrameRate:(int32_t)frameRate {
	_frameRate = frameRate;
	
	if (self.frameRate > 0) {
		if ([self.inputCamera respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [self.inputCamera respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            
            NSError *error;
            [self.inputCamera lockForConfiguration:&error];
            if (error == nil) {
                [self.inputCamera setActiveVideoMinFrameDuration:CMTimeMake(1, self.frameRate)];
                [self.inputCamera setActiveVideoMaxFrameDuration:CMTimeMake(1, self.frameRate)];
            }
            [self.inputCamera unlockForConfiguration];
        } else {
            for (AVCaptureConnection *connection in self.videoOutput.connections) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                    connection.videoMinFrameDuration = CMTimeMake(1, self.frameRate);
                
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                    connection.videoMaxFrameDuration = CMTimeMake(1, self.frameRate);
#pragma clang diagnostic pop
            }
        }
	} else {
        if ([self.inputCamera respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [self.inputCamera respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            
            NSError *error;
            [self.inputCamera lockForConfiguration:&error];
            if (error == nil) {
                [self.inputCamera setActiveVideoMinFrameDuration:kCMTimeInvalid];
                [self.inputCamera setActiveVideoMaxFrameDuration:kCMTimeInvalid];
            }
            [self.inputCamera unlockForConfiguration];
        } else {
            
            for (AVCaptureConnection *connection in self.videoOutput.connections)
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                    connection.videoMinFrameDuration = kCMTimeInvalid; // This sets videoMinFrameDuration back to default
                
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                    connection.videoMaxFrameDuration = kCMTimeInvalid; // This sets videoMaxFrameDuration back to default
#pragma clang diagnostic pop
            }
        }
	}
}

- (AVCaptureConnection *)videoCaptureConnection {
    for (AVCaptureConnection *connection in [self.videoOutput connections] ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:AVMediaTypeVideo] ) {
				return connection;
			}
		}
	}
    return nil;
}

#define INITIALFRAMESTOIGNOREFORBENCHMARK 5

- (void)getColorConversionForFrame:(CVImageBufferRef)frame {
    CFTypeRef colorAttachments = CVBufferGetAttachment(frame, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments != NULL) {
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
            if (self.isFullYUVRange) {
                self.preferredConversion = kColorConversion601FullRange;
            } else {
                self.preferredConversion = kColorConversion601;
            }
        } else {
            self.preferredConversion = kColorConversion709;
        }
    } else {
        if (self.isFullYUVRange) {
            self.preferredConversion = kColorConversion601FullRange;
        } else {
            self.preferredConversion = kColorConversion601;
        }
    }
}

- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (self.capturePaused) {
        return;
    }
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    self.inputTextureSize = CGSizeMake((CGFloat)CVPixelBufferGetWidth(cameraFrame), (CGFloat)CVPixelBufferGetHeight(cameraFrame));

	CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

    [GPUImageContext useImageProcessingContext];

    if ([GPUImageContext supportsFastTextureUpload] && self.captureAsYUV) {
        CVOpenGLESTextureRef luminanceTextureRef = NULL;
        CVOpenGLESTextureRef chrominanceTextureRef = NULL;

        if (CVPixelBufferGetPlaneCount(cameraFrame) > 0) {
            // Check for YUV planar inputs to do RGB conversion
            CVPixelBufferLockBaseAddress(cameraFrame, 0);
            
            CVReturn err;
            // Y-plane
            glActiveTexture(GL_TEXTURE4);
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, (GLsizei)self.inputTextureSize.width, (GLsizei)self.inputTextureSize.height, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
            NSAssert1(err == kCVReturnSuccess, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);

            self.luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, self.luminanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
            // UV-plane
            glActiveTexture(GL_TEXTURE5);
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, (GLsizei)self.inputTextureSize.width/2, (GLsizei)self.inputTextureSize.height/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
            NSAssert1(err == kCVReturnSuccess, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);

            self.chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, self.chrominanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

            [self getColorConversionForFrame:cameraFrame];
            [self convertYUVToRGBOutput];

            [self informTargetsAboutNewFrameAtTime:currentTime];

            CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
            CFRelease(luminanceTextureRef);
            CFRelease(chrominanceTextureRef);
        } else {
            NSAssert(NO, @"not implemented");
        }
    } else {
        CVPixelBufferLockBaseAddress(cameraFrame, 0);
        
        GLsizei bytesPerRow = (GLsizei)CVPixelBufferGetBytesPerRow(cameraFrame);
        self.outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(bytesPerRow / 4, self.inputTextureSize.height) onlyTexture:YES];
        [self.outputFramebuffer activateFramebuffer];

        glBindTexture(GL_TEXTURE_2D, [self.outputFramebuffer texture]);
        // Using BGRA extension to pull in video frame data directly
        // The use of bytesPerRow / 4 accounts for a display glitch present in preview video frames when using the photo preset on the camera
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bytesPerRow / 4, (GLsizei)self.inputTextureSize.height, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));
        
        [self informTargetsAboutNewFrameAtTime:currentTime];

        CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    }

    if (_runBenchmark && ++self.numberOfFramesCaptured > INITIALFRAMESTOIGNOREFORBENCHMARK) {
        CFAbsoluteTime currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime);
        self.totalFrameTimeDuringCapture += currentFrameTime;
        NSLog(@"Average frame time : %f ms", [self averageFrameDurationDuringCapture]);
        NSLog(@"Current frame time : %f ms", 1000.0 * currentFrameTime);
    }
}

- (void)processAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    [self.audioEncodingTarget processAudioBuffer:sampleBuffer]; 
}

- (void)convertYUVToRGBOutput {
    [GPUImageContext setActiveShaderProgram:self.yuvConversionProgram];

    self.inputTextureSize = rotatedSize(self.inputTextureSize, self.inputRotation);

    self.outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:self.inputTextureSize textureOptions:self.outputTextureOptions onlyTexture:NO];
    [self.outputFramebuffer activateFramebuffer];

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
	glActiveTexture(GL_TEXTURE4);
	glBindTexture(GL_TEXTURE_2D, self.luminanceTexture);
	glUniform1i(self.yuvConversionLuminanceTextureUniform, 4);

    glActiveTexture(GL_TEXTURE5);
	glBindTexture(GL_TEXTURE_2D, self.chrominanceTexture);
	glUniform1i(self.yuvConversionChrominanceTextureUniform, 5);

    glUniformMatrix3fv(self.yuvConversionMatrixUniform, 1, GL_FALSE, self.preferredConversion);

    [self bindVerticesAndIndices];

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    [self unbindVerticesAndIndices];
}

#pragma mark - Managing the display FBOs

- (CGSize)outputFrameSize {
    return self.inputTextureSize;
}

#pragma mark - Vertices & Indices

-(void)bindVerticesAndIndices {
    glBindBuffer(GL_ARRAY_BUFFER, self.verticesBuffer);
    glVertexAttribPointer(self.yuvConversionPositionAttribute, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex2D), 0);
    glEnableVertexAttribArray(self.yuvConversionPositionAttribute);

	glVertexAttribPointer(self.yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex2D), (GLvoid*)(sizeof(GLfloat) * 2));
    glEnableVertexAttribArray(self.yuvConversionTextureCoordinateAttribute);
}

-(void)unbindVerticesAndIndices {
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

#pragma mark - Benchmarking

- (GLfloat)averageFrameDurationDuringCapture {
    return (self.totalFrameTimeDuringCapture / (GLfloat)(self.numberOfFramesCaptured - INITIALFRAMESTOIGNOREFORBENCHMARK)) * 1000.0;
}

- (void)resetBenchmarkAverage {
    self.numberOfFramesCaptured = 0;
    self.totalFrameTimeDuringCapture = 0.0;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
  if (self.captureSession.isRunning) {
    if (captureOutput == self.audioOutput) {
      [self processAudioSampleBuffer:sampleBuffer];
    } else {
      if (dispatch_semaphore_wait(self.frameRenderingSemaphore, DISPATCH_TIME_NOW) == 0) {
        CFRetain(sampleBuffer);
        __weak typeof(self) weakSelf = self;
        runAsynchronouslyOnVideoProcessingQueue(^{
          __strong typeof(weakSelf) self = weakSelf;
          if (self) {
            //Feature Detection Hook.
            if (self.delegate) {
              [self.delegate willOutputSampleBuffer:sampleBuffer];
            }
            [self processVideoSampleBuffer:sampleBuffer];
            dispatch_semaphore_signal(self.frameRenderingSemaphore);
          }
          CFRelease(sampleBuffer);
        });
      }
    }
  }
}

#pragma mark - Accessors

- (void)setAudioEncodingTarget:(GPUImageMovieWriter *)newValue {
    if (newValue) {
        /* Add audio inputs and outputs, if necessary */
        self.addedAudioInputsDueToEncodingTarget |= [self addAudioInputsAndOutputs];
    } else if (self.addedAudioInputsDueToEncodingTarget) {
        /* Remove audio inputs and outputs, if they were added by previously setting the audio encoding target */
        [self removeAudioInputsAndOutputs];
        self.addedAudioInputsDueToEncodingTarget = NO;
    }
    
    [super setAudioEncodingTarget:newValue];
}

- (void)updateOrientationSendToTargets {
    runSynchronouslyOnVideoProcessingQueue(^{
        self.inputRotation = kGPUImageNoRotation;
        if ([self cameraPosition] == AVCaptureDevicePositionBack) {
            if (self.horizontallyMirrorRearFacingCamera) {
                switch(self.outputImageOrientation) {
                    case UIInterfaceOrientationPortrait:
                        self.inputRotation = kGPUImageNoRotation;
                        break;
                    case UIInterfaceOrientationPortraitUpsideDown:
                        self.inputRotation = kGPUImageRotate180;
                        break;
                    case UIInterfaceOrientationLandscapeLeft:
                        self.inputRotation = kGPUImageFlipHorizonal;
                        break;
                    case UIInterfaceOrientationLandscapeRight:
                        self.inputRotation = kGPUImageFlipVertical;
                        break;
                    default:
                        self.inputRotation = kGPUImageNoRotation;
                }
            } else {
                switch(self.outputImageOrientation) {
                    case UIInterfaceOrientationPortrait:
                        self.inputRotation = kGPUImageRotateLeftFlipHorizontal;
                        break;
                    case UIInterfaceOrientationPortraitUpsideDown:
                        self.inputRotation = kGPUImageRotateRight;
                        break;
                    case UIInterfaceOrientationLandscapeLeft:
                        self.inputRotation = kGPUImageRotate180;
                        break;
                    case UIInterfaceOrientationLandscapeRight:
                        self.inputRotation = kGPUImageNoRotation;
                        break;
                    default:
                        self.inputRotation = kGPUImageNoRotation;
                }
            }
        } else {
            if (self.horizontallyMirrorFrontFacingCamera) {
                switch(self.outputImageOrientation) {
                    case UIInterfaceOrientationPortrait:
                        self.inputRotation = kGPUImageRotateRightFlipVertical;
                        break;
                    case UIInterfaceOrientationPortraitUpsideDown:
                        self.inputRotation = kGPUImageRotateRightFlipHorizontal;
                        break;
                    case UIInterfaceOrientationLandscapeLeft:
                        self.inputRotation = kGPUImageFlipHorizonal;
                        break;
                    case UIInterfaceOrientationLandscapeRight:
                        self.inputRotation = kGPUImageFlipVertical;
                        break;
                    default:
                        self.inputRotation = kGPUImageNoRotation;
                }
            } else {
                switch(self.outputImageOrientation) {
                    case UIInterfaceOrientationPortrait:
                        self.inputRotation = kGPUImageRotateRight;
                        break;
                    case UIInterfaceOrientationPortraitUpsideDown:
                        self.inputRotation = kGPUImageRotateLeft;
                        break;
                    case UIInterfaceOrientationLandscapeLeft:
                        self.inputRotation = kGPUImageNoRotation;
                        break;
                    case UIInterfaceOrientationLandscapeRight:
                        self.inputRotation = kGPUImageRotate180;
                        break;
                    default:
                        self.inputRotation = kGPUImageNoRotation;
                }
            }
        }

        [self setupVerticesAndTextureCoordinates];

        [self loopTargetsWithTargetAndTextureIndex:^(id<GPUImageInput> target, NSUInteger textureIndex) {
            [target setInputRotation:self.inputRotation index:textureIndex];
        }];
    });
}

- (void)setOutputImageOrientation:(UIInterfaceOrientation)newValue {
    _outputImageOrientation = newValue;
    [self updateOrientationSendToTargets];
}

- (void)setHorizontallyMirrorFrontFacingCamera:(BOOL)newValue {
    _horizontallyMirrorFrontFacingCamera = newValue;
    [self updateOrientationSendToTargets];
}

- (void)setHorizontallyMirrorRearFacingCamera:(BOOL)newValue {
    _horizontallyMirrorRearFacingCamera = newValue;
    [self updateOrientationSendToTargets];
}

@end
