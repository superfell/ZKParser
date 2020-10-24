//
//  ZKParser.h
//  ZKParser
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZKParserInput : NSObject

+(ZKParserInput *)withInput:(NSString *)s;

-(NSUInteger)length;
-(NSString *)value;

-(BOOL)consumeString:(NSString *)s;
-(BOOL)consumeCharacterSet:(NSCharacterSet *)s;

-(void)rewindTo:(NSUInteger)pos;

@end

typedef NSObject *(^ZKParser)(ZKParserInput*);

@interface ZKParserFactory : NSObject
+(ZKParser)whitespace;
+(ZKParser)exactly:(NSString *)s onMatch:(NSObject *(^)(NSString *))block;

+(ZKParser)seq:(NSArray *)items;
+(ZKParser)oneOf:(NSArray *)items;  // NSFastEnumeration ? // onMatch version
+(ZKParser)oneOrMore:(ZKParser)p;

+(NSObject *)parse:(ZKParser)parser input:(NSString *)input error:(NSError **)err;

@end
