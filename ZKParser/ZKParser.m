//
//  ZKParser.m
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import "ZKParser.h"

@implementation ParserResult
+(instancetype)result:(NSObject*)val loc:(NSRange)loc {
    ParserResult *r = [self new];
    r.val = val;
    r.loc = loc;
    return r;
}

-(BOOL)isEqual:(ParserResult*)other {
    return [self.val isEqual:other.val] && (self.loc.location == other.loc.location) && (self.loc.length == other.loc.length);
}
-(NSArray<ParserResult*>*)children {
    assert([self.val isKindOfClass:[NSArray class]]);
    return self.val;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"%@ {%lu,%lu}", self.val, self.loc.location, self.loc.length];
}
@end

@implementation ArrayParserResult
+(instancetype)result:(NSArray<ParserResult*>*)val loc:(NSRange)loc {
    ArrayParserResult *r = [ArrayParserResult new];
    r.val = val;
    r.loc = loc;
    r.child = val;
    return r;
}
-(NSArray*)childVals {
    return [self.child valueForKey:@"val"];
}
-(BOOL)childIsNull:(NSInteger)idx {
    ParserResult *r = self.child[idx];
    return r.val == [NSNull null] || r.val == nil;
}
-(void)setVal:(id)v {
    super.val = v;
    self.child = v;
}

@end

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

@interface ZKParserFirstOf : ZKSingularParser
@property (strong,nonatomic) NSArray<ZKParser*>* items;
@end

@interface ZKParserOneOf()
@property (strong,nonatomic) NSArray<ZKParser*>* items;
@end

@interface ZKParserSeq()
@property (strong,nonatomic) NSArray<ZKParser*>* items;
@end

@interface ZKParserRepeat()
+(instancetype)repeated:(ZKParser*)p sep:(ZKParser*)sep min:(NSUInteger)min max:(NSUInteger)max;
@property (strong,nonatomic) ZKParser *parser;
@property (strong,nonatomic) ZKParser *separator;
@property (assign,nonatomic) NSUInteger min;
@property (assign,nonatomic) NSUInteger max;
@end

@interface ZKParserOptional : ZKSingularParser
@property (strong,nonatomic) ZKParser *optional;
@property (copy,nonatomic) BOOL(^ignoreBlock)(NSObject*);   // is this the right places for this? seems like it should be on eq and/or charSet
@end

@interface ZKParserBlock : ZKSingularParser
@property (copy,nonatomic) ParseBlock parser;
@end


@implementation ZKParser
-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    assert(false);
}

-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err {
    // TODO add debug logging back in
    *err = nil;
    NSInteger start = input.pos;
    ParserResult *r = [self parseImpl:input error:err];
    if (*err != nil) {
        [input rewindTo:start];
    }
    return r;
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

@implementation ZKParserFirstOf

+(instancetype)firstOf:(NSArray<ZKParser*>*)opts {
    ZKParserFirstOf *p = [ZKParserFirstOf new];
    p.items = opts;
    return p;
}

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    for (ZKParser *child in self.items) {
        ParserResult *r = [child parse:input error:err];
        if (*err == nil) {
            return r;
        }
        [input rewindTo:start];
    }
    return nil;
}
@end

@implementation ZKParserOneOf

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSUInteger longestPos = start;
    ParserResult *longestRes = nil;
    NSError *childErr = nil;
    BOOL success = FALSE;
    for (ZKParser *child in self.items) {
        ParserResult *r = [child parse:input error:&childErr];
        if ((childErr == nil) && (input.pos > longestPos)) {
            longestRes = r;
            longestPos = input.pos;
            success = TRUE;
        }
        if (childErr != nil && *err == nil) {
            *err = childErr;
        }
        [input rewindTo:start];
    }
    if (success) {
        *err = nil;
        [input rewindTo:longestPos];
    }
    return longestRes;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"[oneOf:%@]", self.items];
}

@end

@implementation ZKParserSeq

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:self.items.count];
    for (ZKParser *child in self.items) {
        ParserResult *res = [child parse:input error:err];
        if (*err != nil) {
            return nil;
        }
        [results addObject:res];
    }
    return [ArrayParserResult result:results loc:NSMakeRange(start, input.pos-start)];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"[seq:%@]", self.items];
}

@end

@implementation ZKParserRepeat

+(instancetype)repeated:(ZKParser*)p sep:(ZKParser*)sep min:(NSUInteger)min max:(NSUInteger)max {
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
                [input rewindTo:thisStart];
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
    return [NSString stringWithFormat:@"[repeat{%lu,%lu} %@ %@}", self.min, self.max, self.parser, self.separator];
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
    [input rewindTo:start];
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
    return [NSString stringWithFormat:@"[ref:%@]", self.parser];
}

@end

@implementation ZKParserBlock
+(instancetype)block:(ParseBlock)b mapper:(ResultMapper)m {
    ZKParserBlock *p = [ZKParserBlock new];
    p.parser = b;
    p.mapper = m;
    return p;
}

-(ParserResult*)parseImpl:(ZKParserInput*)i error:(NSError**)err {
    return self.parser(i,err);
}

@end

@implementation ZKParserFactory

