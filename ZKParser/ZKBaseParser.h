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


@interface ZKBaseParser : NSObject
-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err;
@end

// All parsers that return a single item should extend this.
@interface ZKSingularParser : ZKBaseParser
// Sets the supplied mapper block, which will be called if the parse is successfull.
// returns the parser to make it easer to chain onMatch calls to new parsers.
-(instancetype)onMatch:(ResultMapper)block;
@end

// All parsers that return an array of results should extend this.
@interface ZKArrayParser: ZKBaseParser
-(instancetype)onMatch:(ArrayResultMapper)block;
@end

// ParserRef lets you pass a parser to another parser, and later
// change the actual parser in use. Useful for dealing with
// recursive definitions.
@interface ZKParserRef : ZKBaseParser
@property (strong,nonatomic) ZKBaseParser *parser;
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
-(ZKSingularParser*)eq:(NSString *)s case:(ZKCaseSensitivity)c;

// match 'min' or more consecutive characters that are in the character set.
-(ZKSingularParser*)characters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

// match 'min' or more consecutive characters that are not in the supplied character set.
-(ZKSingularParser*)notCharacters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

// match an integer number
-(ZKSingularParser*)integerNumber;

// match a decimal number
-(ZKSingularParser*)decimalNumber;

// match a regular expression. Be care to ensure that you anchor the regex to the start of the string.
-(ZKSingularParser*)regex:(NSRegularExpression*)regex name:(NSString*)name;

// match the supplied sequence of parsers.
-(ZKArrayParser*)seq:(NSArray<ZKBaseParser*>*)items;

// selects the first item from the list that matches
-(ZKSingularParser*)firstOf:(NSArray<ZKBaseParser*>*)items;

// tokens is a whitespace separated list of tokens, returns the matching token.
-(ZKSingularParser*)oneOfTokens:(NSString *)tokens;

// selects the item from the list that has the longest match, all items are evaluated.
-(ZKSingularParser*)oneOf:(NSArray<ZKBaseParser*>*)items;

-(ZKArrayParser*)zeroOrMore:(ZKBaseParser*)p;
-(ZKArrayParser*)oneOrMore:(ZKBaseParser*)p;
-(ZKArrayParser*)zeroOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep;
-(ZKArrayParser*)oneOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep;
-(ZKArrayParser*)zeroOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep max:(NSUInteger)maxItems;
-(ZKArrayParser*)oneOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep max:(NSUInteger)maxItems;

-(ZKSingularParser*)zeroOrOne:(ZKBaseParser*)p;
-(ZKSingularParser*)zeroOrOne:(ZKBaseParser*)p ignoring:(BOOL(^)(NSObject*))ignoreBlock;

// Constructs a new Parser instance from the supplied block
-(ZKSingularParser*)fromBlock:(ParseBlock)parser;

// Constucts a new parser that contains a reference to another parser. Can be used to
// refer to as yet unconstructed parsers where there are circular or recursive definitions.
-(ZKParserRef*)parserRef;

@end
