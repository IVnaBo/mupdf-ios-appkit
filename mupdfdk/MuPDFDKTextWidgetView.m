// Copyright © 2018 Artifex Software Inc. All rights reserved.

#import "ARDKGeometry.h"
#import "ARDKTextPosition.h"
#import "ARDKTextRange.h"
#import "ARDKTextSelectionRect.h"
#import "MuPDFDKTextWidgetView.h"

#define CARET_ASPECT (0.1)

static BOOL validRange(UITextRange *range)
{
    NSRange nsRange = ((ARDKTextRange *)range).nsRange;
    return range && nsRange.location != NSNotFound;
}

static BOOL validRangeWithin(UITextRange *range, NSString *string)
{
    NSRange nsRange = ((ARDKTextRange *)range).nsRange;
    return range && nsRange.location != NSNotFound
                 && NSMaxRange(nsRange) <= string.length;
}

static void distPtToRect(CGPoint pt, CGRect rect, CGFloat *x, CGFloat *y)
{
    CGFloat xbelow = CGRectGetMinX(rect) - pt.x;
    CGFloat xabove = pt.x - CGRectGetMaxX(rect);
    CGFloat ybelow = CGRectGetMinY(rect) - pt.y;
    CGFloat yabove = pt.y - CGRectGetMaxY(rect);

    *x = xbelow > 0 ? xbelow : xabove > 0 ? xabove : 0;
    *y = ybelow > 0 ? ybelow : yabove > 0 ? yabove : 0;
}

static BOOL breakchar(UniChar c)
{
    return c == L' ' || c == L'\n';
}

@interface MuPDFDKLayoutIndex : NSObject
@property(readonly) NSInteger lineIndex;
@property(readonly) NSInteger charIndex;
@end

@implementation MuPDFDKLayoutIndex

- (MuPDFDKLayoutIndex *)initWithLineIndex:(NSInteger)lineIndex andCharIndex:(NSInteger)charIndex
{
    self = [super init];
    if (self)
    {
        _lineIndex = lineIndex;
        _charIndex = charIndex;
    }
    return self;
}

+ (MuPDFDKLayoutIndex *)indexWithLineIndex:(NSInteger)lineIndex andCharIndex:(NSInteger)charIndex
{
    return [[MuPDFDKLayoutIndex alloc] initWithLineIndex:lineIndex andCharIndex: charIndex];
}

@end

@interface MuPDFDKTextWidgetView () <UITextInput,UITextInputTraits>
@property MuPDFDKWidgetText *widget;
@property NSMutableString *text;
@property NSArray<MuPDFDKTextLayoutLine *> *layout;
@property NSArray<MuPDFDKLayoutIndex *> *layoutIndex;
@property void (^showRectBlock)(CGRect rect);
@property void (^doneBlock)(void);
@property void (^selectionChangedBlock)(void);
@property id<ARDKPasteboard> pasteBoard;
@end

@implementation MuPDFDKTextWidgetView
{
    ARDKTextRange *_markedTextRange;
    ARDKTextRange *_selectedTextRange;
    CGFloat _scale;
    BOOL _finalized;
    NSString *_initialText;
}

@synthesize markedTextStyle=_markedTextStyle, markedTextRange=_markedTextRange,
inputDelegate=_inputDelegate, tokenizer=_tokenizer;

- (instancetype)initForWidget:(MuPDFDKWidgetText *)widget atScale:(CGFloat)scale withPasteboard:(id<ARDKPasteboard>)pasteBoard
                     showRect:(void (^)(CGRect rect))showBlock whenDone:(void (^)(void))doneBlock whenSelectionChanged:(void (^)(void))selBlock
{
    self = [super initWithFrame:ARCGRectScale(widget.rect, scale)];
    if (self)
    {
        self.opaque = NO;
        _widget = widget;
        _scale = scale;
        _finalized = NO;
        _tokenizer = [[UITextInputStringTokenizer alloc] initWithTextInput:self];
        _initialText = _widget.text;
        _text = [_widget.text stringByReplacingOccurrencesOfString:@"\r" withString:@""].mutableCopy;
        _selectedTextRange = [ARDKTextRange range:NSMakeRange(0, _text.length)];
        // While the widget is being edited, add a space to the end of the text
        // so that we can derive the last caret position from it
        _widget.setText(_text, NO);
        self.showRectBlock = ^(CGRect rect) {
            dispatch_async(dispatch_get_main_queue(), ^{
                showBlock(rect);
            });
        };
        self.doneBlock = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                doneBlock();
            });
        };
        self.selectionChangedBlock = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                selBlock();
            });
        };
        self.pasteBoard = pasteBoard;
        [self updateLayout];
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
    self.frame = ARCGRectScale(_widget.rect, _scale);
    [self setNeedsDisplay];
}

