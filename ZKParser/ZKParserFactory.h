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
// return true if this parser is wrapping a number of child parsers.
// this is used to indent the debug output.
-(BOOL)containsChildParsers;
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
-(ZKBaseParser*)whitespace;
/// 0 or more whitespace characters
-(ZKBaseParser*)maybeWhitespace;

/// Exact match. Case sensitive set by defaultCaseSensitivity
-(ZKBaseParser*)eq:(NSString *)s;
-(ZKBaseParser*)eq:(NSString *)s case:(ZKCaseSensitivity)c;

/// match 'min' or more consecutive characters that are in the character set.
-(ZKBaseParser*)characters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

/// match 'min' or more consecutive characters that are not in the supplied character set.
-(ZKBaseParser*)notCharacters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

/// match an integer number
-(ZKBaseParser*)integerNumber;

/// match a decimal number
-(ZKBaseParser*)decimalNumber;

/// match a regular expression.
-(ZKBaseParser*)regex:(NSRegularExpression*)regex name:(NSString*)name;

/// match the supplied sequence of parsers.
-(ZKBaseParser*)seq:(NSArray<ZKBaseParser*>*)items;

/// tries each parser in turn, stops when there is a successful parse.
-(ZKBaseParser*)firstOf:(NSArray<ZKBaseParser*>*)items;

/// eq: match one of the whitespace separated tokens in this string. case sensitivity comes from defaultCaseSensitivity
-(ZKBaseParser*)oneOfTokens:(NSString *)tokens;

/// eq: match one of the supplied tokens. case sensitivity comes from defaultCaseSensitivity
-(ZKBaseParser*)oneOfTokensList:(NSArray<NSString *>*)tokens;

/// tries all the parsers supplied and returns the one with the longest match.
-(ZKBaseParser*)oneOf:(NSArray<ZKBaseParser*>*)items;

/// zero or more consecutive occurances of the parser
-(ZKBaseParser*)zeroOrMore:(ZKBaseParser*)p;
/// one or more cosecutive occurances of the parser
-(ZKBaseParser*)oneOrMore:(ZKBaseParser*)p;
/// zero or more occurrances of the parer, repeated occurances separated by the supplied separater parser.
-(ZKBaseParser*)zeroOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep;
/// one or more occurrances of the parer, repeated occurances separated by the supplied separater parser.
-(ZKBaseParser*)oneOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep;
/// zero to max occurrances of the parer, repeated occurances separated by the supplied separater parser.
-(ZKBaseParser*)zeroOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep max:(NSUInteger)maxItems;
/// one to max occurrances of the parer, repeated occurances separated by the supplied separater parser.
-(ZKBaseParser*)oneOrMore:(ZKBaseParser*)p separator:(ZKBaseParser*)sep max:(NSUInteger)maxItems;

/// exactly zero or match instances of the supplied parser.
-(ZKBaseParser*)zeroOrOne:(ZKBaseParser*)p;

/// TODO
-(ZKBaseParser*)zeroOrOne:(ZKBaseParser*)p ignoring:(BOOL(^)(NSObject*))ignoreBlock;

/// constructs a new parser instance from the parser implemention in the block.
-(ZKBaseParser*)fromBlock:(ZKParseBlock)parser;

/// Constucts a new parser that contains a reference to another parser. Can be used to
/// refer to as yet unconstructed parsers where there are circular or recursive definitions.
-(ZKParserRef*)parserRef;

/// returns a parser that will prevent future backtracking to go before this point. This is useful in generating
/// better error messages for sequences of parsers where the partial progress is good. e.g.
/// given sequence zeroOrOne:[eq:"LIMIT", whitespace, integer] a failure to parse an integer will back track
/// to the start of the sequence and give an error message along the lines of unexpected input LIMIT...
/// Adding a cut after LIMIT will prevent backtracking to before the LIMIT token and result in an error of
/// expecting integer at ...
-(ZKBaseParser*)cut;

/// Returns a new parser that will execute the supplied parser, and if it is succesfull run the mapper on the results.
-(ZKBaseParser*)onMatch:(ZKBaseParser*)p perform:(ZKResultMapper)mapper;
//-(ZKBaseParser*)onError:(ZKBaseParser*)p perform:(ZKErrorMapper)mapper;
//-(ZKBaseParser*)on:(ZKBaseParser*)p perform:(ZKParseMapper)mapper;

@end
