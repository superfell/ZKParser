//
//  Soql.m
//  ZKParser
//
//  Created by Simon Fell on 4/8/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import "Soql.h"
#import "ZKParser.h"

@implementation SelectField
+(instancetype)name:(NSArray<NSString*>*)n {
    SelectField *f = [SelectField new];
    f.name = n;
    return f;
}
-(NSString *)description {
    return [self.name componentsJoinedByString:@"."];
}
@end

@implementation SelectFunc
+(instancetype) name:(NSString*)n args:(NSArray*)args {
    SelectFunc *f = [SelectFunc new];
    f.name = n;
    f.args = args;
    return f;
}
-(NSString *)description {
    return [NSString stringWithFormat:@"%@(%@)", self.name, self.args];
}
@end


@implementation SObjectRef
+(instancetype) name:(NSString *)n alias:(NSString *)a {
    SObjectRef *r = [SObjectRef new];
    r.name = n;
    r.alias = a;
    return r;
}
-(NSString *)description {
    if (self.alias == nil) {
        return self.name;
    }
    return [NSString stringWithFormat:@"%@ %@", self.name, self.alias];
}
@end

@implementation OrderBy
+(instancetype) field:(NSArray*)f asc:(BOOL)asc nulls:(NSInteger)n {
    OrderBy *g = [OrderBy new];
    g.field = f;
    g.asc = asc;
    g.nulls = n;
    return g;
}
-(NSString *)description {
    NSString *nulls = @"";
    if (self.nulls == NullsLast) {
        nulls = @" NULLS LAST";
    } else if (self.nulls == NullsFirst) {
        nulls = @" NULLS FIRST";
    }
    return [NSString stringWithFormat:@"%@ %@%@", self.field, self.asc ? @"ASC" : @"DESC", nulls];
}
@end

@implementation SelectQuery
-(instancetype)init {
    self = [super init];
    self.limit = NSIntegerMax;
    return self;
}

-(NSString *)description {
    NSMutableString *q = [NSMutableString stringWithCapacity:256];
    [q appendString:@"SELECT "];
    void(^append)(NSArray*) = ^void(NSArray *a) {
        BOOL first = YES;
        for (NSObject *item in a) {
            if (!first) {
                [q appendString:@","];
            }
            [q appendString:[item description]];
            first = NO;
        }
    };
    append(self.selectExprs);
    [q appendFormat:@" FROM %@", self.from.description];
    if (self.orderBy.count > 0) {
        [q appendString:@" ORDER BY "];
        append(self.orderBy);
    }
    if (self.limit < NSIntegerMax) {
        [q appendFormat:@" LIMIT %lu", self.limit];
    }
    if (self.offset > 0) {
        [q appendFormat:@" OFFSET %lu", self.offset];
    }
    return q;
}
@end

typedef NSObject*(^arrayBlock)(NSArray*);

arrayBlock pick(NSUInteger idx) {
    return ^NSObject *(NSArray *m) {
        return m[idx];
    };
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

    ZKParser* field = [[f oneOrMore:ident separator:[f eq:@"."]] onMatch:^NSObject *(NSArray *m) {
        return [SelectField name:m];
    }];
    ZKParser* func = [f seq:@[ident,
                              maybeWs,
                              [f skip:@"("],
                              maybeWs,
                              field,
                              maybeWs,
                              [f skip:@")"],
                              [f zeroOrOne:[[ws then:@[ident]] onMatch:pick(1)] ignoring:ignoreKeywords]] onMatch:^NSObject*(NSArray *m) {
        return [SelectFunc name:m[0] args:@[m[4]]];
    }];
    
    ZKParser* selectExpr = [field or:@[func]];
    ZKParser* selectExprs = [f oneOrMore:selectExpr separator:commaSep];
    selectExprs = [selectExprs or:@[[f exactly:@"count()" case:CaseInsensitive onMatch:^NSObject *(NSString *s) {
        return [SelectFunc name:@"count" args:@[]];
    }]]];

    ZKParser *objectRef = [f seq:@[ident, [f zeroOrOne:[f seq:@[ws, ident] onMatch:pick(1)] ignoring:ignoreKeywords]] onMatch:^NSObject *(NSArray *m) {
        return [SObjectRef name:m[0] alias:m[1] == [NSNull null] ? nil : m[1]];
    }];
    ZKParser *objectRefs = [f oneOrMore:objectRef separator:commaSep];
    
    ZKParser *filterScope = [f zeroOrOne:[[ws then:@[[f eq:@"USING"], ws, [f eq:@"SCOPE"], ws, ident]] onMatch:pick(6)]];
    
    ZKParser *ascDesc = [f seq:@[ws, [f oneOf:@[[f eq:@"ASC"],[f eq:@"DESC"]]]] onMatch:pick(1)];
    ZKParser *nulls = [f seq:@[ws, [f eq:@"NULLS"], ws, [f oneOf:@[[f eq:@"FIRST"], [f eq:@"LAST"]]]]];
    ZKParser *orderByField = [f seq:@[field, [f zeroOrOne:ascDesc], [f zeroOrOne:nulls]] onMatch:^NSObject*(NSArray*m) {
        BOOL asc = YES;
        NSInteger nulls = NullsDefault;
        if (m[1] != [NSNull null]) {
            if ([[m[1] lowercaseString] isEqualToString:@"desc"]) {
                asc = NO;
            }
        }
        if (m[2] != [NSNull null]) {
            NSString *n = [m[2][3] lowercaseString];
            if ([n isEqualToString:@"first"]) {
                nulls = NullsFirst;
            } else if ([n isEqualToString:@"last"]) {
                nulls = NullsLast;
            }
        }
        return [OrderBy field:m[0] asc:asc nulls:nulls];
    }];
    ZKParser *orderByFields = [f zeroOrOne:[f seq:@[ws,[f skip:@"ORDER"],ws,[f skip:@"BY"],ws,[f oneOrMore:orderByField separator:commaSep]] onMatch:pick(5)]];

    ZKParser* selectStmt = [f seq:@[[f eq:@"SELECT"], ws, selectExprs, ws, [f eq:@"FROM"], ws, objectRefs, filterScope, orderByFields] onMatch:^NSObject*(NSArray*m) {
        SelectQuery *q = [SelectQuery new];
        q.selectExprs = m[2];
        q.from = m[6][0];
        q.orderBy = m[8];
        return q;
    }];

    return (SelectQuery*)[input parse:selectStmt error:err];
}

@end
