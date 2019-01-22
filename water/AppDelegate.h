//
//  AppDelegate.h
//  water
//
//  Created by Wong Tom on 2018-12-15.
//  Copyright © 2018 Wang Tom. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

