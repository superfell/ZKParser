//
//  ZKParser.m
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import "ZKParser.h"


typedef NSObject *(^mapperBlock)(NSObject *);

@interface ZKParserOneOf()
@property (strong,nonatomic) NSObject*(^matchBlock)(NSObject*);
@property (strong,nonatomic) NSArray<ZKParser*>* items;
@end
@interface ZKParserSeq()
@property (strong,nonatomic) NSObject*(^matchBlock)(NSArray*);
@property (strong,nonatomic) NSArray<ZKParser*>* items;
@end

@interface ZKParserMapper : ZKParser
@property (strong, nonatomic) ZKParser *inner;
@property (strong, nonatomic) mapperBlock block;
@end

@interface ZKParserExact : ZKParser
@property (strong,nonatomic) NSString *match;
@property (assign,nonatomic) ZKCaseSensitivity caseSensitivity;
@property (strong,nonatomic) NSObject*(^onMatch)(NSString*);
@property (assign,nonatomic) BOOL returnValue;
@end

@interface ZKParserRepeat()
+(instancetype)repeated:(ZKParser*)p sep:(ZKParser*)sep min:(NSUInteger)min max:(NSUInteger)max;
@property (strong,nonatomic) ZKParser *parser;
@property (strong,nonatomic) ZKParser *separator;
@property (assign,nonatomic) NSUInteger min;
@property (assign,nonatomic) NSUInteger max;
@property (strong,nonatomic) NSObject*(^matchBlock)(NSArray*);
@end

@interface ZKParserCharSet : ZKParser
@property (strong,nonatomic) NSCharacterSet* charSet;
@property (assign,nonatomic) NSUInteger minMatches;
@property (strong,nonatomic) NSString *errorName;
@property (assign,nonatomic) BOOL returnValue;
@end

@interface ZKParserOptional : ZKParser
@property (strong,nonatomic) ZKParser *optional;
@property (copy,nonatomic) BOOL(^ignoreBlock)(NSObject*);
@end


@implementation ZKParser
-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err {
    *err = [NSError errorWithDomain:@"Parser"
                               code:5
                           userInfo:@{
                               NSLocalizedDescriptionKey:@"parse method should of be implemented by class",
                           }];
    return nil;
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

@implementation ZKParserMapper
-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err {
    NSObject *res = [self.inner parse:input error:err];
    if (*err == nil) {
        return self.block(res);
    }
    return nil;
}
@end

@implementation ZKParserExact
-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err {
    NSString *res = [input consumeString:self.match caseSensitive:self.caseSensitivity];
    if (res != nil) {
        if (!self.returnValue) {
            return [NSNull null];
        }
        return self.onMatch == nil ? res : self.onMatch(res);
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
-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err {
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
            return self.returnValue ? [input valueOfRange:NSMakeRange(start, count)] : [NSNull null];
        }
        count++;
    }
}
-(NSString *)description {
    return [NSString stringWithFormat:@"{%@ x %lu}", self.errorName, self.minMatches];
}

@end

@implementation ZKParserOneOf

-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err {
    NSObject *res = [self parseInput:input error:err];
    if (*err == nil && self.matchBlock != nil) {
        return self.matchBlock(res);
    }
    return res;
}

-(NSObject *)parseInput:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSUInteger longestPos = start;
    NSObject *longestRes = nil;
    NSError *childErr = nil;
    for (ZKParser *child in self.items) {
        NSObject *r = [child parse:input error:&childErr];
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

-(ZKParserOneOf*)onMatch:(NSObject *(^)(NSObject *))block {
    self.matchBlock = block;
    return self;
}

@end

@implementation ZKParserSeq
-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:self.items.count];
    for (ZKParser *child in self.items) {
        NSObject *res = [child parse:input error:err];
        if (*err != nil) {
            [input rewindTo:start];
            return nil;
        }
        [out addObject:res];
    }
    if (self.matchBlock != nil) {
        return self.matchBlock(out);
    }
    return out;
}

-(ZKParserSeq*)onMatch:(NSObject *(^)(NSArray *))block {
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
    r.matchBlock = ^NSObject *(NSArray *r) {
        return r;
    };
    return r;
}

-(ZKParserRepeat*)onMatch:(NSObject *(^)(NSArray *))block {
    self.matchBlock = block;
    return self;
}

-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSMutableArray *out = [NSMutableArray array];
    NSError *nextError = nil;
    NSObject *first = [self.parser parse:input error:&nextError];
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
            NSObject *next = [self.parser parse:input error:&nextError];
            if (nextError != nil) {
                // unconsume the separator above
                [input rewindTo:thisStart];
                break;
            }
            [out addObject:next];
        }
    }
    if (out.count >= self.min) {
        return self.matchBlock(out);
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

-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSObject *res = [self.optional parse:input error:err];
    if (*err == nil) {
        if (!self.ignoreBlock(res)) {
            return res;
        }
    }
    *err = nil;
    [input rewindTo:start];
    return [NSNull null];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"{%@}?" , self.optional];
}

@end

@implementation ZKParserFactory

-(ZKParser*)map:(ZKParser*)p onMatch:(NSObject *(^)(NSObject *))block {
    ZKParserMapper *m = [ZKParserMapper new];
    m.inner = p;
    m.block = block;
    return m;
}

-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c onMatch:(NSObject *(^)(NSString *))block {
    ZKParserExact *e = [ZKParserExact new];
    e.match = s;
    e.caseSensitivity = c;
    e.onMatch = block;
    e.returnValue = YES;
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

-(ZKParser*)skip:(NSString *)s {
    ZKParserExact *e = [ZKParserExact new];
    e.match = s;
    e.caseSensitivity = self.defaultCaseSensitivity;
    e.returnValue = NO;
    return e;
}

-(ZKParser*)whitespace {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = [NSCharacterSet whitespaceCharacterSet];
    w.minMatches = 1;
    w.errorName = @"whitespace";
    w.returnValue = NO;
    return w;
}

-(ZKParser*)maybeWhitespace {
    ZKParserCharSet *w = [ZKParserCharSet new];
    w.charSet = [NSCharacterSet whitespaceCharacterSet];
    w.minMatches = 0;
    w.errorName = @"whitespace";
    w.returnValue = NO;
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

-(ZKParser*)oneOf:(NSArray<ZKParser*>*)items {  // NSFastEnumeration ?
    ZKParserOneOf *o = [ZKParserOneOf new];
    o.items = items;
    return o;
}

-(ZKParser*)oneOf:(NSArray<ZKParser*>*)items onMatch:(mapperBlock)block {  // NSFastEnumeration ?
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

-(ZKParser*)seq:(NSArray<ZKParser*>*)items onMatch:(NSObject *(^)(NSArray *))block {
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

@end
