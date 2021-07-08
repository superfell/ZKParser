// Copyright (c) 2021 Simon Fell
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "ZKParserFactory.h"


@implementation NSString(ZKParsing)

-(id)parse:(ZKBaseParser*)p error:(NSError**)err{
    return [[ZKParsingState withInput:self] parse:p error:err];
}

@end

@interface ZKParsingState()
@property (strong,nonatomic) NSString *input;
@property (strong,nonatomic) ZKParserError *error;
@property (assign,nonatomic) BOOL hasError;

@end

@implementation ZKParsingState

+(ZKParsingState *)withInput:(NSString *)s {
    ZKParsingState *r = [[ZKParsingState alloc] init];
    r.input = s;
    r.pos = 0;
    r.error = [ZKParserError new];
    return r;
}

-(BOOL)hasMoreInput {
    return self.pos < self.input.length;
}

-(unichar)currentChar {
    NSAssert([self hasMoreInput], @"currentChar called with no remaining input");
    return [self.input characterAtIndex:self.pos];
}

-(NSUInteger)length {
    return self.input.length - self.pos;
}

-(NSString *)value {
    return [self.input substringFromIndex:self.pos];
}

-(NSString*)valueOfRange:(NSRange)r {
    return [self.input substringWithRange:r];
}

-(NSString *)consumeString:(NSString *)s caseSensitive:(ZKCaseSensitivity)cs {
    NSStringCompareOptions opt = cs == ZKCaseSensitive ? NSLiteralSearch : NSCaseInsensitiveSearch;
    NSRange rng = NSMakeRange(self.pos, s.length);
    if (self.length >= s.length && [self.input compare:s options:opt range:rng] == NSOrderedSame) {
        self.pos += s.length;
        return [self.input substringWithRange:rng];
    }
    return nil;
}
-(NSInteger)consumeCharacterSet:(NSCharacterSet *)cs {
    NSInteger count = 0;
    unichar buff[16];
    while (self.hasMoreInput) {
        NSRange chunk = NSMakeRange(self.pos, MIN(16, self.length));
        [self.input getCharacters:buff range:chunk];
        for (int i = 0; i < chunk.length; i++) {
            if (![cs characterIsMember:buff[i]]) {
                return count;
            }
            self.pos++;
            count++;
        }
    }
    return count;
}

-(void)markCut {
    self.cut = self.pos;
}

-(BOOL)canMoveTo:(NSUInteger)targetPos {
    return targetPos >= self.cut;
}

-(void)moveTo:(NSUInteger)pos {
    self.pos = pos;
}

-(id)parse:(ZKBaseParser*)p error:(NSError**)err {
    *err = nil;
    ZKParserResult *res = [p parse:self];
    if (self.length > 0 && !self.hasError) {
        *err = [NSError errorWithDomain:@"Parser" code:1 userInfo:@{
            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unexpected input '%@' at position %lu", self.value, (unsigned long)self.pos+1],
            @"Position": @(self.pos+1)
        }];
        return nil;
    }
    if (self.hasError) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[NSLocalizedDescriptionKey] = self.error.msg;
        userInfo[@"Position"] = @(self.error.pos+1);
        if (self.error.userInfo != nil) {
            [userInfo addEntriesFromDictionary:self.error.userInfo];
        }
        *err = [NSError errorWithDomain:@"Parser" code:2 userInfo:userInfo];
        return nil;
    }
    return res.val;
}

-(ZKParserError*)expectedClass:(NSString*)expected {
    self.hasError = TRUE;
    ZKParserError *e = self.error;
    e.msg = nil;
    e.pos = self.pos;
    e.code = 0;
    e.userInfo = nil;
    e.expected = expected;
    e.expectedClass = TRUE;
    return e;
}
-(ZKParserError*)expected:(NSString*)expected {
    self.hasError = TRUE;
    ZKParserError *e = self.error;
    e.msg = nil;
    e.pos = self.pos;
    e.code = 0;
    e.userInfo = nil;
    e.expected = expected;
    e.expectedClass = FALSE;
    return e;
}

-(ZKParserError*)error:(NSString*)msg {
    self.hasError = TRUE;
    ZKParserError *e = self.error;
    e.msg = msg;
    e.pos = self.pos;
    e.code = 0;
    e.userInfo = nil;
    e.expected = nil;
    e.expectedClass = FALSE;
    return e;
}

-(void)clearError {
    self.hasError = FALSE;
}

@end

@implementation ZKParserError
-(NSString*)msg {
    if (_msg == nil && _expected != nil) {
        // pos is zero based internally, but 1 based to the user.
        if (self.expectedClass) {
            _msg = [NSString stringWithFormat:@"expecting %@ at position %lu", _expected, _pos + 1];
        } else {
            _msg = [NSString stringWithFormat:@"expecting '%@' at position %lu", _expected, _pos + 1];
        }
    }
    return _msg;
}
@end
