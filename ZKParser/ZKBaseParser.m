//
//  ZKParser.m
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import "ZKBaseParser.h"

@interface ZKSingularParser()
@property (copy,nonatomic) ResultMapper mapper;
@end

@interface ZKArrayParser()
@property (copy,nonatomic) ArrayResultMapper mapper;
@end

@interface ZKParserExact : ZKSingularParser
@property (strong,nonatomic) NSString *match;
@property (assign,nonatomic) ZKCaseSensitivity caseSensitivity;
@end

@interface ZKParserCharSet : ZKSingularParser
@property (strong,nonatomic) NSCharacterSet* charSet;
@property (assign,nonatomic) NSUInteger minMatches;
@property (strong,nonatomic) NSString *errorName;
@end

@interface ZKParserNotCharSet : ZKParserCharSet
@end

@interface ZKParserInteger : ZKSingularParser
@end

@interface ZKParserDecimal : ZKSingularParser
@end

@interface ZKParserRegex : ZKSingularParser
@property (strong,nonatomic) NSRegularExpression *regex;
@property (strong,nonatomic) NSString *name;
@end

@interface ZKParserFirstOf : ZKSingularParser
@property (strong,nonatomic) NSArray<ZKBaseParser*>* items;
@end

@interface ZKParserOneOf : ZKSingularParser
@property (strong,nonatomic) NSArray<ZKBaseParser*>* items;
@end

@interface ZKParserSeq : ZKArrayParser
@property (strong,nonatomic) NSArray<ZKBaseParser*>* items;
@end

@interface ZKParserRepeat : ZKArrayParser
+(instancetype)repeated:(ZKBaseParser*)p sep:(ZKBaseParser*)sep min:(NSUInteger)min max:(NSUInteger)max;
@property (strong,nonatomic) ZKBaseParser *parser;
@property (strong,nonatomic) ZKBaseParser *separator;
@property (assign,nonatomic) NSUInteger min;
@property (assign,nonatomic) NSUInteger max;
@end

@interface ZKParserOptional : ZKSingularParser
@property (strong,nonatomic) ZKBaseParser *optional;
@property (copy,nonatomic) BOOL(^ignoreBlock)(NSObject*);   // is this the right places for this? seems like it should be on eq and/or charSet
@end

@interface ZKParserBlock : ZKSingularParser
@property (copy,nonatomic) ParseBlock parser;
@end


@implementation ZKBaseParser
-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    assert(false);
}

-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err {
    // TODO add debug logging back in
    *err = nil;
    NSInteger start = input.pos;
    ParserResult *r = [self parseImpl:input error:err];
    if (*err != nil) {
        [input moveTo:start];
    }
    return r;
}
-(NSString *)parsersDesc:(NSArray<ZKBaseParser*>*)p {
    return [NSString stringWithFormat:@"[%@]", [[p valueForKey:@"description"] componentsJoinedByString:@","]];
}
-(void)setDebugName:(NSString *)n {
    // only does something useful in debug proxy
}
@end

@implementation ZKSingularParser
-(instancetype)onMatch:(ResultMapper)block {
    self.mapper = block;
    return self;
}
-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err {
    ParserResult *r = [super parse:input error:err];
    if (*err == nil && self.mapper != nil) {
        r = self.mapper(r);
    }
    return r;
}
@end

@implementation ZKArrayParser
-(instancetype)onMatch:(ArrayResultMapper)block {
    self.mapper = block;
    return self;
}
-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err {
    ParserResult *r = [super parse:input error:err];
    if (*err == nil && self.mapper != nil) {
        assert([r isKindOfClass:[ArrayParserResult class]]);
        r = self.mapper((ArrayParserResult*)r);
    }
    return r;
}
@end

@implementation ZKParserExact
-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSInteger start = input.pos;
    NSString *res = [input consumeString:self.match caseSensitive:self.caseSensitivity];
    if (res != nil) {
        NSRange pos = NSMakeRange(start, input.pos-start);
        return [ParserResult result:res loc:pos];
    }
    *err = [NSError errorWithDomain:@"Parser"
                               code:2
                           userInfo:@{
                               NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting '%@' at position %lu", self.match, input.pos+1],
                               @"Position":@(input.pos+1)
                           }];
    return nil;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"[eq: %@]", self.match];
}

