// Copyright © 2019 Artifex Software Inc. All rights reserved.

#import "ARDKViewingState.h"

@implementation ARDKViewingState

- (instancetype)initWithPage:(NSInteger)page offset:(CGPoint)offset scale:(CGFloat)scale
{
    self = [super init];
    if (self)
    {
        _page = page;
        _offset = offset;
        _scale = scale;
    }

    return self;
}

+ (instancetype)stateWithPage:(NSInteger)page offset:(CGPoint)offset scale:(CGFloat)scale
{
    return [[ARDKViewingState alloc] initWithPage:page offset:offset scale:scale];
}

static NSString * const PageKey = @"PageKey";
static NSString * const OffsetKey = @"OffsetKey";
static NSString * const ScaleKey = @"ScaleKey";

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder
{
    [aCoder encodeInteger:_page forKey:PageKey];
    [aCoder encodeCGPoint:_offset forKey:OffsetKey];
    [aCoder encodeDouble:_scale forKey:ScaleKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _page = [aDecoder decodeIntegerForKey:PageKey];
        _offset = [aDecoder decodeCGPointForKey:OffsetKey];
        _scale  = [aDecoder containsValueForKey:ScaleKey] ? [aDecoder decodeDoubleForKey:ScaleKey] : 1.0;
    }

    return self;
}

@end

@implementation ARDKViewingStateStack
{
    NSMutableArray<ARDKViewingState *> *_viewingStates;
    NSInteger _index;
}

- (ARDKViewingState *)viewingState
{
    return _viewingStates[_index];
}

- (BOOL)previousAllowed
{
    return _index > 0;
}

- (BOOL)nextAllowed
{
    return _index < _viewingStates.count - 1;
}

- (void)previous
{
    if (_index > 0)
        _index --;
}

- (void)next
{
    if (_index < _viewingStates.count - 1)
        _index ++;
}

- (void)setViewingState:(ARDKViewingState *)viewState
{
    _viewingStates[_index] = viewState;
}

-(void)push:(ARDKViewingState *)viewingState
{
    _index++;
    if (_viewingStates.count > _index)
        [_viewingStates removeObjectsInRange:NSMakeRange(_index, _viewingStates.count - _index)];

    [_viewingStates addObject:viewingState];
}

-(void)push:(NSInteger)page offset:(CGPoint)offset scale:(CGFloat)scale
{
    [self push:[ARDKViewingState stateWithPage:page offset:offset scale:scale]];
}

static NSString * const ViewingStateArrayKey = @"ViewingStateArrayKey";
static NSString * const IndexKey = @"IndexKey";

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _viewingStates = [NSMutableArray arrayWithCapacity:1];
        [_viewingStates addObject:[ARDKViewingState stateWithPage:0 offset:CGPointMake(0, 0) scale:1.0]];
        _index = 0;
    }

    return self;
}

+ (instancetype)viewingStateStack
{
    return [[ARDKViewingStateStack alloc] init];
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder
{
    [aCoder encodeObject:_viewingStates forKey:ViewingStateArrayKey];
    [aCoder encodeInteger:_index forKey:IndexKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _viewingStates = [aDecoder decodeObjectForKey:ViewingStateArrayKey];
        _index = [aDecoder decodeIntegerForKey:IndexKey];
    }

    return self;
}

@end
