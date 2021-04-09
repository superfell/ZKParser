//
//  SoqlTests.m
//  ZKParser
//
//  Created by Simon Fell on 4/8/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <XCTest/XCTest.h>

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

@end
