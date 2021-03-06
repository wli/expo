/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI21_0_0RCTShadowView.h"

#import "ABI21_0_0RCTConvert.h"
#import "ABI21_0_0RCTLog.h"
#import "ABI21_0_0RCTUtils.h"
#import "ABI21_0_0UIView+Private.h"
#import "UIView+ReactABI21_0_0.h"

typedef void (^ABI21_0_0RCTActionBlock)(ABI21_0_0RCTShadowView *shadowViewSelf, id value);
typedef void (^ABI21_0_0RCTResetActionBlock)(ABI21_0_0RCTShadowView *shadowViewSelf);

static NSString *const ABI21_0_0RCTBackgroundColorProp = @"backgroundColor";

typedef NS_ENUM(unsigned int, meta_prop_t) {
  META_PROP_LEFT,
  META_PROP_TOP,
  META_PROP_RIGHT,
  META_PROP_BOTTOM,
  META_PROP_HORIZONTAL,
  META_PROP_VERTICAL,
  META_PROP_ALL,
  META_PROP_COUNT,
};

@implementation ABI21_0_0RCTShadowView
{
  ABI21_0_0RCTUpdateLifecycle _propagationLifecycle;
  ABI21_0_0RCTUpdateLifecycle _textLifecycle;
  NSDictionary *_lastParentProperties;
  NSMutableArray<ABI21_0_0RCTShadowView *> *_ReactABI21_0_0Subviews;
  BOOL _recomputePadding;
  BOOL _recomputeMargin;
  BOOL _recomputeBorder;
  BOOL _didUpdateSubviews;
  ABI21_0_0YGValue _paddingMetaProps[META_PROP_COUNT];
  ABI21_0_0YGValue _marginMetaProps[META_PROP_COUNT];
  ABI21_0_0YGValue _borderMetaProps[META_PROP_COUNT];
}

+ (ABI21_0_0YGConfigRef)yogaConfig
{
  static ABI21_0_0YGConfigRef yogaConfig;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    yogaConfig = ABI21_0_0YGConfigNew();
    // Turnig off pixel rounding.
    ABI21_0_0YGConfigSetPointScaleFactor(yogaConfig, 0.0);
    ABI21_0_0YGConfigSetUseLegacyStretchBehaviour(yogaConfig, true);
  });
  return yogaConfig;
}

@synthesize ReactABI21_0_0Tag = _ReactABI21_0_0Tag;

// YogaNode API

static void ABI21_0_0RCTPrint(ABI21_0_0YGNodeRef node)
{
  ABI21_0_0RCTShadowView *shadowView = (__bridge ABI21_0_0RCTShadowView *)ABI21_0_0YGNodeGetContext(node);
  printf("%s(%zd), ", shadowView.viewName.UTF8String, shadowView.ReactABI21_0_0Tag.integerValue);
}

#define ABI21_0_0RCT_SET_ABI21_0_0YGVALUE(ygvalue, setter, ...)    \
switch (ygvalue.unit) {                          \
  case ABI21_0_0YGUnitAuto:                               \
  case ABI21_0_0YGUnitUndefined:                          \
    setter(__VA_ARGS__, ABI21_0_0YGUndefined);            \
    break;                                       \
  case ABI21_0_0YGUnitPoint:                              \
    setter(__VA_ARGS__, ygvalue.value);          \
    break;                                       \
  case ABI21_0_0YGUnitPercent:                            \
    setter##Percent(__VA_ARGS__, ygvalue.value); \
    break;                                       \
}

#define ABI21_0_0RCT_SET_ABI21_0_0YGVALUE_AUTO(ygvalue, setter, ...) \
switch (ygvalue.unit) {                            \
  case ABI21_0_0YGUnitAuto:                                 \
    setter##Auto(__VA_ARGS__);                     \
    break;                                         \
  case ABI21_0_0YGUnitUndefined:                            \
    setter(__VA_ARGS__, ABI21_0_0YGUndefined);              \
    break;                                         \
  case ABI21_0_0YGUnitPoint:                                \
    setter(__VA_ARGS__, ygvalue.value);            \
    break;                                         \
  case ABI21_0_0YGUnitPercent:                              \
    setter##Percent(__VA_ARGS__, ygvalue.value);   \
    break;                                         \
}