@end

@implementation ZKParserCharSet

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSInteger count = 0;
    NSInteger start = input.pos;
    while (true) {
        if (![input consumeCharacterSet:self.charSet]) {
            if (count < self.minMatches) {
                *err = [NSError errorWithDomain:@"Parser"
                                           code:3
                                       userInfo:@{
                                           NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting %@ at position %lu", self.errorName, start+1],
                                           @"Position": @(start+1)
                                       }];
                return nil;
            }
            NSRange rng = NSMakeRange(start, count);
            return [ParserResult result:[input valueOfRange:rng] loc:rng];
        }
        count++;
    }
}

-(NSString *)description {
    return [NSString stringWithFormat:@"[%lu+ %@]", self.minMatches, self.errorName];
}
@end

@implementation ZKParserNotCharSet

-(void)setCharSet:(NSCharacterSet*)set {
    [super setCharSet:[set invertedSet]];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"[%lu+ !%@]", self.minMatches, self.errorName];
}
@end

@implementation ZKParserInteger

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSInteger start = input.pos;
    NSInteger val = 0;
    NSInteger sign = 1;
    BOOL first = TRUE;
    BOOL valid = FALSE;
    while (input.hasMoreInput) {
        unichar c = input.currentChar;
        if (first) {
            first = FALSE;
            if (c == '-') {
                sign = -1;
                input.pos++;
                continue;
            } else if (c == '+') {
                input.pos++;
                continue;
            }
        }
        if (c < '0' || c > '9') {
            break;
        }
        input.pos++;
        val = val * 10;
        val = val + c-'0';
        valid = TRUE;
    }
    if (!valid) {
        *err = [NSError errorWithDomain:@"Parser"
                                  code:6
                              userInfo:@{
                                  NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting an integer at position %lu", start+1],
                                  @"Position": @(start+1)
                              }];
        return nil;
    }
    return [ParserResult result:[NSNumber numberWithInteger:val * sign] loc:NSMakeRange(start,input.pos-start)];
}

-(NSString *)description {
    return @"[integer]";
}

@end

@implementation ZKParserDecimal

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSInteger start = input.pos;
    BOOL first = TRUE;
    BOOL valid = FALSE;
    BOOL seenDot = FALSE;
    while (input.hasMoreInput) {
        unichar c = input.currentChar;
        if (first) {
            first = FALSE;
            if (c == '-' || c == '+') {
                input.pos++;
                continue;
            }
        }
        if (!seenDot && c =='.') {
            seenDot = TRUE;
            valid = FALSE;  // has to be a number after the .
            input.pos++;
            continue;
        }
        if (c < '0' || c > '9') {
            break;
        }
        input.pos++;
        valid = TRUE;
    }
    if (!valid) {
        *err = [NSError errorWithDomain:@"Parser"
                                  code:6
                              userInfo:@{
                                  NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting a decimal at position %lu", start+1],
                                  @"Position": @(start+1)
                              }];
        return nil;
    }
    NSRange rng = NSMakeRange(start,input.pos-start);
    NSDecimalNumber *val = [NSDecimalNumber decimalNumberWithString:[input valueOfRange:rng]];
    return [ParserResult result:val loc:NSMakeRange(start,input.pos-start)];
}

-(NSString *)description {
    return @"[decimal]";
}

@end

@implementation ZKParserRegex

+(instancetype)with:(NSRegularExpression*)regex name:(NSString*)name {
    ZKParserRegex *p = [self new];
    p.regex = regex;
    p.name = name;
    return p;
}

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSRange match = [self.regex rangeOfFirstMatchInString:input.input options:NSMatchingAnchored range:NSMakeRange(input.pos, input.length)];
    if (NSEqualRanges(NSMakeRange(NSNotFound,0), match)) {
        *err = [NSError errorWithDomain:@"Parser"
                                  code:7
                              userInfo:@{
                                  NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting a %@ at position %lu", self.name, input.pos+1],
                                  @"Position": @(input.pos+1)
                              }];
        return nil;
    }
    input.pos += match.length;
    return [ParserResult result:[input valueOfRange:match] loc:match];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"[regex %@]", self.name];
}
@end

