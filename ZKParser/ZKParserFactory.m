//
//  ZKParser.m
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import "ZKParserFactory.h"

@interface ZKMatchMapperParser : ZKBaseParser
@property (strong,nonatomic) ZKBaseParser *inner;
@property (copy,nonatomic) ZKResultMapper mapper;
@end

@interface ZKErrorMapperParser : ZKBaseParser
@property (strong,nonatomic) ZKBaseParser *inner;
@property (copy,nonatomic) ZKErrorMapper mapper;
@end

@interface ZKParserExact : ZKBaseParser
@property (strong,nonatomic) NSString *match;
@property (assign,nonatomic) ZKCaseSensitivity caseSensitivity;
@end

@interface ZKParserCharSet : ZKBaseParser
@property (strong,nonatomic) NSCharacterSet* charSet;
@property (assign,nonatomic) NSUInteger minMatches;
@property (strong,nonatomic) NSString *errorName;
@end

@interface ZKParserNotCharSet : ZKParserCharSet
@end

@interface ZKParserInteger : ZKBaseParser
@end

@interface ZKParserDecimal : ZKBaseParser
@end

@interface ZKParserRegex : ZKBaseParser
@property (strong,nonatomic) NSRegularExpression *regex;
@property (strong,nonatomic) NSString *name;
@end

@interface ZKParserFirstOf : ZKBaseParser
@property (strong,nonatomic) NSArray<ZKBaseParser*>* items;
@end

@interface ZKParserOneOf : ZKBaseParser
@property (strong,nonatomic) NSArray<ZKBaseParser*>* items;
@end

@interface ZKParserSeq : ZKBaseParser
@property (strong,nonatomic) NSArray<ZKBaseParser*>* items;
@end

@interface ZKParserRepeat : ZKBaseParser
+(instancetype)repeated:(ZKBaseParser*)p sep:(ZKBaseParser*)sep min:(NSUInteger)min max:(NSUInteger)max;
@property (strong,nonatomic) ZKBaseParser *parser;
@property (strong,nonatomic) ZKBaseParser *separator;
@property (assign,nonatomic) NSUInteger min;
@property (assign,nonatomic) NSUInteger max;
@end

@interface ZKParserOptional : ZKBaseParser
@property (strong,nonatomic) ZKBaseParser *optional;
@property (copy,nonatomic) BOOL(^ignoreBlock)(NSObject*);   // is this the right places for this? seems like it should be on eq and/or charSet
@end

@interface ZKParserBlock : ZKBaseParser
@property (copy,nonatomic) ZKParseBlock parser;
@end


@implementation ZKBaseParser

-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
    assert(false);
}

// The default impl for parse will do some common bookkeeping / behavour
// then call parseImpl to do the actual parsing.
-(ZKParserResult *)parse:(ZKParsingState*)input error:(NSError **)err {
    *err = nil;
    NSInteger start = input.pos;
    ZKParserResult *r = [self parseImpl:input error:err];
    if (*err != nil) {
        [input moveTo:start];
    }
    return r;
}

-(NSString *)parsersDesc:(NSArray<ZKBaseParser*>*)parsers {
    NSMutableString *s = [NSMutableString stringWithCapacity:64];
    [s appendString:@"["];
    NSString *sep = @"";
    for (ZKBaseParser *p in parsers) {
        [s appendString:sep];
        [s appendString:p.description];
        sep = @",";
    }
    [s appendString:@"]"];
    return s;
}

-(void)setDebugName:(NSString *)n {
    // only does something useful in debug proxy
}

-(BOOL)containsChildParsers {
    return NO;
}

@end

@implementation ZKMatchMapperParser

-(ZKParserResult *)parse:(ZKParsingState*)input error:(NSError **)err {
    ZKParserResult *r = [self.inner parse:input error:err];
    if (*err == nil) {
        r = self.mapper(r);
    }
    return r;
}
-(BOOL)containsChildParsers {
    return TRUE;
}
-(NSString*)description {
    return [NSString stringWithFormat:@"[onMatch:%@]", self.inner.description];
}

@end

@implementation ZKErrorMapperParser

