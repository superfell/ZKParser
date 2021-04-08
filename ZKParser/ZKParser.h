//
//  ZKParser.h
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZKParserInput.h"

@class ZKParserSeq;
@class ZKParserOneOf;

@interface ZKParser : NSObject
-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err;

-(ZKParserOneOf*)or:(NSArray<ZKParser*>*)otherParsers;
-(ZKParserSeq*)then:(NSArray<ZKParser*>*)otherParsers;
-(ZKParserSeq*)thenZeroOrMore:(ZKParser*)parser;
-(ZKParserSeq*)thenOneOrMore:(ZKParser*)parser;
@end

@interface ZKParserOneOf : ZKParser
-(ZKParserSeq*)onMatch:(NSObject *(^)(NSObject *))block;
@end

@interface ZKParserSeq : ZKParser
-(ZKParserSeq*)onMatch:(NSObject *(^)(NSArray *))block;
@end

@interface ZKParserFactory : NSObject

@property(assign,nonatomic) ZKCaseSensitivity defaultCaseSensitivity;

-(ZKParser*)whitespace;
-(ZKParser*)maybeWhitespace;
-(ZKParser*)eq:(NSString *)s;         // same as exactly. case sensitive set by defaultCaseSensitivity
-(ZKParser*)exactly:(NSString *)s;    // case sensitive set by defaultCaseSensitivity
-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c;
-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c onMatch:(NSObject *(^)(NSString *))block;
-(ZKParser*)characters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;
-(ZKParser*)skip:(NSString *)s;       // same as exactly, but doesn't return a value.

-(ZKParserSeq*)seq:(NSArray<ZKParser*>*)items;
-(ZKParserSeq*)seq:(NSArray<ZKParser*>*)items onMatch:(NSObject *(^)(NSArray *))block;

-(ZKParserOneOf*)oneOf:(NSArray<ZKParser*>*)items;  // NSFastEnumeration ? // onMatch version
-(ZKParserOneOf*)oneOf:(NSArray<ZKParser*>*)items onMatch:(NSObject *(^)(NSObject *))block;

-(ZKParser*)zeroOrMore:(ZKParser*)p;
-(ZKParser*)oneOrMore:(ZKParser*)p;
-(ZKParser*)zeroOrMore:(ZKParser*)p separator:(ZKParser*)sep;
-(ZKParser*)oneOrMore:(ZKParser*)p separator:(ZKParser*)sep;
-(ZKParser*)zeroOrMore:(ZKParser*)p separator:(ZKParser*)sep max:(NSUInteger)maxItems;
-(ZKParser*)oneOrMore:(ZKParser*)p separator:(ZKParser*)sep max:(NSUInteger)maxItems;

-(ZKParser*)zeroOrOne:(ZKParser*)p;
-(ZKParser*)zeroOrOne:(ZKParser*)p ignoring:(BOOL(^)(NSObject*))ignoreBlock;

-(ZKParser*)map:(ZKParser*)p onMatch:(NSObject *(^)(NSObject *))block;

@end
