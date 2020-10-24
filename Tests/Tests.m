//
//  Tests.m
//  Tests
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ZKParser.h"

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(void)testExactMatch {
    ZKParser p = [ZKParserFactory exactly:@"Bob" onMatch:^NSObject *(NSString *m) {
        XCTAssertEqualObjects(m, @"Bob");
        return @"Alice";
    }];
    NSObject *r = [ZKParserFactory parse:p input:@"Bob"];
    XCTAssertEqualObjects(r,  @"Alice");
    XCTAssertNil([ZKParserFactory parse:p input:@"Eve"]);
    XCTAssertNil([ZKParserFactory parse:p input:@"Bo"]);
    XCTAssertNil([ZKParserFactory parse:p input:@"Boc"]);
    XCTAssertNil([ZKParserFactory parse:p input:@"Alice"]);
}

-(void)testOneOf {
    ZKParser bob = [ZKParserFactory exactly:@"Bob" onMatch:^NSObject *(NSString *m) {
        return @"B";
    }];
    ZKParser eve = [ZKParserFactory exactly:@"Eve" onMatch:^NSObject *(NSString *m) {
        return @"E";
    }];
    ZKParser bobby = [ZKParserFactory exactly:@"Bobby" onMatch:^NSObject *(NSString *m) {
        return @"BB";
    }];
    ZKParser n = [ZKParserFactory oneOf:@[bobby,bob,eve]];
    XCTAssertEqualObjects(@"B", [ZKParserFactory parse:n input:@"Bob"]);
    XCTAssertEqualObjects(@"E", [ZKParserFactory parse:n input:@"Eve"]);
    XCTAssertEqualObjects(@"BB", [ZKParserFactory parse:n input:@"Bobby"]);
    XCTAssertNil([ZKParserFactory parse:n input:@"Alice"]);
}

-(void)testSeq {
    ZKParser bob = [ZKParserFactory exactly:@"Bob" onMatch:^NSObject *(NSString *m) {
        return @"B";
    }];
    ZKParser eve = [ZKParserFactory exactly:@"Eve" onMatch:^NSObject *(NSString *m) {
        return @"E";
    }];
    ZKParser bobby = [ZKParserFactory exactly:@"Bobby" onMatch:^NSObject *(NSString *m) {
        return @"BB";
    }];
    ZKParser n = [ZKParserFactory seq:@[bob,eve,bobby]];
    NSObject *exp = @[@"B",@"E",@"BB"];
    XCTAssertEqualObjects(exp, [ZKParserFactory parse:n input:@"BobEveBobby"]);
    XCTAssertNil([ZKParserFactory parse:n input:@"BobEveBobbx"]);
    XCTAssertNil([ZKParserFactory parse:n input:@"AliceBobEveBobby"]);
}

-(void)testWhitespace {
    ZKParser ws = [ZKParserFactory whitespace];
    ZKParserInput *i = [ZKParserInput withInput:@" Hello"];
    ws(i);
    XCTAssertEqualObjects(@"Hello", i.value);
}

-(void)testOneOrMore {
    ZKParser bob = [ZKParserFactory exactly:@"Bob" onMatch:^NSObject *(NSString *m) {
        return @"B";
    }];
    ZKParser bobs = [ZKParserFactory oneOrMore:bob];
    NSObject *exp = @[@"B",@"B",@"B"];
    XCTAssertEqualObjects(exp, bobs([ZKParserInput withInput:@"BobBobBob"]));
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
