//
//  waterFun.h
//  water
//
//  Created by Wong Tom on 2018-12-15.
//  Copyright © 2018 Wang Tom. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef waterHeader
#define waterHeader

typedef struct Size2D {
    float width;
    float height;
} Size2D;

typedef struct Vector2D {
    float x;
    float y;
} Vector2D;

#endif

@interface waterFun : NSObject
+ (void)destroyWorld;
+ (void)createWorldWithGravity:(Vector2D)gravity;
+ (void *)createParticleSystemWithRadius:(float)radius dampingStrength:(float)dampingStrength
                            gravityScale:(float)gravityScale density:(float)density;
+ (void)createParticleBoxForSystem:(void *)particleSystem
                          position:(Vector2D)position size:(Size2D)size;
+ (int)particleCountForSystem:(void *)particleSystem;
+ (void *)particlePositionsForSystem:(void *)particleSystem;
+ (void)worldStep:(CFTimeInterval)timeStep velocityIterations:(int)velocityIterations positionIterations:(int)positionIterations;
+ (void *)createEdgeBoxWithOrigin:(Vector2D)origin size:(Size2D)size;
+ (void)setGravity:(Vector2D)gravity;
+ (void)setParticleLimitForSystem:(void *)particleSystem maxParticles:(int)maxParticles;
@end

NS_ASSUME_NONNULL_END
