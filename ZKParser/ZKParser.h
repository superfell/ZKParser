//
//  ZKParser.h
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZKParserInput.h"

@interface ZKParser : NSObject
-(NSObject *)parse:(ZKParserInput*)input error:(NSError **)err;

-(ZKParser*)or:(NSArray<ZKParser*>*)otherParser;
-(ZKParser*)and:(NSArray<ZKParser*>*)otherParsers;
@end

@interface ZKParserFactory : NSObject

@property(assign,nonatomic) ZKCaseSensitivity defaultCaseSensitivity;

-(ZKParser*)whitespace;
-(ZKParser*)maybeWhitespace;
-(ZKParser*)exactly:(NSString *)s;    // case sensitive set by defaultCaseSensitivity
-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c;
-(ZKParser*)exactly:(NSString *)s case:(ZKCaseSensitivity)c onMatch:(NSObject *(^)(NSString *))block;
-(ZKParser*)characters:(NSCharacterSet*)set name:(NSString *)name min:(NSUInteger)minMatches;

-(ZKParser*)seq:(NSArray<ZKParser*>*)items;
-(ZKParser*)seq:(NSArray<ZKParser*>*)items onMatch:(NSObject *(^)(NSArray *))block;

-(ZKParser*)oneOf:(NSArray<ZKParser*>*)items;  // NSFastEnumeration ? // onMatch version
-(ZKParser*)oneOf:(NSArray<ZKParser*>*)items onMatch:(NSObject *(^)(NSObject *))block;

-(ZKParser*)oneOrMore:(ZKParser*)p;
-(ZKParser*)zeroOrMore:(ZKParser*)p;

-(ZKParser*)map:(ZKParser*)p onMatch:(NSObject *(^)(NSObject *))block;

@end
