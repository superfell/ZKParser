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

ZKParserFactory *f = nil;

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    f = [ZKParserFactory new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(void)testExactMatch {
    ZKParser* p = [f exactly:@"Bob" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        XCTAssertEqualObjects(m, @"Bob");
        return @"Alice";
    }];
    NSError *err = nil;
    NSObject *r = [@"Bob" parse:p error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects(r,  @"Alice");
    XCTAssertNil([@"Eve" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 1", err.localizedDescription);
    XCTAssertNil([@"Bo"  parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 1", err.localizedDescription);
    XCTAssertNil([@"Boc"  parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 1", err.localizedDescription);
    XCTAssertNil([@"Alice"  parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 1", err.localizedDescription);
}

-(void)testCaseInsensitiveMatch {
    ZKParser* p = [f exactly:@"alice" case:CaseInsensitive];
    NSError *err = nil;
    XCTAssertEqualObjects(@"ALICE", [@"ALICE" parse:p error:&err]);
    XCTAssertNil(err);    
    XCTAssertEqualObjects(@"alice", [@"alice"  parse:p error:&err]);
    XCTAssertNil(err);
    XCTAssertEqualObjects(@"ALice", [@"ALice" parse:p error:&err]);
    XCTAssertNil(err);
}

-(void)testDefaultCaseSensitivity {
    ZKParser* p = [f exactly:@"bob"];
    NSError *err = nil;
    XCTAssertEqualObjects(@"bob", [@"bob" parse:p error:&err]);
    XCTAssertNil([@"boB" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'bob' at position 1", err.localizedDescription);
    f.defaultCaseSensitivity = CaseInsensitive;
    ZKParser* i = [f exactly:@"bob"];
    XCTAssertEqualObjects(@"bob", [@"bob" parse:i error:&err]);
    XCTAssertEqualObjects(@"Bob", [@"Bob" parse:i error:&err]);
    XCTAssertEqualObjects(@"BOB", [@"BOB" parse:i error:&err]);
    // p shouldn't be affected by change
    XCTAssertEqualObjects(@"bob", [@"bob" parse:p error:&err]);
    XCTAssertNil([@"boB" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'bob' at position 1", err.localizedDescription);
}

-(void)testOneOf {
    ZKParser* bob = [f exactly:@"Bob" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"B";
    }];
    ZKParser* eve = [f exactly:@"Eve" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"E";
    }];
    ZKParser* bobby = [f exactly:@"Bobby" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"BB";
    }];
    ZKParser* p = [f oneOf:@[bobby,bob,eve]];
    NSError *err = nil;
    XCTAssertEqualObjects(@"B", [@"Bob"  parse:p error:&err]);
    XCTAssertEqualObjects(@"E", [@"Eve"  parse:p error:&err]);
    XCTAssertEqualObjects(@"BB", [@"Bobby"  parse:p error:&err]);
    XCTAssertNil([@"Alice" parse:p error:&err]);
}

-(void)testSeq {
    ZKParser* bob = [f exactly:@"Bob" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"B";
    }];
    ZKParser* eve = [f exactly:@"Eve" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"E";
    }];
    ZKParser* bobby = [f exactly:@"Bobby" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"BB";
    }];
    ZKParser* p = [f seq:@[bob,eve,bobby]];
    NSObject *exp = @[@"B",@"E",@"BB"];
    NSError *err = nil;
    XCTAssertEqualObjects(exp, [@"BobEveBobby" parse:p error:&err]);
    XCTAssertNil([@"BobEveBobbx" parse:p error:&err]);
    XCTAssertNil([@"AliceBobEveBobby" parse:p error:&err]);
}

-(void)testWhitespace {
    ZKParser* ws = [f whitespace];
    ZKParserInput *i = [ZKParserInput withInput:@" Hello"];
    NSError *err = nil;
    [ws parse:i error:&err];
    XCTAssertEqualObjects(@"Hello", i.value);
    XCTAssertNil(err);

    i = [ZKParserInput withInput:@" \t Hello"];
    [ws parse:i error:&err];
    XCTAssertEqualObjects(@"Hello", i.value);
    XCTAssertNil(err);

    i = [ZKParserInput withInput:@"Hello"];
    [ws parse:i error:&err];
    XCTAssertEqual(5, i.length);
    XCTAssertEqualObjects(@"expecting whitespace at position 1", err.localizedDescription);
}

-(void)testCharacterSet {
    ZKParser* p = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABC"] name:@"Id" min:3];
    NSError *err = nil;
    ZKParserInput *i = [ZKParserInput withInput:@"AAAABC"];
    NSObject *res = [p parse:i error:&err];
    XCTAssertEqualObjects(@"AAAABC", res);

    i = [ZKParserInput withInput:@"AAA"];
    res = [p parse:i error:&err];
    XCTAssertEqualObjects(@"AAA", res);

    i = [ZKParserInput withInput:@"AA"];
    res = [p parse:i error:&err];
    XCTAssertNil(res);
    XCTAssertEqualObjects(@"expecting Id at position 1", err.localizedDescription);
    XCTAssertEqual(2, i.length);
}

-(void)testOneOrMore {
    ZKParser* bob = [f exactly:@"Bob" case:CaseSensitive onMatch:^NSObject *(NSString *m) {
        return @"B";
    }];
    ZKParser* bobs = [f oneOrMore:bob];
    NSObject *exp = @[@"B",@"B",@"B"];
    NSError *err = nil;
    XCTAssertEqualObjects(exp, [bobs parse:[ZKParserInput withInput:@"BobBobBob"] error:&err]);
    XCTAssertNil(err);
}

-(void)testZeroOrMore {
    ZKParser* bob = [f exactly:@"Bob"];
    ZKParser* maybeBobs = [f zeroOrMore:bob];
    NSError *err = nil;
    NSObject *r = [@"Bob" parse:maybeBobs error:&err];
    XCTAssertEqualObjects(@[@"Bob"], r);
    XCTAssertNil(err);

    r = [@"" parse:maybeBobs error:&err];
    XCTAssertEqualObjects(@[], r);
    XCTAssertNil(err);

    r = [@"BobBob" parse:maybeBobs error:&err];
    XCTAssertEqualObjects((@[@"Bob",@"Bob"]), r);
    XCTAssertNil(err);
    
    ZKParser* alice = [f exactly:@"Alice"];
    ZKParser* aliceAndMaybeBobs = [f seq:@[alice, [f whitespace], maybeBobs]];
    r = [@"Alice" parse:aliceAndMaybeBobs error:&err];
    XCTAssertNil(r);
    XCTAssertEqualObjects(@"expecting whitespace at position 6", err.localizedDescription);

    r = [@"Alice " parse:aliceAndMaybeBobs error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects((@[@"Alice",@[]]), r);

    r = [@"Alice Bob" parse:aliceAndMaybeBobs error:&err];
    XCTAssertEqualObjects((@[@"Alice",  @[@"Bob"]]), r);
    XCTAssertNil(err);

    r = [@"Alice BobBob" parse:aliceAndMaybeBobs error:&err];
    XCTAssertEqualObjects((@[@"Alice", @[@"Bob", @"Bob"]]), r);
    XCTAssertNil(err);
}

-(void)testSoql {
    f.defaultCaseSensitivity = CaseInsensitive;
    ZKParser* ws = [f whitespace];
    ZKParser* maybeWs = [f maybeWhitespace];
    ZKParser* select = [f exactly:@"SELECT"];
    ZKParser* from = [f exactly:@"FROM"];
    ZKParser* ident = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"] name:@"identifier" min:1];
    ZKParser* pathStep = [f seq:@[[f exactly:@"."], ident] onMatch:^NSObject *(NSArray *m) {
        return [NSString stringWithFormat:@".%@", m[1]];
    }];
    ZKParser* field = [f seq:@[ident, [f zeroOrMore:pathStep]] onMatch:^NSObject *(NSArray *m) {
        if ([m[1] count] == 0) {
            return m[0];
        }
        return [NSString stringWithFormat:@"%@%@", m[0], [m[1] componentsJoinedByString:@""]];
    }];
    ZKParser* func = [f seq:@[ident, maybeWs, [f exactly:@"("],maybeWs, field,maybeWs,[f exactly:@")"]] onMatch:^NSObject *(NSArray *m) {
        return @[m[0], m[2]];
    }];
    ZKParser* selectExpr = [field or:@[func]];
    ZKParser* nextExpr = [f seq:@[maybeWs, [f exactly:@","], maybeWs, selectExpr] onMatch:^NSObject *(NSArray *m) {
        return m[1];
    }];
    ZKParser* fieldList = [f seq:@[selectExpr, [f zeroOrMore:nextExpr]] onMatch:^NSObject *(NSArray *m) {
        NSArray *f = @[m[0]];
        return [f arrayByAddingObjectsFromArray:m[1]];
    }];
    fieldList = [f oneOf:@[fieldList, [f exactly:@"count()"]]];

    ZKParser* selectStmt = [f seq:@[select, ws, fieldList, ws, from, ws, ident]];
    NSError *err = nil;
    NSObject *r = [@"SELECT contact, account.name from contacts" parse:selectStmt error:&err];
    XCTAssertEqualObjects(r, (@[@"SELECT", @[@"contact",@"account.name"], @"from", @"contacts"]));
    r = [@"SELECT contact,account.name from contacts" parse:selectStmt error:&err];
    XCTAssertEqualObjects(r, (@[@"SELECT", @[@"contact",@"account.name"], @"from", @"contacts"]));
    r = [@"SELECTcontact,account.name from contacts" parse:selectStmt error:&err];
    XCTAssertEqualObjects(@"expecting whitespace at position 7", err.localizedDescription);

    r = [@"SELECT count() from contacts" parse:selectStmt error:&err];
    XCTAssertEqualObjects(r, (@[@"SELECT", @"count()", @"from", @"contacts"]));

    r = [@"SELECT max(createdDate) from contacts" parse:selectStmt error:&err];
    XCTAssertEqualObjects(r, (@[@"SELECT", @[@[@"max",@"createdDate"]], @"from", @"contacts"]));

    r = [@"SELECT name, max(createdDate) from contacts" parse:selectStmt error:&err];
    XCTAssertEqualObjects(r, (@[@"SELECT", @[@"name",@[@"max",@"createdDate"]], @"from", @"contacts"]));
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        [self testSoql];
        [self testSoql];
        [self testSoql];
        [self testSoql];
        [self testSoql];
        // Put the code you want to measure the time of here.
    }];
}

@end
