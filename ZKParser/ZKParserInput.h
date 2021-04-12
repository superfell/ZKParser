//
//  ZKParserInput.h
//  ZKParser
//
//  Created by Simon Fell on 4/7/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZKBaseParser;
@class ParserResult;

typedef enum ZKCaseSensitivity {
    CaseSensitive,
    CaseInsensitive,
} ZKCaseSensitivity;

@interface NSString(ZKParsing)
-(ParserResult*)parse:(ZKBaseParser*)p error:(NSError **)err;
@end

@interface ZKParserInput : NSObject

+(ZKParserInput *)withInput:(NSString *)s;

@property (assign) NSUInteger pos;
-(NSUInteger)length;    // remaining length
-(NSString *)value;     // remaining input text

-(BOOL)hasMoreInput;
-(unichar)currentChar;  // asserts if no more input.

-(NSString *)consumeString:(NSString *)s caseSensitive:(ZKCaseSensitivity)cs;
-(BOOL)consumeCharacterSet:(NSCharacterSet *)s;

-(void)rewindTo:(NSUInteger)pos;

-(NSString*)input;
-(NSString*)valueOfRange:(NSRange)r;

-(ParserResult*)parse:(ZKBaseParser*)parser error:(NSError **)err;

@end
