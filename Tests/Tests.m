//
//  Tests.m
//  Tests
//
//  Created by Simon Fell on 10/23/20.
//  Copyright © 2020 Simon Fell. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ZKParserFactory.h"

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
    ZKBaseParser* p = [f onMatch:[f eq:@"Bob" case:CaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        XCTAssertEqualObjects(m.val, @"Bob");
        XCTAssertEqual(m.loc.location, 0);
        XCTAssertEqual(m.loc.length, 3);
        return [ZKParserResult result:@"Alice" ctx:nil loc:m.loc];
    }];
    NSError *err = nil;
    ZKParserResult *r = [@"Bob" parse:p error:&err];
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

ZKParserResult *r(id val, NSInteger start, NSInteger count) {
    return [ZKParserResult result:val ctx:nil loc:NSMakeRange(start, count)];
}

-(void)testCaseInsensitiveMatch {
    ZKBaseParser* p = [f eq:@"alice" case:CaseInsensitive];
    NSError *err = nil;
    XCTAssertEqualObjects(r(@"ALICE",0,5), [@"ALICE" parse:p error:&err]);
    XCTAssertNil(err);    
    XCTAssertEqualObjects(r(@"alice",0,5), [@"alice"  parse:p error:&err]);
    XCTAssertNil(err);
    XCTAssertEqualObjects(r(@"ALice",0,5), [@"ALice" parse:p error:&err]);
    XCTAssertNil(err);
}