static void ABI21_0_0RCTProcessMetaPropsPadding(const ABI21_0_0YGValue metaProps[META_PROP_COUNT], ABI21_0_0YGNodeRef node) {
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE(metaProps[META_PROP_LEFT], ABI21_0_0YGNodeStyleSetPadding, node, ABI21_0_0YGEdgeStart);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE(metaProps[META_PROP_RIGHT], ABI21_0_0YGNodeStyleSetPadding, node, ABI21_0_0YGEdgeEnd);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE(metaProps[META_PROP_TOP], ABI21_0_0YGNodeStyleSetPadding, node, ABI21_0_0YGEdgeTop);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE(metaProps[META_PROP_BOTTOM], ABI21_0_0YGNodeStyleSetPadding, node, ABI21_0_0YGEdgeBottom);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE(metaProps[META_PROP_HORIZONTAL], ABI21_0_0YGNodeStyleSetPadding, node, ABI21_0_0YGEdgeHorizontal);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE(metaProps[META_PROP_VERTICAL], ABI21_0_0YGNodeStyleSetPadding, node, ABI21_0_0YGEdgeVertical);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE(metaProps[META_PROP_ALL], ABI21_0_0YGNodeStyleSetPadding, node, ABI21_0_0YGEdgeAll);
}

static void ABI21_0_0RCTProcessMetaPropsMargin(const ABI21_0_0YGValue metaProps[META_PROP_COUNT], ABI21_0_0YGNodeRef node) {
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE_AUTO(metaProps[META_PROP_LEFT], ABI21_0_0YGNodeStyleSetMargin, node, ABI21_0_0YGEdgeStart);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE_AUTO(metaProps[META_PROP_RIGHT], ABI21_0_0YGNodeStyleSetMargin, node, ABI21_0_0YGEdgeEnd);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE_AUTO(metaProps[META_PROP_TOP], ABI21_0_0YGNodeStyleSetMargin, node, ABI21_0_0YGEdgeTop);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE_AUTO(metaProps[META_PROP_BOTTOM], ABI21_0_0YGNodeStyleSetMargin, node, ABI21_0_0YGEdgeBottom);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE_AUTO(metaProps[META_PROP_HORIZONTAL], ABI21_0_0YGNodeStyleSetMargin, node, ABI21_0_0YGEdgeHorizontal);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE_AUTO(metaProps[META_PROP_VERTICAL], ABI21_0_0YGNodeStyleSetMargin, node, ABI21_0_0YGEdgeVertical);
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE_AUTO(metaProps[META_PROP_ALL], ABI21_0_0YGNodeStyleSetMargin, node, ABI21_0_0YGEdgeAll);
}

static void ABI21_0_0RCTProcessMetaPropsBorder(const ABI21_0_0YGValue metaProps[META_PROP_COUNT], ABI21_0_0YGNodeRef node) {
  ABI21_0_0YGNodeStyleSetBorder(node, ABI21_0_0YGEdgeStart, metaProps[META_PROP_LEFT].value);
  ABI21_0_0YGNodeStyleSetBorder(node, ABI21_0_0YGEdgeEnd, metaProps[META_PROP_RIGHT].value);
  ABI21_0_0YGNodeStyleSetBorder(node, ABI21_0_0YGEdgeTop, metaProps[META_PROP_TOP].value);
  ABI21_0_0YGNodeStyleSetBorder(node, ABI21_0_0YGEdgeBottom, metaProps[META_PROP_BOTTOM].value);
  ABI21_0_0YGNodeStyleSetBorder(node, ABI21_0_0YGEdgeHorizontal, metaProps[META_PROP_HORIZONTAL].value);
  ABI21_0_0YGNodeStyleSetBorder(node, ABI21_0_0YGEdgeVertical, metaProps[META_PROP_VERTICAL].value);
  ABI21_0_0YGNodeStyleSetBorder(node, ABI21_0_0YGEdgeAll, metaProps[META_PROP_ALL].value);
}

// The absolute stuff is so that we can take into account our absolute position when rounding in order to
// snap to the pixel grid. For example, say you have the following structure:
//
// +--------+---------+--------+
// |        |+-------+|        |
// |        ||       ||        |
// |        |+-------+|        |
// +--------+---------+--------+
//
// Say the screen width is 320 pts so the three big views will get the following x bounds from our layout system:
// {0, 106.667}, {106.667, 213.333}, {213.333, 320}
//
// Assuming screen scale is 2, these numbers must be rounded to the nearest 0.5 to fit the pixel grid:
// {0, 106.5}, {106.5, 213.5}, {213.5, 320}
// You'll notice that the three widths are 106.5, 107, 106.5.
//
// This is great for the parent views but it gets trickier when we consider rounding for the subview.
//
// When we go to round the bounds for the subview in the middle, it's relative bounds are {0, 106.667}
// which gets rounded to {0, 106.5}. This will cause the subview to be one pixel smaller than it should be.
// this is why we need to pass in the absolute position in order to do the rounding relative to the screen's
// grid rather than the view's grid.
//
// After passing in the absolutePosition of {106.667, y}, we do the following calculations:
// absoluteLeft = round(absolutePosition.x + viewPosition.left) = round(106.667 + 0) = 106.5
// absoluteRight = round(absolutePosition.x + viewPosition.left + viewSize.left) + round(106.667 + 0 + 106.667) = 213.5
// width = 213.5 - 106.5 = 107
// You'll notice that this is the same width we calculated for the parent view because we've taken its position into account.