-(ZKParserResult *)parse:(ZKParsingState*)input error:(NSError **)err {
    ZKParserResult *r = [self.inner parse:input error:err];
    if (*err != nil) {
        self.mapper(err);
    }
    return r;
}
-(BOOL)containsChildParsers {
    return TRUE;
}
-(NSString*)description {
    return [NSString stringWithFormat:@"[onError:%@]", self.inner.description];
}

@end

@implementation ZKParserExact
-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
    NSInteger start = input.pos;
    NSString *res = [input consumeString:self.match caseSensitive:self.caseSensitivity];
    if (res != nil) {
        NSRange pos = NSMakeRange(start, input.pos-start);
        return [ZKParserResult result:res ctx:input.userContext loc:pos];
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

-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
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
            return [ZKParserResult result:[input valueOfRange:rng] ctx:input.userContext loc:rng];
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

-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
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
    return [ZKParserResult result:[NSNumber numberWithInteger:val * sign] ctx:input.userContext loc:NSMakeRange(start,input.pos-start)];
}

-(NSString *)description {
    return @"[integer]";
}

@end

@implementation ZKParserDecimal

-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
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
    return [ZKParserResult result:val ctx:input.userContext loc:NSMakeRange(start,input.pos-start)];
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

-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
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
    return [ZKParserResult result:[input valueOfRange:match] ctx:input.userContext loc:match];
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

-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    for (ZKBaseParser *child in self.items) {
        ZKParserResult *r = [child parse:input error:err];
        if (*err == nil) {
            return r;
        }
        // The cut point was moved past our start, we're done.
        if (![input canMoveTo:start]) {
            return nil;
        }
        [input moveTo:start];
    }
    return nil;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"[firstOf: %@]", [self parsersDesc:self.items]];
}

-(BOOL)containsChildParsers {
    return YES;
}

@end

@implementation ZKParserOneOf

-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSUInteger longestPos = start;
    ZKParserResult *longestRes = nil;
    NSError *childErr = nil;
    BOOL success = FALSE;
    for (ZKBaseParser *child in self.items) {
        ZKParserResult *r = [child parse:input error:&childErr];
        if ((childErr == nil) && (input.pos > longestPos)) {
            longestRes = r;
            longestPos = input.pos;
            success = TRUE;
        }
        if (childErr != nil && *err == nil) {
            *err = childErr;
        }
        if (![input canMoveTo:start]) {
            // The cut point was moved past our start, we're done
            *err = childErr;
            return r;
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

-(BOOL)containsChildParsers {
    return NO;
}

@end

@implementation ZKParserSeq

-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:self.items.count];
    for (ZKBaseParser *child in self.items) {
        ZKParserResult *res = [child parse:input error:err];
        if (*err != nil) {
            return nil;
        }
        [results addObject:res];
    }
    return [ZKParserResult result:results ctx:input.userContext loc:NSMakeRange(start, input.pos-start)];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"[seq: %@]", [self parsersDesc:self.items]];
}

-(BOOL)containsChildParsers {
    return YES;
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

-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSMutableArray<ZKParserResult*> *results = [NSMutableArray array];
    NSError *nextError = nil;
    ZKParserResult *first = [self.parser parse:input error:&nextError];
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
            ZKParserResult *next = [self.parser parse:input error:&nextError];
            if (nextError != nil) {
                // unconsume the separator above
                if ([input canMoveTo:thisStart]) {
                    [input moveTo:thisStart];
                    break;
                }
                *err = nextError;
                return nil;
            }
            [results addObject:next];
        }
    }
    if (results.count >= self.min) {
        return [ZKParserResult result:results ctx:input.userContext loc:NSMakeRange(start, input.pos-start)];
    }
    *err = nextError;
    return nil;
}

-(NSString *)description {
    NSString *sz = self.max == NSUIntegerMax ? [NSString stringWithFormat:@"%lu+", self.min] : [NSString stringWithFormat:@"%lu-%lu", self.min, self.max];
    return [NSString stringWithFormat:@"[%@ r:%@ s:%@]", sz, self.parser, self.separator];
}

-(BOOL)containsChildParsers {
    return YES;
}

@end

@implementation ZKParserOptional

