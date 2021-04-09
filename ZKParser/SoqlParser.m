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
    ZKParser* field = [f seq:@[[f oneOrMore:ident separator:[f eq:@"."]], alias] onMatch:^ParserResult *(ParserResult *m) {
        
        m.val = [SelectField name:[PositionedString fromArray:[m.children[0] valueForKey:@"val"]]
                            alias:(m.children[1].val != [NSNull null] ? [m.children[1] posString] : nil)
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
                            ] onMatch:^ParserResult*(ParserResult*m) {
        NSArray<ParserResult*>*c = (NSArray<ParserResult*>*)m.val;
        m.val = [SelectFunc name:[c[0] posString] args:[[c[4] val] valueForKey:@"val"] alias:c[7].val == [NSNull null] ? nil : [c[7] posString] loc:m.loc];
        return m;
    }];
    
    ZKParser* selectExpr = [field or:@[func]];
    ZKParser* selectExprs = [[f oneOrMore:selectExpr separator:commaSep] onMatch:^ParserResult *(ParserResult *r) {
        NSArray<ParserResult*>* c = (NSArray<ParserResult*>*)r.val;
        NSArray *out = [c valueForKey:@"val"];
        r.val = out;
        return r;
    }];
    selectExprs = [selectExprs or:@[[f exactly:@"count()" case:CaseInsensitive onMatch:^ParserResult *(ParserResult *s) {
        s.val = [SelectFunc name:[s posString] args:@[] alias:nil loc:s.loc];
        return s;
    }]]];

    ZKParser *objectRef = [f seq:@[ident, [f zeroOrOne:[f seq:@[ws, ident] onMatch:pick(1)] ignoring:ignoreKeywords]]
                         onMatch:^ParserResult *(ParserResult *m) {
        NSArray<ParserResult*>* c = (NSArray<ParserResult*>*)m.val;
        m.val = [SObjectRef name:[c[0] posString] alias:[c[1] val] == [NSNull null] ? nil : [c[1] posString] loc:m.loc];
        return m;
    }];
    ZKParser *objectRefs = [f seq:@[objectRef,
                                [f zeroOrOne:[f seq:@[commaSep,
                                                      [f oneOrMore:field separator:commaSep]] onMatch:pick(1)]]]
                          onMatch:^ParserResult *(ParserResult*r) {

        NSArray<ParserResult*>*c = (NSArray<ParserResult*>*)r.val;
        r.val = [From sobject:c[0].val related:c[1].val == [NSNull null] ? @[] : [c[1].val valueForKey:@"val"] loc:r.loc];
        return r;
    }];
    
    ZKParser *filterScope = [f zeroOrOne:[[ws then:@[[f eq:@"USING"], ws, [f eq:@"SCOPE"], ws, ident]] onMatch:pick(5)]];

    ZKParser *asc  = [f exactly:@"ASC" setValue:@YES];
    ZKParser *desc = [f exactly:@"DESC" setValue:@NO];
    ZKParser *ascDesc = [f seq:@[ws, [f oneOf:@[asc,desc]]] onMatch:pick(1)];
    ZKParser *nulls = [f seq:@[ws, [f eq:@"NULLS"], ws,
                               [f oneOf:@[[f exactly:@"FIRST" setValue:@(NullsFirst)], [f exactly:@"LAST" setValue:@(NullsLast)]]]]
                     onMatch:pick(3)];
    ZKParser *orderByField = [f seq:@[field, [f zeroOrOne:ascDesc], [f zeroOrOne:nulls]] onMatch:^ParserResult*(ParserResult*m) {
        NSArray<ParserResult*>* c = (NSArray<ParserResult*>*)m.val;
        BOOL asc = YES;
        NSInteger nulls = NullsDefault;
        if (c[1].val != [NSNull null]) {
            asc = [c[1].val boolValue];
        }
        if (c[2].val != [NSNull null]) {
            nulls = [c[2].val integerValue];
        }
        m.val = [OrderBy field:(SelectField*)c[0].val asc:asc nulls:nulls loc:m.loc];
        return m;
    }];
    ZKParser *orderByFields = [f zeroOrOne:[f seq:@[ws,[f skip:@"ORDER"],ws,[f skip:@"BY"],ws,[f oneOrMore:orderByField separator:commaSep]] onMatch:^ParserResult*(ParserResult*r) {
        
        NSArray<ParserResult*>* c = (NSArray<ParserResult*>*)r.val;
        r.val = [OrderBys by:[c[5].val valueForKey:@"val"] loc:NSUnionRange(c[1].loc, c[3].loc)];
        return r;
    }]];

    ZKParser* selectStmt = [f seq:@[[f eq:@"SELECT"], ws, selectExprs, ws, [f eq:@"FROM"], ws, objectRefs, filterScope, orderByFields] onMatch:^ParserResult*(ParserResult*m) {
        NSArray<ParserResult*>* c = (NSArray<ParserResult*>*)m.val;
        SelectQuery *q = [SelectQuery new];
        q.selectExprs = c[2].val;
        q.from = c[6].val;
        q.filterScope = c[7].val == [NSNull null] ? nil : [c[7] posString];
        q.orderBy = c[8].val == [NSNull null] ? [OrderBys new] : c[8].val;
        m.val= q;
        return m;
    }];
    return selectStmt;
}

@end
