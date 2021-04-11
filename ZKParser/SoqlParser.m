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

-(ZKSingularParser*)literalStringValue:(ZKParserFactory*)f {
    return [f fromBlock:^ParserResult *(ZKParserInput *input, NSError *__autoreleasing *err) {
        NSInteger start = input.pos;
        if ((!input.hasMoreInput) || input.currentChar != '\'') {
            *err = [NSError errorWithDomain:@"Soql"
                                      code:1
                                  userInfo:@{
                                      NSLocalizedDescriptionKey:[NSString stringWithFormat:@"expecting ' at position %lu", input.pos+1],
                                      @"Position": @(input.pos+1)
                                  }];
            return nil;
        }
        input.pos++;
        while (true) {
            if (!input.hasMoreInput) {
                *err = [NSError errorWithDomain:@"Soql"
                                          code:1
                                      userInfo:@{
                                          NSLocalizedDescriptionKey:[NSString stringWithFormat:@"reached end of input while parsing a string literal, missing closing ' at %lu", input.pos+1],
                                          @"Position": @(input.pos+1)
                                      }];
                return nil;
            }
            unichar c = input.currentChar;
            if (c == '\\') {
                input.pos++;
                if (!input.hasMoreInput) {
                    *err = [NSError errorWithDomain:@"Soql"
                                              code:1
                                          userInfo:@{
                                              NSLocalizedDescriptionKey:[NSString stringWithFormat:@"invalid escape sequence at %lu", input.pos],
                                              @"Position": @(input.pos)
                                          }];
                }
                input.pos++;
                continue;
            }
            input.pos++;
            if (c == '\'') {
                break;
            }
        }
        // range includes the ' tokens, the value does not.
        NSRange rng = NSMakeRange(start,input.pos-start);
        NSString *match = [input valueOfRange:NSMakeRange(start+1,input.pos-start-2)];
        return [ParserResult result:match loc:rng];
    }];
}

