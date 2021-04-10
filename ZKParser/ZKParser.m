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
+(instancetype)result:(NSObject*)val locs:(NSArray<ParserResult*>*)locs {
    if (locs.count > 0) {
        NSRange loc = NSUnionRange(locs[0].loc, [locs lastObject].loc);
        return [self result:val loc:loc];
    }
    return [self result:val loc:NSMakeRange(0,0)];
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

@interface ZKParserExact : ZKParser
@property (strong,nonatomic) NSString *match;
@property (assign,nonatomic) ZKCaseSensitivity caseSensitivity;
@property (strong,nonatomic) MapperBlock onMatch;
@property (assign,nonatomic) BOOL returnValue;
@end

@interface ZKParserCharSet : ZKParser
@property (strong,nonatomic) NSCharacterSet* charSet;
@property (assign,nonatomic) NSUInteger minMatches;
@property (strong,nonatomic) NSString *errorName;
@property (assign,nonatomic) BOOL returnValue;
@end

@interface ZKParserNotCharSet : ZKParserCharSet
@end

@interface ZKParserFirstOf : ZKParser
@property (strong,nonatomic) MapperBlock matchBlock;
@property (strong,nonatomic) NSArray<ZKParser*>* items;
@end

@interface ZKParserOneOf()
@property (strong,nonatomic) MapperBlock matchBlock;
@property (strong,nonatomic) NSArray<ZKParser*>* items;
@end

@interface ZKParserSeq()
@property (strong,nonatomic) ArrayMapperBlock matchBlock;
@property (strong,nonatomic) NSArray<ZKParser*>* items;
@end

@interface ZKParserRepeat()
+(instancetype)repeated:(ZKParser*)p sep:(ZKParser*)sep min:(NSUInteger)min max:(NSUInteger)max;
@property (strong,nonatomic) ArrayMapperBlock matchBlock;
@property (strong,nonatomic) ZKParser *parser;
@property (strong,nonatomic) ZKParser *separator;
@property (assign,nonatomic) NSUInteger min;
@property (assign,nonatomic) NSUInteger max;
@end

@interface ZKParserOptional : ZKParser
@property (strong,nonatomic) ZKParser *optional;
@property (copy,nonatomic) BOOL(^ignoreBlock)(NSObject*);
@end

@interface ZKParserMapper : ZKParser
@property (strong, nonatomic) ZKParser *inner;
@property (strong, nonatomic) MapperBlock block;
@end

@interface ZKParserBlock : ZKParser
@property (copy,nonatomic) ParseBlock parser;
@property (strong, nonatomic) MapperBlock mapper;
@end


@implementation ZKParser
-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    assert(false);
}

-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err {
    if (self.debugName != nil) {
        NSLog(@"=> parse %@\t\tinput: %@", self.debugName, input.value);
    }
    *err = nil;
    ParserResult *r = [self parseImpl:input error:err];
    if (self.debugName != nil) {
        NSLog(@"<= parse %@ :%@", self.debugName, [*err localizedDescription]);
    }
    return r;
}

-(ZKParserOneOf*)or:(NSArray<ZKParser*>*)otherParsers {
    ZKParserOneOf *o = [ZKParserOneOf new];
    o.items = [@[self] arrayByAddingObjectsFromArray:otherParsers];
    return o;
}

-(ZKParserSeq*)then:(NSArray<ZKParser*>*)otherParsers {
    ZKParserSeq *s = [ZKParserSeq new];
    s.items = [@[self] arrayByAddingObjectsFromArray:otherParsers];
    return s;
}

-(ZKParserSeq*)thenZeroOrMore:(ZKParser*)parser {
    return [self then:@[[ZKParserRepeat repeated:parser sep:nil min:0 max:NSUIntegerMax]]];
}

-(ZKParserSeq*)thenOneOrMore:(ZKParser*)parser {
    return [self then:@[[ZKParserRepeat repeated:parser sep:nil min:1 max:NSUIntegerMax]]];
}

@end

@implementation ZKParserRef

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    return [self.parser parse:input error:err];
}

@end

@implementation ZKParserMapper
-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    ParserResult *res = [self.inner parse:input error:err];
    if (*err == nil) {
        return self.block(res);
    }
    return nil;
}
@end

