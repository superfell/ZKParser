// Copyright (c) 2021 Simon Fell
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
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

// returns the 'idx' child.
-(id)child:(NSInteger)idx {
    NSAssert([self isArray], @"child should only be used for array results");
    return self.val[idx];
}

// returns the 'idx' child, unless its NSNull, in which case it returns def.
-(id)child:(NSInteger)idx withDefault:(id)def {
    NSAssert([self isArray], @"childWithDefault should only be used for array results");
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