-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c onMatch:(ResultMapper)block {
    ZKParserExact *e = [ZKParserExact new];
    e.match = s;
    e.caseSensitivity = c;
    e.mapper = block;
    return e;
}

-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c {
    return [self exactly:s case:c onMatch:nil];
}

-(ZKParser*)eq:(NSString *)s {
    return [self exactly:s case:self.defaultCaseSensitivity];
}

// setValue should be helper function instead? same as pick.
-(ZKParser*)exactly:(NSString *)s setValue:(NSObject*)val {
    return [self exactly:s case:self.defaultCaseSensitivity onMatch:^ParserResult*(ParserResult*r) {
        r.val = val;
        return r;
    }];
}

-(ZKParser*)whitespace {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = [NSCharacterSet whitespaceCharacterSet];
    w.minMatches = 1;
    w.errorName = @"whitespace";
    return w;
}

-(ZKParser*)maybeWhitespace {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = [NSCharacterSet whitespaceCharacterSet];
    w.minMatches = 0;
    w.errorName = @"whitespace";
    return w;
}

-(ZKParser*)characters:(NSCharacterSet*)set name:(NSString*)name min:(NSUInteger)minMatches {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = set;
    w.errorName = name;
    w.minMatches = minMatches;
    return w;
}

-(ZKParser*)notCharacters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches {
    ZKParserCharSet *w = [ZKParserNotCharSet new];
    w.charSet = set;
    w.errorName = name;
    w.minMatches = minMatches;
    return w;
}

-(ZKParser*)firstOf:(NSArray<ZKParser*>*)items {
    return [ZKParserFirstOf firstOf:items];
}

-(ZKParser*)firstOf:(NSArray<ZKParser*>*)items onMatch:(ResultMapper)block {
    ZKParserFirstOf *p = [ZKParserFirstOf firstOf:items];
    p.mapper = block;
    return p;
}

-(ZKParser *)oneOfTokens:(NSString *)items {
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
    NSMutableArray<ZKParser*> *parsers = [NSMutableArray arrayWithCapacity:list.count];
    for (NSString *s in list) {
        [parsers addObject:[self eq:s]];
    }
    return [self firstOf:parsers];
}

-(ZKParser*)oneOf:(NSArray<ZKParser*>*)items {
    ZKParserOneOf *o = [ZKParserOneOf new];
    o.items = items;
    return o;
}

-(ZKParser*)oneOf:(NSArray<ZKParser*>*)items onMatch:(ResultMapper)block {
    ZKParserOneOf *o = [ZKParserOneOf new];
    o.items = items;
    o.mapper = block;
    return o;
}

-(ZKParser*)seq:(NSArray<ZKParser*>*)items {
    ZKParserSeq *s = [ZKParserSeq new];
    s.items = items;
    return s;
}

-(ZKParser*)seq:(NSArray<ZKParser*>*)items onMatch:(ArrayResultMapper)block {
    ZKParserSeq *s = [ZKParserSeq new];
    s.items = items;
    s.mapper = block;
    return s;
}

-(ZKParser*)zeroOrOne:(ZKParser*)p {
    ZKParserOptional *o = [ZKParserOptional new];
    o.optional = p;
    o.ignoreBlock = ^BOOL(NSObject *v) {
        return NO;
    };
    return o;
}

-(ZKParser*)zeroOrOne:(ZKParser*)p ignoring:(BOOL(^)(NSObject*))ignoreBlock {
    ZKParserOptional *o = [ZKParserOptional new];
    o.optional = p;
    o.ignoreBlock = ignoreBlock;
    return o;
}

-(ZKParserRepeat*)zeroOrMore:(ZKParser*)p {
    return [ZKParserRepeat repeated:p sep:NULL min:0 max:NSUIntegerMax];
}

-(ZKParserRepeat*)oneOrMore:(ZKParser*)p {
    return [ZKParserRepeat repeated:p sep:NULL min:1 max:NSUIntegerMax];
}

-(ZKParserRepeat*)zeroOrMore:(ZKParser*)p separator:(ZKParser*)sep {
    return [ZKParserRepeat repeated:p sep:sep min:0 max:NSUIntegerMax];
}

-(ZKParserRepeat*)oneOrMore:(ZKParser*)p separator:(ZKParser*)sep {
    return [ZKParserRepeat repeated:p sep:sep min:1 max:NSUIntegerMax];
}

-(ZKParserRepeat*)zeroOrMore:(ZKParser*)p separator:(ZKParser*)sep max:(NSUInteger)maxItems {
    return [ZKParserRepeat repeated:p sep:sep min:0 max:maxItems];
}

-(ZKParserRepeat*)oneOrMore:(ZKParser*)p separator:(ZKParser*)sep max:(NSUInteger)maxItems {
    return [ZKParserRepeat repeated:p sep:sep min:1 max:maxItems];
}

-(ZKParser*)fromBlock:(ParseBlock)parser {
    return [ZKParserBlock block:parser mapper:nil];
}

-(ZKParser*)fromBlock:(ParseBlock)parser mapper:(ResultMapper)m {
    return [ZKParserBlock block:parser mapper:m];
}

-(ZKParserRef*)parserRef {
    return [ZKParserRef new];
}

@end
