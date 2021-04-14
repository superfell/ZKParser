//
//  SoqlParser.m
//  ZKParser
//
//  Created by Simon Fell on 4/9/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import "SoqlParser.h"
#import "Soql.h"
#import "ZKBaseParser.h"

@implementation ParserResult (Soql)
-(PositionedString*)posString {
    return [PositionedString from:self];
}
@end

@interface SoqlParser()
@property (strong,nonatomic) ZKBaseParser *parser;
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
        NSRange overalRng = NSMakeRange(start,input.pos-start);
        NSRange matchRng = NSMakeRange(start+1,input.pos-start-2);
        Expr *expr = [LiteralValue withValue:[PositionedString string:[input valueOfRange:matchRng] loc:matchRng]
                                        type:LTString
                                         loc:overalRng];
        return [ParserResult result:expr loc:overalRng];
    }];
}

-(ZKBaseParser*)literalValue:(ZKParserFactory*)f {
    ZKBaseParser *literalStringValue = [self literalStringValue:f];
    ZKBaseParser *literalNullValue = [[f eq:@"null"] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:[NSNull null] type:LTNull loc:r.loc];
        return r;
    }];
    ZKBaseParser *literalTrueValue = [[f eq:@"true"] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:@TRUE type:LTBool loc:r.loc];
        return r;
    }];
    ZKBaseParser *literalFalseValue = [[f eq:@"false"] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:@FALSE type:LTBool loc:r.loc];
        return r;
    }];
    ZKBaseParser *literalNumberValue = [[f decimalNumber] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:r.val type:LTNumber loc:r.loc];
        return r;
    }];
    NSError *err = nil;
    NSRegularExpression *dateTime = [NSRegularExpression regularExpressionWithPattern:@"\\d\\d\\d\\d-\\d\\d-\\d\\d(?:T\\d\\d:\\d\\d:\\d\\d(?:Z|[+-]\\d\\d:\\d\\d))?"
                                                                              options:NSRegularExpressionCaseInsensitive
                                                                                error:&err];
    NSAssert(err == nil, @"failed to compile regex %@", err);
    NSISO8601DateFormatter *dfDateTime = [NSISO8601DateFormatter new];
    NSISO8601DateFormatter *dfDate = [NSISO8601DateFormatter new];
    dfDate.formatOptions = NSISO8601DateFormatWithFullDate | NSISO8601DateFormatWithDashSeparatorInDate;
    ZKBaseParser *literalDateTimeValue = [[f regex:dateTime name:@"date/time literal"] onMatch:^ParserResult *(ParserResult *r) {
        NSString *dt = r.val;
        if (dt.length == 10) {
            r.val = [LiteralValue withValue:[dfDate dateFromString:dt] type:LTDate loc:r.loc];
        } else {
            r.val = [LiteralValue withValue:[dfDateTime dateFromString:dt] type:LTDateTime loc:r.loc];
        }
        return r;
    }];
    NSRegularExpression *token = [NSRegularExpression regularExpressionWithPattern:@"[a-z]\\S*"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&err];
    NSAssert(err == nil, @"failed to compile regex %@", err);
    ZKBaseParser *literalToken = [[f regex:token name:@"named literal"] onMatch:^ParserResult *(ParserResult *r) {
        r.val = [LiteralValue withValue:r.val type:LTToken loc:r.loc];
        return r;
    }];
    ZKBaseParser *literalValue = [f oneOf:@[literalStringValue, literalNullValue, literalTrueValue, literalFalseValue, literalNumberValue, literalDateTimeValue, literalToken]];
    return literalValue;
}