- (UIReturnKeyType)returnKeyType
{
    return _widget.isMultiline ? UIReturnKeyDefault : UIReturnKeyNext;
}

- (UIKeyboardType)keyboardType
{
    return _widget.isNumber ? UIKeyboardTypeNumbersAndPunctuation : UIKeyboardTypeDefault;
}

- (CGPoint)viewToPage:(CGPoint)pt
{
    return ARCGPointOffset(ARCGPointScale(pt, 1/_scale), CGRectGetMinX(_widget.rect), CGRectGetMinY(_widget.rect));
}

- (CGPoint)pageToView:(CGPoint)pt
{
    return ARCGPointScale(ARCGPointOffset(pt, -CGRectGetMinX(_widget.rect), -CGRectGetMinY(_widget.rect)), _scale);
}

- (BOOL)finalizeField
{
    if (_finalized)
    {
        return YES;
    }
    else
    {
        _finalized = _widget.setText(_text, YES);
        return _finalized;
    }
}

- (void)resetField
{
    if (!_finalized)
    {
        _text = [_initialText stringByReplacingOccurrencesOfString:@"\r" withString:@""].mutableCopy;
        if (!_widget.setText(_initialText, YES))
            _widget.setText(@"", YES);

        _finalized = YES;
    }
}

- (void)willBeRemoved
{
    assert(_finalized);
    _selectionChangedBlock();
}

- (BOOL)focusOnField:(MuPDFDKWidget *)widget
{
    __block MuPDFDKWidgetText *textWidget = nil;

    [widget switchCaseText:^(MuPDFDKWidgetText *widget) {
        textWidget = widget;
    } caseList:^(MuPDFDKWidgetList *widget) {
    } caseRadio:^(MuPDFDKWidgetRadio *widget) {
    } caseSignedSignature:^(MuPDFDKWidgetSignedSignature *widget) {
    } caseUnsignedSignature:^(MuPDFDKWidgetUnsignedSignature *widget) {
    }];

    if (textWidget != nil)
    {
        assert(_finalized);
        _finalized = NO;
        self.frame = ARCGRectScale(widget.rect, _scale);
        _widget = textWidget;
        [_inputDelegate textWillChange:self];
        [_inputDelegate selectionWillChange:self];
        _initialText = _widget.text;
        _text = [_widget.text stringByReplacingOccurrencesOfString:@"\r" withString:@""].mutableCopy;
        _selectedTextRange = [ARDKTextRange range:NSMakeRange(0, _text.length)];
        [_inputDelegate textDidChange:self];
        [_inputDelegate selectionDidChange:self];
        _widget.setText(_text, NO);
        [self reloadInputViews];
        [self updateLayout];
        [self showRect];
        [self setNeedsDisplay];
        _selectionChangedBlock();
    }

    return textWidget != nil;
}

