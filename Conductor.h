//
//  Conductor.h
//  Conductor
//
//  Created by austin on 10/7/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//

#import <TargetConditionals.h>

#ifdef TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

//! Project version number for Conductor.
FOUNDATION_EXPORT double ConductorVersionNumber;

//! Project version string for Conductor.
FOUNDATION_EXPORT const unsigned char ConductorVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <Conductor/PublicHeader.h>