-(ZKBaseParser*)buildParser {
    ZKParserFactory *f = [ZKParserFactory new];
    f.debugFile = @"/Users/simon/Github/ZKParser/typeof.debug";
    f.defaultCaseSensitivity = CaseInsensitive;

    ZKBaseParser* ws = [f characters:[NSCharacterSet whitespaceAndNewlineCharacterSet] name:@"whitespace" min:1];
    ZKBaseParser* maybeWs = [f characters:[NSCharacterSet whitespaceAndNewlineCharacterSet] name:@"whitespace" min:0];

    // constructs a seq parser for each whitespace separated token, e.g. given input "NULLS LAST" will generate
    // seq:"NULLS", ws, "LAST".
    ZKBaseParser*(^tokenSeq)(NSString *tokens) = ^ZKBaseParser*(NSString *t) {
        NSArray<NSString*>* tokens = [t componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSMutableArray *seq = [NSMutableArray arrayWithCapacity:tokens.count *2];
        NSEnumerator *e = [tokens objectEnumerator];
        [seq addObject:[f eq:[e nextObject]]];
        do {
            NSString *next = [e nextObject];
            if (next == nil) break;
            [seq addObject:ws];
            [seq addObject:[f eq:next]];
        } while(true);
        return [[f seq:seq] onMatch:setValue(t)];
    };
    
    // USING is not in the doc, but appears to not be allowed
    // ORDER & OFFSET are issues for our parser, but not the sfdc one.
    NSSet<NSString*>* keywords = [NSSet setWithArray:[@"ORDER OFFSET USING   AND ASC DESC EXCLUDES FIRST FROM GROUP HAVING IN INCLUDES LAST LIKE LIMIT NOT NULL NULLS OR SELECT WHERE WITH" componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    BOOL(^ignoreKeywords)(NSObject*) = ^BOOL(NSObject *v) {
        NSString *s = (NSString *)v;
        return [keywords containsObject:[s uppercaseString]];
    };
    ZKBaseParser* commaSep = [f seq:@[maybeWs, [f eq:@","], maybeWs]];
    ZKBaseParser* ident = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"]
                               name:@"identifier"
                                min:1];
    
    // SELECT LIST
    ZKParserRef *selectStmt = [f parserRef];
    ZKBaseParser *alias = [f zeroOrOne:[[f seq:@[ws, ident]] onMatch:pick(1)] ignoring:ignoreKeywords];
    ZKBaseParser* fieldOnly = [[f oneOrMore:ident separator:[f eq:@"."]] onMatch:^ParserResult *(ArrayParserResult *m) {
        m.val = [SelectField name:[PositionedString fromArray:m.val]
                            alias:nil
                              loc:m.loc];
        return m;
    }];
    fieldOnly.debugName = @"fieldOnly";
    ZKBaseParser* fieldAndAlias = [[f seq:@[[f oneOrMore:ident separator:[f eq:@"."]], alias]] onMatch:^ParserResult *(ArrayParserResult *m) {
        m.val = [SelectField name:[PositionedString fromArray:m.child[0].val]
                            alias:([m childIsNull:1] ? nil : [m.child[1] posString])
                              loc:m.loc];
        return m;
    }];
    fieldAndAlias.debugName = @"field";
    ZKParserRef *fieldOrFunc = [f parserRef];
    ZKBaseParser* func = [[f seq:@[ident,
                              maybeWs,
                              [f eq:@"("],
                              maybeWs,
                              [f oneOrMore:fieldOrFunc separator:commaSep],
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
    
    fieldOrFunc.parser = [f firstOf:@[func, fieldAndAlias]];
    ZKBaseParser *nestedSelectStmt = [[f seq:@[[f eq:@"("], selectStmt, [f eq:@")"]]] onMatch:^ParserResult*(ArrayParserResult*r) {
        SelectQuery *q = r.child[1].val;
        r.val = [NestedSelectQuery from:q];
        return r;
    }];
    ZKBaseParser *typeOfWhen = [[f seq:@[[f eq:@"WHEN"], ws, ident, ws, [f eq:@"THEN"], ws,
                                         [f oneOrMore:fieldOnly separator:commaSep]]] onMatch:^ParserResult *(ArrayParserResult *r) {
        PositionedString *obj = [r.child[2] posString];
        NSArray *fields = [r.child[6].val valueForKey:@"val"];
        r.val = [TypeOfWhen sobject:obj select:fields loc:r.loc];
        return r;
    }];
    ZKBaseParser *typeOfElse = [[f seq:@[[f eq:@"ELSE"], ws, [f oneOrMore:fieldOnly separator:commaSep]]] onMatch:pick(2)];
    ZKBaseParser *typeOf = [[f seq:@[
                                [f eq:@"TYPEOF"], ws,
                                ident, ws,
                                [f oneOrMore:typeOfWhen separator:ws], maybeWs,
                                [f zeroOrOne:typeOfElse], ws,
                                [f eq:@"END"]]] onMatch:^ParserResult *(ArrayParserResult *r) {
        TypeOf *t = [TypeOf new];
        t.relationship = [r.child[2] posString];
        t.whens = [r.child[4].val valueForKey:@"val"];
        t.elses = [r.child[6].val valueForKey:@"val"];
        t.loc = r.loc;
        r.val = t;
        return r;
    }];
    typeOfWhen.debugName = @"typeofWhen";
    typeOfElse.debugName = @"typeofElse";
    
    ZKBaseParser* selectExprs = [[f oneOrMore:[f firstOf:@[func, typeOf, fieldAndAlias, nestedSelectStmt]] separator:commaSep] onMatch:^ParserResult *(ArrayParserResult *r) {
        r.val = r.childVals;
        return r;
    }];
    ZKBaseParser *countOnly = [[f seq:@[[f eq:@"count"], maybeWs, [f eq:@"("], maybeWs, [f eq:@")"]]] onMatch:^ParserResult *(ArrayParserResult *r) {
        // Should we just let count() be handled by the regular func matcher? and not deal with the fact it can only
        // appear on its own.
        r.val =@[[SelectFunc name:[r.child[0] posString] args:@[] alias:nil loc:r.loc]];
        return r;
    }];
    selectExprs = [f oneOf:@[selectExprs, countOnly]];

    /// FROM
    ZKBaseParser *objectRef = [[f seq:@[ident, alias]] onMatch:^ParserResult *(ArrayParserResult *m) {
        m.val = [SObjectRef name:m.child[0].posString
                           alias:[m childIsNull:1] ? nil : m.child[1].posString
                             loc:m.loc];
        return m;
    }];
    ZKBaseParser *objectRefs = [[f seq:@[objectRef, [f zeroOrOne:
                                [[f seq:@[commaSep, [f oneOrMore:fieldAndAlias separator:commaSep]]] onMatch:pick(1)]]]]
                          onMatch:^ParserResult *(ArrayParserResult*r) {
        r.val = [From sobject:r.child[0].val
                      related:[r childIsNull:1] ? @[] : [r.child[1].val valueForKey:@"val"]
                          loc:r.loc];
        return r;
    }];
    
    /// WHERE
    ZKBaseParser *operator = [f oneOfTokens:@"< <= > >= = != LIKE"];
    ZKBaseParser *opIncExcl = [f oneOfTokens:@"INCLUDES EXCLUDES"];
    ZKBaseParser *opInNotIn = [f oneOf:@[[f eq:@"IN"], tokenSeq(@"NOT IN")]];
    ZKBaseParser *literalValue = [self literalValue:f];
    ZKBaseParser *literalStringList = [[f seq:@[    [f eq:@"("], maybeWs,
                                                [f oneOrMore:[self literalStringValue:f] separator:commaSep],
                                                maybeWs, [f eq:@")"]]]
                                   onMatch:^ParserResult*(ArrayParserResult*r) {
        NSArray* vals = [r.child[2].val valueForKey:@"val"];
        r.val = [LiteralValueArray withValues:vals loc:r.loc];
        return r;
    }];
    ZKBaseParser *operatorRHS = [f oneOf:@[
        [f seq:@[operator, maybeWs, literalValue]],
        [f seq:@[opIncExcl, maybeWs, literalStringList]],
        [f seq:@[opInNotIn, maybeWs, [f oneOf:@[literalStringList, nestedSelectStmt]]]]]];

    ZKBaseParser *baseExpr = [[f seq:@[fieldOrFunc, maybeWs, operatorRHS]] onMatch:^ParserResult *(ArrayParserResult *r) {
        ArrayParserResult *opRhs = (ArrayParserResult*)r.child[2];
        r.val = [ComparisonExpr left:r.child[0].val op:[opRhs.child[0] posString] right:opRhs.child[2].val loc:r.loc];
        return r;
    }];

    // use parserRef so that we can set up the recursive decent for (...)
    // be careful not to use oneOf with it as that will recurse infinitly because it checks all branches.
    ZKParserRef *exprList = [f parserRef];
    ZKBaseParser *parens = [[f seq:@[[f eq:@"("], maybeWs, exprList, maybeWs, [f eq:@")"]]] onMatch:pick(2)];
    ZKBaseParser *andOr = [[f seq:@[ws, [f oneOfTokens:@"AND OR"], ws]] onMatch:pick(1)];
    ZKBaseParser *not = [f seq:@[[f eq:@"NOT"], maybeWs]];
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
    ZKBaseParser *where = [f zeroOrOne:[[f seq:@[ws ,[f eq:@"WHERE"], ws, exprList]] onMatch:pick(3)]];
    
    /// FILTER SCOPE
    ZKBaseParser *filterScope = [f zeroOrOne:[[f seq:@[ws, [f eq:@"USING"], ws, [f eq:@"SCOPE"], ws, ident]] onMatch:pick(5)]];

    /// DATA CATEGORY
    ZKBaseParser *catList = [[f seq:@[[f eq:@"("], maybeWs, [f oneOrMore:ident separator:commaSep], maybeWs, [f eq:@")"]]] onMatch:pick(2)];
    ZKBaseParser *catFilterVal = [[f firstOf:@[catList, ident]] onMatch:^ParserResult *(ParserResult *r) {
        if ([r.val isKindOfClass:[NSArray class]]) {
            r.val = [r.val valueForKey:@"posString"];
        } else {
            r.val = [NSArray arrayWithObject:[r posString]];
        }
        return r;
    }];
    ZKBaseParser *catFilter = [[f seq:@[ident, ws, [f oneOfTokens:@"AT ABOVE BELOW ABOVE_OR_BELOW"], maybeWs, catFilterVal]] onMatch:^ParserResult*(ArrayParserResult*r) {
        r.val = [DataCategoryFilter filter:r.child[0].posString op:r.child[2].posString values:r.child[4].val loc:r.loc];
        return r;
    }];
    ZKBaseParser *withDataCat = [f zeroOrOne:[[f seq:@[ws, tokenSeq(@"WITH DATA CATEGORY"), ws,
                                                       [f oneOrMore:catFilter separator:[f seq:@[ws,[f eq:@"AND"],ws]]]]] onMatch:pick(3)]];
    
    
    /// ORDER BY
    ZKBaseParser *asc  = [[f eq:@"ASC"] onMatch:setValue(@YES)];
    ZKBaseParser *desc = [[f eq:@"DESC"] onMatch:setValue(@NO)];
    ZKBaseParser *ascDesc = [[f seq:@[ws, [f oneOf:@[asc,desc]]]] onMatch:pick(1)];
    ZKBaseParser *nulls = [[f seq:@[ws, [f eq:@"NULLS"], ws,
                                [f oneOf:@[[[f eq:@"FIRST"] onMatch:setValue(@(NullsFirst))], [[f eq:@"LAST"] onMatch:setValue(@(NullsLast))]]]]]
                     onMatch:pick(3)];
    ZKBaseParser *orderByField = [[f seq:@[fieldOnly, [f zeroOrOne:ascDesc], [f zeroOrOne:nulls]]] onMatch:^ParserResult*(ArrayParserResult*m) {
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
    ZKBaseParser *orderByFields = [f zeroOrOne:[[f seq:@[maybeWs, [f eq:@"ORDER"], ws, [f eq:@"BY"], ws, [f oneOrMore:orderByField separator:commaSep]]] onMatch:^ParserResult*(ArrayParserResult*r) {
        
        // loc for OrderBys is just the ORDER BY keyword. TODO, we probably don't want that.
        r.val = [OrderBys by:[r.child[5].val valueForKey:@"val"] loc:NSUnionRange(r.child[1].loc, r.child[3].loc)];
        return r;
    }]];

    /// SELECT
    selectStmt.parser = [[f seq:@[maybeWs, [f eq:@"SELECT"], ws, selectExprs, ws, [f eq:@"FROM"], ws, objectRefs, filterScope, where, withDataCat, orderByFields, maybeWs]] onMatch:^ParserResult*(ArrayParserResult*m) {
        SelectQuery *q = [SelectQuery new];
        q.selectExprs = m.child[3].val;
        q.from = m.child[7].val;
        q.filterScope = [m childIsNull:8] ? nil : [m.child[8] posString];
        q.where = [m childIsNull:9] ? nil : m.child[9].val;
        q.withDataCategory = [m childIsNull:10] ? nil : [m.child[10].val valueForKey:@"val"];
        q.orderBy = [m childIsNull:11] ? [OrderBys new] : m.child[11].val;
        m.val = q;
        q.loc = m.loc;
        return m;
    }];
    return selectStmt;
}


@end


