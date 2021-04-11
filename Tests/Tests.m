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
    ZKParser* p = [[f eq:@"Bob" case:CaseSensitive] onMatch:^ParserResult *(ParserResult *m) {
        XCTAssertEqualObjects(m.val, @"Bob");
        XCTAssertEqual(m.loc.location, 0);
        XCTAssertEqual(m.loc.length, 3);
        return [ParserResult result:@"Alice" loc:m.loc];
    }];
    NSError *err = nil;
    ParserResult *r = [@"Bob" parse:p error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects(r.val,  @"Alice");
    XCTAssertNil([@"Eve" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 1", err.localizedDescription);
    XCTAssertNil([@"Bo"  parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 1", err.localizedDescription);
    XCTAssertNil([@"Boc"  parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 1", err.localizedDescription);
    XCTAssertNil([@"Alice"  parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 1", err.localizedDescription);
}

ParserResult *r(id val, NSInteger start, NSInteger count) {
    return [ParserResult result:val loc:NSMakeRange(start, count)];
}

-(void)testCaseInsensitiveMatch {
    ZKParser* p = [f eq:@"alice" case:CaseInsensitive];
    NSError *err = nil;
    XCTAssertEqualObjects(r(@"ALICE",0,5), [@"ALICE" parse:p error:&err]);
    XCTAssertNil(err);    
    XCTAssertEqualObjects(r(@"alice",0,5), [@"alice"  parse:p error:&err]);
    XCTAssertNil(err);
    XCTAssertEqualObjects(r(@"ALice",0,5), [@"ALice" parse:p error:&err]);
    XCTAssertNil(err);
}

-(void)testDefaultCaseSensitivity {
    ZKParser* p = [f eq:@"bob"];
    NSError *err = nil;
    XCTAssertEqualObjects(r(@"bob",0,3), [@"bob" parse:p error:&err]);
    XCTAssertNil([@"boB" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'bob' at position 1", err.localizedDescription);
    f.defaultCaseSensitivity = CaseInsensitive;
    ZKParser* i = [f eq:@"bob"];
    XCTAssertEqualObjects(r(@"bob",0,3), [@"bob" parse:i error:&err]);
    XCTAssertEqualObjects(r(@"Bob",0,3), [@"Bob" parse:i error:&err]);
    XCTAssertEqualObjects(r(@"BOB",0,3), [@"BOB" parse:i error:&err]);
    // p shouldn't be affected by change
    XCTAssertEqualObjects(r(@"bob",0,3), [@"bob" parse:p error:&err]);
    XCTAssertNil([@"boB" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'bob' at position 1", err.localizedDescription);
}

-(void)testOneOf {
    ZKParser* bob = [[f eq:@"Bob" case:CaseSensitive] onMatch:^ParserResult *(ParserResult *m) {
        m.val = @"B";
        return m;
    }];
    ZKParser* eve = [[f eq:@"Eve" case:CaseSensitive] onMatch:^ParserResult *(ParserResult *m) {
        m.val = @"E";
        return m;
    }];
    ZKParser* bobby = [[f eq:@"Bobby" case:CaseSensitive] onMatch:^ParserResult *(ParserResult *m) {
        m.val = @"BB";
        return m;
    }];
    ZKParser* p = [f oneOf:@[bobby,bob,eve]];
    NSError *err = nil;
    XCTAssertEqualObjects(@"B", [@"Bob"  parse:p error:&err].val);
    XCTAssertEqualObjects(@"E", [@"Eve"  parse:p error:&err].val);
    XCTAssertEqualObjects(@"BB", [@"Bobby"  parse:p error:&err].val);
    XCTAssertNil([@"Alice" parse:p error:&err].val);
}

-(void)testSeq {
    ZKParser* bob = [[f eq:@"Bob" case:CaseSensitive] onMatch:^ParserResult *(ParserResult *m) {
        m.val = @"B";
        return m;
    }];
    ZKParser* eve = [[f eq:@"Eve" case:CaseSensitive] onMatch:^ParserResult *(ParserResult *m) {
        m.val = @"E";
        return m;
    }];
    ZKParser* bobby = [[f eq:@"Bobby" case:CaseSensitive] onMatch:^ParserResult *(ParserResult *m) {
        m.val = @"BB";
        return m;
    }];
    ZKParser* p = [f seq:@[bob,eve,bobby]];
    NSObject *exp = @[r(@"B",0,3),r(@"E",3,3),r(@"BB",6,5)];
    NSError *err = nil;
    XCTAssertEqualObjects(exp, [@"BobEveBobby" parse:p error:&err].val);
    XCTAssertNil(err);
    
    XCTAssertNil([@"BobEveBobbx" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bobby' at position 7", err.localizedDescription);

    XCTAssertNil([@"AliceBobEveBobby" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 1", err.localizedDescription);
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
    XCTAssertEqualObjects(r(@"AAAABC",0,6), res);

    i = [ZKParserInput withInput:@"AAA"];
    res = [p parse:i error:&err];
    XCTAssertEqualObjects(r(@"AAA",0,3), res);

    i = [ZKParserInput withInput:@"AA"];
    res = [p parse:i error:&err];
    XCTAssertNil(res);
    XCTAssertEqualObjects(@"expecting Id at position 1", err.localizedDescription);
    XCTAssertEqual(2, i.length);
}

-(void)testInteger {
    NSError *err = nil;
    ZKParser *p = [f integerNumber];
    ParserResult *r = [@"123" parse:p error:&err];
    XCTAssertEqualObjects(@(123), r.val);
    XCTAssertEqual(0, r.loc.location);
    XCTAssertEqual(3, r.loc.length);
    
    r = [@"9" parse:p error:&err];
    XCTAssertEqualObjects(@(9), r.val);
    r = [@"+321" parse:p error:&err];
    XCTAssertEqualObjects(@(321), r.val);
    r = [@"-321" parse:p error:&err];
    XCTAssertEqualObjects(@(-321), r.val);
    ZKParserInput *i = [ZKParserInput withInput:@"-321bob"];
    r = [p parse:i error:&err];
    XCTAssertEqualObjects(@(-321), r.val);
    XCTAssertEqual(4, i.pos);
    
    [@"" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting an integer at position 1", err.localizedDescription);
    [@"++1" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting an integer at position 1", err.localizedDescription);
    [@"x" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting an integer at position 1", err.localizedDescription);
    [@"+a" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting an integer at position 1", err.localizedDescription);
    [@"+a" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting an integer at position 1", err.localizedDescription);
}

-(void)testDecimal {
    NSError *err = nil;
    ZKParser *p = [f decimalNumber];
    ParserResult *r = [@"123" parse:p error:&err];
    XCTAssertEqualObjects(@(123), r.val);
    XCTAssertEqual(0, r.loc.location);
    XCTAssertEqual(3, r.loc.length);
    
    NSDecimalNumber*(^dec)(NSString*) = ^NSDecimalNumber*(NSString*v) {
        return [NSDecimalNumber decimalNumberWithString:v];
    };
    r = [@"9" parse:p error:&err];
    XCTAssertEqualObjects(@(9), r.val);
    r = [@"+321" parse:p error:&err];
    XCTAssertEqualObjects(@(321), r.val);
    r = [@"-321" parse:p error:&err];
    XCTAssertEqualObjects(@(-321), r.val);
    r = [@"-321.1234" parse:p error:&err];
    XCTAssertEqualObjects(dec(@"-321.1234"), r.val);
    r = [@"321.1234" parse:p error:&err];
    XCTAssertEqualObjects(dec(@"321.1234"), r.val);
    r = [@".1234" parse:p error:&err];
    XCTAssertEqualObjects(dec(@".1234"), r.val);
    r = [@"-.1234" parse:p error:&err];
    XCTAssertEqualObjects(dec(@"-0.1234"), r.val);
    r = [@"+.1234" parse:p error:&err];
    XCTAssertEqualObjects(dec(@"0.1234"), r.val);
    ZKParserInput *i = [ZKParserInput withInput:@"-321bob"];
    r = [p parse:i error:&err];
    XCTAssertEqualObjects(@(-321), r.val);
    XCTAssertEqual(4, i.pos);
    
    [@"" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting a decimal at position 1", err.localizedDescription);
    [@"++1" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting a decimal at position 1", err.localizedDescription);
    [@"x" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting a decimal at position 1", err.localizedDescription);
    [@"+a" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting a decimal at position 1", err.localizedDescription);
    [@"+a" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting a decimal at position 1", err.localizedDescription);
    [@"+10." parse:p error:&err];
    XCTAssertEqualObjects(@"expecting a decimal at position 1", err.localizedDescription);
    [@"." parse:p error:&err];
    XCTAssertEqualObjects(@"expecting a decimal at position 1", err.localizedDescription);
}

-(void)testRegex {
    NSError *err = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\d\\d-\\d\\d"
                                                                        options:NSRegularExpressionCaseInsensitive
                                                                          error:&err];
    XCTAssertNil(err);
    ZKParser *p = [f regex:re name:@"number"];
    ZKParserInput *i = [ZKParserInput withInput:@"ABC20-30DEF"];
    [p parse:i error:&err];
    XCTAssertEqualObjects(@"expecting a number at position 1", err.localizedDescription);
    i.pos = 3; // something else consumed ABC;
    ParserResult *r = [p parse:i error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects(@"20-30", r.val);
    XCTAssertTrue(NSEqualRanges(NSMakeRange(3,5), r.loc));
    XCTAssertEqualObjects(@"DEF", i.value);
    
    i.pos = 4;
    r = [p parse:i error:&err];
    XCTAssertNil(r);
    XCTAssertEqualObjects(@"expecting a number at position 5", err.localizedDescription);
}

-(void)testOneOrMore {
    ZKParser* bob = [[f eq:@"Bob" case:CaseSensitive] onMatch:^ParserResult *(ParserResult *m) {
        m.val = @"B";
        return m;
    }];
    ZKParser* bobs = [f oneOrMore:bob];
    NSObject *exp = @[r(@"B",0,3),r(@"B",3,3),r(@"B",6,3)];
    NSError *err = nil;
    XCTAssertEqualObjects(exp, [bobs parse:[ZKParserInput withInput:@"BobBobBob"] error:&err].val);
    XCTAssertNil(err);
    
    bobs = [f oneOrMore:bob separator:[f eq:@","]];
    XCTAssertEqualObjects(@[r(@"B",0,3)], [@"Bob" parse:bobs error:&err].val);
    XCTAssertNil(err);
    XCTAssertEqualObjects((@[r(@"B",0,3),r(@"B",4,3)]), [@"Bob,Bob" parse:bobs error:&err].val);
    XCTAssertNil(err);
    XCTAssertNil([@"Bob,Bob," parse:bobs error:&err]);
    XCTAssertEqualObjects(@"Unexpected input ',' at position 8", err.localizedDescription);
    XCTAssertEqualObjects((@[r(@"B",0,3),r(@"B",4,3),r(@"B",8,3)]), [@"Bob,Bob,Bob" parse:bobs error:&err].val);
    XCTAssertNil(err);
}

-(void)testZeroOrMore {
    ZKParser* bob = [f eq:@"Bob"];
    ZKParser* maybeBobs = [f zeroOrMore:bob];
    NSError *err = nil;
    ParserResult *pr = [@"Bob" parse:maybeBobs error:&err];
    XCTAssertEqualObjects(r(@[r(@"Bob",0,3)],0,3), pr);
    XCTAssertNil(err);

    pr = [@"" parse:maybeBobs error:&err];
    XCTAssertEqualObjects(r(@[],0,0), pr);
    XCTAssertNil(err);

    pr = [@"BobBob" parse:maybeBobs error:&err];
    XCTAssertEqualObjects(r(@[r(@"Bob",0,3),r(@"Bob",3,3)],0,6), pr);
    XCTAssertNil(err);
    
    ZKParser* alice = [f eq:@"Alice"];
    ZKParser* aliceAndMaybeBobs = [f seq:@[alice, [f whitespace], maybeBobs]];
    pr = [@"Alice" parse:aliceAndMaybeBobs error:&err];
    XCTAssertNil(pr);
    XCTAssertEqualObjects(@"expecting whitespace at position 6", err.localizedDescription);

    pr = [@"Alice " parse:aliceAndMaybeBobs error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects(r(@[r(@"Alice",0,5),r(@" ",5,1), r(@[],6,0)],0,6), pr);

    pr = [@"Alice Bob" parse:aliceAndMaybeBobs error:&err];
    XCTAssertEqualObjects(r(@[r(@"Alice",0,5),r(@" ",5,1), r(@[r(@"Bob",6,3)],6,3)],0,9), pr);
    XCTAssertNil(err);

    pr = [@"Alice BobBob" parse:aliceAndMaybeBobs error:&err];
    XCTAssertEqualObjects(r(@[r(@"Alice",0,5),r(@" ",5,1), r(@[r(@"Bob",6,3),r(@"Bob",9,3)],6,6)],0,12), pr);
    XCTAssertNil(err);
}

@end
