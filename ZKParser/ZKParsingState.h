//
//  ZKParsingState.h
//  ZKParser
//
//  Created by Simon Fell on 4/7/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZKBaseParser;
@class ZKParserResult;

typedef enum ZKCaseSensitivity {
    CaseSensitive,
    CaseInsensitive,
} ZKCaseSensitivity;

@interface NSString(ZKParsing)
-(ZKParserResult*)parse:(ZKBaseParser*)p error:(NSError **)err;
@end

@interface ZKParsingState : NSObject

+(ZKParsingState *)withInput:(NSString *)s;

@property (assign) NSUInteger pos;
@property (assign) NSUInteger cut;

-(NSUInteger)length;    // remaining length
-(NSString *)value;     // remaining input text

-(BOOL)hasMoreInput;
-(unichar)currentChar;  // asserts if no more input.

-(NSString *)consumeString:(NSString *)s caseSensitive:(ZKCaseSensitivity)cs;
-(BOOL)consumeCharacterSet:(NSCharacterSet *)s;

-(void)markCut;
-(BOOL)canMoveTo:(NSUInteger)pos;
-(void)moveTo:(NSUInteger)pos;

-(NSString*)input;
-(NSString*)valueOfRange:(NSRange)r;

@property (strong,nonatomic) NSDictionary *userContext;

-(ZKParserResult*)parse:(ZKBaseParser*)parser error:(NSError **)err;

@end
