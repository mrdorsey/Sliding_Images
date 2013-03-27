//
//  UIImage+UWExtensions.h
//  UW-iOS-HW7
//
//  Created by Tim Ekl on 3/10/13.
//  Copyright (c) 2013 Tim Ekl. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (UWExtensions)

- (UIImage *)scaledImageWithSize:(CGSize)size;
    // does fitting while keeping aspect ratio

@end
