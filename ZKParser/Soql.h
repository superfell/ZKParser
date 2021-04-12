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
-(void)appendSoql:(NSMutableString*)dest;
@end

@interface PositionedString : AstNode
+(instancetype)string:(NSString *)s loc:(NSRange)loc;
+(instancetype)from:(ParserResult*)r;
+(NSArray<PositionedString*>*)fromArray:(NSArray<ParserResult*>*)r;

@property (strong,nonatomic) NSString *val;
@property (readonly) NSInteger length;
@end

@interface Expr : AstNode
@end

@interface SelectField : Expr
+(instancetype)name:(NSArray<PositionedString*>*)n alias:(PositionedString*)alias loc:(NSRange)loc;
@property (strong,nonatomic) NSArray<PositionedString*> *name;
@property (strong,nonatomic) PositionedString *alias;
@end

@interface SelectFunc : Expr
+(instancetype) name:(PositionedString*)n args:(NSArray<SelectField*>*)args alias:(PositionedString*)alias loc:(NSRange)loc;
@property (strong, nonatomic) PositionedString *name;
@property (strong, nonatomic) NSArray<SelectField*> *args;
@property (strong,nonatomic) PositionedString *alias;
@end

@interface SObjectRef : AstNode
+(instancetype) name:(PositionedString *)n alias:(PositionedString *)a loc:(NSRange)loc;
@property (strong,nonatomic) PositionedString *name;
@property (strong,nonatomic) PositionedString *alias;
@end

@interface From : AstNode
+(instancetype) sobject:(SObjectRef*)o related:(NSArray<SelectField*>*)r loc:(NSRange)loc;
@property (strong,nonatomic) SObjectRef *sobject;
@property (strong,nonatomic) NSArray<SelectField*>* relatedObjects;
@end

typedef NS_ENUM(uint16_t, LiteralType) {
    LTString,
    LTNull,
    LTBool,
    LTNumber,
    LTDateTime,
    LTDate,
    LTToken
};

@interface LiteralValue : Expr
+(instancetype)withValue:(NSObject *)v type:(LiteralType)t loc:(NSRange)loc;
@property (strong,nonatomic) NSObject *val;
@property (assign,nonatomic) LiteralType type;
@end

@interface LiteralValueArray : Expr
+(instancetype)withValues:(NSArray<LiteralValue*> *)v loc:(NSRange)loc;
@property (strong,nonatomic) NSArray<LiteralValue*> *values;
@end

@interface ComparisonExpr : Expr
+(instancetype) left:(Expr*)left op:(PositionedString*)op right:(LiteralValue*)right loc:(NSRange)loc;
@property (strong,nonatomic) Expr *left;
@property (assign,nonatomic) PositionedString *op;
@property (strong,nonatomic) LiteralValue *right;
@end

@interface OpAndOrExpr : Expr
+(instancetype) left:(Expr*)l op:(PositionedString*)op right:(Expr*)right loc:(NSRange)loc;
@property (strong,nonatomic) Expr *leftExpr;
@property (assign,nonatomic) PositionedString *op;
@property (strong,nonatomic) Expr *rightExpr;
@end

@interface NotExpr: Expr
+(instancetype)expr:(Expr*)expr loc:(NSRange)loc;
@property (strong,nonatomic) Expr *expr;
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
+(instancetype) by:(NSArray<OrderBy*>*)items loc:(NSRange)loc;
@property (strong,nonatomic) NSArray<OrderBy*> *items;
@end

@interface SelectQuery : Expr
@property (strong,nonatomic) NSArray<Expr*> *selectExprs;
@property (strong,nonatomic) From *from;
@property (strong,nonatomic) PositionedString *filterScope;
@property (strong,nonatomic) Expr *where;
@property (strong,nonatomic) OrderBys *orderBy;
@property (assign,nonatomic) NSInteger limit;
@property (assign,nonatomic) NSInteger offset;
@end
