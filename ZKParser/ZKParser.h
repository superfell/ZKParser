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

@interface ParserResult : NSObject
+(instancetype)result:(NSObject*)val loc:(NSRange)loc;
+(instancetype)result:(NSObject*)val locs:(NSArray<ParserResult*>*)locs;

@property (strong,nonatomic) id val;
@property (assign,nonatomic) NSRange loc;
@end

@interface ArrayParserResult : ParserResult
+(instancetype)result:(NSArray<ParserResult*>*)val loc:(NSRange)loc;

@property (strong,nonatomic) NSArray<ParserResult*> *child;
// returns the val field from each of the child results.
-(NSArray*)childVals;
// returns true if the value for the indicated child is nil or [NSNull null]
-(BOOL)childIsNull:(NSInteger)idx;
@end

typedef ParserResult *(^MapperBlock)(ParserResult *r);
typedef ParserResult *(^ArrayMapperBlock)(ArrayParserResult *r);


@interface ZKParser : NSObject
-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err;

-(ZKParserOneOf*)or:(NSArray<ZKParser*>*)otherParsers;
-(ZKParserSeq*)then:(NSArray<ZKParser*>*)otherParsers;
-(ZKParserSeq*)thenZeroOrMore:(ZKParser*)parser;
-(ZKParserSeq*)thenOneOrMore:(ZKParser*)parser;
@end

@interface ZKParserOneOf : ZKParser
-(ZKParserSeq*)onMatch:(MapperBlock)block;
@end

@interface ZKParserSeq : ZKParser
-(ZKParserSeq*)onMatch:(ArrayMapperBlock)block;
@end

@interface ZKParserRepeat : ZKParser
-(ZKParserSeq*)onMatch:(ArrayMapperBlock)block;
@end

// ParserRef lets you pass a parser to another parser, and later
// change the actual parser in use. Useful for dealing with
// recursive definitions.
@interface ZKParserRef : ZKParser
@property (strong,nonatomic) ZKParser *parser;
@end

@interface ZKParserFactory : NSObject

@property(assign,nonatomic) ZKCaseSensitivity defaultCaseSensitivity;

-(ZKParser*)whitespace;
-(ZKParser*)maybeWhitespace;
-(ZKParser*)eq:(NSString *)s;         // same as exactly. case sensitive set by defaultCaseSensitivity
-(ZKParser*)exactly:(NSString *)s;    // case sensitive set by defaultCaseSensitivity
-(ZKParser*)exactly:(NSString *)s setValue:(NSObject*)val;    // case sensitive set by defaultCaseSensitivity
-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c;
-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c onMatch:(MapperBlock)block;

// match 0 or more consecutive characters that are in the character set.
-(ZKParser*)characters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

// match 0 or more consecutive characters not in the supplied character set.
-(ZKParser*)notCharacters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

-(ZKParser*)skip:(NSString *)s;       // same as exactly, but doesn't return a value.

-(ZKParserSeq*)seq:(NSArray<ZKParser*>*)items;
-(ZKParserSeq*)seq:(NSArray<ZKParser*>*)items onMatch:(ArrayMapperBlock)block;

-(ZKParserOneOf*)oneOf:(NSArray<ZKParser*>*)items;  // NSFastEnumeration ? // onMatch version
-(ZKParserOneOf*)oneOf:(NSArray<ZKParser*>*)items onMatch:(MapperBlock)block;

-(ZKParserRepeat*)zeroOrMore:(ZKParser*)p;
-(ZKParserRepeat*)oneOrMore:(ZKParser*)p;
-(ZKParserRepeat*)zeroOrMore:(ZKParser*)p separator:(ZKParser*)sep;
-(ZKParserRepeat*)oneOrMore:(ZKParser*)p separator:(ZKParser*)sep;
-(ZKParserRepeat*)zeroOrMore:(ZKParser*)p separator:(ZKParser*)sep max:(NSUInteger)maxItems;
-(ZKParserRepeat*)oneOrMore:(ZKParser*)p separator:(ZKParser*)sep max:(NSUInteger)maxItems;

-(ZKParser*)zeroOrOne:(ZKParser*)p;
-(ZKParser*)zeroOrOne:(ZKParser*)p ignoring:(BOOL(^)(NSObject*))ignoreBlock;

-(ZKParser*)map:(ZKParser*)p onMatch:(MapperBlock)block;

@end
