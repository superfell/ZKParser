//
//  ZKParserResult.h
//  ZKParser
//
//  Created by Simon Fell on 4/15/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ZKParserResult : NSObject
+(instancetype)result:(NSObject*)val loc:(NSRange)loc;

@property (strong,nonatomic) id val;
@property (assign,nonatomic) NSRange loc;
@end

@interface ArrayParserResult : ZKParserResult
+(instancetype)result:(NSArray<ZKParserResult*>*)val loc:(NSRange)loc;

@property (strong,nonatomic) NSArray<ZKParserResult*> *child;

// returns the val field from each of the child results.
-(NSArray*)childVals;

// returns true if the value for the indicated child is nil or [NSNull null]
-(BOOL)childIsNull:(NSInteger)idx;

@end

typedef ZKParserResult *(^ResultMapper)(ZKParserResult *r);
typedef ZKParserResult *(^ArrayResultMapper)(ArrayParserResult *r);

// These are some common result Mapper's you can use to ease parser construction

// returns a mapper that will select a single item as the result for an array result.
ArrayResultMapper pick(NSUInteger idx);

// a mapper that will replace the child ParserResult with their value.
ZKParserResult * pickVals(ArrayParserResult*r);

// returns a mapper that will set the results value to a specific value. Useful for
// mapping tokens to AST specific types
ResultMapper setValue(NSObject *val);

