//
//  ZKParserInput.m
//  ZKParser
//
//  Created by Simon Fell on 4/7/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import "ZKParserFactory.h"


@implementation NSString(ZKParsing)

-(NSObject*)parse:(ZKBaseParser*)p error:(NSError **)err {
    return [[ZKParsingState withInput:self] parse:p error:err];
}

@end

@interface ZKParsingState()
@property (strong,nonatomic) NSString *input;
@end

@implementation ZKParsingState

+(ZKParsingState *)withInput:(NSString *)s {
    ZKParsingState *r = [[ZKParsingState alloc] init];
    r.input = s;
    r.pos = 0;
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

-(void)markCut {
    self.cut = self.pos;
}

-(BOOL)canMoveTo:(NSUInteger)pos {
    return self.pos >= self.cut;
}

-(void)moveTo:(NSUInteger)pos {
    self.pos = pos;
}

-(NSObject *)parse:(ZKBaseParser*)p error:(NSError **)err {
    *err = nil;
    NSObject *res = [p parse:self error:err];
    if (self.length > 0 && *err == nil) {
        NSString *msg = [NSString stringWithFormat:@"Unexpected input '%@' at position %lu", self.value, (unsigned long)self.pos+1];
        *err = [NSError errorWithDomain:@"Parser" code:-1 userInfo:@{NSLocalizedDescriptionKey:msg, @"Position":@(self.pos+1)}];
        return nil;
    }
    return res;
}

@end