-(void)testDefaultCaseSensitivity {
    ZKBaseParser* p = [f eq:@"bob"];
    NSError *err = nil;
    XCTAssertEqualObjects(r(@"bob",0,3), [@"bob" parse:p error:&err]);
    XCTAssertNil([@"boB" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'bob' at position 1", err.localizedDescription);
    f.defaultCaseSensitivity = CaseInsensitive;
    ZKBaseParser* i = [f eq:@"bob"];
    XCTAssertEqualObjects(r(@"bob",0,3), [@"bob" parse:i error:&err]);
    XCTAssertEqualObjects(r(@"Bob",0,3), [@"Bob" parse:i error:&err]);
    XCTAssertEqualObjects(r(@"BOB",0,3), [@"BOB" parse:i error:&err]);
    // p shouldn't be affected by change
    XCTAssertEqualObjects(r(@"bob",0,3), [@"bob" parse:p error:&err]);
    XCTAssertNil([@"boB" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'bob' at position 1", err.localizedDescription);
}

-(void)testOneOf {
    ZKBaseParser* bob = [f onMatch:[f eq:@"Bob" case:CaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"B";
        return m;
    }];
    ZKBaseParser* eve = [f onMatch:[f eq:@"Eve" case:CaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"E";
        return m;
    }];
    ZKBaseParser* bobby = [f onMatch:[f eq:@"Bobby" case:CaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"BB";
        return m;
    }];
    ZKBaseParser* p = [f oneOf:@[bobby,bob,eve]];
    NSError *err = nil;
    XCTAssertEqualObjects(@"B", [@"Bob"  parse:p error:&err].val);
    XCTAssertEqualObjects(@"E", [@"Eve"  parse:p error:&err].val);
    XCTAssertEqualObjects(@"BB", [@"Bobby"  parse:p error:&err].val);
    XCTAssertNil([@"Alice" parse:p error:&err].val);
}

-(void)testSeq {
    ZKBaseParser* bob = [f onMatch:[f eq:@"Bob" case:CaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"B";
        return m;
    }];
    ZKBaseParser* eve = [f onMatch:[f eq:@"Eve" case:CaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"E";
        return m;
    }];
    ZKBaseParser* bobby = [f onMatch:[f eq:@"Bobby" case:CaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"BB";
        return m;
    }];
    ZKBaseParser* p = [f seq:@[bob,eve,bobby]];
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
    ZKBaseParser* ws = [f whitespace];
    ZKParsingState *i = [ZKParsingState withInput:@" Hello"];
    NSError *err = nil;
    [ws parse:i error:&err];
    XCTAssertEqualObjects(@"Hello", i.value);
    XCTAssertNil(err);

    i = [ZKParsingState withInput:@" \t Hello"];
    [ws parse:i error:&err];
    XCTAssertEqualObjects(@"Hello", i.value);
    XCTAssertNil(err);

    i = [ZKParsingState withInput:@"Hello"];
    [ws parse:i error:&err];
    XCTAssertEqual(5, i.length);
    XCTAssertEqualObjects(@"expecting whitespace at position 1", err.localizedDescription);
}

-(void)testCharacterSet {
    ZKBaseParser* p = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABC"] name:@"Id" min:3];
    NSError *err = nil;
    ZKParsingState *i = [ZKParsingState withInput:@"AAAABC"];
    NSObject *res = [p parse:i error:&err];
    XCTAssertEqualObjects(r(@"AAAABC",0,6), res);

    i = [ZKParsingState withInput:@"AAA"];
    res = [p parse:i error:&err];
    XCTAssertEqualObjects(r(@"AAA",0,3), res);

    i = [ZKParsingState withInput:@"AA"];
    res = [p parse:i error:&err];
    XCTAssertNil(res);
    XCTAssertEqualObjects(@"expecting Id at position 1", err.localizedDescription);
    XCTAssertEqual(2, i.length);
}

-(void)testInteger {
    NSError *err = nil;
    ZKBaseParser *p = [f integerNumber];
    ZKParserResult *r = [@"123" parse:p error:&err];
    XCTAssertEqualObjects(@(123), r.val);
    XCTAssertEqual(0, r.loc.location);
    XCTAssertEqual(3, r.loc.length);
    
    r = [@"9" parse:p error:&err];
    XCTAssertEqualObjects(@(9), r.val);
    r = [@"+321" parse:p error:&err];
    XCTAssertEqualObjects(@(321), r.val);
    r = [@"-321" parse:p error:&err];
    XCTAssertEqualObjects(@(-321), r.val);
    ZKParsingState *i = [ZKParsingState withInput:@"-321bob"];
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
    ZKBaseParser *p = [f decimalNumber];
    ZKParserResult *r = [@"123" parse:p error:&err];
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
    ZKParsingState *i = [ZKParsingState withInput:@"-321bob"];
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
    ZKBaseParser *p = [f regex:re name:@"number"];
    ZKParsingState *i = [ZKParsingState withInput:@"ABC20-30DEF"];
    [p parse:i error:&err];
    XCTAssertEqualObjects(@"expecting a number at position 1", err.localizedDescription);
    i.pos = 3; // something else consumed ABC;
    ZKParserResult *r = [p parse:i error:&err];
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
    ZKBaseParser* bob = [f onMatch:[f eq:@"Bob" case:CaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"B";
        return m;
    }];
    ZKBaseParser* bobs = [f oneOrMore:bob];
    NSObject *exp = @[r(@"B",0,3),r(@"B",3,3),r(@"B",6,3)];
    NSError *err = nil;
    XCTAssertEqualObjects(exp, [bobs parse:[ZKParsingState withInput:@"BobBobBob"] error:&err].val);
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
    ZKBaseParser* bob = [f eq:@"Bob"];
    ZKBaseParser* maybeBobs = [f zeroOrMore:bob];
    NSError *err = nil;
    ZKParserResult *pr = [@"Bob" parse:maybeBobs error:&err];
    XCTAssertEqualObjects(r(@[r(@"Bob",0,3)],0,3), pr);
    XCTAssertNil(err);

    pr = [@"" parse:maybeBobs error:&err];
    XCTAssertEqualObjects(r(@[],0,0), pr);
    XCTAssertNil(err);

    pr = [@"BobBob" parse:maybeBobs error:&err];
    XCTAssertEqualObjects(r(@[r(@"Bob",0,3),r(@"Bob",3,3)],0,6), pr);
    XCTAssertNil(err);
    
    ZKBaseParser* alice = [f eq:@"Alice"];
    ZKBaseParser* aliceAndMaybeBobs = [f seq:@[alice, [f whitespace], maybeBobs]];
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

-(void)testCut {
    // without cut
    ZKBaseParser *p1 = [f seq:@[[f eq:@"LIMIT"], [f whitespace], [f integerNumber]]];
    ZKBaseParser *p = [f zeroOrOne:p1];
    NSError *err = nil;
    [@"LIMIT bob" parse:p error:&err];
    XCTAssertEqualObjects(@"Unexpected input 'LIMIT bob' at position 1", err.localizedDescription);

    p1 = [f seq:@[[f eq:@"LIMIT"], [f cut], [f whitespace], [f integerNumber]]];
    p = [f zeroOrOne:p1];
    err = nil;
    [@"LIMIT bob" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting an integer at position 7", err.localizedDescription);
}

-(void)testOnMatchStacking {
    ZKBaseParser *p = [f seq:@[[f eq:@"A"], [f eq:@"B"]]];
    p = [f onMatch:p perform:^ZKParserResult *(ZKParserResult *r) {
        r.val = @"AB";
        return r;
    }];
    ZKBaseParser *p2 = [f onMatch:p perform:^ZKParserResult *(ZKParserResult *r) {
        r.val = [NSString stringWithFormat:@"x%@", r.val];
        return r;
    }];
    NSError *err = nil;
    ZKParserResult *r = [@"AB" parse:p error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects(@"AB", r.val);
    r = [@"AB" parse:p2 error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects(@"xAB", r.val);
    XCTAssertFalse(p == p2);
}

-(void)testOnError {
    ZKBaseParser *p = [f eq:@"Bob"];
    p = [f onError:p perform:^(NSError *__autoreleasing *err) {
        *err = [NSError errorWithDomain:@"test" code:42 userInfo:nil];
    }];
    NSError *err = nil;
    [@"Alice" parse:p error:&err];
    XCTAssertEqualObjects(@"test", err.domain);
}

@end
