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

@end
