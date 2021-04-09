//
//  Soql.m
//  ZKParser
//
//  Created by Simon Fell on 4/8/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import "Soql.h"
#import "ZKParser.h"

void append(NSMutableString *q, NSArray *a) {
    BOOL first = YES;
    for (id item in a) {
        if (!first) {
            [q appendString:@","];
        }
        [q appendString:[item toSoql]];
        first = NO;
    }
};

@implementation PositionedString
+(instancetype)string:(NSString *)s loc:(NSRange)loc {
    PositionedString *r = [PositionedString new];
    r.val = s;
    r.loc = loc;
    return r;
}
+(instancetype)from:(ParserResult*)r {
    assert([r.val isKindOfClass:[NSString class]]);
    return [self string:(NSString*)r.val loc:r.loc];
}
+(NSArray<PositionedString*>*)fromArray:(NSArray<ParserResult*>*)r {
    NSMutableArray<PositionedString*> *out = [NSMutableArray arrayWithCapacity:r.count];
    for (ParserResult *item in r) {
        [out addObject:[PositionedString from:item]];
    }
    return out;
}

-(NSString*)toSoql {
    return self.val;
}
@end

@implementation ParserResult (Soql)
-(PositionedString*)posString {
    return [PositionedString from:self];
}
@end

@implementation SelectField
+(instancetype)name:(NSArray<PositionedString*>*)n loc:(NSRange)loc {
    SelectField *f = [SelectField new];
    f.name = n;
    f.loc = loc;
    return f;
}
-(NSString *)toSoql {
    return [[self.name valueForKey:@"toSoql"] componentsJoinedByString:@"."];
}
@end

@implementation SelectFunc
+(instancetype) name:(PositionedString*)n args:(NSArray<PositionedString*>*)args {
    SelectFunc *f = [SelectFunc new];
    f.name = n;
    f.args = args;
    return f;
}
-(NSString *)toSoql {
    return [NSString stringWithFormat:@"%@(%@)", self.name.toSoql, [self.args valueForKey:@"toSoql"]];
}
@end


@implementation SObjectRef
+(instancetype) name:(PositionedString *)n alias:(PositionedString *)a loc:(NSRange)loc {
    SObjectRef *r = [SObjectRef new];
    r.name = n;
    r.alias = a;
    r.loc = loc;
    return r;
}
-(NSString *)toSoql {
    if (self.alias == nil) {
        return self.name.toSoql;
    }
    return [NSString stringWithFormat:@"%@ %@", self.name.toSoql, self.alias.toSoql];
}
@end

@implementation OrderBys
+(instancetype) items:(NSArray<OrderBy*>*)items loc:(NSRange)loc {
    OrderBys *r = [OrderBys new];
    r.items = items;
    r.loc = loc;
    return r;
}
-(NSString*)toSoql {
    if (self.items.count == 0) {
        return @"";
    }
    NSMutableString *q = [NSMutableString stringWithCapacity:64];
    [q appendString:@" ORDER BY "];
    append(q, self.items);
    return q;
}

@end

@implementation OrderBy
+(instancetype) field:(SelectField*)f asc:(BOOL)asc nulls:(NSInteger)n loc:(NSRange)loc {
    OrderBy *g = [OrderBy new];
    g.field = f;
    g.asc = asc;
    g.nulls = n;
    g.loc = loc;
    return g;
}
-(NSString *)toSoql {
    NSString *nulls = @"";
    if (self.nulls == NullsLast) {
        nulls = @" NULLS LAST";
    } else if (self.nulls == NullsFirst) {
        nulls = @" NULLS FIRST";
    }
    return [NSString stringWithFormat:@"%@ %@%@", self.field.toSoql, self.asc ? @"ASC" : @"DESC", nulls];
}
@end

@implementation SelectQuery
-(instancetype)init {
    self = [super init];
    self.limit = NSIntegerMax;
    return self;
}