- (BOOL)tapAt:(CGPoint)pt
{
    if (CGRectContainsPoint(_widget.rect, pt))
    {
        ARDKTextPosition *pos = (ARDKTextPosition *)[self closestPositionToPoint:[self pageToView:pt]];
        [_inputDelegate selectionWillChange:self];
        _selectedTextRange = [ARDKTextRange range:NSMakeRange(pos.index, 0)];
        [_inputDelegate selectionDidChange:self];
        [self showRect];
        [self setNeedsDisplay];
        _selectionChangedBlock();
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
        CGPoint viewPt = [self pageToView:pt];
        ARDKTextPosition *pos = (ARDKTextPosition *)[self closestPositionToPoint:viewPt];

        NSUInteger start = pos.index;
        while (start > 0 && !breakchar([_text characterAtIndex:start - 1]))
            --start;

        NSUInteger end = pos.index;
        while (end < _text.length && !breakchar([_text characterAtIndex:end]))
            ++end;

        [_inputDelegate selectionWillChange:self];
        _selectedTextRange = [ARDKTextRange range:NSMakeRange(start, end-start)];
        [_inputDelegate selectionDidChange:self];
        [self showRect];
        [self setNeedsDisplay];
        _selectionChangedBlock();
        return YES;
    }
    else
    {
        return NO;
    }
}

- (NSArray<NSValue *> *)selRectsForRange:(NSRange)nsRange
{
    NSMutableArray<NSValue *> *rects = [NSMutableArray array];

    if (nsRange.location != NSNotFound && nsRange.length > 0)
    {
        assert(NSMaxRange(nsRange) <= _layoutIndex.count);
        MuPDFDKLayoutIndex *first = _layoutIndex[nsRange.location];
        MuPDFDKLayoutIndex *last = _layoutIndex[NSMaxRange(nsRange) - 1];

        if (last.charIndex == _layout[last.lineIndex].charRects.count)
        {
            // Selection includes the new line char at the end of this line, so
            // Include the following line, but set the char index to -1
            // to denote not including any characters from that line
            last = [MuPDFDKLayoutIndex indexWithLineIndex:last.lineIndex + 1 andCharIndex: -1];
        }

        assert(last.lineIndex < _layout.count);
        for (NSInteger l = first.lineIndex; l <= last.lineIndex; l++)
        {
            CGRect rect = _layout[l].lineRect;
            CGFloat start, end;

            if (l == first.lineIndex)
            {
                // First line: start to the left of the first character included, or the right of
                // the whole line if no characters included
                start = first.charIndex == _layout[first.lineIndex].charRects.count
                        ? CGRectGetMaxX(rect)
                        : CGRectGetMinX(_layout[first.lineIndex].charRects[first.charIndex].CGRectValue);
            }
            else
            {
                // Not first line: use the entire line rectangle, adding a little sliver to
                // the left in case the line is empty
                start = CGRectGetMinX(rect) - rect.size.height * CARET_ASPECT;
            }

            if (l == last.lineIndex)
            {
                // Last line: end to the right of the last character included, or the left of
                // the whole line if no characters included
                end = last.charIndex == -1
                        ? CGRectGetMinX(rect)
                        : CGRectGetMaxX(_layout[last.lineIndex].charRects[last.charIndex].CGRectValue);
            }
            else
            {
                // Not last line: use the entire line rectangle, adding a little sliver to
                // the right in case the line is empty
                end = CGRectGetMaxX(rect) + rect.size.height * CARET_ASPECT;
            }

            rect = CGRectMake(start, rect.origin.y, end - start, rect.size.height);

            [rects addObject:[NSValue valueWithCGRect:rect]];
        }
    }

    return rects;
}

- (CGRect) caretRectForLocation:(NSInteger)location aspect:(CGFloat)aspect
{
    CGRect rect;
    BOOL before;

    if (location == 0)
    {
        rect = _layout[0].lineRect;
        before = YES;
    }
    else
    {
        MuPDFDKLayoutIndex *index = _layoutIndex[location - 1];
        if (index.charIndex == _layout[index.lineIndex].charRects.count)
        {
            rect = _layout[index.lineIndex + 1].lineRect;
            before = YES;
        }
        else
        {
            rect = _layout[index.lineIndex].charRects[index.charIndex].CGRectValue;
            before = NO;
        }
    }

    CGFloat w = rect.size.height * aspect;

    if (before)
        rect.origin.x -= w;
    else
        rect.origin.x += rect.size.width;

    rect.size.width = w;

    return rect;
}

