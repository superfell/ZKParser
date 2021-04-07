//
//  ZKParser.m
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import "ZKParser.h"

@implementation NSString(ZKParsing)

-(NSObject*)parse:(ZKParser)p error:(NSError **)err {
    return [[ZKParserInput withInput:self] parse:p error:err];
}

@end


@interface ZKParserInput()
@property (assign) NSString *input;
@property (assign) NSUInteger pos;
@end

@implementation ZKParserInput

+(ZKParserInput *)withInput:(NSString *)s {
    ZKParserInput *r = [[ZKParserInput alloc] init];
    r.input = s;
    r.pos = 0;
    return r;
}

-(NSUInteger)length {
    return self.input.length - self.pos;
}

-(NSString *)value {
    return [self.input substringFromIndex:self.pos];
}

-(NSString *)consumeString:(NSString *)s caseSensitive:(ZKCaseSensitivity)cs {
    NSStringCompareOptions opt = cs == CaseSensitive ? NSLiteralSearch : NSCaseInsensitiveSearch;
    NSRange rng = NSMakeRange(self.pos, s.length);
    if (self.length >= s.length && [self.input compare:s options:opt range:rng] == NSOrderedSame) {
        self.pos += s.length;
        return [self.input substringWithRange:rng];
    }
    return nil;
}

-(BOOL)consumeCharacterSet:(NSCharacterSet *)s {
    if (self.length == 0) {
        return NO;
    }
    unichar c = [self.input characterAtIndex:self.pos];
    if ([s characterIsMember:c]) {
        self.pos += 1;
        return YES;
    }
    return NO;
}

-(void)rewindTo:(NSUInteger)pos {
    self.pos = pos;
}

-(NSObject *)parse:(ZKParser)p error:(NSError **)err {
    *err = nil;
    NSObject *res = p(self, err);
    if (self.length > 0 && *err == nil) {
        NSString *msg = [NSString stringWithFormat:@"Unexpected input '%@' at position %lu", self.value, (unsigned long)self.pos+1];
        *err = [NSError errorWithDomain:@"Parser" code:-1 userInfo:@{NSLocalizedDescriptionKey:msg, @"Position":@(self.pos+1)}];
        return nil;
    }
    return res;
}

@end

@implementation ZKParserFactory

-(ZKParser)map:(ZKParser)p onMatch:(NSObject *(^)(NSObject *))block {
    return ^NSObject *(ZKParserInput *input, NSError **err) {
        NSObject *res = p(input, err);
        if (*err == nil) {
            return block(res);
        }
        return nil;
    };
}

-(ZKParser)exactly:(NSString *)s case:(ZKCaseSensitivity)c onMatch:(NSObject *(^)(NSString *))block {
    return ^NSObject *(ZKParserInput *input, NSError **err) {
        NSString *res = [input consumeString:s caseSensitive:c];
        if (res != nil) {
            return block(res);
        }
        *err = [NSError errorWithDomain:@"Parser" code:2 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting '%@' at position %lu", s, input.pos+1], @"Position":@(input.pos+1)}];
        return nil;
    };
}

-(ZKParser)exactly:(NSString *)s case:(ZKCaseSensitivity)c {
    return [self exactly:s case:c onMatch:^NSObject *(NSString *m) {
        return m;
    }];
}

-(ZKParser)exactly:(NSString *)s {
    return [self exactly:s case:self.defaultCaseSensitivity];
}

-(ZKParser)whitespace {
    return ^NSObject *(ZKParserInput *input, NSError **err) {
        ZKParser ws = [self characters:[NSCharacterSet whitespaceCharacterSet] name:@"whitespace" min:1];
        ws(input, err);
        return nil;
    };
}

-(ZKParser)maybeWhitespace {
    return ^NSObject *(ZKParserInput *input, NSError **err) {
        ZKParser ws = [self characters:[NSCharacterSet whitespaceCharacterSet] name:@"whitespace" min:0];
        ws(input, err);
        return nil;
    };
}

-(ZKParser)characters:(NSCharacterSet*)set name:(NSString*)name min:(NSUInteger)minMatches {
    return ^NSObject *(ZKParserInput *input, NSError **err) {
        NSInteger count = 0;
        NSInteger start = input.pos;
        while (true) {
            if (![input consumeCharacterSet:set]) {
                if (count < minMatches) {
                    *err = [NSError errorWithDomain:@"Parser"
                                               code:3
                                           userInfo:@{
                                               NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting %@ at position %lu", name, start+1],
                                               @"Position": @(start+1)
                                           }];
                    [input rewindTo:start];
                    return nil;
                }
                return [input.input substringWithRange:NSMakeRange(start, count)];
            }
            count++;
        }
    };
}

-(ZKParser)oneOf:(NSArray<ZKParser>*)items {  // NSFastEnumeration ?
    return ^NSObject *(ZKParserInput *input, NSError **err) {
        NSUInteger start = input.pos;
        NSUInteger longestPos = start;
        NSObject *longestRes = nil;
        NSError *childErr = nil;
        for (ZKParser child in items) {
            NSObject *r = child(input, &childErr);
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
    };
}

-(ZKParser)seq:(NSArray<ZKParser>*)items {
    return ^NSObject *(ZKParserInput*input, NSError **err) {
        NSUInteger start = input.pos;
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];
        for (ZKParser child in items) {
            NSObject *res = child(input, err);
            if (*err != nil) {
                [input rewindTo:start];
                return nil;
            }
            if (res != nil) {
                [out addObject:res];
            }
        }
        return out;
    };
}

-(ZKParser)seq:(NSArray<ZKParser>*)items onMatch:(NSObject *(^)(NSArray *))block {
    return ^NSObject *(ZKParserInput*input, NSError **err) {
        ZKParser seq = [self seq:items];
        NSArray *res = (NSArray*)seq(input, err);
        if (*err == nil) {
            return block(res);
        }
        return nil;
    };
}

-(ZKParser)repeating:(ZKParser)p minCount:(NSUInteger)min {
    return ^NSObject *(ZKParserInput *input, NSError **err) {
        NSUInteger start = input.pos;
        NSMutableArray *out = [NSMutableArray array];
        NSError *nextError = nil;
        while (true) {
            NSObject *next = p(input, &nextError);
            if (nextError != nil) {
                if (out.count >= min) {
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
    };
}

-(ZKParser)oneOrMore:(ZKParser)p {
    return [self repeating:p minCount:1];
}

-(ZKParser)zeroOrMore:(ZKParser)p {
    return [self repeating:p minCount:0];
}

@end