@implementation ZKParserFirstOf

+(instancetype)firstOf:(NSArray<ZKBaseParser*>*)opts {
    ZKParserFirstOf *p = [ZKParserFirstOf new];
    p.items = opts;
    return p;
}

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    for (ZKBaseParser *child in self.items) {
        ParserResult *r = [child parse:input error:err];
        if (*err == nil) {
            return r;
        }
        [input moveTo:start];
    }
    return nil;
}
-(NSString *)description {
    return [NSString stringWithFormat:@"[firstOf: %@]", [self parsersDesc:self.items]];
}

@end

@implementation ZKParserOneOf

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSUInteger longestPos = start;
    ParserResult *longestRes = nil;
    NSError *childErr = nil;
    BOOL success = FALSE;
    for (ZKBaseParser *child in self.items) {
        ParserResult *r = [child parse:input error:&childErr];
        if ((childErr == nil) && (input.pos > longestPos)) {
            longestRes = r;
            longestPos = input.pos;
            success = TRUE;
        }
        if (childErr != nil && *err == nil) {
            *err = childErr;
        }
        [input moveTo:start];
    }
    if (success) {
        *err = nil;
        [input moveTo:longestPos];
    }
    return longestRes;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"[oneOf: %@]", [self parsersDesc:self.items]];
}

@end

@implementation ZKParserSeq

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:self.items.count];
    for (ZKBaseParser *child in self.items) {
        ParserResult *res = [child parse:input error:err];
        if (*err != nil) {
            return nil;
        }
        [results addObject:res];
    }
    return [ArrayParserResult result:results loc:NSMakeRange(start, input.pos-start)];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"[seq: %@]", [self parsersDesc:self.items]];
}

@end

@implementation ZKParserRepeat

+(instancetype)repeated:(ZKBaseParser*)p sep:(ZKBaseParser*)sep min:(NSUInteger)min max:(NSUInteger)max {
    ZKParserRepeat *r = [ZKParserRepeat new];
    r.parser = p;
    r.separator = sep;
    r.min = min;
    r.max = max;
    return r;
}

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSMutableArray<ParserResult*> *results = [NSMutableArray array];
    NSError *nextError = nil;
    ParserResult *first = [self.parser parse:input error:&nextError];
    if (nextError == nil) {
        [results addObject:first];
        while (results.count < self.max) {
            NSUInteger thisStart = input.pos;
            if (self.separator != nil) {
                [self.separator parse:input error:&nextError];
                if (nextError != nil) {
                    break;
                }
            }
            ParserResult *next = [self.parser parse:input error:&nextError];
            if (nextError != nil) {
                // unconsume the separator above
                [input moveTo:thisStart];
                break;
            }
            [results addObject:next];
        }
    }
    if (results.count >= self.min) {
        return [ArrayParserResult result:results loc:NSMakeRange(start, input.pos-start)];
    }
    *err = nextError;
    return nil;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"[repeat{%lu,%lu} r:%@ s:%@}", self.min, self.max, self.parser, self.separator];
}
@end

@implementation ZKParserOptional

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    ParserResult *res = [self.optional parse:input error:err];
    if (*err == nil) {
        if (!self.ignoreBlock(res.val)) {
            return res;
        }
    }
    *err = nil;
    [input moveTo:start];
    return [ParserResult result:[NSNull null] loc:NSMakeRange(start,0)];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"%@?" , self.optional];
}

@end

@implementation ZKParserRef

-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err {
    return [self.parser parse:input error:err];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"[ref:%p]", self.parser];
}

@end

@implementation ZKParserBlock
+(instancetype)block:(ParseBlock)b {
    ZKParserBlock *p = [ZKParserBlock new];
    p.parser = b;
    return p;
}