- (CGPoint)selectionStart
{
    NSRange range = _selectedTextRange.nsRange;
    if (range.length > 0)
    {
        NSArray<NSValue *> *rects = [self selRectsForRange:range];
        assert(rects.count > 0);
        CGRect rect = rects.count > 0 ? rects.firstObject.CGRectValue : CGRectZero;
        return CGPointMake(CGRectGetMinX(_widget.rect) + CGRectGetMinX(rect),
                           CGRectGetMinY(_widget.rect) + CGRectGetMinY(rect));
    }
    else
    {
        return CGPointZero;
    }
}

- (CGPoint)selectionEnd
{
    NSRange range = _selectedTextRange.nsRange;
    if (range.length > 0)
    {
        NSArray<NSValue *> *rects = [self selRectsForRange:range];
        assert(rects.count > 0);
        CGRect rect = rects.count > 0 ? rects.lastObject.CGRectValue : CGRectZero;
        return CGPointMake(CGRectGetMinX(_widget.rect) + CGRectGetMaxX(rect),
                           CGRectGetMinY(_widget.rect) + CGRectGetMaxY(rect));
    }
    else
    {
        return CGPointZero;
    }
}

- (void)setSelectionStart:(CGPoint)pt
{
    NSRange range = _selectedTextRange.nsRange;
    ARDKTextPosition *pos = (ARDKTextPosition *)[self closestPositionToPoint:[self pageToView:pt]];
    if (pos.index < range.location + range.length)
    {
        NSInteger diff = pos.index - range.location;
        range.location += diff;
        range.length -= diff;
        [_inputDelegate selectionWillChange:self];
        _selectedTextRange = [ARDKTextRange range:range];
        [_inputDelegate selectionDidChange:self];
        [self setNeedsDisplay];
    }
    _selectionChangedBlock();
}

- (void)setSelectionEnd:(CGPoint)pt
{
    NSRange range = _selectedTextRange.nsRange;
    ARDKTextPosition *pos = (ARDKTextPosition *)[self closestPositionToPoint:[self pageToView:pt]];
    if (pos.index > range.location)
    {
        range.length = pos.index - range.location;
        [_inputDelegate selectionWillChange:self];
        _selectedTextRange = [ARDKTextRange range:range];
        [_inputDelegate selectionDidChange:self];
        [self setNeedsDisplay];
    }
    _selectionChangedBlock();
}

- (void)cut:(id)sender
{
    [_pasteBoard ARDKPasteboard_setString:[self textInRange:_selectedTextRange]];
    [self insertText:@""];
}

- (void)copy:(id)sender
{
    [_pasteBoard ARDKPasteboard_setString:[self textInRange:_selectedTextRange]];
}

- (void)paste:(id)sender
{
    [self insertText:_pasteBoard.ARDKPasteboard_string];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    NSRange selRange = _selectedTextRange.nsRange;
    if (action == @selector(cut:) || action == @selector(copy:))
        return selRange.length > 0;
    else if (action == @selector(paste:))
        return _pasteBoard.ARDKPasteboard_hasStrings;
    else
        return NO;
}

- (UITextRange *)selectedTextRange
{
    return _selectedTextRange;
}

- (void)setSelectedTextRange:(UITextRange *)selectedTextRange
{
    _selectedTextRange = (ARDKTextRange *)selectedTextRange;
    [self setNeedsDisplay];
    _selectionChangedBlock();
}

+ (instancetype)viewForWidget:(MuPDFDKWidgetText *)widget atScale:(CGFloat)scale withPasteboard:(id<ARDKPasteboard>)pasteBoard
                     showRect:(void (^)(CGRect))showBlock whenDone:(void (^)(void))doneBlock whenSelectionChanged:(void (^)(void))selBlock
{
    return [[MuPDFDKTextWidgetView alloc] initForWidget:widget atScale:scale withPasteboard:pasteBoard showRect:showBlock whenDone:doneBlock whenSelectionChanged:selBlock];
}

- (void)showRect
{
    CGRect selRect = CGRectNull;
    if (validRange(_selectedTextRange))
    {
        NSRange nsRange = ((ARDKTextRange *)_selectedTextRange).nsRange;
        if (nsRange.length > 0)
        {
            NSArray<NSValue *> *rects = [self selRectsForRange:nsRange];
            for (NSValue *val in rects)
            {
                selRect = CGRectUnion(selRect, val.CGRectValue);
            }
        }
        else
        {
            selRect = [self caretRectForLocation:nsRange.location aspect:CARET_ASPECT];
        }

        selRect.origin = ARCGPointOffset(selRect.origin, CGRectGetMinX(_widget.rect), CGRectGetMinY(_widget.rect));
    }

    if (!CGRectIsNull(selRect))
        self.showRectBlock(selRect);
}

