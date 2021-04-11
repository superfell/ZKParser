//
//  SoqlTests.m
//  ZKParser
//
//  Created by Simon Fell on 4/8/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "SoqlParser.h"
#import "Soql.h"

@interface SoqlTests : XCTestCase

@end

NSString *spaces(NSInteger count) {
    NSMutableString *s = [NSMutableString stringWithCapacity:count];
    while (count > 0) {
        [s appendString:@" "];
        count--;
    }
    return s;
}

void assertStringsEq(NSString *act, NSString *exp) {
    if ([exp isEqualToString:act]) {
        return;
    }
    NSString *same = [exp commonPrefixWithString:act options:(NSLiteralSearch)];
    NSString *msg = [NSString stringWithFormat:@"Strings don't match starting at pos %lu\n%@\n%@%@\n",
                     same.length, exp, spaces(same.length), [act substringFromIndex:same.length]];
    XCTFail("%@", msg);
}

@implementation SoqlTests

SoqlParser *p = nil;

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    p = [[SoqlParser alloc] init];
}

-(void)testSelectExprs {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id,name from contact order by name desc" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT id,name FROM contact ORDER BY name DESC");
    NSRange oloc = res.orderBy.loc;
    XCTAssertEqual(28, oloc.location);
    XCTAssertEqual(8, oloc.length);
    XCTAssertNil(err);
    
    res = [p parse:@"SELECT max(createdDate) from account" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT max(createdDate) FROM account");
    XCTAssertNil(err);

    res = [p parse:@"SELECT max(createdBy.createdDate, createdDate) from account" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT max(createdBy.createdDate,createdDate) FROM account");
    XCTAssertNil(err);

    res = [p parse:@"SELECT count() from account" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT count() FROM account");
    XCTAssertNil(err);

    // count() is special and can only appear on its own (unlike count(some_field))
    res = [p parse:@"SELECT count(), id from account" error:&err];
    XCTAssertEqualObjects(@"expecting whitespace at position 15", err.localizedDescription);
}

-(void)testFrom {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select count(id) from contacts c, c.account a" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT count(id) FROM contacts c,c.account a");
    XCTAssertNil(err);

    res = [p parse:@"select count(id) x from contacts, c.account a" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT count(id) x FROM contacts,c.account a");
    XCTAssertNil(err);
}

-(void)testOrderBy {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact order by name desc, city asc nulls last" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT id FROM contact ORDER BY name DESC,city ASC NULLS LAST");
    XCTAssertNil(err);
    
    res = [p parse:@"select id from contact order by name desc, city nulls first" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT id FROM contact ORDER BY name DESC,city ASC NULLS FIRST");
    XCTAssertNil(err);
}

-(void)testFilterScope {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact Using  Scope delegated" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT id FROM contact USING SCOPE delegated");
    XCTAssertNil(err);
}

-(void)testParenWhere {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact where (name='bob')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE name='bob'");
    XCTAssertNil(err);
}

-(void)testWhereParenTerm {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact where (name = 'bob') or (name='alice' and city='SF')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name='bob' OR (name='alice' AND city='SF'))");
    XCTAssertNil(err);
}

-(void)testWhereLiteralTypes {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact where name='bob'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE name='bob'");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where city!='o\\'hare'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE city!='o\\'hare'");
    XCTAssertNil(err);

    [p parse:@"select id from contact where city!='o'hare'" error:&err];
    assertStringsEq(err.localizedDescription, @"Unexpected input 'hare'' at position 39");
    [p parse:@"select id from contact where city!='SF" error:&err];
    assertStringsEq(err.localizedDescription, @"Unexpected input ' where city!='SF' at position 23");

    res = [p parse:@"select id from contact where city!=null" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE city!=NULL");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ishot=true" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot=TRUE");
    XCTAssertNil(err);
    res = [p parse:@"select id from contact where ishot= false" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot=FALSE");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ishot > -10" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot>-10");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ishot > .5" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot>0.5");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ishot > YESTERDAY" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot>YESTERDAY");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ishot < LAST_N_MONTHS:3" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot<LAST_N_MONTHS:3");
    XCTAssertNil(err);
}

-(void)testWhere {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact where name = 'bob'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE name='bob'");
    XCTAssertNil(err);
    
    res = [p parse:@"select id from contact where name = 'bob' or name='alice'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name='bob' OR name='alice')");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where name = 'bob' or name='alice' and city='SF'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name='bob' OR (name='alice' AND city='SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where (name='bob')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE name='bob'");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where (name = 'bob' or name='alice' and city='SF')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name='bob' OR (name='alice' AND city='SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ( name = 'bob' or name='alice' and city='SF'  )" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name='bob' OR (name='alice' AND city='SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where name = 'bob' or (name='alice' and city='SF')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name='bob' OR (name='alice' AND city='SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where (name = 'bob' or name='alice') and city='SF'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ((name='bob' OR name='alice') AND city='SF')");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where (name = 'bob') or (name='alice' and city='SF')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name='bob' OR (name='alice' AND city='SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where (name = 'bob') or (((name='alice' and city='SF')))" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name='bob' OR (name='alice' AND city='SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ((name = 'bob' or name='alice') and city='SF')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ((name='bob' OR name='alice') AND city='SF')");
    XCTAssertNil(err);
}

@end
