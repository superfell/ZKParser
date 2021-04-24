//
//  ZKParserResult.m
//  ZKParser
//
//  Created by Simon Fell on 4/15/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import "ZKParserResult.h"


@implementation ZKParserResult
+(instancetype)result:(NSObject*)val ctx:(NSDictionary*)userContext loc:(NSRange)loc {
    ZKParserResult *r = [self new];
    r.val = val;
    r.loc = loc;
    r.userContext = userContext;
    return r;
}

-(BOOL)isEqual:(ZKParserResult*)other {
    return [self.val isEqual:other.val] && (self.loc.location == other.loc.location) && (self.loc.length == other.loc.length);
}
-(NSArray<ZKParserResult*>*)children {
    assert([self.val isKindOfClass:[NSArray class]]);
    return self.val;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"%@ {%lu,%lu}", self.val, self.loc.location, self.loc.length];
}
@end

@implementation ZKArrayParserResult

+(instancetype)result:(NSArray<ZKParserResult*>*)val ctx:(NSDictionary*)userContext loc:(NSRange)loc {
    ZKArrayParserResult *r = [ZKArrayParserResult new];
    r.val = val;
    r.loc = loc;
    r.userContext = userContext;
    r.child = val;
    return r;
}
-(NSArray*)childVals {
    return [self.child valueForKey:@"val"];
}
-(BOOL)childIsNull:(NSInteger)idx {
    ZKParserResult *r = self.child[idx];
    return r.val == [NSNull null] || r.val == nil;
}
-(void)setVal:(id)v {
    super.val = v;
    self.child = v;
}

@end

ZKArrayResultMapper pick(NSUInteger idx) {
    return ^ZKParserResult *(ZKArrayParserResult *r) {
        return r.val[idx];
    };
}

ZKParserResult * pickVals(ZKArrayParserResult*r) {
    r.val = [r childVals];
    return r;
}

ZKResultMapper setValue(NSObject *val) {
    return ^ZKParserResult *(ZKParserResult *r) {
        r.val = val;
        return r;
    };
}
