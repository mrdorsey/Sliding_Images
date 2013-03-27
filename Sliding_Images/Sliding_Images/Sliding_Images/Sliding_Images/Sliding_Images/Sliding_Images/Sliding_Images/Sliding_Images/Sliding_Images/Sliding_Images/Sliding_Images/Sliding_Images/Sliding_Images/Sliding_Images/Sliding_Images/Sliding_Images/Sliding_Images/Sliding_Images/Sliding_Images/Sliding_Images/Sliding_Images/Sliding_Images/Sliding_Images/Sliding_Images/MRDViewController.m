//
//  MRDViewController.m
//  Sliding_Images
//
//  Created by Michael Dorsey on 3/24/13.
//  Copyright (c) 2013 Michael Dorsey. All rights reserved.
//

#import "MRDViewController.h"
#import "UIImage+UWExtensions.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreMotion/CoreMotion.h>
#import <MobileCoreServices/MobileCoreServices.h>

#define FRICITON 0.02f
#define UPDATE_INTERVAL 0.10

#define CLAMP(x, low, high) (((x) > (high)) ? (high) : (((x) < (low)) ? (low) : (x)))

@interface MRDViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate, AVAudioPlayerDelegate>

@property (nonatomic, strong) NSMutableArray *imageViews;

@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) NSOperationQueue *motionQueue;

@property (nonatomic, strong) NSMutableSet *edgeConstrainedImageViews;
@property (nonatomic, strong) NSMutableSet *activeAudioPlayers;

@end

@implementation MRDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// init arrays and sets
	
	self.imageViews = [NSMutableArray array];
	
	self.motionManager = [[CMMotionManager alloc] init];
    self.motionQueue = [[NSOperationQueue alloc] init];
	
	self.edgeConstrainedImageViews = [NSMutableSet set];
	self.activeAudioPlayers = [NSMutableSet set];
	
	self.motionManager.accelerometerUpdateInterval = UPDATE_INTERVAL;
	[self.motionManager startAccelerometerUpdatesToQueue:self.motionQueue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
		[self _updateImagePos:accelerometerData.acceleration];
	}];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
	
	[self.imageViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
	self.imageViews = [NSMutableArray array];
	self.edgeConstrainedImageViews = [NSMutableSet set];
}

- (IBAction)addImage:(id)sender;
{	
	// maybe put this in available source types helper?, filtered array using predicate?
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Add Image", nil)
													   delegate:self
											  cancelButtonTitle:nil
										 destructiveButtonTitle:nil
											  otherButtonTitles:nil];
	
	for (NSNumber *typeNumber in [self _availableSourceTypes]) {
		UIImagePickerControllerSourceType sourceType = [typeNumber unsignedIntegerValue];
		[sheet addButtonWithTitle:[self _nameForSourceType:sourceType]];
	}

	[sheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
	[sheet setCancelButtonIndex:sheet.numberOfButtons - 1];
	[sheet showInView:self.view];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info;
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    NSLog(@"%@", info[UIImagePickerControllerMediaType]);
    if (!UTTypeConformsTo((__bridge CFStringRef)(info[UIImagePickerControllerMediaType]), kUTTypeImage))
        return;
    
	UIImage *image = info[UIImagePickerControllerEditedImage];
	if (image == nil) {
		image = info[UIImagePickerControllerOriginalImage];
	}
	if (image == nil) {
		return; // no image available
	}
	
	CGSize size = (CGSize){.width = 50.0f, .height = 50.0f};
	UIImageView *imageView = [[UIImageView alloc] initWithFrame:(CGRect){.origin = CGPointZero, .size = size}];
	
	imageView.contentMode = UIViewContentModeScaleAspectFill;
	imageView.image = [image scaledImageWithSize:size];
	[imageView sizeToFit];
	imageView.center = self.view.center;

	[self.imageViews addObject:imageView];
	[self.view addSubview:imageView];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
{
	[picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - AVAudioPlayerDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag;
{
	player.delegate = nil;
	[self.activeAudioPlayers removeObject:player];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex;
{
	if (buttonIndex == actionSheet.cancelButtonIndex) {
		return;
	}
	
	UIImagePickerControllerSourceType sourceType = [[[self _availableSourceTypes] objectAtIndex:buttonIndex] unsignedIntegerValue];
	
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
	imagePicker.sourceType = sourceType;
	imagePicker.delegate = self;
	[self presentViewController:imagePicker animated:YES completion:nil];
}

#pragma mark - private helpers
- (NSArray *)_sourceTypes;
{
	return @[ @(UIImagePickerControllerSourceTypeCamera), @(UIImagePickerControllerSourceTypePhotoLibrary) ];
}

- (NSArray *)_availableSourceTypes;
{
	return [[self _sourceTypes] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
		NSAssert([evaluatedObject isKindOfClass:[NSNumber class]], @"Expected source type to be NSNumber instance");
		UIImagePickerControllerSourceType sourceType = [evaluatedObject unsignedIntegerValue];
		return [UIImagePickerController isSourceTypeAvailable:sourceType];
	}]];
}

- (NSString *)_nameForSourceType:(UIImagePickerControllerSourceType)sourceType;
{
	switch (sourceType) {
		case UIImagePickerControllerSourceTypeCamera: return NSLocalizedString(@"Camera", nil);
		case UIImagePickerControllerSourceTypePhotoLibrary: return NSLocalizedString(@"Photo Library", nil);
		case UIImagePickerControllerSourceTypeSavedPhotosAlbum: return NSLocalizedString(@"Camera Roll", nil);
		default: return nil;
	}
}

- (void)_updateImagePos:(CMAcceleration)accel;
{
    dispatch_async(dispatch_get_main_queue(), ^{
		__block BOOL click = NO;
		
		[UIView animateWithDuration:0.10f animations:^{						
			for (UIImageView *imageView in [self imageViews]) {
				CGPoint center = imageView.center;
				CGSize imageSize = imageView.bounds.size;
				
				// do acceleration adjustment
				center.x += floor(accel.x / FRICITON);
				center.y -= floor(accel.y / FRICITON);
				
				// ensure image is still inside frame
				CGFloat xMin = imageSize.width / 2.0f, xMax = self.view.bounds.size.width - imageSize.width / 2.0f;
				CGFloat yMin = imageSize.height / 2.0f, yMax = self.view.bounds.size.height - imageSize.height / 2.0f;
				center.x = CLAMP(center.x, xMin, xMax);
				center.y = CLAMP(center.y, yMin, yMax);
				
				BOOL hitEdge = NO;
				if (center.x == xMin || center.x == xMax || center.y == yMin || center.y == yMax) {
					hitEdge = YES;
				}
				
				BOOL alreadyHit = [self.edgeConstrainedImageViews containsObject:imageView];
				
				if (hitEdge && !alreadyHit) {
					[self.edgeConstrainedImageViews addObject:imageView];
					click = YES;
				}
				else if (!hitEdge && alreadyHit) {
					[self.edgeConstrainedImageViews removeObject:imageView];
				}
				
				imageView.center = center;
			}
		}];
		
		if (click) {
			[self _click];
		}
    });
}

- (void)_click;
{
	AVAudioPlayer *click = [[AVAudioPlayer alloc] initWithContentsOfURL:self._soundURL error:nil];
	[self.activeAudioPlayers addObject:click];
	[click play];
}

- (NSURL *)_soundURL;
{
	static NSURL *url = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"click" ofType:@"wav"]];
	});
					
	return url;
}

@end