-(ZKParser*)literalValue:(ZKParserFactory*)f {
    ZKParser *literalStringValue = [[self literalStringValue:f] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:r.posString type:LTString loc:r.loc];
        return r;
    }];
    ZKParser *literalNullValue = [[f eq:@"null"] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:[NSNull null] type:LTNull loc:r.loc];
        return r;
    }];
    ZKParser *literalTrueValue = [[f eq:@"true"] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:@TRUE type:LTBool loc:r.loc];
        return r;
    }];
    ZKParser *literalFalseValue = [[f eq:@"false"] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:@FALSE type:LTBool loc:r.loc];
        return r;
    }];
    ZKParser *literalNumberValue = [[f decimalNumber] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:r.val type:LTNumber loc:r.loc];
        return r;
    }];
    NSError *err = nil;
    NSRegularExpression *token = [NSRegularExpression regularExpressionWithPattern:@"[a-z]\\S*"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&err];
    NSAssert(err == nil, @"failed to compile regex %@", err);
    ZKParser *literalToken = [[f regex:token name:@"named literal"] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:r.val type:LTToken loc:r.loc];
        return r;
    }];
    ZKParser *literalValue = [f oneOf:@[literalStringValue, literalNullValue, literalTrueValue, literalFalseValue, literalNumberValue, literalToken]];
    return literalValue;
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
    
    // SELECT LIST
    ZKParser *alias = [f zeroOrOne:[[f seq:@[ws, ident]] onMatch:pick(1)] ignoring:ignoreKeywords];
    ZKParser* field = [[f seq:@[[f oneOrMore:ident separator:[f eq:@"."]], alias]] onMatch:^ParserResult *(ArrayParserResult *m) {
        m.val = [SelectField name:[PositionedString fromArray:m.child[0].val]
                            alias:([m childIsNull:1] ? nil : [m.child[1] posString])
                              loc:m.loc];
        return m;
    }];
    ZKParser* func = [[f seq:@[ident,
                              maybeWs,
                              [f eq:@"("],
                              maybeWs,
                              [f oneOrMore:field separator:commaSep],
                              maybeWs,
                              [f eq:@")"],
                              alias
                            ]] onMatch:^ParserResult*(ArrayParserResult*m) {
        
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
    ZKParser *countOnly = [[f seq:@[[f eq:@"count"], maybeWs, [f eq:@"("], maybeWs, [f eq:@")"]]] onMatch:^ParserResult *(ArrayParserResult *r) {
        // Should we just let count() be handled by the regular func matcher? and not deal with the fact it can only
        // appear on its own.
        r.val =@[[SelectFunc name:[r.child[0] posString] args:@[] alias:nil loc:r.loc]];
        return r;
    }];
    selectExprs = [f oneOf:@[selectExprs, countOnly]];

    /// FROM
    ZKParser *objectRef = [[f seq:@[ident, alias]] onMatch:^ParserResult *(ArrayParserResult *m) {
        m.val = [SObjectRef name:m.child[0].posString
                           alias:[m childIsNull:1] ? nil : m.child[1].posString
                             loc:m.loc];
        return m;
    }];
    ZKParser *objectRefs = [[f seq:@[objectRef, [f zeroOrOne:
                                [[f seq:@[commaSep, [f oneOrMore:field separator:commaSep]]] onMatch:pick(1)]]]]
                          onMatch:^ParserResult *(ArrayParserResult*r) {
        r.val = [From sobject:r.child[0].val
                      related:[r childIsNull:1] ? @[] : [r.child[1].val valueForKey:@"val"]
                          loc:r.loc];
        return r;
    }];
    
    /// WHERE
    ZKParser *operator = [f oneOfTokens:@"< <= > >= = != LIKE IN NOT INCLUDES EXCLUDES"];
    ZKParser *literalValue = [self literalValue:f];
    ZKParser *baseExpr = [[f seq:@[selectExpr, maybeWs, operator, maybeWs, literalValue]] onMatch:^ParserResult *(ArrayParserResult *r) {
        r.val = [ComparisonExpr left:r.child[0].val op:[r.child[2] posString] right:r.child[4].val loc:r.loc];
        return r;
    }];

    // use parserRef so that we can set up the recursive decent for (...)
    // be careful not to use oneOf with it as that will recurse infinitly because it checks all branches.
    ZKParserRef *exprList = [f parserRef];
    ZKParser *parens = [[f seq:@[[f eq:@"("], maybeWs, exprList, maybeWs, [f eq:@")"]]] onMatch:pick(2)];
    ZKParser *andOr = [[f seq:@[ws, [f oneOfTokens:@"AND OR"], ws]] onMatch:pick(1)];
    ZKParser *not = [f seq:@[[f eq:@"NOT"], maybeWs]];
    exprList.parser = [[f seq:@[[f zeroOrOne:not],[f firstOf:@[parens, baseExpr]], [f zeroOrOne:[f seq:@[andOr, exprList]]]]] onMatch:^ParserResult*(ArrayParserResult*r) {
        Expr *expr = r.child[1].val;
        if (![r childIsNull:2]) {
            ArrayParserResult *rhs = (ArrayParserResult *)r.child[2];
            PositionedString *op = [rhs.child[0] posString];
            Expr *right = rhs.child[1].val;
            expr = [OpAndOrExpr left:expr op:op right:right loc:NSUnionRange(r.child[1].loc, r.child[2].loc)];
        }
        if (![r childIsNull:0]) {
            expr = [NotExpr expr:expr loc:r.loc];
        }
        r.val = expr;
        return r;
    }];
    ZKParser *where = [f zeroOrOne:[[f seq:@[ws ,[f eq:@"WHERE"], ws, exprList]] onMatch:pick(3)]];
    
    /// FILTER SCOPE
    ZKParser *filterScope = [f zeroOrOne:[[f seq:@[ws, [f eq:@"USING"], ws, [f eq:@"SCOPE"], ws, ident]] onMatch:pick(5)]];

    
    /// ORDER BY
    ZKParser *asc  = [[f eq:@"ASC"] onMatch:setValue(@YES)];
    ZKParser *desc = [[f eq:@"DESC"] onMatch:setValue(@NO)];
    ZKParser *ascDesc = [[f seq:@[ws, [f oneOf:@[asc,desc]]]] onMatch:pick(1)];
    ZKParser *nulls = [[f seq:@[ws, [f eq:@"NULLS"], ws,
                                [f oneOf:@[[[f eq:@"FIRST"] onMatch:setValue(@(NullsFirst))], [[f eq:@"LAST"] onMatch:setValue(@(NullsLast))]]]]]
                     onMatch:pick(3)];
    ZKParser *orderByField = [[f seq:@[field, [f zeroOrOne:ascDesc], [f zeroOrOne:nulls]]] onMatch:^ParserResult*(ArrayParserResult*m) {
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
    ZKParser *orderByFields = [f zeroOrOne:[[f seq:@[ws, [f eq:@"ORDER"], ws, [f eq:@"BY"], ws, [f oneOrMore:orderByField separator:commaSep]]] onMatch:^ParserResult*(ArrayParserResult*r) {
        
        // loc for OrderBys is just the ORDER BY keyword. TODO, we probably don't want that.
        r.val = [OrderBys by:[r.child[5].val valueForKey:@"val"] loc:NSUnionRange(r.child[1].loc, r.child[3].loc)];
        return r;
    }]];

    /// SELECT
    ZKParser* selectStmt = [[f seq:@[[f eq:@"SELECT"], ws, selectExprs, ws, [f eq:@"FROM"], ws, objectRefs, filterScope, where, orderByFields]] onMatch:^ParserResult*(ArrayParserResult*m) {
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


