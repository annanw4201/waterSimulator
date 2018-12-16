//
//  ViewController.m
//  water
//
//  Created by Wong Tom on 2018-12-15.
//  Copyright © 2018 Wang Tom. All rights reserved.
//

#import "MainViewController.h"
#import "waterFun.h"
#import <MetalKit/MetalKit.h>
#import <Metal/MTLDevice.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKMath.h>
#import <CoreMotion/CoreMotion.h>

typedef struct myFloat16 {
    float data[16];
}myFloat16;

@interface MainViewController ()
@property(nonatomic) float gravity;
@property(nonatomic) float ptmRatio;
@property(nonatomic) float particleRadius;
@property(nonatomic) void *particleSys;
@property(nonatomic, weak) id<MTLDevice> mtlDevice;
@property(nonatomic, weak) CAMetalLayer* metalLayer;
@property(nonatomic) int particleCount;
@property(nonatomic) id<MTLBuffer> vertexBuffer;
@property(nonatomic) id<MTLBuffer> uniformBuffer;
@property(nonatomic) id<MTLRenderPipelineState> pipelineState;
@property(nonatomic) id<MTLCommandQueue> commandQueue;
@property(nonatomic) CMMotionManager *motionManager;
@property(nonatomic) int maxParticles;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.gravity = 9.8;
    self.ptmRatio = 32.0;
    self.particleRadius = 3;
    self.motionManager = [[CMMotionManager alloc] init];
    self.maxParticles = 6666;
    
    Vector2D gravityVec = {0, - self.gravity};
    [waterFun createWorldWithGravity:gravityVec];
    // Do any additional setup after loading the view, typically from a nib.
    self.particleSys = [waterFun createParticleSystemWithRadius:self.particleRadius / self.ptmRatio dampingStrength:0.2 gravityScale:1.0 density:1.2];
    
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    Vector2D positionVec = {screenSize.width * 0.5 / self.ptmRatio, screenSize.height * 0.5 / self.ptmRatio};
    Size2D sizeVec = {66 / self.ptmRatio, 66 / self.ptmRatio};
    [waterFun createParticleBoxForSystem:self.particleSys position:positionVec size:sizeVec];
    
    [waterFun setParticleLimitForSystem:self.particleSys maxParticles:self.maxParticles]; // max particles
    
    Vector2D edgeBoxOrigin = {0, 0};
    Size2D edgeBoxSize = {screenSize.width / self.ptmRatio, screenSize.height / self.ptmRatio};
    [waterFun createEdgeBoxWithOrigin:edgeBoxOrigin size:edgeBoxSize];
    
    [self printParticleInfo];
    [self createMetalLayer];
    [self refreshVertexBuffer];
    [self refreshUniformBuffer];
    [self buildRenderPipeline];
    [self render];
    
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateDisplayLink:)];
    [displayLink setPreferredFramesPerSecond:0];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData * _Nullable accelerometerData, NSError * _Nullable error) {
        CMAcceleration acceleration = [accelerometerData acceleration];
        Vector2D gravity = {acceleration.x * self.gravity, acceleration.y * self.gravity};
        [waterFun setGravity:gravity];
    }];
}

- (void)dealloc {
    [waterFun destroyWorld];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [touches enumerateObjectsUsingBlock:^(UITouch * _Nonnull obj, BOOL * _Nonnull stop) {
        CGPoint touchLocation = [obj locationInView:self.view];
        NSLog(@"touch location: (%f, %f)", touchLocation.x, touchLocation.y);
        Vector2D position = {touchLocation.x / self.ptmRatio, (self.view.bounds.size.height - touchLocation.y) / self.ptmRatio};
        Size2D size = {66 / self.ptmRatio, 66 / self.ptmRatio};
        [waterFun createParticleBoxForSystem:self.particleSys position:position size:size];
    }];
}

- (void)printParticleInfo {
    int count = [waterFun particleCountForSystem:self.particleSys];
    NSLog(@"Total particle count: %d", count);
    Vector2D *positionArray = (Vector2D *)([waterFun particlePositionsForSystem:self.particleSys]);
    for (int i = 0; i < count; ++i) {
        NSLog(@"Particle (%d): %f, %f", i, positionArray[i].x, positionArray[i].y);
    }
}

