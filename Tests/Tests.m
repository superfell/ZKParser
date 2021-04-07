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
    ZKParser p = [ZKParserFactory exactly:@"Bob" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        XCTAssertEqualObjects(m, @"Bob");
        return @"Alice";
    }];
    NSError *err = nil;
    NSObject *r = [ZKParserFactory parse:p input:@"Bob" error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects(r,  @"Alice");
    XCTAssertNil([ZKParserFactory parse:p input:@"Eve" error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 0", err.localizedDescription);
    XCTAssertNil([ZKParserFactory parse:p input:@"Bo" error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 0", err.localizedDescription);
    XCTAssertNil([ZKParserFactory parse:p input:@"Boc" error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 0", err.localizedDescription);
    XCTAssertNil([ZKParserFactory parse:p input:@"Alice" error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 0", err.localizedDescription);
}

-(void)testCaseInsensitiveMatch {
    ZKParser p = [ZKParserFactory exactly:@"alice" case:CaseInsensitive];
    NSError *err = nil;
    XCTAssertEqualObjects(@"ALICE", [ZKParserFactory parse:p input:@"ALICE" error:&err]);
    XCTAssertNil(err);    
    XCTAssertEqualObjects(@"alice", [ZKParserFactory parse:p input:@"alice" error:&err]);
    XCTAssertNil(err);
    XCTAssertEqualObjects(@"ALice", [ZKParserFactory parse:p input:@"ALice" error:&err]);
    XCTAssertNil(err);
}

-(void)testOneOf {
    ZKParser bob = [ZKParserFactory exactly:@"Bob" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"B";
    }];
    ZKParser eve = [ZKParserFactory exactly:@"Eve" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"E";
    }];
    ZKParser bobby = [ZKParserFactory exactly:@"Bobby" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
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
    ZKParser bob = [ZKParserFactory exactly:@"Bob" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"B";
    }];
    ZKParser eve = [ZKParserFactory exactly:@"Eve" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"E";
    }];
    ZKParser bobby = [ZKParserFactory exactly:@"Bobby" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
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
    NSError *err = nil;
    ws(i, &err);
    XCTAssertEqualObjects(@"Hello", i.value);
    XCTAssertNil(err);

    i = [ZKParserInput withInput:@" \t Hello"];
    ws(i, &err);
    XCTAssertEqualObjects(@"Hello", i.value);
    XCTAssertNil(err);

    i = [ZKParserInput withInput:@"Hello"];
    ws(i, &err);
    XCTAssertEqual(5, i.length);
    XCTAssertEqualObjects(@"expecting whitespace at position 0", err.localizedDescription);
}

-(void)testCharacterSet {
    ZKParser p = [ZKParserFactory characters:[NSCharacterSet characterSetWithCharactersInString:@"ABC"] name:@"Id" min:3];
    NSError *err = nil;
    ZKParserInput *i = [ZKParserInput withInput:@"AAAABC"];
    NSObject *res = p(i,&err);
    XCTAssertEqualObjects(@"AAAABC", res);

    i = [ZKParserInput withInput:@"AAA"];
    res = p(i,&err);
    XCTAssertEqualObjects(@"AAA", res);

    i = [ZKParserInput withInput:@"AA"];
    res = p(i,&err);
    XCTAssertNil(res);
    XCTAssertEqualObjects(@"expecting Id at position 0", err.localizedDescription);
    XCTAssertEqual(2, i.length);
}

-(void)testOneOrMore {
    ZKParser bob = [ZKParserFactory exactly:@"Bob" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"B";
    }];
    ZKParser bobs = [ZKParserFactory oneOrMore:bob];
    NSObject *exp = @[@"B",@"B",@"B"];
    NSError *err = nil;
    XCTAssertEqualObjects(exp, bobs([ZKParserInput withInput:@"BobBobBob"], &err));
    XCTAssertNil(err);
}

-(void)testZeroOrMore {
    ZKParser bob = [ZKParserFactory exactly:@"Bob"];
    ZKParser maybeBobs = [ZKParserFactory zeroOrMore:bob];
    NSError *err = nil;
    NSObject *r = [ZKParserFactory parse:maybeBobs input:@"Bob" error:&err];
    XCTAssertEqualObjects(@[@"Bob"], r);
    XCTAssertNil(err);

    r = [ZKParserFactory parse:maybeBobs input:@"" error:&err];
    XCTAssertEqualObjects(@[], r);
    XCTAssertNil(err);

    r = [ZKParserFactory parse:maybeBobs input:@"BobBob" error:&err];
    XCTAssertEqualObjects((@[@"Bob",@"Bob"]), r);
    XCTAssertNil(err);
    
    ZKParser alice = [ZKParserFactory exactly:@"Alice"];
    ZKParser aliceAndMaybeBobs = [ZKParserFactory seq:@[alice, [ZKParserFactory whitespace], maybeBobs]];
    r = [ZKParserFactory parse:aliceAndMaybeBobs input:@"Alice" error:&err];
    XCTAssertNil(r);
    XCTAssertEqualObjects(@"expecting whitespace at position 5", err.localizedDescription);

    r = [ZKParserFactory parse:aliceAndMaybeBobs input:@"Alice " error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects((@[@"Alice", @" ",@[]]), r);

    r = [ZKParserFactory parse:aliceAndMaybeBobs input:@"Alice Bob" error:&err];
    XCTAssertEqualObjects((@[@"Alice", @" ", @[@"Bob"]]), r);
    XCTAssertNil(err);

    r = [ZKParserFactory parse:aliceAndMaybeBobs input:@"Alice BobBob" error:&err];
    XCTAssertEqualObjects((@[@"Alice", @" ", @[@"Bob", @"Bob"]]), r);
    XCTAssertNil(err);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
//    [self measureBlock:^{
        // Put the code you want to measure the time of here.
  //  }];
}

@end