- (void)updateLayout
{
    _layout = _widget.getTextLayout();

    // Create an index, locating where each character appears in the layout
    NSMutableArray<MuPDFDKLayoutIndex *> *layoutIndex = [NSMutableArray array];
    NSInteger lineIndex = 0;
    NSInteger charIndex = 0;

    assert(_layout.count > 0);

    for (NSInteger textIndex = 0; textIndex < _text.length; textIndex++)
    {
        assert(lineIndex < _layout.count && charIndex <= _layout[lineIndex].charRects.count);

        unichar c = [_text characterAtIndex:textIndex];
        if (c == L'\n')
        {
            // We should have used up all the characters in the current line
            assert(charIndex == _layout[lineIndex].charRects.count);

            [layoutIndex addObject:[MuPDFDKLayoutIndex indexWithLineIndex:lineIndex andCharIndex: charIndex]];
            lineIndex++;
            charIndex = 0;
        }
        else
        {
            if (charIndex == _layout[lineIndex].charRects.count)
            {
                lineIndex++;
                charIndex = 0;
            }

            [layoutIndex addObject:[MuPDFDKLayoutIndex indexWithLineIndex:lineIndex andCharIndex:charIndex]];
            charIndex++;
        }
    }

    // We should be on the last line and have used up all the characters within it
    assert(lineIndex == _layout.count - 1 && charIndex == _layout[lineIndex].charRects.count);
    _layoutIndex = layoutIndex;
}

- (NSInteger)numCharsWithinFieldArea
{
    CGRect wrect = CGRectMake(0, 0, _widget.rect.size.width, _widget.rect.size.height);
    for (NSInteger i = 0; i < _text.length; i++)
    {
        CGRect charRect;

        MuPDFDKLayoutIndex *index = _layoutIndex[i];
        if (index.charIndex == _layout[index.lineIndex].charRects.count)
        {
            charRect = _layout[index.lineIndex + 1].lineRect;
            charRect.size.width = 0;
        }
        else
        {
            charRect = _layout[index.lineIndex].charRects[index.charIndex].CGRectValue;
        }

        if (CGRectGetMidX(charRect) > CGRectGetMaxX(wrect) || CGRectGetMidY(charRect) > CGRectGetMaxY(wrect))
            return i;
    }

    return _text.length;
}

- (NSString *)textInRange:(UITextRange *)range
{
    return [_text substringWithRange:((ARDKTextRange *)range).nsRange];
}

- (void)limitTextLength:(NSInteger)limit
{
    [_text deleteCharactersInRange:NSMakeRange(limit, _text.length - limit)];
}

- (void)limitSelectionPosition
{
    if (_selectedTextRange == nil)
        return;

    NSRange nsRange = _selectedTextRange.nsRange;
    NSInteger maxChars = _text.length;
    if (nsRange.location + nsRange.length > maxChars)
    {
        NSInteger start = MIN(maxChars, nsRange.location);
        NSInteger end = MIN(maxChars, nsRange.location + nsRange.length);
        _selectedTextRange = [ARDKTextRange range:NSMakeRange(start, end - start)];
    }
}

