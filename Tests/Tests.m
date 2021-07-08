// Copyright (c) 2020 Simon Fell
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
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
    ZKBaseParser* p = [f onMatch:[f eq:@"Bob" case:ZKCaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        XCTAssertEqualObjects(m.val, @"Bob");
        XCTAssertEqual(m.loc.location, 0);
        XCTAssertEqual(m.loc.length, 3);
        return [ZKParserResult result:@"Alice" ctx:nil loc:m.loc];
    }];
    NSError *err = nil;
    NSString *r = [@"Bob" parse:p error:&err];
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

ZKParserResult *r(id val, NSInteger start, NSInteger count) {
    return [ZKParserResult result:val ctx:nil loc:NSMakeRange(start, count)];
}

-(void)testCaseInsensitiveMatch {
    ZKBaseParser* p = [f eq:@"alice" case:ZKCaseInsensitive];
    NSError *err = nil;
    XCTAssertEqualObjects(@"ALICE", [@"ALICE" parse:p error:&err]);
    XCTAssertNil(err);    
    XCTAssertEqualObjects(@"alice", [@"alice"  parse:p error:&err]);
    XCTAssertNil(err);
    XCTAssertEqualObjects(@"ALice", [@"ALice" parse:p error:&err]);
    XCTAssertNil(err);
    XCTAssertNil([@"alicy" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'alice' at position 1", err.localizedDescription);
}

-(void)testDefaultCaseSensitivity {
    ZKBaseParser* p = [f eq:@"bob"];
    NSError *err = nil;
    XCTAssertEqualObjects(@"bob", [@"bob" parse:p error:&err]);
    XCTAssertNil([@"boB" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'bob' at position 1", err.localizedDescription);
    f.defaultCaseSensitivity = ZKCaseInsensitive;
    ZKBaseParser* i = [f eq:@"bob"];
    XCTAssertEqualObjects(@"bob", [@"bob" parse:i error:&err]);
    XCTAssertEqualObjects(@"Bob", [@"Bob" parse:i error:&err]);
    XCTAssertEqualObjects(@"BOB", [@"BOB" parse:i error:&err]);
    // p shouldn't be affected by change
    XCTAssertEqualObjects(@"bob", [@"bob" parse:p error:&err]);
    XCTAssertNil([@"boB" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'bob' at position 1", err.localizedDescription);
}

-(void)testWhitespace {
    ZKBaseParser* ws = [f whitespace];
    ZKParsingState *i = [ZKParsingState withInput:@" Hello"];
    ZKParserResult *r = [ws parse:i];
    XCTAssertEqualObjects(@"Hello", i.value);
    XCTAssertEqualObjects(@" ", r.val);
    XCTAssertFalse(i.hasError);

    i = [ZKParsingState withInput:@" \t Hello"];
    r = [ws parse:i];
    XCTAssertEqualObjects(@"Hello", i.value);
    XCTAssertEqualObjects(@" \t ", r.val);
    XCTAssertFalse(i.hasError);

    i = [ZKParsingState withInput:@"Hello"];
    r = [ws parse:i];
    XCTAssertEqual(5, i.length);
    XCTAssertEqualObjects(@"expecting whitespace at position 1", i.error.msg);
    XCTAssertTrue(i.hasError);
}

-(void)testMaybeWhitespace {
    ZKBaseParser *p = [f maybeWhitespace];
    XCTAssertEqualObjects(r(@"  ",0,2), [p parse:[ZKParsingState withInput:@"  Bob"]]);
    XCTAssertEqualObjects(r(@"",0,0), [p parse:[ZKParsingState withInput:@"Bob"]]);
}

-(void)testCharacterSet {
    ZKBaseParser* p = [f characters:[NSCharacterSet characterSetWithCharactersInString:@"ABC"] name:@"Id" min:3];
    void(^test)(NSString*input) = ^(NSString*input) {
        ZKParsingState *i = [ZKParsingState withInput:input];
        ZKParserResult *res = [p parse:i];
        XCTAssertEqualObjects(r(input,0,input.length), res);
    };
    test(@"ABC");
    test(@"AAAAABBBBBCCCCC");
    test(@"AAAAABBBBBCCCCCA");
    test(@"AAAAABBBBBCCCCCAA");
    test(@"AAAAABBBBBCCCCCAAA");

    ZKParsingState *i = [ZKParsingState withInput:@"AA"];
    ZKParserResult *res = [p parse:i];
    XCTAssertNil(res);
    XCTAssertEqualObjects(@"expecting Id at position 1", i.error.msg);
    XCTAssertEqual(2, i.length);

    i = [ZKParsingState withInput:@"AADEF"];
    res = [p parse:i];
    XCTAssertNil(res);
    XCTAssertEqualObjects(@"expecting Id at position 1", i.error.msg);
    XCTAssertEqual(5, i.length);
}

-(void)testNotCharSet {
    ZKBaseParser *p = [f notCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABC"] name:@"Id" min:1];
    XCTAssertEqualObjects(r(@"Hello",0,5), [p parse:[ZKParsingState withInput:@"Hello"]]);
    XCTAssertEqualObjects(r(@"H",0,1), [p parse:[ZKParsingState withInput:@"HA"]]);
}

-(void)testInteger {
    NSError *err = nil;
    ZKBaseParser *p = [f integerNumber];
    NSNumber *r = [@"123" parse:p error:&err];
    XCTAssertEqualObjects(@(123), r);
    
    r = [@"9" parse:p error:&err];
    XCTAssertEqualObjects(@(9), r);
    r = [@"+321" parse:p error:&err];
    XCTAssertEqualObjects(@(321), r);
    r = [@"-321" parse:p error:&err];
    XCTAssertEqualObjects(@(-321), r);
    ZKParsingState *i = [ZKParsingState withInput:@"-321bob"];
    ZKParserResult *pr = [p parse:i];
    XCTAssertEqualObjects(@(-321), pr.val);
    XCTAssertEqual(4, i.pos);
    
    [@"" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting integer at position 1", err.localizedDescription);
    [@"++1" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting integer at position 1", err.localizedDescription);
    [@"x" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting integer at position 1", err.localizedDescription);
    [@"+a" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting integer at position 1", err.localizedDescription);
    [@"+a" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting integer at position 1", err.localizedDescription);
}

-(void)testDecimal {
    NSError *err = nil;
    ZKBaseParser *p = [f decimalNumber];
    ZKParserResult *r = [@"123" parse:p error:&err];
    XCTAssertEqualObjects(@(123), r);
    XCTAssertNil(err);
    
    NSDecimalNumber*(^dec)(NSString*) = ^NSDecimalNumber*(NSString*v) {
        return [NSDecimalNumber decimalNumberWithString:v];
    };
    r = [@"9" parse:p error:&err];
    XCTAssertEqualObjects(@(9), r);
    r = [@"+321" parse:p error:&err];
    XCTAssertEqualObjects(@(321), r);
    r = [@"-321" parse:p error:&err];
    XCTAssertEqualObjects(@(-321), r);
    r = [@"-321.1234" parse:p error:&err];
    XCTAssertEqualObjects(dec(@"-321.1234"), r);
    r = [@"321.1234" parse:p error:&err];
    XCTAssertEqualObjects(dec(@"321.1234"), r);
    r = [@".1234" parse:p error:&err];
    XCTAssertEqualObjects(dec(@".1234"), r);
    r = [@"-.1234" parse:p error:&err];
    XCTAssertEqualObjects(dec(@"-0.1234"), r);
    r = [@"+.1234" parse:p error:&err];
    XCTAssertEqualObjects(dec(@"0.1234"), r);
    ZKParsingState *i = [ZKParsingState withInput:@"-321bob"];
    r = [p parse:i];
    XCTAssertEqualObjects(@(-321), r.val);
    XCTAssertEqual(4, i.pos);
    
    [@"" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting decimal at position 1", err.localizedDescription);
    [@"++1" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting decimal at position 1", err.localizedDescription);
    [@"x" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting decimal at position 1", err.localizedDescription);
    [@"+a" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting decimal at position 1", err.localizedDescription);
    [@"+a" parse:p error:&err];
    XCTAssertEqualObjects(@"expecting decimal at position 1", err.localizedDescription);
    [@"+10." parse:p error:&err];
    XCTAssertEqualObjects(@"expecting decimal at position 1", err.localizedDescription);
    [@"." parse:p error:&err];
    XCTAssertEqualObjects(@"expecting decimal at position 1", err.localizedDescription);
}

-(void)testFirstOf {
    ZKBaseParser *p = [f firstOf:@[[f eq:@"AA"], [f eq:@"A"], [f eq:@"B"]]];
    XCTAssertEqualObjects(r(@"AA",0,2), [p parse:[ZKParsingState withInput:@"AAA"]]);
    XCTAssertEqualObjects(r(@"A",0,1), [p parse:[ZKParsingState withInput:@"ABC"]]);
    XCTAssertEqualObjects(r(@"B",0,1), [p parse:[ZKParsingState withInput:@"BC"]]);
    ZKParsingState *s = [ZKParsingState withInput:@"EVE"];
    ZKParserResult *r = [p parse:s];
    XCTAssertNil(r);
    XCTAssertEqualObjects(@"expecting 'B' at position 1", s.error.msg);
}

-(void)testOneOfTokens {
    ZKBaseParser *p = [f oneOfTokens:@"< <= > >= = EQ NOT"];
    XCTAssertEqualObjects(r(@"<",0,1), [p parse:[ZKParsingState withInput:@"< "]]);
    XCTAssertEqualObjects(r(@"<=",0,2), [p parse:[ZKParsingState withInput:@"<="]]);
    XCTAssertEqualObjects(r(@">",0,1), [p parse:[ZKParsingState withInput:@">1"]]);
    XCTAssertEqualObjects(r(@">=",0,2), [p parse:[ZKParsingState withInput:@">="]]);
    XCTAssertEqualObjects(r(@"=",0,1), [p parse:[ZKParsingState withInput:@"=1"]]);
    XCTAssertEqualObjects(r(@"NOT",0,3), [p parse:[ZKParsingState withInput:@"NOT("]]);
}

-(void)testOneOf {
    ZKBaseParser* bob = [f onMatch:[f eq:@"Bob" case:ZKCaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"B";
        return m;
    }];
    ZKBaseParser* eve = [f onMatch:[f eq:@"Eve" case:ZKCaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"E";
        return m;
    }];
    ZKBaseParser* bobby = [f onMatch:[f eq:@"Bobby" case:ZKCaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"BB";
        return m;
    }];
    ZKBaseParser* p = [f oneOf:@[bobby,bob,eve]];
    NSError *err = nil;
    XCTAssertEqualObjects(@"B", [@"Bob"  parse:p error:&err]);
    XCTAssertEqualObjects(@"E", [@"Eve"  parse:p error:&err]);
    XCTAssertEqualObjects(@"BB", [@"Bobby"  parse:p error:&err]);
    XCTAssertNil([@"Alice" parse:p error:&err]);
}

-(void)testSeq {
    ZKBaseParser* bob = [f onMatch:[f eq:@"Bob" case:ZKCaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"B";
        return m;
    }];
    ZKBaseParser* eve = [f onMatch:[f eq:@"Eve" case:ZKCaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"E";
        return m;
    }];
    ZKBaseParser* bobby = [f onMatch:[f eq:@"Bobby" case:ZKCaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"BB";
        return m;
    }];
    ZKBaseParser* p = [f seq:@[bob,eve,bobby]];
    NSObject *exp = @[r(@"B",0,3),r(@"E",3,3),r(@"BB",6,5)];
    NSError *err = nil;
    XCTAssertEqualObjects(exp, [@"BobEveBobby" parse:p error:&err]);
    XCTAssertNil(err);
    
    XCTAssertNil([@"BobEveBobbx" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bobby' at position 7", err.localizedDescription);

    XCTAssertNil([@"AliceBobEveBobby" parse:p error:&err]);
    XCTAssertEqualObjects(@"expecting 'Bob' at position 1", err.localizedDescription);
}

-(void)testRegex {
    NSError *err = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\d\\d-\\d\\d"
                                                                        options:NSRegularExpressionCaseInsensitive
                                                                          error:&err];
    XCTAssertNil(err);
    ZKBaseParser *p = [f regex:re name:@"number"];
    ZKParsingState *i = [ZKParsingState withInput:@"ABC20-30DEF"];
    [p parse:i];
    XCTAssertEqualObjects(@"expecting number at position 1", i.error.msg);
    i.pos = 3; // something else consumed ABC;
    ZKParserResult *r = [p parse:i];
    XCTAssertNil(err);
    XCTAssertEqualObjects(@"20-30", r.val);
    XCTAssertTrue(NSEqualRanges(NSMakeRange(3,5), r.loc));
    XCTAssertEqualObjects(@"DEF", i.value);
    
    i.pos = 4;
    r = [p parse:i];
    XCTAssertNil(r);
    XCTAssertEqualObjects(@"expecting number at position 5", i.error.msg);
}

-(void)testZeroOrOne {
    ZKBaseParser *p = [f zeroOrOne:[f eq:@"Bob"]];
    XCTAssertEqualObjects(r(@"Bob",0,3), [p parse:[ZKParsingState withInput:@"Bob"]]);
    XCTAssertEqualObjects(r([NSNull null],0,0), [p parse:[ZKParsingState withInput:@"Eve"]]);
}

-(void)testOneOrMore {
    ZKBaseParser* bob = [f onMatch:[f eq:@"Bob" case:ZKCaseSensitive] perform:^ZKParserResult *(ZKParserResult *m) {
        m.val = @"B";
        return m;
    }];
    ZKBaseParser* bobs = [f oneOrMore:bob];
    NSObject *exp = @[r(@"B",0,3),r(@"B",3,3),r(@"B",6,3)];
    NSError *err = nil;
    XCTAssertEqualObjects(exp, [bobs parse:[ZKParsingState withInput:@"BobBobBob"]].val);
    XCTAssertNil(err);
    
    bobs = [f oneOrMore:bob separator:[f eq:@","]];
    XCTAssertEqualObjects(@[r(@"B",0,3)], [@"Bob" parse:bobs error:&err]);
    XCTAssertNil(err);
    XCTAssertEqualObjects((@[r(@"B",0,3),r(@"B",4,3)]), [@"Bob,Bob" parse:bobs error:&err]);
    XCTAssertNil(err);
    XCTAssertNil([@"Bob,Bob," parse:bobs error:&err]);
    XCTAssertEqualObjects(@"Unexpected input ',' at position 8", err.localizedDescription);
    XCTAssertEqualObjects((@[r(@"B",0,3),r(@"B",4,3),r(@"B",8,3)]), [@"Bob,Bob,Bob" parse:bobs error:&err]);
    XCTAssertNil(err);
}

-(void)testZeroOrMore {
    ZKBaseParser* bob = [f eq:@"Bob"];
    ZKBaseParser* maybeBobs = [f zeroOrMore:bob];
    NSError *err = nil;
    id pr = [@"Bob" parse:maybeBobs error:&err];
    XCTAssertEqualObjects(@[r(@"Bob",0,3)], pr);
    XCTAssertNil(err);

    pr = [@"" parse:maybeBobs error:&err];
    XCTAssertEqualObjects(@[], pr);
    XCTAssertNil(err);

    pr = [@"BobBob" parse:maybeBobs error:&err];
    XCTAssertEqualObjects((@[r(@"Bob",0,3),r(@"Bob",3,3)]), pr);
    XCTAssertNil(err);
    
    ZKBaseParser* alice = [f eq:@"Alice"];
    ZKBaseParser* aliceAndMaybeBobs = [f seq:@[alice, [f whitespace], maybeBobs]];
    pr = [@"Alice" parse:aliceAndMaybeBobs error:&err];
    XCTAssertNil(pr);
    XCTAssertEqualObjects(@"expecting whitespace at position 6", err.localizedDescription);

    pr = [@"Alice " parse:aliceAndMaybeBobs error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects((@[r(@"Alice",0,5),r(@" ",5,1), r(@[],6,0)]), pr);

    pr = [@"Alice Bob" parse:aliceAndMaybeBobs error:&err];
    XCTAssertEqualObjects((@[r(@"Alice",0,5),r(@" ",5,1), r(@[r(@"Bob",6,3)],6,3)]), pr);
    XCTAssertNil(err);

    pr = [@"Alice BobBob" parse:aliceAndMaybeBobs error:&err];
    XCTAssertEqualObjects((@[r(@"Alice",0,5),r(@" ",5,1), r(@[r(@"Bob",6,3),r(@"Bob",9,3)],6,6)]), pr);
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
    XCTAssertEqualObjects(@"expecting integer at position 7", err.localizedDescription);
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
    NSString *r = [@"AB" parse:p error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects(@"AB", r);
    r = [@"AB" parse:p2 error:&err];
    XCTAssertNil(err);
    XCTAssertEqualObjects(@"xAB", r);
    XCTAssertFalse(p == p2);
}

-(void)testOnError {
    ZKBaseParser *p = [f eq:@"Bob"];
    p = [f onError:p perform:^(ZKParsingState *s) {
        [s error:@"test"];
    }];
    NSError *err = nil;
    [@"Alice" parse:p error:&err];
    XCTAssertEqualObjects(@"test", err.localizedDescription);
}

@end