-(ZKParserResult *)parseImpl:(ZKParsingState*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    ZKParserResult *res = [self.optional parse:input error:err];
    if (*err == nil) {
        if (!self.ignoreBlock(res.val)) {
            return res;
        }
    }
    if ([input canMoveTo:start]) {
        *err = nil;
        [input moveTo:start];
        return [ZKParserResult result:[NSNull null] ctx:input.userContext loc:NSMakeRange(start,0)];
    }
    return nil;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"%@?" , self.optional];
}

@end

@implementation ZKParserRef

-(ZKParserResult *)parse:(ZKParsingState*)input error:(NSError **)err {
    return [self.parser parse:input error:err];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"[ref:%p]", self.parser];
}

@end

@implementation ZKParserBlock
+(instancetype)block:(ZKParseBlock)b {
    ZKParserBlock *p = [ZKParserBlock new];
    p.parser = b;
    return p;
}

-(ZKParserResult*)parseImpl:(ZKParsingState*)i error:(NSError**)err {
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

-(ZKBaseParser*)eq:(NSString *)s case:(ZKCaseSensitivity)c {
    ZKParserExact *e = [ZKParserExact new];
    e.match = s;
    e.caseSensitivity = c;
    return [self wrapDebug:e];
}

-(ZKBaseParser*)eq:(NSString *)s {
    return [self eq:s case:self.defaultCaseSensitivity];
}

-(ZKBaseParser*)whitespace {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = [NSCharacterSet whitespaceCharacterSet];
    w.minMatches = 1;
    w.errorName = @"whitespace";
    return [self wrapDebug:w];
}

-(ZKBaseParser*)maybeWhitespace {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = [NSCharacterSet whitespaceCharacterSet];
    w.minMatches = 0;
    w.errorName = @"whitespace";
    return [self wrapDebug:w];
}

-(ZKBaseParser*)characters:(NSCharacterSet*)set name:(NSString*)name min:(NSUInteger)minMatches {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = set;
    w.errorName = name;
    w.minMatches = minMatches;
    return [self wrapDebug:w];
}

-(ZKBaseParser*)notCharacters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches {
    ZKParserCharSet *w = [ZKParserNotCharSet new];
    w.charSet = set;
    w.errorName = name;
    w.minMatches = minMatches;
    return [self wrapDebug:w];
}

-(ZKBaseParser*)integerNumber {
    return [self wrapDebug:[ZKParserInteger new]];
}

// match a decimal number
-(ZKBaseParser*)decimalNumber {
    return [self wrapDebug:[ZKParserDecimal new]];
}

-(ZKBaseParser*)regex:(NSRegularExpression*)regex name:(NSString*)name {
    return [self wrapDebug:[ZKParserRegex with:regex name:name]];
}

-(ZKBaseParser*)firstOf:(NSArray<ZKBaseParser*>*)items {
    return [self wrapDebug:[ZKParserFirstOf firstOf:items]];
}

-(ZKBaseParser *)oneOfTokens:(NSString *)items {
    // although its called oneOf... we can use firstOf because all the tokens are unique, we sort them
    // longest to shortest so that the longest match matches first.
    NSArray *list = [items componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return [self oneOfTokensList:list];
}

-(ZKBaseParser*)oneOfTokensList:(NSArray<NSString *>*)list {
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
        ZKBaseParser *p = [self eq:s];
        p = [self onMatch:p perform:setValue(s)];
        [parsers addObject:p];
    }
    return [self wrapDebug:[self firstOf:parsers]];
}

-(ZKBaseParser*)oneOf:(NSArray<ZKBaseParser*>*)items {
    ZKParserOneOf *o = [ZKParserOneOf new];
    o.items = items;
    return [self wrapDebug:o];
}

-(ZKBaseParser*)seq:(NSArray<ZKBaseParser*>*)items {
    ZKParserSeq *s = [ZKParserSeq new];
    s.items = items;
    return [self wrapDebug:s];
}

-(ZKBaseParser*)zeroOrOne:(ZKBaseParser*)p {
    ZKParserOptional *o = [ZKParserOptional new];
    o.optional = p;
    o.ignoreBlock = ^BOOL(NSObject *v) {
        return NO;
    };
    return [self wrapDebug:o];
}

-(ZKBaseParser*)zeroOrOne:(ZKBaseParser*)p ignoring:(BOOL(^)(NSObject*))ignoreBlock {
    ZKParserOptional *o = [ZKParserOptional new];
    o.optional = p;
    o.ignoreBlock = ignoreBlock;
    return [self wrapDebug:o];
}

-(ZKBaseParser*)zeroOrMore:(ZKBaseParser*)p {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:NULL min:0 max:NSUIntegerMax]];
}

