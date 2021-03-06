//
//  SPEventListener.m
//  Sparrow
//
//  Created by Daniel Sperl on 28.02.13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPEventListener.h"
#import "SPMacros.h"
#import "SPNSExtensions.h"

#import <objc/message.h>

@implementation SPEventListener
{
    SPEventBlock _block;
    id __weak _target;
    SEL _selector;
}

@synthesize target = _target;
@synthesize selector = _selector;

- (id)initWithTarget:(id)target selector:(SEL)selector block:(SPEventBlock)block
{
    if ((self = [super init]))
    {
        _block = [block copy];
        _target = target;
        _selector = selector;
    }
    
    return self;
}

- (id)initWithTarget:(id)target selector:(SEL)selector
{
    __block id weakTarget = target;
    
    return [self initWithTarget:target selector:selector block:^(SPEvent *event)
            {
                objc_msgSend(weakTarget, selector, event);
            }];
}

- (void)dealloc
{
    [_block release];
    [super dealloc];
}

- (id)initWithBlock:(SPEventBlock)block
{
    return [self initWithTarget:nil selector:nil block:block];
}

- (void)invokeWithEvent:(SPEvent *)event
{
    _block(event);
}

- (BOOL)fitsTarget:(id)target andSelector:(SEL)selector orBlock:(SPEventBlock)block
{
    BOOL fitsTargetAndSelector = (target && (target == _target)) && (!selector || (selector == _selector));
    BOOL fitsBlock = block == _block;
    return fitsTargetAndSelector || fitsBlock;
}

@end
