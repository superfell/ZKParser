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

NSString *spaces(NSInteger count) {
    NSMutableString *s = [NSMutableString stringWithCapacity:count];
    while (count > 0) {
        [s appendString:@" "];
        count--;
    }
    return s;
}

void assertStringsEq(NSString *act, NSString *exp) {
    if ([exp isEqualToString:act]) {
        return;
    }
    NSString *same = [exp commonPrefixWithString:act options:(NSLiteralSearch)];
    NSString *msg = [NSString stringWithFormat:@"Strings don't match starting at pos %lu\n%@\n%@%@\n",
                     same.length, exp, spaces(same.length), [act substringFromIndex:same.length]];
    XCTFail("%@", msg);
}

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

    res = [p parse:@"SELECT count() from account" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT count() FROM account");
    XCTAssertNil(err);

    // count() is special and can only appear on its own (unlike count(some_field))
    res = [p parse:@"SELECT count(), id from account" error:&err];
    XCTAssertEqualObjects(@"expecting whitespace at position 15", err.localizedDescription);
}

-(void)testNestedSelectStmt {
    NSError *err = nil;
    SelectQuery * res = [p parse:@"SELECT name,(select name from contacts) from account" error:&err];
    assertStringsEq([res toSoql], @"SELECT name,(SELECT name FROM contacts) FROM account");
    XCTAssertNil(err);
    
    res = [p parse:@"SELECT name,(select name from contacts ) , id , ( select id from notes) from account" error:&err];
    assertStringsEq([res toSoql], @"SELECT name,(SELECT name FROM contacts),id,(SELECT id FROM notes) FROM account");
    XCTAssertNil(err);
}

-(void)testTypeOf {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"SELECT subject,TYPEOF what WHEN account Then id,BillingCity when opportunity then name,nextStep else id,name end from Task" error:&err];
    assertStringsEq([res toSoql], @"SELECT subject,TYPEOF what WHEN account THEN id,BillingCity WHEN opportunity THEN name,nextStep ELSE id,name END FROM Task");
    XCTAssertNil(err);
}

-(void)testWhitespace {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"  \t select \t id from \n account \r\n where id\t=true\n" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM account WHERE id = TRUE");
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

-(void)testFilterScope {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact Using  Scope delegated" error:&err];
    XCTAssertEqualObjects([res toSoql], @"SELECT id FROM contact USING SCOPE delegated");
    XCTAssertNil(err);
}

-(void)testDataCategory {
    NSError *err = nil;
    SelectQuery *res= [p parse:@"SELECT name from Account with data  category Geography__c above usa__c" error:&err];
    assertStringsEq(res.toSoql, @"SELECT name FROM Account WITH DATA CATEGORY Geography__c ABOVE usa__c");
    XCTAssertNil(err);

    res= [p parse:@"SELECT name from Account with data  category Geography__c above (uk__c,usa__c) AND product Below phone__c" error:&err];
    assertStringsEq(res.toSoql, @"SELECT name FROM Account WITH DATA CATEGORY Geography__c ABOVE (uk__c,usa__c) AND product BELOW phone__c");
    XCTAssertNil(err);

    res= [p parse:@"SELECT name from Account where name LIKE 'a%' with data  category Geography__c above (uk__c,usa__c) AND product Below phone__c order by name" error:&err];
    assertStringsEq(res.toSoql, @"SELECT name FROM Account WHERE name LIKE 'a%' WITH DATA CATEGORY Geography__c ABOVE (uk__c,usa__c) AND product BELOW phone__c ORDER BY name ASC");
    XCTAssertNil(err);
}

-(void)testParenWhere {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact where (name='bob')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE name = 'bob'");
    XCTAssertNil(err);
}

-(void)testWhereParenTerm {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact where (name = 'bob') or (name='alice' and city='SF')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name = 'bob' OR (name = 'alice' AND city = 'SF'))");
    XCTAssertNil(err);
}

