//
//  SPRenderTexture.m
//  Sparrow
//
//  Created by Daniel Sperl on 04.12.10.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPRenderTexture.h"
#import "SPGLTexture.h"
#import "SPMacros.h"
#import "SPOpenGL.h"
#import "SPUtils.h"
#import "SPStage.h"
#import "SparrowClass.h"

@implementation SPRenderTexture
{
    GLuint _framebuffer;
    BOOL   _framebufferIsActive;
    SPRenderSupport *_renderSupport;
}

- (id)initWithWidth:(float)width height:(float)height fillColor:(uint)argb scale:(float)scale
{
    int legalWidth  = [SPUtils nextPowerOfTwo:width  * scale];
    int legalHeight = [SPUtils nextPowerOfTwo:height * scale];
    
    SPRectangle *region = [SPRectangle rectangleWithX:0 y:0 width:width height:height];
    SPGLTexture *glTexture = [[SPGLTexture alloc] initWithData:NULL
                                                         width:legalWidth
                                                        height:legalHeight
                                               generateMipmaps:NO
                                                         scale:scale
                                            premultipliedAlpha:YES];

    if ((self = [super initWithRegion:region ofTexture:glTexture]))
    {
        _renderSupport = [[SPRenderSupport alloc] init];
        
        [self createFramebuffer];
        [self clearWithColor:argb alpha:SP_COLOR_PART_ALPHA(argb)];
    }

    [glTexture release];
    return self;
}

- (id)initWithWidth:(float)width height:(float)height fillColor:(uint)argb
{
    return [self initWithWidth:width height:height fillColor:argb scale:Sparrow.contentScaleFactor];
}

- (id)initWithWidth:(float)width height:(float)height
{
    return [self initWithWidth:width height:height fillColor:0x0];
}

- (id)init
{
    return [self initWithWidth:256 height:256];    
}

- (void)dealloc
{
    [self destroyFramebuffer];

    [_renderSupport release];
    [super dealloc];
}

- (void)createFramebuffer 
{
    int prevFramebuffer = -1;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFramebuffer);

    // create framebuffer
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    // attach renderbuffer
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                              self.baseTexture.name, 0);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        NSLog(@"failed to create frame buffer for render texture");
    
    // unbind frame buffer
    glBindFramebuffer(GL_FRAMEBUFFER, prevFramebuffer);
}

- (void)destroyFramebuffer 
{
    glDeleteFramebuffers(1, &_framebuffer);
    _framebuffer = 0;
}

- (void)renderToFramebuffer:(SPDrawingBlock)block
{
    if (!block) return;
    
    // the block may call a draw-method again, so we're making sure that the frame buffer switching
    // happens only in the outermost block.
    
    int stdFramebuffer = -1;
    int stdViewport[4] = { -1 };
    
    if (!_framebufferIsActive)
    {
        _framebufferIsActive = YES;
        
        // remember standard frame buffer
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &stdFramebuffer);
        glGetIntegerv(GL_VIEWPORT, stdViewport);
        
        // switch to the texture's framebuffer for rendering
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        
        SPTexture *baseTexture = self.baseTexture;
        float width  = baseTexture.width;
        float height = baseTexture.height;
        float scale  = baseTexture.scale;
        
        // prepare viewport and OpenGL matrices
        glViewport(0, 0, width * scale, height * scale);
        [_renderSupport setupOrthographicProjectionWithLeft:0 right:width top:height bottom:0];
    }
    
    block();
    
    if (stdFramebuffer != -1)
    {
        _framebufferIsActive = NO;
        
        [_renderSupport finishQuadBatch];
        [_renderSupport nextFrame];
        
        // return to standard frame buffer
        glBindFramebuffer(GL_FRAMEBUFFER, stdFramebuffer);
        glViewport(stdViewport[0], stdViewport[1], stdViewport[2], stdViewport[3]);
    }
}

- (void)drawObject:(SPDisplayObject *)object
{
    [self renderToFramebuffer:^
     {
         [_renderSupport pushStateWithMatrix:object.transformationMatrix
                                       alpha:object.alpha
                                   blendMode:object.blendMode];
         
         [object render:_renderSupport];
         
         [_renderSupport popState];
     }];
}

- (void)drawBundled:(SPDrawingBlock)block
{
    [self renderToFramebuffer:block];
}

- (void)clearWithColor:(uint)color alpha:(float)alpha
{
    [self renderToFramebuffer:^
     {
         [SPRenderSupport clearWithColor:color alpha:alpha];
     }];
}

+ (id)textureWithWidth:(float)width height:(float)height
{
    return [[[self alloc] initWithWidth:width height:height] autorelease];
}

+ (id)textureWithWidth:(float)width height:(float)height fillColor:(uint)argb
{
    return [[[self alloc] initWithWidth:width height:height fillColor:argb] autorelease];
}

@end
