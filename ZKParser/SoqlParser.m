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

@implementation ZKParserFactory (Soql)
-(ZKParser *)oneOfFromString:(NSString *)items {
    NSArray *list = [items componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray<ZKParser*> *parsers = [NSMutableArray arrayWithCapacity:list.count];
    for (NSString *s in list) {
        [parsers addObject:[self exactly:s]];
    }
    return [self oneOf:parsers];
}
@end

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
    ZKParser* commaSep = [f seq:@[maybeWs, [f skip:@","], maybeWs]];
    ZKParser* ident = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"]
                               name:@"identifier"
                                min:1];
    ident.debugName = @"ident";
    
    // SELECT LIST
    ZKParser *alias = [f zeroOrOne:[f seq:@[ws, ident] onMatch:pick(1)] ignoring:ignoreKeywords];
    ZKParser* field = [f seq:@[[f oneOrMore:ident separator:[f eq:@"."]], alias] onMatch:^ParserResult *(ArrayParserResult *m) {
        m.val = [SelectField name:[PositionedString fromArray:[m.child[0] valueForKey:@"val"]]
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
    
    ZKParser* selectExpr = [field or:@[func]];
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
    selectExprs = [selectExprs or:@[countOnly]];

    /// FROM
    ZKParser *objectRef = [f seq:@[ident, [f zeroOrOne:[f seq:@[ws, ident] onMatch:pick(1)] ignoring:ignoreKeywords]]
                         onMatch:^ParserResult *(ArrayParserResult *m) {

        m.val = [SObjectRef name:m.child[0].posString
                           alias:[m childIsNull:1] ? nil : m.child[1].posString
                             loc:m.loc];
        return m;
    }];
    ZKParser *objectRefs = [f seq:@[objectRef,
                                [f zeroOrOne:[f seq:@[commaSep,
                                                      [f oneOrMore:field separator:commaSep]] onMatch:pick(1)]]]
                          onMatch:^ParserResult *(ArrayParserResult*r) {

        r.val = [From sobject:r.child[0].val
                      related:[r childIsNull:1] ? @[] : [r.child[1].val valueForKey:@"val"]
                          loc:r.loc];
        return r;
    }];
    
    /// WHERE
    ZKParser *operator = [f oneOfFromString:@"< <= > >= = != LIKE IN NOT INCLUDES EXCLUDES"];
    NSCharacterSet *charSetQuote = [NSCharacterSet characterSetWithCharactersInString:@"'"];
    ZKParser *literalValue = [f seq:@[[f eq:@"'"], [f notCharacters:charSetQuote name:@"literal" min:1], [f eq:@"'"]] onMatch:^ParserResult *(ArrayParserResult *r) {
        LiteralValue *v = [LiteralValue new];
        v.val = [r.child[1] posString];
        v.loc = r.loc;
        r.val = v;
        return r;
    }];
    ZKParser *baseExpr = [f seq:@[field, maybeWs, operator, maybeWs, literalValue] onMatch:^ParserResult *(ArrayParserResult *r) {
        Expr *e = [Expr leftF:r.child[0].val op:[r.child[2] posString] rightV:r.child[4].val loc:r.loc];
        r.val = e;
        return r;
    }];
    baseExpr.debugName = @"baseExpr";

    ZKParser *andOr = [f oneOfFromString:@"AND OR"];
    ZKParser *baseExprList = [f seq:@[baseExpr, [f zeroOrMore:[f seq:@[ws, andOr, ws, baseExpr]]]] onMatch:^ParserResult *(ArrayParserResult *r) {
        Expr *e = r.child[0].val;
        for (ArrayParserResult *next in r.child[1].val) {
            PositionedString *op = [next.child[1] posString];
            LiteralValue *v = next.child[3].val;
            e = [Expr leftE:e op:op rightV:v loc:next.loc];
        }
        r.val = e;
        return r;
    }];
    baseExprList.debugName = @"innerBaseExprList";
    ZKParser *parenticalBaseExprList = [f seq:@[[f eq:@"("], baseExprList, [f eq:@")"]] onMatch:pick(1)];
    parenticalBaseExprList.debugName = @"parenticalBaseExprList";
    baseExprList = [f oneOf:@[baseExprList, parenticalBaseExprList]];
    baseExprList.debugName = @"baseExprList";
    
    ZKParser *andOr1 = [f seq:@[baseExpr, [f zeroOrMore:[f seq:@[ws, andOr, ws, baseExprList]]]] onMatch:^ParserResult *(ArrayParserResult *r) {
        Expr *e = r.child[0].val;
        for (ArrayParserResult *next in r.child[1].val) {
            PositionedString *op = [next.child[1] posString];
            Expr *right = next.child[3].val;
            e = [Expr leftE:e op:op rightE:right loc:next.loc];
        }
        r.val = e;
        return r;
    }];
    ZKParser *andOr2 = [f seq:@[baseExprList, [f zeroOrMore:[f seq:@[ws, andOr, ws, baseExprList]]]] onMatch:^ParserResult *(ArrayParserResult *r) {
        Expr *e = r.child[0].val;
        for (ArrayParserResult *next in r.child[1].val) {
            PositionedString *op = [next.child[1] posString];
            Expr *right = next.child[3].val;
            e = [Expr leftE:e op:op rightE:right loc:next.loc];
        }
        r.val = e;
        return r;
    }];
    ZKParser *andOr3 = [f seq:@[baseExprList, [f zeroOrMore:[f seq:@[ws, andOr, ws, baseExpr]]]] onMatch:^ParserResult *(ArrayParserResult *r) {
        Expr *e = r.child[0].val;
        for (ArrayParserResult *next in r.child[1].val) {
            PositionedString *op = [next.child[1] posString];
            Expr *right = next.child[3].val;
            e = [Expr leftE:e op:op rightE:right loc:next.loc];
        }
        r.val = e;
        return r;
    }];

    ZKParser *rootExprList = [f oneOf:@[andOr1, andOr2, andOr3]];
    
    ZKParser *where = [f zeroOrOne:[f seq:@[ws,[f eq:@"WHERE"], ws, rootExprList] onMatch:pick(3)]];
    where.debugName = @"Where";
    
    /// FILTER SCOPE
    ZKParser *filterScope = [f zeroOrOne:[[ws then:@[[f eq:@"USING"], ws, [f eq:@"SCOPE"], ws, ident]] onMatch:pick(5)]];

    
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
        assert([m.child[0].val isKindOfClass:[SelectField class]]);
        m.val = [OrderBy field:(SelectField*)m.child[0].val asc:asc nulls:nulls loc:m.loc];
        return m;
    }];
    ZKParser *orderByFields = [f zeroOrOne:[f seq:@[ws,[f skip:@"ORDER"],ws,[f skip:@"BY"],ws,[f oneOrMore:orderByField separator:commaSep]] onMatch:^ParserResult*(ArrayParserResult*r) {
        
        // loc for OrderBys is just the ORDER BY keyword.
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
        NSLog(@"where %@", m.child[8]);
        m.val= q;
        return m;
    }];
    return selectStmt;
}

@end


