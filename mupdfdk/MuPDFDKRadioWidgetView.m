// Copyright © 2019 Artifex Software Inc. All rights reserved.

#import "ARDKGeometry.h"
#import "ARDKTextPosition.h"
#import "ARDKTextRange.h"
#import "MuPDFDKRadioWidgetView.h"
#define LINE_WIDTH (3)

@interface MuPDFDKRadioWidgetView () <UITextInput,UITextInputTraits>
@property MuPDFDKWidgetRadio *widget;
@property void (^showRectBlock)(CGRect rect);
@property void (^doneBlock)(void);
@end

@implementation MuPDFDKRadioWidgetView
{
    CGFloat _scale;
}

@synthesize markedTextStyle=_markedTextStyle, markedTextRange=_markedTextRange,
inputDelegate=_inputDelegate, tokenizer=_tokenizer;

- (instancetype)initForWidget:(MuPDFDKWidgetRadio *)widget atScale:(CGFloat)scale
                     showRect:(void (^)(CGRect rect))showBlock whenDone:(void (^)(void))doneBlock
{
    self = [super initWithFrame:ARCGRectScale(widget.rect, scale)];
    if (self)
    {
        self.opaque = NO;
        _widget = widget;
        _scale = scale;
        _tokenizer = [[UITextInputStringTokenizer alloc] initWithTextInput:self];
        self.showRectBlock = showBlock;
        self.doneBlock = doneBlock;
        [self showRect];
    }

    return self;
}

- (CGFloat)scale
{
    return _scale;
}

- (void)setScale:(CGFloat)scale
{
    _scale = scale;
    [self setNeedsDisplay];
}

- (UITextAutocorrectionType)autocorrectionType
{
    return UITextAutocorrectionTypeNo;
}

- (UIReturnKeyType)returnKeyType
{
    return UIReturnKeyNext;
}

- (BOOL)finalizeField
{
    return YES;
}

- (void)resetField
{
}

- (void)willBeRemoved
{
}

- (BOOL)focusOnField:(MuPDFDKWidget *)widget
{
    __block MuPDFDKWidgetRadio *radioWidget = nil;

    [widget switchCaseText:^(MuPDFDKWidgetText *widget) {
    } caseList:^(MuPDFDKWidgetList *widget) {
    } caseRadio:^(MuPDFDKWidgetRadio *widget) {
        radioWidget = widget;
    } caseSignedSignature:^(MuPDFDKWidgetSignedSignature *widget) {
    } caseUnsignedSignature:^(MuPDFDKWidgetUnsignedSignature *widget) {
    }];

    if (radioWidget != nil)
    {
        self.frame = ARCGRectScale(widget.rect, _scale);
        _widget = radioWidget;
        [self showRect];
    }

    return radioWidget != nil;
}

- (BOOL)tapAt:(CGPoint)pt
{
    if (CGRectContainsPoint(_widget.rect, pt))
    {
        _widget.toggle();
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)doubleTapAt:(CGPoint)pt
{
    if (CGRectContainsPoint(_widget.rect, pt))
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (CGPoint)selectionStart
{
    return CGPointZero;
}

- (CGPoint)selectionEnd
{
    return CGPointZero;
}

- (void)setSelectionStart:(CGPoint)pt
{
}

- (void)setSelectionEnd:(CGPoint)pt
{
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    return NO;
}

- (UITextRange *)selectedTextRange
{
    return [ARDKTextRange range:NSMakeRange(0, 0)];
}

- (void)setSelectedTextRange:(UITextRange *)selectedTextRange
{
}

+ (instancetype)viewForWidget:(MuPDFDKWidgetRadio *)widget atScale:(CGFloat)scale showRect:(void (^)(CGRect))showBlock whenDone:(void (^)(void))doneBlock
{
    return [[MuPDFDKRadioWidgetView alloc] initForWidget:widget atScale:scale showRect:showBlock whenDone:doneBlock];
}

- (void)showRect
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.showRectBlock(self.widget.rect);
    });
}

- (NSString *)textInRange:(UITextRange *)range
{
    return @"";
}

- (void)replaceRange:(UITextRange *)range withText:(NSString *)text
{
}

- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange
{
}

- (void)unmarkText
{
}

- (UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition
{
    NSInteger fromIndex = ((ARDKTextPosition *)fromPosition).index;
    NSInteger toIndex = ((ARDKTextPosition *)toPosition).index;

    return [ARDKTextRange range:NSMakeRange(MIN(fromIndex, toIndex), ABS(toIndex - fromIndex))];
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset
{
    return [ARDKTextPosition position:0];
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset
{
    return [ARDKTextPosition position:0];
}

- (UITextPosition *)beginningOfDocument
{
    return [ARDKTextPosition position:0];
}

- (UITextPosition *)endOfDocument
{
    return [ARDKTextPosition position:0];
}

- (NSComparisonResult)comparePosition:(UITextPosition *)position toPosition:(UITextPosition *)other
{
    NSInteger offset = [self offsetFromPosition:position toPosition:other];

    return offset == 0 ? NSOrderedSame : offset < 0 ? NSOrderedDescending : NSOrderedAscending;
}

- (NSInteger)offsetFromPosition:(UITextPosition *)from toPosition:(UITextPosition *)toPosition
{
    return ((ARDKTextPosition *)toPosition).index - ((ARDKTextPosition *)from).index;
}

- (UITextPosition *)positionWithinRange:(UITextRange *)range farthestInDirection:(UITextLayoutDirection)direction
{
    return nil;
}

- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction
{
    return [ARDKTextRange range:NSMakeRange(0, 0)];
}

- (UITextWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction
{
    return UITextWritingDirectionLeftToRight;
}

- (void)setBaseWritingDirection:(UITextWritingDirection)writingDirection forRange:(UITextRange *)range
{
}

- (CGRect)firstRectForRange:(UITextRange *)range
{
    return CGRectNull;
}

- (CGRect)caretRectForPosition:(UITextPosition *)position
{
    return CGRectNull;
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point
{
    return [ARDKTextPosition position:0];
}

- (NSArray<UITextSelectionRect *> *)selectionRectsForRange:(UITextRange *)range
{
    return [NSArray array];
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range
{
    return [ARDKTextPosition position:0];
}

- (UITextRange *)characterRangeAtPoint:(CGPoint)point
{
    return [ARDKTextRange range:NSMakeRange(0, 0)];
}

- (void)insertText:(NSString *)text
{
    if ([text isEqualToString:@"\n"] || [text isEqualToString:@"\t"])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.doneBlock)
                self.doneBlock();
        });
    }
    else
    {
        self.widget.toggle();
    }
}

- (void)deleteBackward
{
}

- (BOOL)hasText
{
    return NO;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef cref = UIGraphicsGetCurrentContext();
    [[UIColor redColor] set];
    CGContextSetLineWidth(cref, LINE_WIDTH);
    CGContextStrokeRect(cref, self.bounds);
}

@end