- (void)applyLayoutNode:(ABI21_0_0YGNodeRef)node
      viewsWithNewFrame:(NSMutableSet<ABI21_0_0RCTShadowView *> *)viewsWithNewFrame
       absolutePosition:(CGPoint)absolutePosition
{
  if (!ABI21_0_0YGNodeGetHasNewLayout(node)) {
    return;
  }

  ABI21_0_0RCTAssert(!ABI21_0_0YGNodeIsDirty(node), @"Attempt to get layout metrics from dirtied Yoga node.");

  ABI21_0_0YGNodeSetHasNewLayout(node, false);

  if (ABI21_0_0YGNodeStyleGetDisplay(node) == ABI21_0_0YGDisplayNone) {
    // If the node is hidden (has `display: none;`), its (and its descendants)
    // layout metrics are invalid and/or dirtied, so we have to stop here.
    return;
  }

#if ABI21_0_0RCT_DEBUG
  // This works around a breaking change in Yoga layout where setting flexBasis needs to be set explicitly, instead of relying on flex to propagate.
  // We check for it by seeing if a width/height is provided along with a flexBasis of 0 and the width/height is laid out as 0.
  if (ABI21_0_0YGNodeStyleGetFlexBasis(node).unit == ABI21_0_0YGUnitPoint && ABI21_0_0YGNodeStyleGetFlexBasis(node).value == 0 &&
      ((ABI21_0_0YGNodeStyleGetWidth(node).unit == ABI21_0_0YGUnitPoint && ABI21_0_0YGNodeStyleGetWidth(node).value > 0 && ABI21_0_0YGNodeLayoutGetWidth(node) == 0) ||
      (ABI21_0_0YGNodeStyleGetHeight(node).unit == ABI21_0_0YGUnitPoint && ABI21_0_0YGNodeStyleGetHeight(node).value > 0 && ABI21_0_0YGNodeLayoutGetHeight(node) == 0))) {
    ABI21_0_0RCTLogError(@"View was rendered with explicitly set width/height but with a 0 flexBasis. (This might be fixed by changing flex: to flexGrow:) View: %@", self);
  }
#endif

  CGPoint absoluteTopLeft = {
    absolutePosition.x + ABI21_0_0YGNodeLayoutGetLeft(node),
    absolutePosition.y + ABI21_0_0YGNodeLayoutGetTop(node)
  };

  CGPoint absoluteBottomRight = {
    absolutePosition.x + ABI21_0_0YGNodeLayoutGetLeft(node) + ABI21_0_0YGNodeLayoutGetWidth(node),
    absolutePosition.y + ABI21_0_0YGNodeLayoutGetTop(node) + ABI21_0_0YGNodeLayoutGetHeight(node)
  };

  CGRect frame = {{
    ABI21_0_0RCTRoundPixelValue(ABI21_0_0YGNodeLayoutGetLeft(node)),
    ABI21_0_0RCTRoundPixelValue(ABI21_0_0YGNodeLayoutGetTop(node)),
  }, {
    ABI21_0_0RCTRoundPixelValue(absoluteBottomRight.x - absoluteTopLeft.x),
    ABI21_0_0RCTRoundPixelValue(absoluteBottomRight.y - absoluteTopLeft.y)
  }};

  if (!CGRectEqualToRect(frame, _frame)) {
    _frame = frame;
    [viewsWithNewFrame addObject:self];
  }

  absolutePosition.x += ABI21_0_0YGNodeLayoutGetLeft(node);
  absolutePosition.y += ABI21_0_0YGNodeLayoutGetTop(node);

  [self applyLayoutToChildren:node viewsWithNewFrame:viewsWithNewFrame absolutePosition:absolutePosition];
}

- (void)applyLayoutToChildren:(ABI21_0_0YGNodeRef)node
            viewsWithNewFrame:(NSMutableSet<ABI21_0_0RCTShadowView *> *)viewsWithNewFrame
             absolutePosition:(CGPoint)absolutePosition
{
  for (unsigned int i = 0; i < ABI21_0_0YGNodeGetChildCount(node); ++i) {
    ABI21_0_0RCTShadowView *child = (ABI21_0_0RCTShadowView *)_ReactABI21_0_0Subviews[i];
    [child applyLayoutNode:ABI21_0_0YGNodeGetChild(node, i)
         viewsWithNewFrame:viewsWithNewFrame
          absolutePosition:absolutePosition];
  }
}