-(ParserResult*)parseImpl:(ZKParserInput*)i error:(NSError**)err {
    return self.parser(i,err);
}

-(NSString *)description {
    return [NSString stringWithFormat:@"[block:%p]", self.parser];
}
@end

@interface ParserDebugState : NSObject
@property(strong,nonatomic) NSFileHandle *out;
@property(assign,nonatomic) NSInteger depth;
@end

@interface ParserDebug : NSProxy
+(instancetype)wrap:(ZKBaseParser*)p state:(ParserDebugState*)h;
@property(strong,nonatomic) ZKBaseParser *inner;
@property(strong,nonatomic) ParserDebugState *state;
@property(strong,nonatomic) NSString *debugName;
@end

@interface ZKParserFactory ()
@property (strong, nonatomic) ParserDebugState *debug;
-(id)wrapDebug:(ZKBaseParser*)p;
@end


@implementation ZKParserFactory

-(ZKSingularParser*)eq:(NSString *)s case:(ZKCaseSensitivity)c {
    ZKParserExact *e = [ZKParserExact new];
    e.match = s;
    e.caseSensitivity = c;
    return [self wrapDebug:e];
}

-(ZKSingularParser*)eq:(NSString *)s {
    return [self eq:s case:self.defaultCaseSensitivity];
}

-(ZKSingularParser*)whitespace {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = [NSCharacterSet whitespaceCharacterSet];
    w.minMatches = 1;
    w.errorName = @"whitespace";
    return [self wrapDebug:w];
}

-(ZKSingularParser*)maybeWhitespace {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = [NSCharacterSet whitespaceCharacterSet];
    w.minMatches = 0;
    w.errorName = @"whitespace";
    return [self wrapDebug:w];
}

-(ZKSingularParser*)characters:(NSCharacterSet*)set name:(NSString*)name min:(NSUInteger)minMatches {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = set;
    w.errorName = name;
    w.minMatches = minMatches;
    return [self wrapDebug:w];
}

-(ZKSingularParser*)notCharacters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches {
    ZKParserCharSet *w = [ZKParserNotCharSet new];
    w.charSet = set;
    w.errorName = name;
    w.minMatches = minMatches;
    return [self wrapDebug:w];
}

-(ZKSingularParser*)integerNumber {
    return [self wrapDebug:[ZKParserInteger new]];
}

// match a decimal number
-(ZKSingularParser*)decimalNumber {
    return [self wrapDebug:[ZKParserDecimal new]];
}

-(ZKSingularParser*)regex:(NSRegularExpression*)regex name:(NSString*)name {
    return [self wrapDebug:[ZKParserRegex with:regex name:name]];
}

-(ZKSingularParser*)firstOf:(NSArray<ZKBaseParser*>*)items {
    return [self wrapDebug:[ZKParserFirstOf firstOf:items]];
}

-(ZKSingularParser *)oneOfTokens:(NSString *)items {
    // although its called oneOf... we can use firstOf because all the tokens are unique, we sort them
    // longest to shortest so that the longest match matches first.
    NSArray *list = [items componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    list = [list sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull a, id  _Nonnull b) {
        NSInteger alen = [a length];
        NSInteger blen = [b length];
        if (alen < blen) {
            return NSOrderedDescending;
        } else if (blen < alen) {
            return NSOrderedAscending;
        }
        return NSOrderedSame;
    }];
    // TODO, there's lots more scope to make this more efficient
    NSMutableArray<ZKBaseParser*> *parsers = [NSMutableArray arrayWithCapacity:list.count];
    for (NSString *s in list) {
        [parsers addObject:[[self eq:s] onMatch:setValue(s)]];
    }
    return [self wrapDebug:[self firstOf:parsers]];
}

-(ZKSingularParser*)oneOf:(NSArray<ZKBaseParser*>*)items {
    ZKParserOneOf *o = [ZKParserOneOf new];
    o.items = items;
    return [self wrapDebug:o];
}

