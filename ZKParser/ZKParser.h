//
//  ZKParser.h
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZKParserInput.h"

@interface ParserResult : NSObject
+(instancetype)result:(NSObject*)val loc:(NSRange)loc;

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

typedef ParserResult *(^ResultMapper)(ParserResult *r);
typedef ParserResult *(^ArrayResultMapper)(ArrayParserResult *r);

// These are some common result Mapper's you can use to ease parser construction

// returns a mapper that will select a single item as the result for an array result.
ArrayResultMapper pick(NSUInteger idx);

// a mapper that will replace the child ParserResult with their value.
ParserResult * pickVals(ArrayParserResult*r);

// returns a mapper that will set the results value to a specific value. Useful for
// mapping tokens to AST specific types
ResultMapper setValue(NSObject *val);


@interface ZKParser : NSObject
-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err;
@end

// All parsers that return a single item should extend this.
@interface ZKSingularParser : ZKParser
// Sets the supplied mapper block, which will be called if the parse is successfull.
// returns the parser to make it easer to chain onMatch calls to new parsers.
-(instancetype)onMatch:(ResultMapper)block;
@end

// All parsers that return an array of results should extend this.
@interface ZKArrayParser: ZKParser
-(instancetype)onMatch:(ArrayResultMapper)block;
@end

// ParserRef lets you pass a parser to another parser, and later
// change the actual parser in use. Useful for dealing with
// recursive definitions.
@interface ZKParserRef : ZKParser
@property (strong,nonatomic) ZKParser *parser;
@end

typedef ParserResult *(^ParseBlock)(ZKParserInput*input,NSError **err);

@interface ZKParserFactory : NSObject

@property(assign,nonatomic) ZKCaseSensitivity defaultCaseSensitivity;

/// 1 or more whitespace characters
-(ZKSingularParser*)whitespace;
/// 0 or more whitespace characters
-(ZKSingularParser*)maybeWhitespace;

/// Exact match. Case sensitive set by defaultCaseSensitivity
-(ZKSingularParser*)eq:(NSString *)s;
-(ZKSingularParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c;

// match 'min' or more consecutive characters that are in the character set.
-(ZKSingularParser*)characters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

// match 'min' or more consecutive characters that are not in the supplied character set.
-(ZKSingularParser*)notCharacters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

-(ZKArrayParser*)seq:(NSArray<ZKParser*>*)items;

// selects the first item from the list that matches
-(ZKSingularParser*)firstOf:(NSArray<ZKParser*>*)items;

// tokens is a whitespace separated list of tokens, returns the matching token.
-(ZKSingularParser*)oneOfTokens:(NSString *)tokens;

// selects the item from the list that has the longest match, all items are evaluated.
-(ZKSingularParser*)oneOf:(NSArray<ZKParser*>*)items;

-(ZKArrayParser*)zeroOrMore:(ZKParser*)p;
-(ZKArrayParser*)oneOrMore:(ZKParser*)p;
-(ZKArrayParser*)zeroOrMore:(ZKParser*)p separator:(ZKParser*)sep;
-(ZKArrayParser*)oneOrMore:(ZKParser*)p separator:(ZKParser*)sep;
-(ZKArrayParser*)zeroOrMore:(ZKParser*)p separator:(ZKParser*)sep max:(NSUInteger)maxItems;
-(ZKArrayParser*)oneOrMore:(ZKParser*)p separator:(ZKParser*)sep max:(NSUInteger)maxItems;

-(ZKSingularParser*)zeroOrOne:(ZKParser*)p;
-(ZKSingularParser*)zeroOrOne:(ZKParser*)p ignoring:(BOOL(^)(NSObject*))ignoreBlock;

// Constructs a new Parser instance from the supplied block
-(ZKSingularParser*)fromBlock:(ParseBlock)parser;

// Constucts a new parser that contains a reference to another parser. Can be used to
// refer to as yet unconstructed parsers where there are circular or recursive definitions.
-(ZKParserRef*)parserRef;

@end
