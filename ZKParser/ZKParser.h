//
//  ZKParser.h
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum ZKCaseSensitivity {
    CaseSensitive,
    CaseInsensitive,
} ZKCaseSensitivity;

@class ZKParserInput;

typedef NSObject *(^ZKParser)(ZKParserInput*, NSError **);

@interface NSString(ZKParsing)
-(NSObject*)parse:(ZKParser)p error:(NSError **)err;
@end

@interface ZKParserInput : NSObject

+(ZKParserInput *)withInput:(NSString *)s;

-(NSUInteger)length;
-(NSString *)value;

-(NSString *)consumeString:(NSString *)s caseSensitive:(ZKCaseSensitivity)cs;
-(BOOL)consumeCharacterSet:(NSCharacterSet *)s;

-(void)rewindTo:(NSUInteger)pos;

-(NSObject *)parse:(ZKParser)parser error:(NSError **)err;

@end

@interface ZKParserFactory : NSObject

-(ZKParser)whitespace;
-(ZKParser)maybeWhitespace;
-(ZKParser)exactly:(NSString *)s;
-(ZKParser)exactly:(NSString *)s case:(ZKCaseSensitivity)c;
-(ZKParser)exactly:(NSString *)s case:(ZKCaseSensitivity)c onMatch:(NSObject *(^)(NSString *))block;
-(ZKParser)characters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

-(ZKParser)seq:(NSArray<ZKParser>*)items;
-(ZKParser)seq:(NSArray<ZKParser>*)items onMatch:(NSObject *(^)(NSArray *))block;
-(ZKParser)oneOf:(NSArray<ZKParser>*)items;  // NSFastEnumeration ? // onMatch version
-(ZKParser)oneOrMore:(ZKParser)p;
-(ZKParser)zeroOrMore:(ZKParser)p;

-(ZKParser)map:(ZKParser)p onMatch:(NSObject *(^)(NSObject *))block;

@end
