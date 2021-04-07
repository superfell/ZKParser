//
//  ZKParser.m
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import "ZKParser.h"


typedef NSObject *(^mapperBlock)(NSObject *);

@interface ZKParserMapper : ZKParser
@property (strong, nonatomic) ZKParser *inner;
@property (strong, nonatomic) mapperBlock block;
@end
@interface ZKParserExact : ZKParser
@property (strong,nonatomic) NSString *match;
@property (assign,nonatomic) ZKCaseSensitivity caseSensitivity;
@property (strong,nonatomic) NSObject*(^onMatch)(NSString*);
@end
@interface ZKParserRepeat : ZKParser
@property (strong,nonatomic) ZKParser *parser;
@property (assign,nonatomic) NSUInteger min;
@property (strong,nonatomic) NSObject*(^onMatch)(NSArray*);
@end
@interface ZKParserCharSet : ZKParser
@property (strong,nonatomic) NSCharacterSet* charSet;
@property (assign,nonatomic) NSUInteger minMatches;
@property (strong,nonatomic) NSString *errorName;
@property (assign,nonatomic) BOOL returnValue;
@end
@interface ZKParserOneOf : ZKParser
@property (strong,nonatomic) NSArray<ZKParser*>* items;
@property (strong,nonatomic) NSObject*(^onMatch)(NSObject*);
@end
@interface ZKParserSeq : ZKParser
@property (strong,nonatomic) NSArray<ZKParser*>* items;
@property (strong,nonatomic) NSObject*(^onMatch)(NSArray*);
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

-(ZKParser*)or:(NSArray<ZKParser*>*)otherParsers {
    ZKParserOneOf *o = [ZKParserOneOf new];
    o.items = [@[self] arrayByAddingObjectsFromArray:otherParsers];
    return o;
}

-(ZKParser*)and:(NSArray<ZKParser*>*)otherParsers {
    ZKParserSeq *s = [ZKParserSeq new];
    s.items = [@[self] arrayByAddingObjectsFromArray:otherParsers];
    return s;
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
            return self.returnValue ? [input valueOfRange:NSMakeRange(start, count)] : nil;
        }
        count++;
    }
}
@end

@implementation ZKParserOneOf
-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err {
    NSObject *res = [self parseInput:input error:err];
    if (*err == nil && self.onMatch != nil) {
        return self.onMatch(res);
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
        if (res != nil) {
            [out addObject:res];
        }
    }
    if (self.onMatch != nil) {
        return self.onMatch(out);
    }
    return out;
}
@end

@implementation ZKParserRepeat
-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err {
    NSUInteger start = input.pos;
    NSMutableArray *out = [NSMutableArray array];
    NSError *nextError = nil;
    while (true) {
        NSObject *next = [self.parser parse:input error:&nextError];
        if (nextError != nil) {
            if (out.count >= self.min) {
                if (self.onMatch != nil) {
                    return self.onMatch(out);
                }
                return out;
            } else {
                *err = nextError;
                [input rewindTo:start];
                return nil;
            }
        }
        if (next != nil) {
            [out addObject:next];
        }
    }
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
    return e;
}

-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c {
    return [self exactly:s case:c onMatch:nil];
}

-(ZKParser*)exactly:(NSString *)s {
    return [self exactly:s case:self.defaultCaseSensitivity];
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
    o.onMatch = block;
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
    s.onMatch = block;
    return s;
}

-(ZKParser*)repeating:(ZKParser*)p minCount:(NSUInteger)min {
    ZKParserRepeat *r = [ZKParserRepeat new];
    r.parser = p;
    r.min = min;
    return r;
}

-(ZKParser*)oneOrMore:(ZKParser*)p {
    return [self repeating:p minCount:1];
}

-(ZKParser*)zeroOrMore:(ZKParser*)p {
    return [self repeating:p minCount:0];
}

@end
