//
//  Soql.h
//  ZKParser
//
//  Created by Simon Fell on 4/8/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SObjectRef : NSObject
@property (strong,nonatomic) NSString *name;
@property (strong,nonatomic) NSString *alias;
@end

static const NSInteger NullsDefault = 1;
static const NSInteger NullsFirst = 2;
static const NSInteger NullsLast = 3;

@interface OrderBy : NSObject
@property (strong, nonatomic) NSArray* field;
@property (assign, nonatomic) BOOL asc;
@property (assign, nonatomic) NSInteger nulls;
@end

@interface SelectField : NSObject
@property (strong,nonatomic) NSArray *name;
@property (strong,nonatomic) NSString *alias; // ?
@end

@interface SelectFunc : NSObject
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSArray *args;
@end

@interface SelectQuery : NSObject
@property (strong,nonatomic) NSArray *selectExprs;
@property (strong,nonatomic) SObjectRef *from;
@property (strong,nonatomic) NSArray<OrderBy*> *orderBy;
@property (assign,nonatomic) NSInteger limit;
@property (assign,nonatomic) NSInteger offset;
@end

@interface SoqlParser : NSObject
-(SelectQuery*)parse:(NSString *)input error:(NSError**)err;
@end

