//  Copyright © 2017 Artifex Software Inc. All rights reserved.

#import "ARDKTextView.h"

@implementation ARDKTextView

/// Count the number of characters in a string
///
/// This is intended to match the offsets returned by UITextField's
/// offsetFromPosition:self.beginningOfDocument toPosition:, which appear
/// to be actual visible characters. ie. a UTF-16 surrogate pair is counted
/// as '1', whereas NSString.length treats it as '2'.
///
/// I've not tested if this correctly handles decomposed characters. I'm not
/// sure if they can ever occur.
///
/// taken from http://stackoverflow.com/questions/15328688/
- (NSUInteger)ARDK_characterCount:(NSString *)str
{
    NSUInteger cnt = 0;
    NSUInteger index = 0;
    while (index < str.length) {
        NSRange range = [str rangeOfComposedCharacterSequenceAtIndex:index];
        cnt++;
        index += range.length;
    }

    return cnt;
}



- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    // returns no for everything except things we know of and explicitly
    // want to allow. This runs the risk that we might reject something
    // that's actually important to happen, but equally protects us from the
    // risk of allowing an unwanted action added in an iOS update.
    // The range of selectors we can get called with is pretty vast,
    // and many are undocumented private ones, so it would not surprise me
    // if we blocked something important and had to revise this.
    // If we did whitelist instead, we would want to be sure to block other
    // selectors that might leak information to other apps - 'Share',
    // 'Define', and so on.
#ifdef SODKTEXTFIELD_LOG_SELECTORS
    NSLog(@"canPerformAction: %@\n", NSStringFromSelector(action));
#endif /* SODKTEXTFIELD_LOG_SELECTORS */

    // This class is sometimes used without a pasteboard set, as in some
    // textfields that it is not important to allow clipboard actions
    if (_pasteboard)
    {
        if (action == @selector(copy:) ||
            action == @selector(cut:))
        {
            return !self.selectedTextRange.isEmpty;
        }
        if (action == @selector(paste:))
        {
            return _pasteboard.ARDKPasteboard_hasStrings;
        }
    }

    // Disallow everything else. This means we lose the 'Define' option and
    // other potentially useful options, but in turn it also means we won't
    // accidentally leak data if a new iOS adds new menu entries.

    return NO;
}

- (void)paste:(id)sender
{
    if (!_pasteboard)
        return;

    NSString *text = _pasteboard.ARDKPasteboard_string;

    if (text)
    {
        UITextPosition *start = self.selectedTextRange.start;
        UITextPosition *end = self.selectedTextRange.end;

        // NB: next two values are measured in UTF16 characters; I'm unsure what
        // means but it appears that an emoji, eg, 🌍 (U+1F30D) which is a
        // UTF-16 surrogate pair, is a single character
        NSInteger startOffset = [self offsetFromPosition:self.beginningOfDocument toPosition:start];
        NSInteger endOffset = [self offsetFromPosition:self.beginningOfDocument toPosition:end];
        NSRange range = NSMakeRange(startOffset, endOffset - startOffset);

        self.text = [self.text stringByReplacingCharactersInRange:range withString:text];

        // position caret after the newly inserted text
        UITextPosition *pos = [self positionFromPosition:start inDirection:UITextLayoutDirectionRight offset:[self ARDK_characterCount:text]];
        self.selectedTextRange = [self textRangeFromPosition:pos toPosition:pos];
    }
}

- (void)cut:(id)sender
{
    if (!_pasteboard)
        return;

    NSString *text = [self textInRange:self.selectedTextRange];

    if (!text)
        return;

    _pasteboard.ARDKPasteboard_string = text;

    UITextPosition *start = self.selectedTextRange.start;
    UITextPosition *end = self.selectedTextRange.end;

    // NB: next two values are measured in UTF16 characters
    NSInteger startOffset = [self offsetFromPosition:self.beginningOfDocument toPosition:start];
    NSInteger endOffset = [self offsetFromPosition:self.beginningOfDocument toPosition:end];
    NSRange range = NSMakeRange(startOffset, endOffset - startOffset);

    // remove the cut text from the textview
    self.text = [self.text stringByReplacingCharactersInRange:range withString:@""];

    // position caret where the text was removed from
    self.selectedTextRange = [self textRangeFromPosition:start toPosition:start];
}

- (void)copy:(id)sender
{
    if (!_pasteboard)
        return;

    NSString *text = [self textInRange:self.selectedTextRange];

    if (text)
    {
        _pasteboard.ARDKPasteboard_string = text;
    }
}

@end