- (NSDictionary<NSString *, id> *)processUpdatedProperties:(NSMutableSet<ABI21_0_0RCTApplierBlock> *)applierBlocks
                                          parentProperties:(NSDictionary<NSString *, id> *)parentProperties
{
  // TODO: we always refresh all propagated properties when propagation is
  // dirtied, but really we should track which properties have changed and
  // only update those.

  if (_didUpdateSubviews) {
    _didUpdateSubviews = NO;
    [self didUpdateReactABI21_0_0Subviews];
    [applierBlocks addObject:^(NSDictionary<NSNumber *, UIView *> *viewRegistry) {
      UIView *view = viewRegistry[self->_ReactABI21_0_0Tag];
      [view didUpdateReactABI21_0_0Subviews];
    }];
  }

  if (!_backgroundColor) {
    UIColor *parentBackgroundColor = parentProperties[ABI21_0_0RCTBackgroundColorProp];
    if (parentBackgroundColor) {
      [applierBlocks addObject:^(NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        UIView *view = viewRegistry[self->_ReactABI21_0_0Tag];
        [view ReactABI21_0_0SetInheritedBackgroundColor:parentBackgroundColor];
      }];
    }
  } else {
    // Update parent properties for children
    NSMutableDictionary<NSString *, id> *properties = [NSMutableDictionary dictionaryWithDictionary:parentProperties];
    CGFloat alpha = CGColorGetAlpha(_backgroundColor.CGColor);
    if (alpha < 1.0) {
      // If bg is non-opaque, don't propagate further
      properties[ABI21_0_0RCTBackgroundColorProp] = [UIColor clearColor];
    } else {
      properties[ABI21_0_0RCTBackgroundColorProp] = _backgroundColor;
    }
    return properties;
  }
  return parentProperties;
}

- (void)collectUpdatedProperties:(NSMutableSet<ABI21_0_0RCTApplierBlock> *)applierBlocks
                parentProperties:(NSDictionary<NSString *, id> *)parentProperties
{
  if (_propagationLifecycle == ABI21_0_0RCTUpdateLifecycleComputed && [parentProperties isEqualToDictionary:_lastParentProperties]) {
    return;
  }
  _propagationLifecycle = ABI21_0_0RCTUpdateLifecycleComputed;
  _lastParentProperties = parentProperties;
  NSDictionary<NSString *, id> *nextProps = [self processUpdatedProperties:applierBlocks parentProperties:parentProperties];
  for (ABI21_0_0RCTShadowView *child in _ReactABI21_0_0Subviews) {
    [child collectUpdatedProperties:applierBlocks parentProperties:nextProps];
  }
}

- (void)collectUpdatedFrames:(NSMutableSet<ABI21_0_0RCTShadowView *> *)viewsWithNewFrame
                   withFrame:(CGRect)frame
                      hidden:(BOOL)hidden
            absolutePosition:(CGPoint)absolutePosition
{
  // This is not the core layout method. It is only used by ABI21_0_0RCTShadowText to layout
  // nested views.

  if (_hidden != hidden) {
    // The hidden state has changed. Even if the frame hasn't changed, add
    // this ShadowView to viewsWithNewFrame so the UIManager will process
    // this ShadowView's UIView and update its hidden state.
    _hidden = hidden;
    [viewsWithNewFrame addObject:self];
  }

  if (!CGRectEqualToRect(frame, _frame)) {
    ABI21_0_0YGNodeStyleSetPositionType(_yogaNode, ABI21_0_0YGPositionTypeAbsolute);
    ABI21_0_0YGNodeStyleSetWidth(_yogaNode, frame.size.width);
    ABI21_0_0YGNodeStyleSetHeight(_yogaNode, frame.size.height);
    ABI21_0_0YGNodeStyleSetPosition(_yogaNode, ABI21_0_0YGEdgeLeft, frame.origin.x);
    ABI21_0_0YGNodeStyleSetPosition(_yogaNode, ABI21_0_0YGEdgeTop, frame.origin.y);
  }

  ABI21_0_0YGNodeCalculateLayout(_yogaNode, frame.size.width, frame.size.height, ABI21_0_0YGDirectionInherit);
  [self applyLayoutNode:_yogaNode viewsWithNewFrame:viewsWithNewFrame absolutePosition:absolutePosition];
}

- (CGRect)measureLayoutRelativeToAncestor:(ABI21_0_0RCTShadowView *)ancestor
{
  CGPoint offset = CGPointZero;
  NSInteger depth = 30; // max depth to search
  ABI21_0_0RCTShadowView *shadowView = self;
  while (depth && shadowView && shadowView != ancestor) {
    offset.x += shadowView.frame.origin.x;
    offset.y += shadowView.frame.origin.y;
    shadowView = shadowView->_superview;
    depth--;
  }
  if (ancestor != shadowView) {
    return CGRectNull;
  }
  return (CGRect){offset, self.frame.size};
}

