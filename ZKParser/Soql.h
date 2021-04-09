//
//  Soql.h
//  ZKParser
//
//  Created by Simon Fell on 4/8/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SelectQuery;

@interface SoqlParser : NSObject
-(SelectQuery*)parse:(NSString *)input error:(NSError**)err;
@end

@interface PositionedString : NSObject
@property (strong,nonatomic) NSString *val;
@property (assign,nonatomic) NSRange loc;
-(NSString*)toSoql;
@end

@interface SelectField : NSObject
@property (strong,nonatomic) NSArray<PositionedString*> *name;
@property (strong,nonatomic) PositionedString *alias; // ?
@property (assign,nonatomic) NSRange loc;
-(NSString*)toSoql;
@end

@interface SelectFunc : NSObject
@property (strong, nonatomic) PositionedString *name;
@property (strong, nonatomic) NSArray<SelectField*> *args;
@property (assign,nonatomic) NSRange loc;
-(NSString*)toSoql;
@end

@interface SObjectRef : NSObject
@property (strong,nonatomic) PositionedString *name;
@property (strong,nonatomic) PositionedString *alias;
@property (assign,nonatomic) NSRange loc;
-(NSString*)toSoql;
@end

static const NSInteger NullsDefault = 1;
static const NSInteger NullsFirst = 2;
static const NSInteger NullsLast = 3;

@interface OrderBy : NSObject
@property (strong, nonatomic) SelectField* field;
@property (assign, nonatomic) BOOL asc;
@property (assign, nonatomic) NSInteger nulls;
@property (assign,nonatomic) NSRange loc;
-(NSString*)toSoql;
@end

@interface OrderBys : NSObject
@property (strong,nonatomic) NSArray<OrderBy*> *items;
@property (assign,nonatomic) NSRange loc;   // location of the ORDER BY keywork
-(NSString*)toSoql;
@end

@interface SelectQuery : NSObject
@property (strong,nonatomic) NSArray *selectExprs;
@property (strong,nonatomic) SObjectRef *from;
@property (strong,nonatomic) OrderBys *orderBy;
@property (assign,nonatomic) NSInteger limit;
@property (assign,nonatomic) NSInteger offset;
@property (assign,nonatomic) NSRange loc;
-(NSString*)toSoql;
@end


