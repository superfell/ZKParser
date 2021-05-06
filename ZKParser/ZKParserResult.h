//
//  ZKParserResult.h
//  ZKParser
//
//  Created by Simon Fell on 4/15/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>


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

// returns the 'idx' child value.
-(id)child:(NSInteger)idx;

// returns the 'idx' child value, unless its NSNull, in which case it returns def.
-(id)child:(NSInteger)idx withDefault:(id)def;

@end

typedef ZKParserResult *(^ZKResultMapper)(ZKParserResult *r);
typedef void(^ZKErrorMapper)(NSError **);

// These are some common result Mapper's you can use to ease parser construction

// returns a mapper that will select a single item as the result for an array result.
ZKResultMapper pick(NSUInteger idx);

// a mapper that will replace the child ParserResult with their value.
ZKParserResult * pickVals(ZKParserResult*r);

// returns a mapper that will set the results value to a specific value. Useful for
// mapping tokens to AST specific types
ZKResultMapper setValue(id val);
