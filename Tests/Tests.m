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
    NSError *err = nil;
    NSObject *r = [ZKParserFactory parse:p input:@"Bob" error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects(r,  @"Alice");
    XCTAssertNil([ZKParserFactory parse:p input:@"Eve" error:&err]);
    XCTAssertNil(err);
    XCTAssertNil([ZKParserFactory parse:p input:@"Bo" error:&err]);
    XCTAssertNil(err);
    XCTAssertNil([ZKParserFactory parse:p input:@"Boc" error:&err]);
    XCTAssertNil(err);
    XCTAssertNil([ZKParserFactory parse:p input:@"Alice" error:&err]);
    XCTAssertNil(err);
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
    NSError *err = nil;
    XCTAssertEqualObjects(@"B", [ZKParserFactory parse:n input:@"Bob" error:&err]);
    XCTAssertEqualObjects(@"E", [ZKParserFactory parse:n input:@"Eve" error:&err]);
    XCTAssertEqualObjects(@"BB", [ZKParserFactory parse:n input:@"Bobby" error:&err]);
    XCTAssertNil([ZKParserFactory parse:n input:@"Alice" error:&err]);
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
    NSError *err = nil;
    XCTAssertEqualObjects(exp, [ZKParserFactory parse:n input:@"BobEveBobby" error:&err]);
    XCTAssertNil([ZKParserFactory parse:n input:@"BobEveBobbx" error:&err]);
    XCTAssertNil([ZKParserFactory parse:n input:@"AliceBobEveBobby" error:&err]);
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
