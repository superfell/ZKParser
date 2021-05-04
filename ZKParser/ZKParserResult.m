//
//  ZKParserResult.m
//  ZKParser
//
//  Created by Simon Fell on 4/15/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import "ZKParserResult.h"

@implementation ZKParserResult

+(instancetype)result:(id)val ctx:(NSDictionary*)userContext loc:(NSRange)loc {
    ZKParserResult *r = [self new];
    r.val = val;
    r.loc = loc;
    r.userContext = userContext;
    return r;
}

-(BOOL)isEqual:(ZKParserResult*)other {
    return [self.val isEqual:other.val] && (self.loc.location == other.loc.location) && (self.loc.length == other.loc.length);
}

-(NSString*)description {
    return [NSString stringWithFormat:@"%@ {%lu,%lu}", self.val, self.loc.location, self.loc.length];
}

-(BOOL)isArray {
    return [self.val isKindOfClass:[NSArray class]];
}

-(NSArray*)childVals {
    NSAssert([self isArray], @"ChildVals should only be used for array results");
    return [self.val valueForKey:@"val"];
}

-(BOOL)childIsNull:(NSInteger)idx {
    NSAssert([self isArray], @"childIsNull should only be used for array results");
    ZKParserResult *r = self.val[idx];
    return r.val == [NSNull null];
}

// returns the 'idx' child value.
-(id)child:(NSInteger)idx {
    NSAssert([self isArray], @"childIsNull should only be used for array results");
    return self.val[idx];
}

// returns the 'idx' child value, unless its NSNull, in which case it returns def.
-(id)child:(NSInteger)idx withDefault:(id)def {
    NSAssert([self isArray], @"childIsNull should only be used for array results");
    id r = self.val[idx];
    return r == [NSNull null] ? def : r;
}

@end

ZKResultMapper pick(NSUInteger idx) {
    return ^ZKParserResult *(ZKParserResult *r) {
        return [r child:idx];
    };
}

ZKParserResult * pickVals(ZKParserResult*r) {
    r.val = [r childVals];
    return r;
}

ZKResultMapper setValue(id val) {
    return ^ZKParserResult *(ZKParserResult *r) {
        r.val = val;
        return r;
    };
}
