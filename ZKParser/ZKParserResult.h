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

#import <Foundation/Foundation.h>

@class ZKParsingState;

@interface ZKParserResult : NSObject
+(instancetype)result:(id)val ctx:(NSDictionary*)userContext loc:(NSRange)loc;

@property (strong,nonatomic) id val;
@property (assign,nonatomic) NSRange loc;
@property (strong,nonatomic) NSDictionary *userContext;

// returns true if the value is an array of parser results.
-(BOOL)isArray;

// returns the val field from each of the child results.
-(NSArray*)childVals;

// returns true if the value for the indicated child is [NSNull null]
-(BOOL)childIsNull:(NSInteger)idx;

// returns the 'idx' child.
-(id)child:(NSInteger)idx;

// returns the 'idx' child, unless its NSNull, in which case it returns def.
-(id)child:(NSInteger)idx withDefault:(id)def;

@end

typedef ZKParserResult *(^ZKResultMapper)(ZKParserResult *r);
typedef void(^ZKErrorMapper)(ZKParsingState*);

// These are some common result Mapper's you can use to ease parser construction

// returns a mapper that will select a single item as the result for an array result.
ZKResultMapper pick(NSUInteger idx);

// a mapper that will replace the child ParserResult with their value.
ZKParserResult * pickVals(ZKParserResult*r);

// returns a mapper that will set the results value to a specific value. Useful for
// mapping tokens to AST specific types
ZKResultMapper setValue(id val);