-(NSString *)toSoql {
    NSMutableString *q = [NSMutableString stringWithCapacity:256];
    [q appendString:@"SELECT "];

    append(q, self.selectExprs);
    [q appendFormat:@" FROM %@%@", self.from.toSoql, self.orderBy.toSoql];
    if (self.limit < NSIntegerMax) {
        [q appendFormat:@" LIMIT %lu", self.limit];
    }
    if (self.offset > 0) {
        [q appendFormat:@" OFFSET %lu", self.offset];
    }
    return q;
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

@implementation SoqlParser

-(SelectQuery*)parse:(NSString *)input error:(NSError**)err {
    ZKParserFactory *f = [ZKParserFactory new];
    NSSet<NSString*>* keywords = [NSSet setWithArray:@[@"from",@"where",@"order",@"by",@"having",@"limit",@"offset",@"group by",@"using",@"scope"]];
    BOOL(^ignoreKeywords)(NSObject*) = ^BOOL(NSObject *v) {
        NSString *s = (NSString *)v;
        return [keywords containsObject:[s lowercaseString]];
    };
    f.defaultCaseSensitivity = CaseInsensitive;
    ZKParser* ws = [f whitespace];
    ZKParser* maybeWs = [f maybeWhitespace];
    ZKParser* commaSep = [f seq:@[maybeWs, [f skip:@","], maybeWs]];
    ZKParser* ident = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"]
                               name:@"identifier"
                                min:1];

    ZKParser* field = [[f oneOrMore:ident separator:[f eq:@"."]] onMatch:^ParserResult *(ParserResult *m) {
        m.val = [SelectField name:[PositionedString fromArray:m.val] loc:m.loc];
        return m;
    }];
    ZKParser* func = [f seq:@[ident,
                              maybeWs,
                              [f skip:@"("],
                              maybeWs,
                              field,
                              maybeWs,
                              [f skip:@")"],
                              [f zeroOrOne:[[ws then:@[ident]] onMatch:pick(1)] ignoring:ignoreKeywords]
                            ] onMatch:^ParserResult*(ParserResult*m) {
        m.val = [SelectFunc name:[m.val[0] posString] args:@[[m.val[4] posString]]];
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
        s.val = [SelectFunc name:[s posString] args:@[]];
        return s;
    }]]];

    ZKParser *objectRef = [f seq:@[ident, [f zeroOrOne:[f seq:@[ws, ident] onMatch:pick(1)] ignoring:ignoreKeywords]]
                         onMatch:^ParserResult *(ParserResult *m) {
        NSArray<ParserResult*>* c = (NSArray<ParserResult*>*)m.val;
        m.val = [SObjectRef name:[c[0] posString] alias:[c[1] val] == [NSNull null] ? nil : [c[1] posString] loc:m.loc];
        return m;
    }];
    ZKParser *objectRefs = [f oneOrMore:objectRef separator:commaSep];
    
    ZKParser *filterScope = [f zeroOrOne:[[ws then:@[[f eq:@"USING"], ws, [f eq:@"SCOPE"], ws, ident]] onMatch:pick(6)]];

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
        OrderBys *o = [OrderBys new];
        o.items = [c[5].val valueForKey:@"val"];
        o.loc = NSUnionRange(c[1].loc, c[3].loc);
        r.val = o;
        return r;
    }]];

    ZKParser* selectStmt = [f seq:@[[f eq:@"SELECT"], ws, selectExprs, ws, [f eq:@"FROM"], ws, objectRefs, filterScope, orderByFields] onMatch:^ParserResult*(ParserResult*m) {
        NSArray<ParserResult*>* c = (NSArray<ParserResult*>*)m.val;
        SelectQuery *q = [SelectQuery new];
        q.selectExprs = c[2].val;
        q.from = [c[6].val[0] val];
        q.orderBy = c[8].val;
        m.val= q;
        return m;
    }];

    return (SelectQuery*)[input parse:selectStmt error:err].val;
}

@end
