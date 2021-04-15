//
//  ZKParser.h
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZKParsingState.h"
#import "ZKParserResult.h"

@interface ZKBaseParser : NSObject
-(ZKParserResult *)parse:(ZKParsingState*)input error:(NSError **)err;
-(void)setDebugName:(NSString *)n;
@end

// All parsers that return a single item should extend this.
@interface ZKSingularParser : ZKBaseParser
// Sets the supplied mapper block, which will be called if the parse is successfull.
// returns the parser to make it easer to chain onMatch calls to new parsers.
-(instancetype)onMatch:(ZKResultMapper)block;
@end

// All parsers that return an array of results should extend this.
@interface ZKArrayParser: ZKBaseParser
-(instancetype)onMatch:(ZKArrayResultMapper)block;
@end

// ParserRef lets you pass a parser to another parser, and later
// change the actual parser in use. Useful for dealing with
// recursive definitions.
@interface ZKParserRef : ZKBaseParser
@property (strong,nonatomic) ZKBaseParser *parser;
@end

typedef ZKParserResult *(^ZKParseBlock)(ZKParsingState*input,NSError **err);

@interface ZKParserFactory : NSObject

@property(assign,nonatomic) ZKCaseSensitivity defaultCaseSensitivity;
@property(strong,nonatomic) NSString *debugFile;

/// 1 or more whitespace characters
-(ZKSingularParser*)whitespace;
/// 0 or more whitespace characters
-(ZKSingularParser*)maybeWhitespace;

/// Exact match. Case sensitive set by defaultCaseSensitivity
-(ZKSingularParser*)eq:(NSString *)s;
-(ZKSingularParser*)eq:(NSString *)s case:(ZKCaseSensitivity)c;

/// match 'min' or more consecutive characters that are in the character set.
-(ZKSingularParser*)characters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

/// match 'min' or more consecutive characters that are not in the supplied character set.
-(ZKSingularParser*)notCharacters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

/// match an integer number
-(ZKSingularParser*)integerNumber;

/// match a decimal number
-(ZKSingularParser*)decimalNumber;

/// match a regular expression.
-(ZKSingularParser*)regex:(NSRegularExpression*)regex name:(NSString*)name;

/// match the supplied sequence of parsers.
-(ZKArrayParser*)seq:(NSArray<ZKBaseParser*>*)items;

/// tries each parser in turn, stops when there is a successful parse.
-(ZKSingularParser*)firstOf:(NSArray<ZKBaseParser*>*)items;

/// eq: match one of the whitespace separated tokens in this string. case sensitivity comes from defaultCaseSensitivity
-(ZKSingularParser*)oneOfTokens:(NSString *)tokens;

/// tries all the parsers supplied and returns the one with the longest match.
-(ZKSingularParser*)oneOf:(NSArray<ZKBaseParser*>*)items;

/// zero or more consecutive occurances of the parser
-(ZKArrayParser*)zeroOrMore:(ZKBaseParser*)p;
/// one or more cosecutive occurances of the parser
-(ZKArrayParser*)oneOrMore:(ZKBaseParser*)p;
/// zero or more occurrances of the parer, repeated occurances separated by the supplied separater parser.
-(ZKArrayParser*)zeroOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep;
/// one or more occurrances of the parer, repeated occurances separated by the supplied separater parser.
-(ZKArrayParser*)oneOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep;
/// zero to max occurrances of the parer, repeated occurances separated by the supplied separater parser.
-(ZKArrayParser*)zeroOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep max:(NSUInteger)maxItems;
/// one to max occurrances of the parer, repeated occurances separated by the supplied separater parser.
-(ZKArrayParser*)oneOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep max:(NSUInteger)maxItems;

/// exactly zero or match instances of the supplied parser.
-(ZKSingularParser*)zeroOrOne:(ZKBaseParser*)p;

/// TODO
-(ZKSingularParser*)zeroOrOne:(ZKBaseParser*)p ignoring:(BOOL(^)(NSObject*))ignoreBlock;

/// constructs a new parser instance from the parser implemention in the block.
-(ZKSingularParser*)fromBlock:(ZKParseBlock)parser;

/// Constucts a new parser that contains a reference to another parser. Can be used to
/// refer to as yet unconstructed parsers where there are circular or recursive definitions.
-(ZKParserRef*)parserRef;

@end
