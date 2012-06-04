//
//  ImportableDatabase.m
//
//
//  Created by Dustin Sallings on 3/19/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "ImportableDatabase.h"


@implementation ImportableDatabase

- (id)initWithName:(NSString *)n size:(NSNumber*)s {
    self = [super init];
    if (self) {
        _name = [n retain];
        _shouldImport = YES;
        _totalSize = (size_t)[s longLongValue];
        _copiedSize = 0;
    }

    return self;
}

- (void)dealloc
{
    [_name release];
    [super dealloc];
}

-(NSString *)name {
    return [_name stringByDeletingPathExtension];
}

-(NSString *)pathFrom:(NSString*)base {
    return [base stringByAppendingPathComponent:_name];
}

-(BOOL)shouldImport {
    return _shouldImport;
}

-(void)shouldImport:(BOOL)to {
    _shouldImport = to;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"<ImportableDatabase %@ - %s>",
            _name, _shouldImport ? "YES" : "NO"];
}

-(size_t)totalSize {
    return _totalSize;
}

-(void)copiedSize:(size_t)to {
    _copiedSize = to;
}

-(size_t)copiedSize {
    return _copiedSize;
}

@end