- (BOOL)viewIsDescendantOf:(ABI21_0_0RCTShadowView *)ancestor
{
  NSInteger depth = 30; // max depth to search
  ABI21_0_0RCTShadowView *shadowView = self;
  while (depth && shadowView && shadowView != ancestor) {
    shadowView = shadowView->_superview;
    depth--;
  }
  return ancestor == shadowView;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _frame = CGRectMake(0, 0, ABI21_0_0YGUndefined, ABI21_0_0YGUndefined);

    for (unsigned int ii = 0; ii < META_PROP_COUNT; ii++) {
      _paddingMetaProps[ii] = ABI21_0_0YGValueUndefined;
      _marginMetaProps[ii] = ABI21_0_0YGValueUndefined;
      _borderMetaProps[ii] = ABI21_0_0YGValueUndefined;
    }

    _intrinsicContentSize = CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric);

    _newView = YES;
    _propagationLifecycle = ABI21_0_0RCTUpdateLifecycleUninitialized;
    _textLifecycle = ABI21_0_0RCTUpdateLifecycleUninitialized;

    _ReactABI21_0_0Subviews = [NSMutableArray array];

    _yogaNode = ABI21_0_0YGNodeNewWithConfig([[self class] yogaConfig]);
    ABI21_0_0YGNodeSetContext(_yogaNode, (__bridge void *)self);
    ABI21_0_0YGNodeSetPrintFunc(_yogaNode, ABI21_0_0RCTPrint);
  }
  return self;
}

- (BOOL)isReactABI21_0_0RootView
{
  return ABI21_0_0RCTIsReactABI21_0_0RootView(self.ReactABI21_0_0Tag);
}

- (void)dealloc
{
  ABI21_0_0YGNodeFree(_yogaNode);
}

- (BOOL)canHaveSubviews
{
  return NO;
}

- (BOOL)isYogaLeafNode
{
  return NO;
}

- (void)dirtyPropagation
{
  if (_propagationLifecycle != ABI21_0_0RCTUpdateLifecycleDirtied) {
    _propagationLifecycle = ABI21_0_0RCTUpdateLifecycleDirtied;
    [_superview dirtyPropagation];
  }
}

- (BOOL)isPropagationDirty
{
  return _propagationLifecycle != ABI21_0_0RCTUpdateLifecycleComputed;
}

- (void)dirtyText
{
  if (_textLifecycle != ABI21_0_0RCTUpdateLifecycleDirtied) {
    _textLifecycle = ABI21_0_0RCTUpdateLifecycleDirtied;
    [_superview dirtyText];
  }
}

- (BOOL)isTextDirty
{
  return _textLifecycle != ABI21_0_0RCTUpdateLifecycleComputed;
}

- (void)setTextComputed
{
  _textLifecycle = ABI21_0_0RCTUpdateLifecycleComputed;
}

- (void)insertReactABI21_0_0Subview:(ABI21_0_0RCTShadowView *)subview atIndex:(NSInteger)atIndex
{
  ABI21_0_0RCTAssert(!self.canHaveSubviews, @"Attempt to insert subview inside leaf view.");

  [_ReactABI21_0_0Subviews insertObject:subview atIndex:atIndex];
  if (![self isYogaLeafNode]) {
    ABI21_0_0YGNodeInsertChild(_yogaNode, subview.yogaNode, (uint32_t)atIndex);
  }
  subview->_superview = self;
  _didUpdateSubviews = YES;
  [self dirtyText];
  [self dirtyPropagation];
}

- (void)removeReactABI21_0_0Subview:(ABI21_0_0RCTShadowView *)subview
{
  [subview dirtyText];
  [subview dirtyPropagation];
  _didUpdateSubviews = YES;
  subview->_superview = nil;
  [_ReactABI21_0_0Subviews removeObject:subview];
  if (![self isYogaLeafNode]) {
    ABI21_0_0YGNodeRemoveChild(_yogaNode, subview.yogaNode);
  }
}

- (NSArray<ABI21_0_0RCTShadowView *> *)ReactABI21_0_0Subviews
{
  return _ReactABI21_0_0Subviews;
}

- (ABI21_0_0RCTShadowView *)ReactABI21_0_0Superview
{
  return _superview;
}

- (NSNumber *)ReactABI21_0_0TagAtPoint:(CGPoint)point
{
  for (ABI21_0_0RCTShadowView *shadowView in _ReactABI21_0_0Subviews) {
    if (CGRectContainsPoint(shadowView.frame, point)) {
      CGPoint relativePoint = point;
      CGPoint origin = shadowView.frame.origin;
      relativePoint.x -= origin.x;
      relativePoint.y -= origin.y;
      return [shadowView ReactABI21_0_0TagAtPoint:relativePoint];
    }
  }
  return self.ReactABI21_0_0Tag;
}

- (NSString *)description
{
  NSString *description = super.description;
  description = [[description substringToIndex:description.length - 1] stringByAppendingFormat:@"; viewName: %@; ReactABI21_0_0Tag: %@; frame: %@>", self.viewName, self.ReactABI21_0_0Tag, NSStringFromCGRect(self.frame)];
  return description;
}