-(ZKArrayParser*)seq:(NSArray<ZKBaseParser*>*)items {
    ZKParserSeq *s = [ZKParserSeq new];
    s.items = items;
    return [self wrapDebug:s];
}

-(ZKSingularParser*)zeroOrOne:(ZKBaseParser*)p {
    ZKParserOptional *o = [ZKParserOptional new];
    o.optional = p;
    o.ignoreBlock = ^BOOL(NSObject *v) {
        return NO;
    };
    return [self wrapDebug:o];
}

-(ZKSingularParser*)zeroOrOne:(ZKBaseParser*)p ignoring:(BOOL(^)(NSObject*))ignoreBlock {
    ZKParserOptional *o = [ZKParserOptional new];
    o.optional = p;
    o.ignoreBlock = ignoreBlock;
    return [self wrapDebug:o];
}

-(ZKArrayParser*)zeroOrMore:(ZKBaseParser*)p {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:NULL min:0 max:NSUIntegerMax]];
}

-(ZKArrayParser*)oneOrMore:(ZKBaseParser*)p {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:NULL min:1 max:NSUIntegerMax]];
}

-(ZKArrayParser*)zeroOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:sep min:0 max:NSUIntegerMax]];
}

-(ZKArrayParser*)oneOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:sep min:1 max:NSUIntegerMax]];
}

-(ZKArrayParser*)zeroOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep max:(NSUInteger)maxItems {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:sep min:0 max:maxItems]];
}

-(ZKArrayParser*)oneOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep max:(NSUInteger)maxItems {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:sep min:1 max:maxItems]];
}

-(ZKSingularParser*)fromBlock:(ParseBlock)parser {
    return [self wrapDebug:[ZKParserBlock block:parser]];
}

-(ZKParserRef*)parserRef {
    return [self wrapDebug:[ZKParserRef new]];
}

-(id)wrapDebug:(ZKBaseParser *)p {
    if (self.debugFile == nil) {
        return p;
    }
    if (self.debug == nil) {
        self.debug = [ParserDebugState new];
        self.debug.out = [NSFileHandle fileHandleForWritingAtPath:self.debugFile];
    }
    return [ParserDebug wrap:p state:self.debug];
}
@end

@implementation ParserDebugState
-(void)write:(NSString*)s {
    [self.out writeData:[[@"" stringByPaddingToLength:self.depth * 2 withString:@" " startingAtIndex:0] dataUsingEncoding:NSUTF8StringEncoding]];
    [self.out writeData:[s dataUsingEncoding:NSUTF8StringEncoding]];
}
@end

@implementation ParserDebug
+(instancetype)wrap:(ZKBaseParser*)p state:(ParserDebugState*)s {
    ParserDebug *d = [ParserDebug alloc];
    d.inner = p;
    d.state = s;
    return d;
}

-(NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [self.inner methodSignatureForSelector:sel];
}
-(void)forwardInvocation:(NSInvocation *)invocation {
    invocation.target = self.inner;
    [invocation invoke];
    if ([[invocation methodSignature] methodReturnType][0] == '@') {
        id __unsafe_unretained retVal;
        [invocation getReturnValue:&retVal];
        if (retVal == self.inner) {
            retVal = self;
            [invocation setReturnValue:&retVal];
        }
    }
}

-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err {
    NSString *name = self.description;
    [self.state write:[NSString stringWithFormat:@"=> %@ : %@\n", name, input.value]];
    BOOL isArray = [self.inner isKindOfClass:[ZKArrayParser class]];
    if (isArray) self.state.depth++;
    ParserResult *r = [self.inner parse:input error:err];
    if (isArray) self.state.depth--;
    if (*err == nil) {
        [self.state write:[NSString stringWithFormat:@"<= %@ : result %@\n", name, r]];
    } else {
        [self.state write:[NSString stringWithFormat:@"<= %@ : error  %@\n", name, *err]];
    }
    return r;
}

-(NSString *)description {
    return self.debugName != nil ? [NSString stringWithFormat:@"[%@]", self.debugName] : self.inner.description;
}

@end
