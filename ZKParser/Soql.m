//
//  Soql.m
//  ZKParser
//
//  Created by Simon Fell on 4/8/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import "Soql.h"
#import "ZKParser.h"

void append_sep(NSMutableString *q, NSArray *a, NSString *sep) {
    BOOL first = YES;
    for (id item in a) {
        if (!first) {
            [q appendString:sep];
        }
        [item appendSoql:q];
        first = NO;
    }
};

void append(NSMutableString *q, NSArray *a) {
    append_sep(q,a,@",");
}

@implementation AstNode
-(NSString*)toSoql {
    NSMutableString *s = [NSMutableString stringWithCapacity:256];
    [self appendSoql:s];
    return s;
}
-(void)appendSoql:(NSMutableString*)dest {
    [dest appendFormat:@"[TODO on %@]", self.className];
}

@end

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

-(void)appendSoql:(NSMutableString*)dest {
    [dest appendString:self.val];
}
-(NSInteger)length {
    return self.val.length;
}
@end

@implementation Expr
@end

@implementation SelectField
+(instancetype)name:(NSArray<PositionedString*>*)n loc:(NSRange)loc {
    return [self name:n alias:nil loc:loc];
}
+(instancetype)name:(NSArray<PositionedString*>*)n alias:(PositionedString*)alias loc:(NSRange)loc {
    SelectField *f = [SelectField new];
    f.name = n;
    f.alias = alias;
    f.loc = loc;
    return f;
}
-(void)appendSoql:(NSMutableString*)dest {
    append_sep(dest, self.name, @".");
    if (self.alias.length > 0) {
        [dest appendString:@" "];
        [self.alias appendSoql:dest];
    }
}
@end

@implementation SelectFunc
+(instancetype) name:(PositionedString*)n args:(NSArray<SelectField*>*)args alias:(PositionedString*)alias loc:(NSRange)loc {
    SelectFunc *f = [SelectFunc new];
    f.name = n;
    f.args = args;
    f.alias = alias;
    f.loc = loc;
    return f;
}
-(void)appendSoql:(NSMutableString*)dest {
    [self.name appendSoql:dest];
    [dest appendString:@"("];
    append(dest, self.args);
    [dest appendString:@")"];
    if (self.alias.length > 0) {
        [dest appendString:@" "];
        [self.alias appendSoql:dest];
    }
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
-(void)appendSoql:(NSMutableString*)dest {
    [self.name appendSoql:dest];
    if (self.alias.length > 0) {
        [dest appendString:@" "];
        [self.alias appendSoql:dest];
    }
}
@end

@implementation From
+(instancetype) sobject:(SObjectRef*)o related:(NSArray<SelectField*>*)r loc:(NSRange)loc {
    From *f = [From new];
    f.sobject = o;
    f.relatedObjects = r;
    f.loc = loc;
    return f;
}
-(void)appendSoql:(NSMutableString*)dest {
    [dest appendString:@" FROM "];
    [self.sobject appendSoql:dest];
    if (self.relatedObjects.count > 0) {
        [dest appendString:@","];
        append(dest, self.relatedObjects);
    }
}
@end

@implementation LiteralValue
+(instancetype)withValue:(NSObject *)val type:(LiteralType)t loc:(NSRange)loc {
    LiteralValue *v = [self new];
    v.val = val;
    v.type = t;
    v.loc = loc;
    return v;
}

-(void)appendSoql:(NSMutableString *)dest {
    switch (self.type) {
        case LTString:
            [dest appendString:@"'"];
            [(PositionedString*)self.val appendSoql:dest];
            [dest appendString:@"'"];
            break;
        case LTNull:
            [dest appendString:@"NULL"];
            break;
        case LTBool:
            [dest appendString:[(NSNumber*)self.val boolValue] ? @"TRUE": @"FALSE"];
            break;
        case LTNumber:
            [dest appendFormat:@"%@", self.val];
            break;
        case LTToken:
            [dest appendString:[(NSString*)self.val uppercaseString]];
            break;
        default:
            NSAssert(false, @"unknown type in LiteralValue");
    }
}

@end

@implementation ComparisonExpr
+(instancetype) left:(Expr*)left op:(PositionedString*)op right:(LiteralValue*)right loc:(NSRange)loc {
    ComparisonExpr *e = [self new];
    e.left = left;
    e.op = op;
    e.op.val = [op.val uppercaseString];
    e.right = right;
    e.loc = loc;
    return e;
}
-(void)appendSoql:(NSMutableString *)dest {
    [self.left appendSoql:dest];
    [self.op appendSoql:dest];
    [self.right appendSoql:dest];
}
@end

@implementation OpAndOrExpr
+(instancetype) left:(Expr*)left op:(PositionedString*)op right:(Expr*)right loc:(NSRange)loc {
    OpAndOrExpr *e = [self new];
    e.leftExpr = left;
    e.op = op;
    e.op.val = [op.val uppercaseString];
    e.rightExpr = right;
    e.loc = loc;
    return e;
}

-(void)appendSoql:(NSMutableString *)dest {
    [dest appendString:@"("];
    [self.leftExpr appendSoql:dest];
    [dest appendString:@" "];
    [self.op appendSoql:dest];
    [dest appendString:@" "];
    [self.rightExpr appendSoql:dest];
    [dest appendString:@")"];
}

@end

@implementation OrderBys
+(instancetype) by:(NSArray<OrderBy*>*)items loc:(NSRange)loc {
    OrderBys *r = [OrderBys new];
    r.items = items;
    r.loc = loc;
    return r;
}
-(void)appendSoql:(NSMutableString*)dest {
    if (self.items.count == 0) {
        return;
    }
    [dest appendString:@" ORDER BY "];
    append(dest, self.items);
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
-(void)appendSoql:(NSMutableString*)dest {
    [self.field appendSoql:dest];
    [dest appendString:self.asc ? @" ASC": @" DESC"];
    if (self.nulls == NullsLast) {
        [dest appendString:@" NULLS LAST"];
    } else if (self.nulls == NullsFirst) {
        [dest appendString:@" NULLS FIRST"];
    }
}
@end

@implementation SelectQuery
-(instancetype)init {
    self = [super init];
    self.limit = NSIntegerMax;
    return self;
}

-(void)appendSoql:(NSMutableString*)dest {
    [dest appendString:@"SELECT "];

    append(dest, self.selectExprs);
    [self.from appendSoql:dest];
    if (self.filterScope.val.length > 0) {
        [dest appendFormat:@" USING SCOPE %@", self.filterScope.val];
    }
    if (self.where != nil) {
        [dest appendString:@" WHERE "];
        [self.where appendSoql:dest];
    }
    [self.orderBy appendSoql:dest];
    if (self.limit < NSIntegerMax) {
        [dest appendFormat:@" LIMIT %lu", self.limit];
    }
    if (self.offset > 0) {
        [dest appendFormat:@" OFFSET %lu", self.offset];
    }
}
@end

