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

@implementation AstNode
-(NSString*)toSoql {
    return [NSString stringWithFormat:@"[TODO on %@]", self.className];
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

-(NSString*)toSoql {
    return self.val;
}
-(NSInteger)length {
    return self.val.length;
}
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
-(NSString *)toSoql {
    NSMutableString *f = [NSMutableString stringWithCapacity:32];
    [f appendString:[[self.name valueForKey:@"toSoql"] componentsJoinedByString:@"."]];
    if (self.alias.length > 0) {
        [f appendString:@" "];
        [f appendString:self.alias.val];
    }
    return f;
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
-(NSString *)toSoql {
    NSMutableString *s = [NSMutableString stringWithCapacity:32];
    [s appendString:self.name.toSoql];
    [s appendString:@"("];
    append(s, self.args);
    [s appendString:@")"];
    if (self.alias.length > 0) {
        [s appendString:@" "];
        [s appendString:self.alias.val];
    }
    return s;
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
    if (self.alias.val.length == 0) {
        return self.name.toSoql;
    }
    return [NSString stringWithFormat:@"%@ %@", self.name.toSoql, self.alias.toSoql];
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
-(NSString *)toSoql {
    NSMutableString* q = [NSMutableString stringWithCapacity:32];
    [q appendFormat:@"FROM %@", self.sobject.toSoql];
    if (self.relatedObjects.count > 0) {
        [q appendString:@","];
        append(q, self.relatedObjects);
    }
    return q;
}

@end
@implementation OrderBys
+(instancetype) by:(NSArray<OrderBy*>*)items loc:(NSRange)loc {
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
    [q appendFormat:@" %@", self.from.toSoql];
    if (self.filterScope.val.length > 0) {
        [q appendFormat:@" USING SCOPE %@", self.filterScope.val];
    }
    [q appendString:self.orderBy.toSoql];
    if (self.limit < NSIntegerMax) {
        [q appendFormat:@" LIMIT %lu", self.limit];
    }
    if (self.offset > 0) {
        [q appendFormat:@" OFFSET %lu", self.offset];
    }
    return q;
}
@end

