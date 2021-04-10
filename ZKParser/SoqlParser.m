//
//  SoqlParser.m
//  ZKParser
//
//  Created by Simon Fell on 4/9/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import "SoqlParser.h"
#import "Soql.h"
#import "ZKParser.h"

@implementation ParserResult (Soql)
-(PositionedString*)posString {
    return [PositionedString from:self];
}
@end

MapperBlock pick(NSUInteger idx) {
    return ^ParserResult *(ParserResult *m) {
        return m.val[idx];
    };
}

ParserResult * pickVals(ParserResult*r) {
    r.val = [r.val valueForKey:@"val"];
    return r;
}

@interface SoqlParser()
@property (strong,nonatomic) ZKParser *parser;
@end

@implementation SoqlParser

-(instancetype)init {
    self = [super init];
    self.parser = [self buildParser];
    return self;
}

-(SelectQuery*)parse:(NSString *)input error:(NSError**)err {
    return (SelectQuery*)[input parse:self.parser error:err].val;
}

-(ZKParser*)buildParser {
    ZKParserFactory *f = [ZKParserFactory new];
    f.defaultCaseSensitivity = CaseInsensitive;

    // USING is not in the doc, but appears to not be allowed
    // ORDER & OFFSET are issues for our parser, but not the sfdc one.
    NSSet<NSString*>* keywords = [NSSet setWithArray:[@"ORDER OFFSET USING   AND ASC DESC EXCLUDES FIRST FROM GROUP HAVING IN INCLUDES LAST LIKE LIMIT NOT NULL NULLS OR SELECT WHERE WITH" componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    BOOL(^ignoreKeywords)(NSObject*) = ^BOOL(NSObject *v) {
        NSString *s = (NSString *)v;
        return [keywords containsObject:[s uppercaseString]];
    };
    ZKParser* ws = [f whitespace];
    ZKParser* maybeWs = [f maybeWhitespace];
    ZKParser* commaSep = [f seq:@[maybeWs, [f eq:@","], maybeWs]];
    ZKParser* ident = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"]
                               name:@"identifier"
                                min:1];
    ident.debugName = @"ident";
    
    // SELECT LIST
    ZKParser *alias = [f zeroOrOne:[f seq:@[ws, ident] onMatch:pick(1)] ignoring:ignoreKeywords];
    ZKParser* field = [f seq:@[[f oneOrMore:ident separator:[f eq:@"."]], alias] onMatch:^ParserResult *(ArrayParserResult *m) {
        m.val = [SelectField name:[PositionedString fromArray:m.child[0].val]
                            alias:([m childIsNull:1] ? nil : [m.child[1] posString])
                              loc:m.loc];
        return m;
    }];
    ZKParser* func = [f seq:@[ident,
                              maybeWs,
                              [f eq:@"("],
                              maybeWs,
                              [f oneOrMore:field separator:commaSep],
                              maybeWs,
                              [f eq:@")"],
                              alias
                            ] onMatch:^ParserResult*(ArrayParserResult*m) {
        
        m.val = [SelectFunc name:[m.child[0] posString]
                            args:[m.child[4].val valueForKey:@"val"]
                           alias:[m childIsNull:7] ? nil : [m.child[7] posString]
                             loc:m.loc];
        return m;
    }];
    
    ZKParser* selectExpr = [f oneOf:@[field, func]];
    ZKParser* selectExprs = [[f oneOrMore:selectExpr separator:commaSep] onMatch:^ParserResult *(ArrayParserResult *r) {
        r.val = r.childVals;
        return r;
    }];
    ZKParser *countOnly = [f seq:@[[f eq:@"count"], maybeWs, [f eq:@"("], maybeWs, [f eq:@")"]] onMatch:^ParserResult *(ArrayParserResult *r) {
        // Should we just let count() be handled by the regular func matcher? and not deal with the fact it can only
        // appear on its own.
        r.val =@[[SelectFunc name:[r.child[0] posString] args:@[] alias:nil loc:r.loc]];
        return r;
    }];
    selectExprs = [f oneOf:@[selectExprs, countOnly]];

    /// FROM
    ZKParser *objectRef = [f seq:@[ident, alias] onMatch:^ParserResult *(ArrayParserResult *m) {
        m.val = [SObjectRef name:m.child[0].posString
                           alias:[m childIsNull:1] ? nil : m.child[1].posString
                             loc:m.loc];
        return m;
    }];
    ZKParser *objectRefs = [f seq:@[objectRef, [f zeroOrOne:
                                [f seq:@[commaSep, [f oneOrMore:field separator:commaSep]] onMatch:pick(1)]]]
                          onMatch:^ParserResult *(ArrayParserResult*r) {
        r.val = [From sobject:r.child[0].val
                      related:[r childIsNull:1] ? @[] : [r.child[1].val valueForKey:@"val"]
                          loc:r.loc];
        return r;
    }];
    
    /// WHERE
    ZKParser *operator = [f oneOfTokens:@"< <= > >= = != LIKE IN NOT INCLUDES EXCLUDES"];
    NSCharacterSet *charSetQuote = [NSCharacterSet characterSetWithCharactersInString:@"'"];
    ZKParser *literalValue = [f seq:@[[f eq:@"'"], [f notCharacters:charSetQuote name:@"literal" min:1], [f eq:@"'"]] onMatch:^ParserResult *(ArrayParserResult *r) {
        LiteralValue *v = [LiteralValue new];
        v.val = [r.child[1] posString];
        v.loc = r.loc;
        r.val = v;
        return r;
    }];
    ZKParser *baseExpr = [f seq:@[field, maybeWs, operator, maybeWs, literalValue] onMatch:^ParserResult *(ArrayParserResult *r) {
        r.val = [ComparisonExpr left:r.child[0].val op:[r.child[2] posString] right:r.child[4].val loc:r.loc];
        return r;
    }];


    // use parserRef so that we can set up the recursive decent for (...)
    // be careful not to use oneOf with it as that will recurse infinitly because it checks all branches.
    ZKParserRef *exprList = [ZKParserRef new];
    ZKParser *parens = [f seq:@[[f eq:@"("], maybeWs, exprList, maybeWs, [f eq:@")"]] onMatch:pick(2)];
    ZKParser *andOr = [f seq:@[ws, [f oneOfTokens:@"AND OR"], ws] onMatch:pick(1)];
    exprList.parser = [f seq:@[[f firstOf:@[parens, baseExpr]], [f zeroOrOne:[f seq:@[andOr, exprList]]]] onMatch:^ParserResult*(ArrayParserResult*r) {
        Expr *left = r.child[0].val;
        if ([r childIsNull:1]) {
            r.val = left;
            return r;
        }
        ArrayParserResult *rhs = (ArrayParserResult *)r.child[1];
        PositionedString *op = [rhs.child[0] posString];
        Expr *right = rhs.child[1].val;
        r.val = [OpAndOrExpr left:left op:op right:right loc:r.loc];
        return r;
    }];
    ZKParser *where = [f zeroOrOne:[f seq:@[ws ,[f eq:@"WHERE"], ws, exprList] onMatch:pick(3)]];
    
    /// FILTER SCOPE
    ZKParser *filterScope = [f zeroOrOne:[f seq:@[ws, [f eq:@"USING"], ws, [f eq:@"SCOPE"], ws, ident] onMatch:pick(5)]];

    
    /// ORDER BY
    ZKParser *asc  = [f exactly:@"ASC" setValue:@YES];
    ZKParser *desc = [f exactly:@"DESC" setValue:@NO];
    ZKParser *ascDesc = [f seq:@[ws, [f oneOf:@[asc,desc]]] onMatch:pick(1)];
    ZKParser *nulls = [f seq:@[ws, [f eq:@"NULLS"], ws,
                               [f oneOf:@[[f exactly:@"FIRST" setValue:@(NullsFirst)], [f exactly:@"LAST" setValue:@(NullsLast)]]]]
                     onMatch:pick(3)];
    ZKParser *orderByField = [f seq:@[field, [f zeroOrOne:ascDesc], [f zeroOrOne:nulls]] onMatch:^ParserResult*(ArrayParserResult*m) {
        BOOL asc = YES;
        NSInteger nulls = NullsDefault;
        if (![m childIsNull:1]) {
            asc = [m.child[1].val boolValue];
        }
        if (![m childIsNull:2]) {
            nulls = [m.child[2].val integerValue];
        }
        m.val = [OrderBy field:m.child[0].val asc:asc nulls:nulls loc:m.loc];
        return m;
    }];
    ZKParser *orderByFields = [f zeroOrOne:[f seq:@[ws, [f eq:@"ORDER"], ws, [f eq:@"BY"], ws, [f oneOrMore:orderByField separator:commaSep]] onMatch:^ParserResult*(ArrayParserResult*r) {
        
        // loc for OrderBys is just the ORDER BY keyword. TODO, we probably don't want that.
        r.val = [OrderBys by:[r.child[5].val valueForKey:@"val"] loc:NSUnionRange(r.child[1].loc, r.child[3].loc)];
        return r;
    }]];

    /// SELECT
    ZKParser* selectStmt = [f seq:@[[f eq:@"SELECT"], ws, selectExprs, ws, [f eq:@"FROM"], ws, objectRefs, filterScope, where, orderByFields] onMatch:^ParserResult*(ArrayParserResult*m) {
        SelectQuery *q = [SelectQuery new];
        q.selectExprs = m.child[2].val;
        q.from = m.child[6].val;
        q.filterScope = [m childIsNull:7] ? nil : [m.child[7] posString];
        q.where = [m childIsNull:8] ? nil : m.child[8].val;
        q.orderBy = [m childIsNull:9] ? [OrderBys new] : m.child[9].val;
        m.val = q;
        return m;
    }];
    return selectStmt;
}

@end


