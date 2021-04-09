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

    NSSet<NSString*>* keywords = [NSSet setWithArray:@[@"from",@"where",@"order",@"by",@"having",@"limit",@"offset",@"group by",@"using",@"scope",@"asc",@"desc",@"nulls"]];
    BOOL(^ignoreKeywords)(NSObject*) = ^BOOL(NSObject *v) {
        NSString *s = (NSString *)v;
        return [keywords containsObject:[s lowercaseString]];
    };
    ZKParser* ws = [f whitespace];
    ZKParser* maybeWs = [f maybeWhitespace];
    ZKParser* commaSep = [f seq:@[maybeWs, [f skip:@","], maybeWs]];
    ZKParser* ident = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"]
                               name:@"identifier"
                                min:1];

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
    selectExprs = [selectExprs or:@[[f exactly:@"count()" case:CaseInsensitive onMatch:^ParserResult *(ParserResult *s) {
        s.val = [SelectFunc name:[s posString] args:@[] alias:nil loc:s.loc];
        return s;
    }]]];

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
    
    ZKParser *filterScope = [f zeroOrOne:[[ws then:@[[f eq:@"USING"], ws, [f eq:@"SCOPE"], ws, ident]] onMatch:pick(5)]];

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

    ZKParser* selectStmt = [f seq:@[[f eq:@"SELECT"], ws, selectExprs, ws, [f eq:@"FROM"], ws, objectRefs, filterScope, orderByFields] onMatch:^ParserResult*(ArrayParserResult*m) {
        SelectQuery *q = [SelectQuery new];
        q.selectExprs = m.child[2].val;
        q.from = m.child[6].val;
        q.filterScope = [m childIsNull:7] ? nil : [m.child[7] posString];
        q.orderBy = [m childIsNull:8] ? [OrderBys new] : m.child[8].val;
        m.val= q;
        return m;
    }];
    return selectStmt;
}

@end