@implementation ZKParserExact
-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSInteger start = input.pos;
    NSString *res = [input consumeString:self.match caseSensitive:self.caseSensitivity];
    if (res != nil) {
        NSRange pos = NSMakeRange(start, input.pos-start);
        ParserResult *r = [ParserResult result:res loc:pos];
        return self.onMatch == nil ? r : self.onMatch(r);
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
    return self.match;
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
                [input rewindTo:start];
                return nil;
            }
            NSRange rng = NSMakeRange(start, count);
            return [ParserResult result:[input valueOfRange:rng] loc:rng];
        }
        count++;
    }
}
-(NSString *)description {
    return [NSString stringWithFormat:@"{%@ x %lu}", self.errorName, self.minMatches];
}
@end

@implementation ZKParserNotCharSet

-(void)setCharSet:(NSCharacterSet*)set {
    [super setCharSet:[set invertedSet]];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"{!%@ x %lu}", self.errorName, self.minMatches];
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
            if (self.matchBlock != nil) {
                r = self.matchBlock(r);
            }
            return r;
        }
        [input rewindTo:start];
    }
    return nil;
}
@end

@implementation ZKParserOneOf

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    ParserResult *res = [self parseInput:input error:err];
    if (*err == nil && self.matchBlock != nil) {
        return self.matchBlock(res);
    }
    return res;
}

-(ParserResult *)parseInput:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSUInteger longestPos = start;
    ParserResult *longestRes = nil;
    NSError *childErr = nil;
    for (ZKParser *child in self.items) {
        ParserResult *r = [child parse:input error:&childErr];
        if (input.pos > longestPos) {
            longestRes = r;
            longestPos = input.pos;
        } else {
            if (childErr != nil && *err == nil) {
                *err = childErr;
            }
        }
        [input rewindTo:start];
    }
    if (longestPos > start) {
        *err = nil;
        [input rewindTo:longestPos];
    }
    return longestRes;
}

-(ZKParserOneOf*)or:(NSArray<ZKParser*>*)otherParsers {
    if (self.matchBlock == nil) {
        self.items = [self.items arrayByAddingObjectsFromArray:otherParsers];
        return self;
    }
    return [super or:otherParsers];
}

-(ZKParserOneOf*)onMatch:(MapperBlock)block {
    self.matchBlock = block;
    return self;
}

@end

@implementation ZKParserSeq
-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:self.items.count];
    for (ZKParser *child in self.items) {
        ParserResult *res = [child parse:input error:err];
        if (*err != nil) {
            [input rewindTo:start];
            return nil;
        }
        [out addObject:res];
    }
    ArrayParserResult *r = [ArrayParserResult result:out loc:NSMakeRange(start, input.pos-start)];
    if (self.matchBlock != nil) {
        return self.matchBlock(r);
    }
    return r;
}

-(ZKParserSeq*)onMatch:(ArrayMapperBlock)block {
    self.matchBlock = block;
    return self;
}

-(ZKParserSeq*)then:(NSArray<ZKParser*>*)otherParsers {
    if (self.matchBlock == nil) {
        self.items = [self.items arrayByAddingObjectsFromArray:otherParsers];
        return self;
    }
    return [super then:otherParsers];
}

-(NSString*)description {
    return [self.items description];
}

@end

@implementation ZKParserRepeat

+(instancetype)repeated:(ZKParser*)p sep:(ZKParser*)sep min:(NSUInteger)min max:(NSUInteger)max {
    ZKParserRepeat *r = [ZKParserRepeat new];
    r.parser = p;
    r.separator = sep;
    r.min = min;
    r.max = max;
    r.matchBlock = ^ParserResult *(ParserResult*r) {
        return r;
    };
    return r;
}

-(ZKParserRepeat*)onMatch:(ArrayMapperBlock)block {
    self.matchBlock = block;
    return self;
}

-(ParserResult *)parseImpl:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSMutableArray<ParserResult*> *out = [NSMutableArray array];
    NSError *nextError = nil;
    ParserResult *first = [self.parser parse:input error:&nextError];
    if (nextError == nil) {
        [out addObject:first];
        while (out.count < self.max) {
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
            [out addObject:next];
        }
    }
    if (out.count >= self.min) {
        ArrayParserResult *r = [ArrayParserResult result:out loc:NSMakeRange(start, input.pos-start)];
        return self.matchBlock(r);
    }
    *err = nextError;
    [input rewindTo:start];
    return nil;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"{%lu}x%@", self.min, self.parser];
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
    return [NSString stringWithFormat:@"{%@}?" , self.optional];
}

@end

@implementation ZKParserBlock
+(instancetype)block:(ParseBlock)b mapper:(MapperBlock)m {
    ZKParserBlock *p = [ZKParserBlock new];
    p.parser = b;
    p.mapper = m;
    return p;
}