-(void)testWhereLiteralTypes {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact where name='bob'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE name = 'bob'");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where city!='o\\'hare'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE city != 'o\\'hare'");
    XCTAssertNil(err);

    [p parse:@"select id from contact where city!='o'hare'" error:&err];
    assertStringsEq(err.localizedDescription, @"Unexpected input 'hare'' at position 39");
    [p parse:@"select id from contact where city!='SF" error:&err];
    assertStringsEq(err.localizedDescription, @"Unexpected input 'where city!='SF' at position 24");

    res = [p parse:@"select id from contact where city!=null" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE city != NULL");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ishot=true" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot = TRUE");
    XCTAssertNil(err);
    res = [p parse:@"select id from contact where ishot= false" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot = FALSE");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ishot > -10" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot > -10");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ishot > .5" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot > 0.5");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ishot > YESTERDAY" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot > YESTERDAY");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ishot < LAST_N_MONTHS:3" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ishot < LAST_N_MONTHS:3");
    XCTAssertNil(err);
}

-(void)testDateLiteralTypes {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact where createdDate >2020-02-03" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE createdDate > 2020-02-03");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where createdDate >2020-02-03T12:13:14Z" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE createdDate > 2020-02-03T12:13:14Z");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where createdDate >2020-02-03T12:13:14-07:00" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE createdDate > 2020-02-03T19:13:14Z");
    XCTAssertNil(err);
}

-(void)testWhere {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact where name = 'bob'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE name = 'bob'");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where toLabel(status)='employee'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE toLabel(status) = 'employee'");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where toLabel(LeadSource)='employee' AND NOT CALENDAR_YEAR(CreatedDate) < 2018" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (toLabel(LeadSource) = 'employee' AND (NOT CALENDAR_YEAR(CreatedDate) < 2018))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where toLabel(LeadSource)='employee' AND (NOT CALENDAR_YEAR(CreatedDate) < 2018)" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (toLabel(LeadSource) = 'employee' AND (NOT CALENDAR_YEAR(CreatedDate) < 2018))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where name = 'bob' or name='alice'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name = 'bob' OR name = 'alice')");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where name = 'bob' or name='alice' and city='SF'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name = 'bob' OR (name = 'alice' AND city = 'SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where (name='bob')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE name = 'bob'");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where (name = 'bob' or name='alice' and city='SF')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name = 'bob' OR (name = 'alice' AND city = 'SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ( name = 'bob' or name='alice' and city='SF'  )" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name = 'bob' OR (name = 'alice' AND city = 'SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where name = 'bob' or (name='alice' and city='SF')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name = 'bob' OR (name = 'alice' AND city = 'SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where (name = 'bob' or name='alice') and city='SF'" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ((name = 'bob' OR name = 'alice') AND city = 'SF')");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where (name = 'bob') or (name='alice' and city='SF')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name = 'bob' OR (name = 'alice' AND city = 'SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where (name = 'bob') or (((name='alice' and city='SF')))" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE (name = 'bob' OR (name = 'alice' AND city = 'SF'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from contact where ((name = 'bob' or name='alice') and city='SF')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact WHERE ((name = 'bob' OR name = 'alice') AND city = 'SF')");
    XCTAssertNil(err);
}

-(void)testWhereIncExcl {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from account where name = 'bob' AND msp__c includes ('A','B;C')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM account WHERE (name = 'bob' AND msp__c INCLUDES ('A','B;C'))");
    XCTAssertNil(err);
    
    res = [p parse:@"select id from account where name = 'bob' AND msp__c excludes('A')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM account WHERE (name = 'bob' AND msp__c EXCLUDES ('A'))");
    XCTAssertNil(err);

    [p parse:@"select id from account where name = 'bob' AND msp__c excludes bob" error:&err];
    assertStringsEq(err.localizedDescription, @"Unexpected input 'AND msp__c excludes bob' at position 43");
}

