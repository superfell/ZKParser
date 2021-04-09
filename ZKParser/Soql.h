//
//  Soql.h
//  ZKParser
//
//  Created by Simon Fell on 4/8/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ParserResult;

@interface AstNode : NSObject
@property (assign,nonatomic) NSRange loc;
-(NSString*)toSoql;
@end

@interface PositionedString : AstNode
+(instancetype)string:(NSString *)s loc:(NSRange)loc;
+(instancetype)from:(ParserResult*)r;
+(NSArray<PositionedString*>*)fromArray:(NSArray<ParserResult*>*)r;

@property (strong,nonatomic) NSString *val;
@end

@interface SelectField : AstNode
+(instancetype)name:(NSArray<PositionedString*>*)n loc:(NSRange)loc;
@property (strong,nonatomic) NSArray<PositionedString*> *name;
@property (strong,nonatomic) PositionedString *alias; // ?
@end

@interface SelectFunc : AstNode
+(instancetype) name:(PositionedString*)n args:(NSArray<SelectField*>*)args;
@property (strong, nonatomic) PositionedString *name;
@property (strong, nonatomic) NSArray<SelectField*> *args;
@end

@interface SObjectRef : AstNode
+(instancetype) name:(PositionedString *)n alias:(PositionedString *)a loc:(NSRange)loc;
@property (strong,nonatomic) PositionedString *name;
@property (strong,nonatomic) PositionedString *alias;
@end

@interface From : AstNode
@property (strong,nonatomic) SObjectRef *sobject;
@property (strong,nonatomic) NSArray<SelectField*>* relatedObjects;
@end

static const NSInteger NullsDefault = 1;
static const NSInteger NullsFirst = 2;
static const NSInteger NullsLast = 3;

@interface OrderBy : AstNode
+(instancetype) field:(SelectField*)f asc:(BOOL)asc nulls:(NSInteger)n loc:(NSRange)loc;
@property (strong, nonatomic) SelectField* field;
@property (assign, nonatomic) BOOL asc;
@property (assign, nonatomic) NSInteger nulls;
@end

@interface OrderBys : AstNode
@property (strong,nonatomic) NSArray<OrderBy*> *items;
@end

@interface SelectQuery : AstNode
@property (strong,nonatomic) NSArray *selectExprs;
@property (strong,nonatomic) SObjectRef *from;
@property (strong,nonatomic) PositionedString *filterScope;
@property (strong,nonatomic) OrderBys *orderBy;
@property (assign,nonatomic) NSInteger limit;
@property (assign,nonatomic) NSInteger offset;
@end
