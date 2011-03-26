//
//  ImportableDatabase.h
//
//
//  Created by Dustin Sallings on 3/19/11.
//  Copyright 2011 NorthScale. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ImportableDatabase : NSObject {
@private
    NSString *_name;
    BOOL _shouldImport;

    size_t _totalSize;
    size_t _copiedSize;
}

-(id)initWithName:(NSString *)n size:(NSNumber*)s;

-(NSString *)name;
-(BOOL)shouldImport;

-(NSString *)pathFrom:(NSString*)base;

-(NSString *)description;

-(size_t)totalSize;
-(void)copiedSize:(size_t)to;
-(size_t)copiedSize;

@end
