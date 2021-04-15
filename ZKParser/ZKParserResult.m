//
//  ZKParserResult.m
//  ZKParser
//
//  Created by Simon Fell on 4/15/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import "ZKParserResult.h"


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

ArrayResultMapper pick(NSUInteger idx) {
    return ^ParserResult *(ArrayParserResult *r) {
        return r.val[idx];
    };
}

ParserResult * pickVals(ArrayParserResult*r) {
    r.val = [r childVals];
    return r;
}

ResultMapper setValue(NSObject *val) {
    return ^ParserResult *(ParserResult *r) {
        r.val = val;
        return r;
    };
}
