//
//  ZKParser.m
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import "ZKParser.h"

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

-(BOOL)consumeString:(NSString *)s {
    if ([self.input compare:s options:NSLiteralSearch range:NSMakeRange(self.pos, MIN(self.length, s.length))] == NSOrderedSame) {
        self.pos += s.length;
        return YES;
    }
    return NO;
}

-(BOOL)consumeCharacterSet:(NSCharacterSet *)s {
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

@end

@implementation ZKParserFactory

+(ZKParser)exactly:(NSString *)s onMatch:(NSObject *(^)(NSString *))block {
    return ^NSObject *(ZKParserInput *input) {
        if ([input consumeString:s]) {
            return block(s);
        }
        return nil;
    };
}

+(ZKParser)whitespace {
    return ^NSObject *(ZKParserInput *input) {
        [input consumeCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
        return nil;
    };
}

+(ZKParser)oneOf:(NSArray *)items {  // NSFastEnumeration ?
    return ^NSObject *(ZKParserInput *input) {
        NSUInteger start = input.pos;
        NSUInteger longestPos = start;
        NSObject *longestRes = nil;
        for (ZKParser child in items) {
            NSObject *r = child(input);
            if (input.pos > longestPos) {
                longestRes = r;
                longestPos = input.pos;
            }
            [input rewindTo:start];
        }
        return longestRes;
    };
}

+(ZKParser)seq:(NSArray *)items {
    return ^NSObject *(ZKParserInput*input) {
        NSUInteger start = input.pos;
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];
        for (ZKParser child in items) {
            NSUInteger thisStart = input.pos;
            NSObject *res = child(input);
            if (input.pos == thisStart) {
                [input rewindTo:start];
                return nil;
            }
            [out addObject:res];
        }
        return out;
    };
}

+(ZKParser)oneOrMore:(ZKParser)p {
    return ^NSObject *(ZKParserInput *input) {
        NSUInteger start = input.pos;
        NSObject *first = p(input);
        if (input.pos > start) {
            NSMutableArray *out = [NSMutableArray arrayWithObject:first];
            while (true) {
                NSUInteger thisStart = input.pos;
                NSObject *next = p(input);
                if (thisStart == input.pos) {
                    [input rewindTo:thisStart];
                    return out;
                }
                [out addObject:next];
            }
        }
        [input rewindTo:start];
        return nil;
    };
}

+(NSObject *)parse:(ZKParser)parser input:(NSString *)input error:(NSError **)err {
    ZKParserInput *i = [ZKParserInput withInput:input];
    NSObject *res = parser(i);
    if (i.length > 0) {
        NSString *msg = [NSString stringWithFormat:@"Unexpected input '%@' at position %lu", i.value, (unsigned long)i.pos];
        *err = [NSError errorWithDomain:@"Parser" code:-1 userInfo:@{NSLocalizedDescriptionKey:msg, @"Position":@(i.pos)}];
        return nil;
    }
    return res;
}

@end