- (void)replaceRange:(UITextRange *)range withText:(NSString *)text
{
    if (!validRangeWithin(range, _text))
    {
        assert(NO); //Should never happen
        return;
    }

    NSRange nsRange = ((ARDKTextRange *)range).nsRange;
    [_text replaceCharactersInRange:nsRange withString:text];
    _selectedTextRange = [ARDKTextRange range:NSMakeRange(nsRange.location + text.length, 0)];
    _markedTextRange = nil;
    _widget.setText(_text, NO);
    [self updateLayout];

    // Check that no characters stray outside the form field
    NSInteger maxChars = [self numCharsWithinFieldArea];
    if (_widget.maxChars > 0 && _widget.maxChars < maxChars)
        maxChars = _widget.maxChars;

    if (_text.length <= maxChars)
    {
        [self showRect];
        [self setNeedsDisplay];
        _selectionChangedBlock();
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.text.length > maxChars)
            {
                [self.inputDelegate textWillChange:self];
                [self.inputDelegate selectionWillChange:self];
                [self limitTextLength:maxChars];
                [self limitSelectionPosition];
                self.widget.setText(self.text, NO);
                [self updateLayout];
                [self.inputDelegate textDidChange:self];
                [self.inputDelegate selectionDidChange:self];
                [self showRect];
                [self setNeedsDisplay];
                self.selectionChangedBlock();
            }
        });
    }
}

- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange
{
    ARDKTextRange *rangeToReplace = validRange(_markedTextRange) ? _markedTextRange : _selectedTextRange;
    if (validRangeWithin(rangeToReplace, _text))
    {
        [_inputDelegate textWillChange:self];
        [_inputDelegate selectionWillChange:self];
        [_text replaceCharactersInRange:rangeToReplace.nsRange withString:markedText];
        _markedTextRange = [ARDKTextRange range:NSMakeRange(rangeToReplace.nsRange.location, markedText.length)];
        if (selectedRange.location != NSNotFound)
            _selectedTextRange = [ARDKTextRange range:NSMakeRange(_markedTextRange.nsRange.location + selectedRange.location, selectedRange.length)];
        else
            _selectedTextRange = nil;
        if (_widget.maxChars > 0)
        {
            [self limitTextLength:_widget.maxChars];
            [self limitSelectionPosition];
        }
        _widget.setText(_text, NO);
        [self updateLayout];
        NSInteger maxChars = [self numCharsWithinFieldArea];
        if (maxChars < _text.length)
        {
            [self limitTextLength:maxChars];
            [self limitSelectionPosition];
            _widget.setText(_text, NO);
            [self updateLayout];
        }
        [self showRect];
        [_inputDelegate textDidChange:self];
        [_inputDelegate selectionDidChange:self];
        [self setNeedsDisplay];
        _selectionChangedBlock();
    }
}

- (void)unmarkText
{
    _markedTextRange = nil;
}

