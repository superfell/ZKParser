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


@interface ZKParser : NSObject
-(ParserResult *)parse:(ZKParserInput*)input error:(NSError **)err;
@end

@interface ZKParserOneOf : ZKParser
-(instancetype)onMatch:(ResultMapper)block;
@end

@interface ZKParserSeq : ZKParser
-(ZKParserSeq*)onMatch:(ArrayResultMapper)block;
@end

@interface ZKParserRepeat : ZKParser
-(ZKParserSeq*)onMatch:(ArrayResultMapper)block;
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

-(ZKParser*)whitespace;
-(ZKParser*)maybeWhitespace;
-(ZKParser*)eq:(NSString *)s;         // same as exactly. case sensitive set by defaultCaseSensitivity
-(ZKParser*)exactly:(NSString *)s;    // case sensitive set by defaultCaseSensitivity
-(ZKParser*)exactly:(NSString *)s setValue:(NSObject*)val;    // case sensitive set by defaultCaseSensitivity
-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c;
-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c onMatch:(ResultMapper)block;

// match 0 or more consecutive characters that are in the character set.
-(ZKParser*)characters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

// match 0 or more consecutive characters not in the supplied character set.
-(ZKParser*)notCharacters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

-(ZKParserSeq*)seq:(NSArray<ZKParser*>*)items;
-(ZKParserSeq*)seq:(NSArray<ZKParser*>*)items onMatch:(ArrayResultMapper)block;

// selects the first item from the list that matches
-(ZKParser*)firstOf:(NSArray<ZKParser*>*)items;
-(ZKParser*)firstOf:(NSArray<ZKParser*>*)items onMatch:(ResultMapper)block;

// tokens is a whitespace separated list of tokens, returns the matching token.
-(ZKParser*)oneOfTokens:(NSString *)tokens;

// selects the item from the list that has the longest match, all items are evaluated.
-(ZKParserOneOf*)oneOf:(NSArray<ZKParser*>*)items;
-(ZKParserOneOf*)oneOf:(NSArray<ZKParser*>*)items onMatch:(ResultMapper)block;

-(ZKParserRepeat*)zeroOrMore:(ZKParser*)p;
-(ZKParserRepeat*)oneOrMore:(ZKParser*)p;
-(ZKParserRepeat*)zeroOrMore:(ZKParser*)p separator:(ZKParser*)sep;
-(ZKParserRepeat*)oneOrMore:(ZKParser*)p separator:(ZKParser*)sep;
-(ZKParserRepeat*)zeroOrMore:(ZKParser*)p separator:(ZKParser*)sep max:(NSUInteger)maxItems;
-(ZKParserRepeat*)oneOrMore:(ZKParser*)p separator:(ZKParser*)sep max:(NSUInteger)maxItems;

-(ZKParser*)zeroOrOne:(ZKParser*)p;
-(ZKParser*)zeroOrOne:(ZKParser*)p ignoring:(BOOL(^)(NSObject*))ignoreBlock;

// Constructs a new Parser instance from the supplied block
-(ZKParser*)fromBlock:(ParseBlock)parser;
-(ZKParser*)fromBlock:(ParseBlock)parser mapper:(ResultMapper)m;

-(ZKParser*)map:(ZKParser*)p onMatch:(ResultMapper)block;

// Constucts a new parser that contains a reference to another parser. Can be used to
// refer to as yet unconstructed parsers where there are circular or recursive definitions.
-(ZKParserRef*)parserRef;

@end