-(void)testWhereInNotIn {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from account where name = 'bob' AND city IN ('SF','LA')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM account WHERE (name = 'bob' AND city IN ('SF','LA'))");
    XCTAssertNil(err);
    
    res = [p parse:@"select id from account where name = 'bob' AND city not    in ('SF','LA')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM account WHERE (name = 'bob' AND city NOT IN ('SF','LA'))");
    XCTAssertNil(err);

    res = [p parse:@"select id from account where name = 'bob' AND not city not    in ('SF','LA')" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM account WHERE (name = 'bob' AND (NOT city NOT IN ('SF','LA')))");
    XCTAssertNil(err);

    res = [p parse:@"SELECT Id FROM Task WHERE WhoId IN ( SELECT  Id FROM Contact WHERE MailingCity = 'Twin Falls')" error:&err];
    assertStringsEq([res toSoql], @"SELECT Id FROM Task WHERE WhoId IN (SELECT Id FROM Contact WHERE MailingCity = 'Twin Falls')");
    XCTAssertNil(err);

    res = [p parse:@"SELECT Id FROM Task WHERE WhoId NOT IN ( SELECT  Id FROM Contact WHERE MailingCity = 'Twin Falls')" error:&err];
    assertStringsEq([res toSoql], @"SELECT Id FROM Task WHERE WhoId NOT IN (SELECT Id FROM Contact WHERE MailingCity = 'Twin Falls')");
    XCTAssertNil(err);
}

-(void)testNestedFuncs {
    NSError *err = nil;
    SelectQuery *res = [p parse:  @"SELECT HOUR_IN_DAY(convertTimezone(CreatedDate)) hour, SUM(Amount) amt FROM Opportunity" error:&err];
    assertStringsEq([res toSoql], @"SELECT HOUR_IN_DAY(convertTimezone(CreatedDate)) hour,SUM(Amount) amt FROM Opportunity");
    XCTAssertNil(err);
    
    res = [p parse:  @"SELECT HOUR_IN_DAY ( convertTimezone ( CreatedDate ) ) hour, SUM(Amount) amt FROM Opportunity" error:&err];
    assertStringsEq([res toSoql], @"SELECT HOUR_IN_DAY(convertTimezone(CreatedDate)) hour,SUM(Amount) amt FROM Opportunity");
    XCTAssertNil(err);
}

-(void)testGroupBy {
    NSError *err = nil;
    SelectQuery *res =[p parse:@"SELECT account.name,count(id) from case group by account.name" error:&err];
    assertStringsEq(res.toSoql, @"SELECT account.name,count(id) FROM case GROUP BY account.name");
    XCTAssertNil(err);

    res = [p parse:@"SELECT calendar_year(createdDate) yr, count(id) cnt  from case group by calendar_year(createdDate)" error:&err];
    assertStringsEq(res.toSoql, @"SELECT calendar_year(createdDate) yr,count(id) cnt FROM case GROUP BY calendar_year(createdDate)");
    XCTAssertNil(err);

    res = [p parse:@"SELECT calendar_year(createdDate) yr, count(id) cnt  from case group by calendar_year(createdDate), createdBy.alias" error:&err];
    assertStringsEq(res.toSoql, @"SELECT calendar_year(createdDate) yr,count(id) cnt FROM case GROUP BY calendar_year(createdDate),createdBy.alias");
    XCTAssertNil(err);
}

-(void)testOrderBy {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact order by name desc, city asc nulls last" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact ORDER BY name DESC,city ASC NULLS LAST");
    XCTAssertNil(err);
    
    res = [p parse:@"select id from contact order by name desc, city nulls first" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact ORDER BY name DESC,city ASC NULLS FIRST");
    XCTAssertNil(err);

    res = [p parse:@"SELECT id FROM contact ORDER BY name DESC,calendar_year(createdDate) ASC NULLS FIRST" error:&err];
    assertStringsEq([res toSoql], @"SELECT id FROM contact ORDER BY name DESC,calendar_year(createdDate) ASC NULLS FIRST");
    XCTAssertNil(err);
}

-(void)testGroupByOrderBy {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"SELECT calendar_year(createdDate) yr,count(id) cnt FROM case GROUP BY calendar_year(createdDate),createdBy.alias ORDER BY calendar_year(createdDate)" error:&err];
    assertStringsEq(res.toSoql,@"SELECT calendar_year(createdDate) yr,count(id) cnt FROM case GROUP BY calendar_year(createdDate),createdBy.alias ORDER BY calendar_year(createdDate) ASC");
    XCTAssertNil(err);
}

-(void)testWhereOrderBy {
    NSError *err = nil;
    SelectQuery *res = [p parse:@"select id from contact where (name='bob')Order by createdDate desc" error:&err];
    assertStringsEq(res.toSoql,@"SELECT id FROM contact WHERE name = 'bob' ORDER BY createdDate DESC");
    XCTAssertNil(err);
}

@end
