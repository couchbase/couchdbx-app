//
//  LoginItemManager.h
//  AppHider
//
//  Created by Dustin Sallings on 3/23/11.
//

#import <Foundation/Foundation.h>


@interface LoginItemManager : NSObject {
@private

}

-(BOOL)inLoginItems;
-(void)removeLoginItem:(id)sender;
-(void)addToLoginItems:(id)sender;

@end
