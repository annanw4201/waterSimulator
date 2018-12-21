//
//  waterFun.m
//  water
//
//  Created by Wong Tom on 2018-12-15.
//  Copyright © 2018 Wang Tom. All rights reserved.
//

#import "waterFun.h"
#import "Box2D/Box2D.h"
static b2World *world;

@implementation waterFun

// destroy the world
+ (void)destroyWorld {
    delete world;
    world = nil;
}

// create the world using the gravity provided
+ (void)createWorldWithGravity:(Vector2D)gravity {
    world = new b2World(b2Vec2(gravity.x, gravity.y));
}

// create a particle system which will contains the particles
+ (void *)createParticleSystemWithRadius:(float)radius dampingStrength:(float)dampingStrength gravityScale:(float)gravityScale density:(float)density {
    b2ParticleSystemDef particleSysDef;
    particleSysDef.radius = radius;
    particleSysDef.dampingStrength = dampingStrength;
    particleSysDef.gravityScale = gravityScale;
    particleSysDef.density = density;
    b2ParticleSystem * particleSys = world->CreateParticleSystem(&particleSysDef);
    return particleSys;
}

// create a box of particles for the particle system
+ (void)createParticleBoxForSystem:(void *)particleSystem position:(Vector2D)position size:(Size2D)size {
    b2PolygonShape shape;
    shape.SetAsBox(size.width * 0.5f, size.height * 0.5f);
    
    b2ParticleGroupDef particleGroupDef;
    particleGroupDef.flags = b2_waterParticle;
    particleGroupDef.position.Set(position.x, position.y);
    particleGroupDef.shape = &shape;
    ((b2ParticleSystem *)particleSystem)->CreateParticleGroup(particleGroupDef);
}

// get number of particles inside a particle system
+ (int)particleCountForSystem:(void *)particleSystem {
    return ((b2ParticleSystem *)particleSystem)->GetParticleCount();
}

// returns an array of all particles' positions
+ (void *)particlePositionsForSystem:(void *)particleSystem {
    return ((b2ParticleSystem *)particleSystem)->GetPositionBuffer();
}

// simulate particles' with a time step
+ (void)worldStep:(CFTimeInterval)timeStep velocityIterations:(int)velocityIterations positionIterations:(int)positionIterations {
    world->Step(timeStep, velocityIterations, positionIterations);
}

// create a box with the specified size
+ (void *)createEdgeBoxWithOrigin:(Vector2D)origin size:(Size2D)size {
    // create the body
    b2BodyDef bodyDef;
    bodyDef.position.Set(origin.x, origin.y);
    b2Body *body = world->CreateBody(&bodyDef);
    
    // create the edges of the box
    b2EdgeShape shape;
    
    // bottom
    shape.Set(b2Vec2(0, 0), b2Vec2(size.width, 0));
    body->CreateFixture(&shape, 0);
    
    // top
    shape.Set(b2Vec2(0, size.height), b2Vec2(size.width, size.height));
    body->CreateFixture(&shape, 0);
    
    // left
    shape.Set(b2Vec2(0, size.height), b2Vec2(0, 0));
    body->CreateFixture(&shape, 0);
    
    // right
    shape.Set(b2Vec2(size.width, size.height), b2Vec2(size.width, 0));
    body->CreateFixture(&shape, 0);
    
    return body;
}

// set the gravity of the world
+ (void)setGravity:(Vector2D)gravity {
    world->SetGravity(b2Vec2(gravity.x, gravity.y));
}

// limit the number of particles inside a particle system
+ (void)setParticleLimitForSystem:(void *)particleSystem maxParticles:(int)maxParticles {
    ((b2ParticleSystem *)particleSystem)->SetDestructionByAge(false);
    ((b2ParticleSystem *)particleSystem)->SetMaxParticleCount(maxParticles);
}

@end
