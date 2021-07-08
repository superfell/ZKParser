// Copyright (c) 2021 Simon Fell
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <Foundation/Foundation.h>

@class ZKBaseParser;
@class ZKParserResult;
@class ZKParserError;

typedef NS_ENUM(uint8_t, ZKCaseSensitivity) {
    ZKCaseSensitive,
    ZKCaseInsensitive,
};

@interface NSString(ZKParsing)
-(id)parse:(ZKBaseParser*)parser error:(NSError**)err;
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
-(NSInteger)consumeCharacterSet:(NSCharacterSet *)s;

-(void)markCut;
-(BOOL)canMoveTo:(NSUInteger)pos;
-(void)moveTo:(NSUInteger)pos;

-(NSString*)input;
-(NSString*)valueOfRange:(NSRange)r;

@property (strong,nonatomic) NSDictionary *userContext;

// errors
@property (readonly,nonatomic) ZKParserError *error;
@property (readonly,nonatomic) BOOL hasError;

// A lot of parser errors are of the form "expected 'A' at position 3".
// As there's a lot of errors thrown away due to backtracking/branching
// we want indicating an error to be cheap. Calling expected will
// lazyly generate the error message when needed. This can result in
// unused/thrown away errors not costing any allocations at all. This is
// the preferred way to indicate a parser error.
-(ZKParserError*)expected:(NSString*)expected;
// This is similar to expected, except the expected thing is a class or
// type of value, e.g. whitespace, rather than a specific character sequence.
// This results in the expected item in the generated message to not be quoted.
-(ZKParserError*)expectedClass:(NSString*)expected;
// Flag a parser error with an explict message.
-(ZKParserError*)error:(NSString*)msg;
// Clear the error state.
-(void)clearError;

-(id)parse:(ZKBaseParser*)parser error:(NSError**)err;

@end

@interface ZKParserError : NSObject
@property (assign,nonatomic) NSInteger code;
@property (strong,nonatomic) NSString *msg;
@property (assign,nonatomic) NSUInteger pos;
@property (strong,nonatomic) NSMutableDictionary *userInfo;
@property (strong,nonatomic) NSString *expected;
@property (assign,nonatomic) BOOL expectedClass;
@end
