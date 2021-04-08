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

-(void)testBasic {
    SoqlParser *p = [SoqlParser new];
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id,name from contact order by name desc" error:&err];
    XCTAssertEqualObjects([res description], @"SELECT id,name FROM contact ORDER BY name DESC");
    XCTAssertNil(err);
}

@end