- (void)addRecursiveDescriptionToString:(NSMutableString *)string atLevel:(NSUInteger)level
{
  for (NSUInteger i = 0; i < level; i++) {
    [string appendString:@"  | "];
  }

  [string appendString:self.description];
  [string appendString:@"\n"];

  for (ABI21_0_0RCTShadowView *subview in _ReactABI21_0_0Subviews) {
    [subview addRecursiveDescriptionToString:string atLevel:level + 1];
  }
}

- (NSString *)recursiveDescription
{
  NSMutableString *description = [NSMutableString string];
  [self addRecursiveDescriptionToString:description atLevel:0];
  return description;
}

// Layout Direction

- (UIUserInterfaceLayoutDirection)effectiveLayoutDirection {
  // Even if `ABI21_0_0YGNodeLayoutGetDirection` can return `ABI21_0_0YGDirectionInherit` here, it actually means
  // that Yoga will use LTR layout for the view (even if layout process is not finished yet).
  return ABI21_0_0YGNodeLayoutGetDirection(_yogaNode) == ABI21_0_0YGDirectionRTL ? UIUserInterfaceLayoutDirectionRightToLeft : UIUserInterfaceLayoutDirectionLeftToRight;
}

// Margin

#define ABI21_0_0RCT_MARGIN_PROPERTY(prop, metaProp)       \
- (void)setMargin##prop:(ABI21_0_0YGValue)value            \
{                                                 \
  _marginMetaProps[META_PROP_##metaProp] = value; \
  _recomputeMargin = YES;                         \
}                                                 \
- (ABI21_0_0YGValue)margin##prop                           \
{                                                 \
  return _marginMetaProps[META_PROP_##metaProp];  \
}

ABI21_0_0RCT_MARGIN_PROPERTY(, ALL)
ABI21_0_0RCT_MARGIN_PROPERTY(Vertical, VERTICAL)
ABI21_0_0RCT_MARGIN_PROPERTY(Horizontal, HORIZONTAL)
ABI21_0_0RCT_MARGIN_PROPERTY(Top, TOP)
ABI21_0_0RCT_MARGIN_PROPERTY(Left, LEFT)
ABI21_0_0RCT_MARGIN_PROPERTY(Bottom, BOTTOM)
ABI21_0_0RCT_MARGIN_PROPERTY(Right, RIGHT)

// Padding

#define ABI21_0_0RCT_PADDING_PROPERTY(prop, metaProp)       \
- (void)setPadding##prop:(ABI21_0_0YGValue)value            \
{                                                  \
  _paddingMetaProps[META_PROP_##metaProp] = value; \
  _recomputePadding = YES;                         \
}                                                  \
- (ABI21_0_0YGValue)padding##prop                           \
{                                                  \
  return _paddingMetaProps[META_PROP_##metaProp];  \
}

ABI21_0_0RCT_PADDING_PROPERTY(, ALL)
ABI21_0_0RCT_PADDING_PROPERTY(Vertical, VERTICAL)
ABI21_0_0RCT_PADDING_PROPERTY(Horizontal, HORIZONTAL)
ABI21_0_0RCT_PADDING_PROPERTY(Top, TOP)
ABI21_0_0RCT_PADDING_PROPERTY(Left, LEFT)
ABI21_0_0RCT_PADDING_PROPERTY(Bottom, BOTTOM)
ABI21_0_0RCT_PADDING_PROPERTY(Right, RIGHT)

// Border

#define ABI21_0_0RCT_BORDER_PROPERTY(prop, metaProp)             \
- (void)setBorder##prop##Width:(float)value             \
{                                                       \
  _borderMetaProps[META_PROP_##metaProp].value = value; \
  _recomputeBorder = YES;                               \
}                                                       \
- (float)border##prop##Width                            \
{                                                       \
  return _borderMetaProps[META_PROP_##metaProp].value;  \
}

ABI21_0_0RCT_BORDER_PROPERTY(, ALL)
ABI21_0_0RCT_BORDER_PROPERTY(Top, TOP)
ABI21_0_0RCT_BORDER_PROPERTY(Left, LEFT)
ABI21_0_0RCT_BORDER_PROPERTY(Bottom, BOTTOM)
ABI21_0_0RCT_BORDER_PROPERTY(Right, RIGHT)

// Dimensions
#define ABI21_0_0RCT_DIMENSION_PROPERTY(setProp, getProp, cssProp)           \
- (void)set##setProp:(ABI21_0_0YGValue)value                                 \
{                                                                   \
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE_AUTO(value, ABI21_0_0YGNodeStyleSet##cssProp, _yogaNode);  \
  [self dirtyText];                                                 \
}                                                                   \
- (ABI21_0_0YGValue)getProp                                                  \
{                                                                   \
  return ABI21_0_0YGNodeStyleGet##cssProp(_yogaNode);                        \
}

#define ABI21_0_0RCT_MIN_MAX_DIMENSION_PROPERTY(setProp, getProp, cssProp)   \
- (void)set##setProp:(ABI21_0_0YGValue)value                                 \
{                                                                   \
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE(value, ABI21_0_0YGNodeStyleSet##cssProp, _yogaNode);       \
  [self dirtyText];                                                 \
}                                                                   \
- (ABI21_0_0YGValue)getProp                                                  \
{                                                                   \
  return ABI21_0_0YGNodeStyleGet##cssProp(_yogaNode);                        \
}

ABI21_0_0RCT_DIMENSION_PROPERTY(Width, width, Width)
ABI21_0_0RCT_DIMENSION_PROPERTY(Height, height, Height)
ABI21_0_0RCT_MIN_MAX_DIMENSION_PROPERTY(MinWidth, minWidth, MinWidth)
ABI21_0_0RCT_MIN_MAX_DIMENSION_PROPERTY(MinHeight, minHeight, MinHeight)
ABI21_0_0RCT_MIN_MAX_DIMENSION_PROPERTY(MaxWidth, maxWidth, MaxWidth)
ABI21_0_0RCT_MIN_MAX_DIMENSION_PROPERTY(MaxHeight, maxHeight, MaxHeight)

// Position

#define ABI21_0_0RCT_POSITION_PROPERTY(setProp, getProp, edge)               \
- (void)set##setProp:(ABI21_0_0YGValue)value                                 \
{                                                                   \
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE(value, ABI21_0_0YGNodeStyleSetPosition, _yogaNode, edge);  \
  [self dirtyText];                                                 \
}                                                                   \
- (ABI21_0_0YGValue)getProp                                                  \
{                                                                   \
  return ABI21_0_0YGNodeStyleGetPosition(_yogaNode, edge);                   \
}

ABI21_0_0RCT_POSITION_PROPERTY(Top, top, ABI21_0_0YGEdgeTop)
ABI21_0_0RCT_POSITION_PROPERTY(Right, right, ABI21_0_0YGEdgeEnd)
ABI21_0_0RCT_POSITION_PROPERTY(Bottom, bottom, ABI21_0_0YGEdgeBottom)
ABI21_0_0RCT_POSITION_PROPERTY(Left, left, ABI21_0_0YGEdgeStart)

// Size

- (CGSize)size
{
  ABI21_0_0YGValue width = ABI21_0_0YGNodeStyleGetWidth(_yogaNode);
  ABI21_0_0YGValue height = ABI21_0_0YGNodeStyleGetHeight(_yogaNode);

  return CGSizeMake(
    width.unit == ABI21_0_0YGUnitPoint ? width.value : NAN,
    height.unit == ABI21_0_0YGUnitPoint ? height.value : NAN
  );
}

- (void)setSize:(CGSize)size
{
  ABI21_0_0YGNodeStyleSetWidth(_yogaNode, size.width);
  ABI21_0_0YGNodeStyleSetHeight(_yogaNode, size.height);
}

// IntrinsicContentSize

static inline ABI21_0_0YGSize ABI21_0_0RCTShadowViewMeasure(ABI21_0_0YGNodeRef node, float width, ABI21_0_0YGMeasureMode widthMode, float height, ABI21_0_0YGMeasureMode heightMode)
{
  ABI21_0_0RCTShadowView *shadowView = (__bridge ABI21_0_0RCTShadowView *)ABI21_0_0YGNodeGetContext(node);

  CGSize intrinsicContentSize = shadowView->_intrinsicContentSize;
  // Replace `UIViewNoIntrinsicMetric` (which equals `-1`) with zero.
  intrinsicContentSize.width = MAX(0, intrinsicContentSize.width);
  intrinsicContentSize.height = MAX(0, intrinsicContentSize.height);

  ABI21_0_0YGSize result;

  switch (widthMode) {
    case ABI21_0_0YGMeasureModeUndefined:
      result.width = intrinsicContentSize.width;
      break;
    case ABI21_0_0YGMeasureModeExactly:
      result.width = width;
      break;
    case ABI21_0_0YGMeasureModeAtMost:
      result.width = MIN(width, intrinsicContentSize.width);
      break;
  }

  switch (heightMode) {
    case ABI21_0_0YGMeasureModeUndefined:
      result.height = intrinsicContentSize.height;
      break;
    case ABI21_0_0YGMeasureModeExactly:
      result.height = height;
      break;
    case ABI21_0_0YGMeasureModeAtMost:
      result.height = MIN(height, intrinsicContentSize.height);
      break;
  }

  return result;
}

- (void)setIntrinsicContentSize:(CGSize)intrinsicContentSize
{
  if (CGSizeEqualToSize(_intrinsicContentSize, intrinsicContentSize)) {
    return;
  }

  _intrinsicContentSize = intrinsicContentSize;

  if (CGSizeEqualToSize(_intrinsicContentSize, CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric))) {
    ABI21_0_0YGNodeSetMeasureFunc(_yogaNode, NULL);
  } else {
    ABI21_0_0YGNodeSetMeasureFunc(_yogaNode, ABI21_0_0RCTShadowViewMeasure);
  }

  ABI21_0_0YGNodeMarkDirty(_yogaNode);
}

// Flex

- (void)setFlexBasis:(ABI21_0_0YGValue)value
{
  ABI21_0_0RCT_SET_ABI21_0_0YGVALUE_AUTO(value, ABI21_0_0YGNodeStyleSetFlexBasis, _yogaNode);
}

- (ABI21_0_0YGValue)flexBasis
{
  return ABI21_0_0YGNodeStyleGetFlexBasis(_yogaNode);
}

#define ABI21_0_0RCT_STYLE_PROPERTY(setProp, getProp, cssProp, type) \
- (void)set##setProp:(type)value                            \
{                                                           \
  ABI21_0_0YGNodeStyleSet##cssProp(_yogaNode, value);                \
}                                                           \
- (type)getProp                                             \
{                                                           \
  return ABI21_0_0YGNodeStyleGet##cssProp(_yogaNode);                \
}

ABI21_0_0RCT_STYLE_PROPERTY(Flex, flex, Flex, float)
ABI21_0_0RCT_STYLE_PROPERTY(FlexGrow, flexGrow, FlexGrow, float)
ABI21_0_0RCT_STYLE_PROPERTY(FlexShrink, flexShrink, FlexShrink, float)
ABI21_0_0RCT_STYLE_PROPERTY(FlexDirection, flexDirection, FlexDirection, ABI21_0_0YGFlexDirection)
ABI21_0_0RCT_STYLE_PROPERTY(JustifyContent, justifyContent, JustifyContent, ABI21_0_0YGJustify)
ABI21_0_0RCT_STYLE_PROPERTY(AlignSelf, alignSelf, AlignSelf, ABI21_0_0YGAlign)
ABI21_0_0RCT_STYLE_PROPERTY(AlignItems, alignItems, AlignItems, ABI21_0_0YGAlign)
ABI21_0_0RCT_STYLE_PROPERTY(AlignContent, alignContent, AlignContent, ABI21_0_0YGAlign)
ABI21_0_0RCT_STYLE_PROPERTY(Position, position, PositionType, ABI21_0_0YGPositionType)
ABI21_0_0RCT_STYLE_PROPERTY(FlexWrap, flexWrap, FlexWrap, ABI21_0_0YGWrap)
ABI21_0_0RCT_STYLE_PROPERTY(Overflow, overflow, Overflow, ABI21_0_0YGOverflow)
ABI21_0_0RCT_STYLE_PROPERTY(Display, display, Display, ABI21_0_0YGDisplay)
ABI21_0_0RCT_STYLE_PROPERTY(Direction, direction, Direction, ABI21_0_0YGDirection)
ABI21_0_0RCT_STYLE_PROPERTY(AspectRatio, aspectRatio, AspectRatio, float)

- (void)setBackgroundColor:(UIColor *)color
{
  _backgroundColor = color;
  [self dirtyPropagation];
}

- (void)setZIndex:(NSInteger)zIndex
{
  _zIndex = zIndex;
  if (_superview) {
    // Changing zIndex means the subview order of the parent needs updating
    _superview->_didUpdateSubviews = YES;
    [_superview dirtyPropagation];
  }
}

- (void)didUpdateReactABI21_0_0Subviews
{
  // Does nothing by default
}

- (void)didSetProps:(__unused NSArray<NSString *> *)changedProps
{
  if (_recomputePadding) {
    ABI21_0_0RCTProcessMetaPropsPadding(_paddingMetaProps, _yogaNode);
  }
  if (_recomputeMargin) {
    ABI21_0_0RCTProcessMetaPropsMargin(_marginMetaProps, _yogaNode);
  }
  if (_recomputeBorder) {
    ABI21_0_0RCTProcessMetaPropsBorder(_borderMetaProps, _yogaNode);
  }
  _recomputeMargin = NO;
  _recomputePadding = NO;
  _recomputeBorder = NO;
}

@end

@implementation ABI21_0_0RCTShadowView (Deprecated)

- (ABI21_0_0YGNodeRef)cssNode
{
  ABI21_0_0RCTLogWarn(@"Calling deprecated `[-ABI21_0_0RCTShadowView cssNode]`.");
  return _yogaNode;
}

- (BOOL)isCSSLeafNode
{
  ABI21_0_0RCTLogWarn(@"Calling deprecated `[-ABI21_0_0RCTShadowView isCSSLeafNode]`.");
  return self.isYogaLeafNode;
}

@end