- (UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition
{
    NSInteger fromIndex = ((ARDKTextPosition *)fromPosition).index;
    NSInteger toIndex = ((ARDKTextPosition *)toPosition).index;

    return [ARDKTextRange range:NSMakeRange(MIN(fromIndex, toIndex), ABS(toIndex - fromIndex))];
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset
{
    NSInteger index = ((ARDKTextPosition *)position).index + offset;
    return 0 <= index && index < _text.length ? [ARDKTextPosition position:index] : nil;
}

- (UITextPosition *)positionFromPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset
{
    switch (direction)
    {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionDown:
            return nil;

        case UITextLayoutDirectionLeft:
            return [self positionFromPosition:position offset:-offset];

        case UITextLayoutDirectionRight:
            return [self positionFromPosition:position offset:offset];

        default:
            return nil;
    }
}

- (UITextPosition *)beginningOfDocument
{
    return [ARDKTextPosition position:0];
}

- (UITextPosition *)endOfDocument
{
    return [ARDKTextPosition position:_text.length];
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
    NSRange nsRange = ((ARDKTextRange *)range).nsRange;

    switch (direction)
    {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionDown:
            return nil;
        case UITextLayoutDirectionLeft:
            return [ARDKTextPosition position:nsRange.location];
        case UITextLayoutDirectionRight:
            return [ARDKTextPosition position:nsRange.location + nsRange.length];
        default:
            return nil;
    }
}

- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction
{
    NSInteger index = ((ARDKTextPosition *)position).index;

    switch (direction)
    {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionDown:
            return nil;
        case UITextLayoutDirectionLeft:
            return [ARDKTextRange range:NSMakeRange(0, index)];
        case UITextLayoutDirectionRight:
            return [ARDKTextRange range:NSMakeRange(index, _text.length - index)];
        default:
            return nil;
    }
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
    NSArray<NSValue *> *rects = [self selRectsForRange:((ARDKTextRange *)range).nsRange];

    return rects.count == 0 ? CGRectNull : ARCGRectScale(rects.firstObject.CGRectValue, _scale);
}

- (CGRect)caretRectForPosition:(UITextPosition *)position
{
    NSInteger index = ((ARDKTextPosition *)position).index;

    if (index > _layoutIndex.count)
    {
        NSLog(@"caretRectForPosition: position out of range");
        return CGRectNull;
    }

    return ARCGRectScale([self caretRectForLocation:index aspect:CARET_ASPECT], _scale);
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point
{
    return [self closestPositionToPoint:point withinRange:[ARDKTextRange range:NSMakeRange(0, _text.length)]];
}

- (NSArray<UITextSelectionRect *> *)selectionRectsForRange:(UITextRange *)range
{
    NSArray<NSValue *> *rects = [self selRectsForRange:((ARDKTextRange *)range).nsRange];

    NSMutableArray<UITextSelectionRect *> *selRects = [NSMutableArray array];
    for (int i = 0; i < rects.count; i++)
    {
        [selRects addObject:[ARDKTextSelectionRect selectionRect:ARCGRectScale(rects[i].CGRectValue, _scale) start:i == 0 end:i == rects.count-1]];
    }

    return selRects;
}

- (UITextPosition *)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range
{
    NSRange nsRange = ((ARDKTextRange *)range).nsRange;

    if (nsRange.location == NSNotFound)
        return nil;

    point = ARCGPointScale(point, 1/_scale);
    NSInteger index = nsRange.location;
    CGFloat xdist = CGFLOAT_MAX;
    CGFloat ydist = CGFLOAT_MAX;

    for (int i = 0; i <= nsRange.length && nsRange.location + i <= _text.length; i++)
    {
        CGFloat nxdist, nydist;
        distPtToRect(point, [self caretRectForLocation:nsRange.location + i aspect:0], &nxdist, &nydist);
        if (nydist < ydist || (nydist == ydist && nxdist < xdist))
        {
            ydist = nydist;
            xdist = nxdist;
            index = nsRange.location + i;
        }
    }

    return [ARDKTextPosition position:index];
}

- (UITextRange *)characterRangeAtPoint:(CGPoint)point
{
    UITextPosition *pos = [self closestPositionToPoint:point];
    NSInteger index = ((ARDKTextPosition *)pos).index;
    return [ARDKTextRange range:NSMakeRange(index, 0)];
}

- (void)insertText:(NSString *)text
{
    if (([text isEqualToString:@"\n"] && !_widget.isMultiline) || [text isEqualToString:@"\t"])
    {
        self.doneBlock();
    }
    else if (validRange(_selectedTextRange))
    {
        [self replaceRange:_selectedTextRange withText:text];
    }
}

- (void)deleteBackward
{
    if (validRange(_selectedTextRange))
    {
        NSRange nsRange = ((ARDKTextRange *)_selectedTextRange).nsRange;
        if (nsRange.length == 0 && nsRange.location > 0)
            nsRange = NSMakeRange(nsRange.location - 1, 1);
        if (nsRange.length > 0)
            [self replaceRange:[ARDKTextRange range:nsRange] withText:@""];
    }
}

- (BOOL)hasText
{
    return _text.length > 0;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)drawRect:(CGRect)rect
{
    if (validRange(_selectedTextRange))
    {
        CGContextRef cref = UIGraphicsGetCurrentContext();
        if (((ARDKTextRange *)_selectedTextRange).nsRange.length > 0)
        {
            [[UIColor colorWithRed:0x25/255.0 green:0x72/255.0 blue:0xAC/255.0 alpha:0.5] set];
            NSArray<UITextSelectionRect *> *rects = [self selectionRectsForRange:_selectedTextRange];
            for (UITextSelectionRect *rect in rects)
            {
                CGContextFillRect(cref, rect.rect);
            }
        }
        else
        {
            [[UIColor redColor] set];
            CGRect rect = [self caretRectForPosition:_selectedTextRange.end];
            CGContextFillRect(cref, rect);
        }
    }
}

@end
