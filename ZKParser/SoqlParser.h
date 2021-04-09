//
//  SoqlParser.h
//  ZKParser
//
//  Created by Simon Fell on 4/9/21.
//  Copyright © 2021 Simon Fell. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SelectQuery;

@interface SoqlParser : NSObject
-(SelectQuery*)parse:(NSString *)input error:(NSError**)err;
@end