- (void)createMetalLayer {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    self.mtlDevice = device;
    self.metalLayer = [CAMetalLayer layer];
    self.metalLayer.device = self.mtlDevice;
    self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalLayer.framebufferOnly = true;
    self.metalLayer.frame = self.view.layer.frame;
    [[self.view layer] addSublayer:self.metalLayer];
}

- (void)refreshVertexBuffer {
    self.particleCount = [waterFun particleCountForSystem:self.particleSys];
    self.vertexBuffer = [self.mtlDevice newBufferWithBytes:[waterFun particlePositionsForSystem:self.particleSys] length:sizeof(float) * self.particleCount * 2 options:MTLResourceStorageModeShared];
    
}

- (myFloat16)makeOrthographicMatrixWithLeft: (float)left Right:(float)right Bottom:(float)bottom Top:(float)top Near:(float)near Far:(float)far {
    float ral = right + left;
    float rsl = right - left;
    float tab = top + bottom;
    float tsb = top - bottom;
    float fan = far + near;
    float fsn = far - near;
    myFloat16 float16 =
    {{
        2.0 / rsl, 0.0, 0.0, 0.0,
        0.0, 2.0 / tsb, 0.0, 0.0,
        0.0, 0.0, -2.0 / fsn, 0.0,
        -ral / rsl, -tab / tsb, -fan / fsn, 1.0
    }};
    return float16;
}

- (void)refreshUniformBuffer {
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    myFloat16 ndcMatrix = [self makeOrthographicMatrixWithLeft:0 Right:screenSize.width Bottom:0 Top:screenSize.height Near:-1 Far:1];
    float radius = self.particleRadius;
    float ratio = self.ptmRatio;
    
    int float4x4ByteAlignment = sizeof(float) * 4;
    int float4x4Size = sizeof(float) * 16;
    int paddingBytesSize = float4x4ByteAlignment - sizeof(float) * 2;
    int uniformStructSize = float4x4Size + sizeof(float) * 2 + paddingBytesSize;
    
    // 3
    self.uniformBuffer = [self.mtlDevice newBufferWithLength:uniformStructSize options:MTLResourceStorageModeShared];
    void *bufferPointer = [self.uniformBuffer contents];
    memcpy(bufferPointer, &ndcMatrix, float4x4Size);
    memcpy(bufferPointer + float4x4Size, &ratio, sizeof(float));
    memcpy(bufferPointer + float4x4Size + sizeof(float), &radius, sizeof(float));
}

- (void)buildRenderPipeline {
    id<MTLLibrary> defaultLibrary = [self.mtlDevice newDefaultLibrary];
    id<MTLFunction> fragmentFunc = [defaultLibrary newFunctionWithName:@"basic_fragment"];
    id<MTLFunction> vertexFunc = [defaultLibrary newFunctionWithName:@"particle_vertex"];
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    [pipelineDescriptor setVertexFunction:vertexFunc];
    [pipelineDescriptor setFragmentFunction:fragmentFunc];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    NSError *pipelineErr = nil;
    self.pipelineState = [self.mtlDevice newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&pipelineErr];
    if (pipelineErr == nil) {
        NSLog(@"Error when create pipeline state");
    }
    self.commandQueue = [self.mtlDevice newCommandQueue];
}

- (void)render {
    id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 104.0/255.0, 5.0/255.0, 1.0);
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    if (renderEncoder) {
        [renderEncoder setRenderPipelineState:self.pipelineState];
        [renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
        [renderEncoder setVertexBuffer:self.uniformBuffer offset:0 atIndex:1];
        [renderEncoder drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:self.particleCount instanceCount:1];
        [renderEncoder endEncoding];
    }
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

- (void)updateDisplayLink:(CADisplayLink *)displayLink {
    [waterFun worldStep:displayLink.duration velocityIterations:8 positionIterations:3];
    [self refreshVertexBuffer];
    [self render];
}

@end