-(ZKBaseParser*)oneOrMore:(ZKBaseParser*)p {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:NULL min:1 max:NSUIntegerMax]];
}

-(ZKBaseParser*)zeroOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:sep min:0 max:NSUIntegerMax]];
}

-(ZKBaseParser*)oneOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:sep min:1 max:NSUIntegerMax]];
}

-(ZKBaseParser*)zeroOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep max:(NSUInteger)maxItems {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:sep min:0 max:maxItems]];
}

-(ZKBaseParser*)oneOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep max:(NSUInteger)maxItems {
    return [self wrapDebug:[ZKParserRepeat repeated:p sep:sep min:1 max:maxItems]];
}

-(ZKBaseParser*)fromBlock:(ZKParseBlock)parser {
    return [self wrapDebug:[ZKParserBlock block:parser]];
}

-(ZKParserRef*)parserRef {
    return [self wrapDebug:[ZKParserRef new]];
}

-(ZKBaseParser*)cut {
    ZKBaseParser *p = [self fromBlock:^ZKParserResult *(ZKParsingState *input, NSError *__autoreleasing *err) {
        [input markCut];
        return [ZKParserResult result:[NSNull null] ctx:input.userContext loc:NSMakeRange(input.pos,0)];
    }];
    p.debugName = @"CUT";
    return p;
}

-(ZKBaseParser*)onMatch:(ZKBaseParser*)p perform:(ZKResultMapper)mapper {
    ZKMatchMapperParser *mp = [ZKMatchMapperParser new];
    mp.inner = p;
    mp.mapper = mapper;
    return [self wrapDebug:mp];
}

-(ZKBaseParser*)onError:(ZKBaseParser*)p perform:(ZKErrorMapper)mapper {
    ZKErrorMapperParser *mp = [ZKErrorMapperParser new];
    mp.inner = p;
    mp.mapper = mapper;
    return [self wrapDebug:mp];
}

-(id)wrapDebug:(ZKBaseParser *)p {
    if (self.debugFile == nil) {
        return p;
    }
    if (self.debug == nil) {
        self.debug = [ParserDebugState new];
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.debugFile]) {
            [[NSFileManager defaultManager] createFileAtPath:self.debugFile contents:nil attributes:nil];
        }
        self.debug.out = [NSFileHandle fileHandleForWritingAtPath:self.debugFile];
        [self.debug.out seekToEndOfFile];
        [self.debug.out writeData:[[NSString stringWithFormat:@"\nParser Debug Log %@\n", [NSDate date].description] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    return [ParserDebug wrap:p state:self.debug];
}
@end

@implementation ParserDebugState
-(void)write:(NSString*)s {
    [self.out writeData:[[@"" stringByPaddingToLength:self.depth * 3 withString:@" " startingAtIndex:0] dataUsingEncoding:NSUTF8StringEncoding]];
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

-(ZKParserResult *)parse:(ZKParsingState*)input error:(NSError **)err {
    NSString *name = self.description;
    if(name.length > 80) {
        name = [NSString stringWithFormat:@"%@...", [name substringToIndex:80]];
    }
    NSString *nextInput = [[[input valueOfRange:NSMakeRange(input.pos, MIN(input.length,40))]
                           stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]
                           stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    [self.state write:[NSString stringWithFormat:@"=> %@ : %@\n", name, nextInput]];
    BOOL isArray = self.inner.containsChildParsers;
    if (isArray) self.state.depth++;
    ZKParserResult *r = [self.inner parse:input error:err];
    if (isArray) self.state.depth--;
    if (*err == nil) {
        [self.state write:[NSString stringWithFormat:@"<= %@ :result: %@\n", name, r]];
    } else {
        [self.state write:[NSString stringWithFormat:@"<= %@ :error : %@\n", name, (*err).localizedDescription]];
    }
    return r;
}

-(NSString *)description {
    return self.debugName != nil ? [NSString stringWithFormat:@"[%@]", self.debugName] : self.inner.description;
}

@end
