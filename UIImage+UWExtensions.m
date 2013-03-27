//
//  UIImage+UWExtensions.m
//  UW-iOS-HW7
//
//  Created by Tim Ekl on 3/10/13.
//  Copyright (c) 2013 Tim Ekl. All rights reserved.
//

#import "UIImage+UWExtensions.h"

@implementation UIImage (UWExtensions)

- (UIImage *)scaledImageWithSize:(CGSize)size;
{
    // adapted from http://stackoverflow.com/questions/2658738/the-simplest-way-to-resize-an-uiimage
    
    CGSize imageSize = self.size;
    CGSize scalingFactors = (CGSize){.width = size.width / imageSize.width, .height = size.height / imageSize.height};
    CGFloat scalingFactor = MIN(scalingFactors.width, scalingFactors.height);
    CGSize desiredSize = (CGSize){.width = imageSize.width * scalingFactor, .height = imageSize.height * scalingFactor};
    
    UIGraphicsBeginImageContextWithOptions(desiredSize, NO, 0.0);
    [self drawInRect:CGRectMake(0, 0, desiredSize.width, desiredSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end