-(ParserResult*)parseImpl:(ZKParserInput*)i error:(NSError**)err {
    ParserResult *res = self.parser(i,err);
    if (*err == nil && self.mapper != nil) {
        res = self.mapper(res);
    }
    return res;
}
@end

@implementation ZKParserFactory

-(ZKParser*)map:(ZKParser*)p onMatch:(MapperBlock)block {
    ZKParserMapper *m = [ZKParserMapper new];
    m.inner = p;
    m.block = block;
    return m;
}

-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c onMatch:(MapperBlock)block {
    ZKParserExact *e = [ZKParserExact new];
    e.match = s;
    e.caseSensitivity = c;
    e.onMatch = block;
    e.returnValue = YES;
    e.debugName = [NSString stringWithFormat:@"eq:%@", s];
    return e;
}

-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c {
    return [self exactly:s case:c onMatch:nil];
}

-(ZKParser*)exactly:(NSString *)s {
    return [self exactly:s case:self.defaultCaseSensitivity];
}

-(ZKParser*)eq:(NSString *)s {
    return [self exactly:s case:self.defaultCaseSensitivity];
}
-(ZKParser*)exactly:(NSString *)s setValue:(NSObject*)val {
    return [self exactly:s case:self.defaultCaseSensitivity onMatch:^ParserResult*(ParserResult*r) {
        r.val = val;
        return r;
    }];
}

-(ZKParser*)skip:(NSString *)s {
    ZKParserExact *e = [ZKParserExact new];
    e.match = s;
    e.caseSensitivity = self.defaultCaseSensitivity;
    e.returnValue = NO;
    e.debugName = [NSString stringWithFormat:@"skip: %@", s];
    return e;
}

-(ZKParser*)whitespace {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = [NSCharacterSet whitespaceCharacterSet];
    w.minMatches = 1;
    w.errorName = @"whitespace";
    w.returnValue = NO;
    w.debugName = w.errorName;
    return w;
}

-(ZKParser*)maybeWhitespace {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = [NSCharacterSet whitespaceCharacterSet];
    w.minMatches = 0;
    w.errorName = @"whitespace";
    w.returnValue = NO;
    w.debugName = w.errorName;
    return w;
}

-(ZKParser*)characters:(NSCharacterSet*)set name:(NSString*)name min:(NSUInteger)minMatches {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = set;
    w.errorName = name;
    w.minMatches = minMatches;
    w.returnValue = YES;
    return w;
}

-(ZKParser*)notCharacters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches {
    ZKParserCharSet *w = [ZKParserNotCharSet new];
    w.charSet = set;
    w.errorName = name;
    w.minMatches = minMatches;
    w.returnValue = YES;
    return w;
}

-(ZKParser*)firstOf:(NSArray<ZKParser*>*)items {
    return [ZKParserFirstOf firstOf:items];
}

-(ZKParser*)firstOf:(NSArray<ZKParser*>*)items onMatch:(MapperBlock)block {
    ZKParserFirstOf *p = [ZKParserFirstOf firstOf:items];
    p.matchBlock = block;
    return p;
}

-(ZKParser *)oneOfTokens:(NSString *)items {
    // although its called oneOf... we can use firstOf because all the tokens are unique, we sort them
    // longest to shortest so that the longest one matches first.
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
    NSMutableArray<ZKParser*> *parsers = [NSMutableArray arrayWithCapacity:list.count];
    for (NSString *s in list) {
        [parsers addObject:[self exactly:s]];
    }
    return [self firstOf:parsers];
}


-(ZKParser*)oneOf:(NSArray<ZKParser*>*)items {
    ZKParserOneOf *o = [ZKParserOneOf new];
    o.items = items;
    return o;
}

-(ZKParser*)oneOf:(NSArray<ZKParser*>*)items onMatch:(MapperBlock)block {
    ZKParserOneOf *o = [ZKParserOneOf new];
    o.items = items;
    o.matchBlock = block;
    return o;
}

-(ZKParser*)seq:(NSArray<ZKParser*>*)items {
    ZKParserSeq *s = [ZKParserSeq new];
    s.items = items;
    return s;
}

-(ZKParser*)seq:(NSArray<ZKParser*>*)items onMatch:(ArrayMapperBlock)block {
    ZKParserSeq *s = [ZKParserSeq new];
    s.items = items;
    s.matchBlock = block;
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

-(ZKParser*)fromBlock:(ParseBlock)parser mapper:(MapperBlock)m {
    return [ZKParserBlock block:parser mapper:m];
}

@end
