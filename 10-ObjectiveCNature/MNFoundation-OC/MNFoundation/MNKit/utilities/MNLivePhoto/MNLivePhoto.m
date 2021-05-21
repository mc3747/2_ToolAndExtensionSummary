//
//  MNLivePhoto.m
//  MNKit
//
//  Created by Vincent on 2019/12/14.
//  Copyright © 2019 Vincent. All rights reserved.
//

#import "MNLivePhoto.h"
#if __has_include(<Photos/PHLivePhoto.h>)
#import "MNJPEG.h"
#import "MNQuickTime.h"
#import <Photos/PHLivePhoto.h>

@implementation MNLivePhoto
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_1
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
+ (void)requestLivePhotoWithVideoResourceOfPath:(NSString *)videoPath
                              completionHandler:(void(^)(MNLivePhoto *livePhoto))completionHandler
{
    [self requestLivePhotoWithVideoResourceOfPath:videoPath
                                  progressHandler:nil
                                completionHandler:completionHandler];
}

+ (void)requestLivePhotoWithVideoResourceOfPath:(NSString *)videoPath
                                progressHandler:(void(^)(float  progress))progressHandler
                              completionHandler:(void(^)(MNLivePhoto *livePhoto))completionHandler
{
    [self requestLivePhotoWithVideoPath:videoPath progressHandler:^(float progress) {
        if (progressHandler) progressHandler(MIN(.99f, progress));
    } completionHandler:^(NSString *jpgPath, NSString *movPath) {
        if (jpgPath && movPath) {
            UIImage *image = [UIImage imageWithContentsOfFile:jpgPath];
            [PHLivePhoto requestLivePhotoWithResourceFileURLs:@[[NSURL fileURLWithPath:jpgPath], [NSURL fileURLWithPath:movPath]] placeholderImage:image targetSize:image.size contentMode:PHImageContentModeAspectFit resultHandler:^(PHLivePhoto * _Nullable livePhoto, NSDictionary * _Nonnull info) {
                if (livePhoto) {
                    if ([[info objectForKey:@"PHLivePhotoInfoIsDegradedKey"] boolValue]) return;
                    if ([livePhoto valueForKey:@"videoAsset"] && [livePhoto valueForKey:@"image"]) {
                        MNLivePhoto *photo = [MNLivePhoto new];
                        photo->_imagePath = jpgPath;
                        photo->_videoPath = movPath;
                        photo->_content = livePhoto;
                        if (progressHandler) progressHandler(1.f);
                        if (completionHandler) completionHandler(photo);
                    } else {
                        [NSFileManager.defaultManager removeItemAtPath:jpgPath error:nil];
                        [NSFileManager.defaultManager removeItemAtPath:movPath error:nil];
                        if (completionHandler) completionHandler(nil);
                    }
                } else {
                    [NSFileManager.defaultManager removeItemAtPath:jpgPath error:nil];
                    [NSFileManager.defaultManager removeItemAtPath:movPath error:nil];
                    if (completionHandler) completionHandler(nil);
                }
            }];
        } else {
            if (completionHandler) completionHandler(nil);
        }
    }];
}
#pragma clang diagnostic pop
#endif

+ (void)requestLivePhotoWithVideoPath:(NSString *)videoPath
                    completionHandler:(void(^)(NSString *jpgPath, NSString *movPath))completionHandler
{
    [self requestLivePhotoWithVideoPath:videoPath
                        progressHandler:nil
                      completionHandler:completionHandler];
}

+ (void)requestLivePhotoWithVideoPath:(NSString *)videoPath
                      progressHandler:(void(^)(float  progress))progressHandler
                    completionHandler:(void(^)(NSString *jpgPath, NSString *movPath))completionHandler
{
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:videoPath isDirectory:&isDirectory] || isDirectory) {
        NSLog(@"video path error");
        if (completionHandler) completionHandler(nil, nil);
        return;
    }
    // 获取截图
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoPath] options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@(YES)}];
    __block CGSize naturalSize = CGSizeZero;
    [videoAsset.tracks enumerateObjectsUsingBlock:^(AVAssetTrack * _Nonnull track, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([track.mediaType isEqualToString:AVMediaTypeVideo]) {
            naturalSize = CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform);
            naturalSize.width = fabs(naturalSize.width);
            naturalSize.height = fabs(naturalSize.height);
            *stop = YES;
        }
    }];
    if (CGSizeEqualToSize(naturalSize, CGSizeZero)) {
        NSLog(@"video natural size error");
        if (completionHandler) completionHandler(nil, nil);
        return;
    }
    // 获取封面图片
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:videoAsset];
    generator.appliesPreferredTrackTransform = YES;
    generator.requestedTimeToleranceBefore = kCMTimeZero;
    generator.requestedTimeToleranceAfter = kCMTimeZero;
    generator.maximumSize = naturalSize;
    CGImageRef imageRef = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(.01f, videoAsset.duration.timescale) actualTime:NULL error:NULL];
    if (!imageRef) {
        NSLog(@"video thumbnail error");
        if (completionHandler) completionHandler(nil, nil);
        return;
    }
    UIImage *thumbnailImage = [UIImage imageWithCGImage:imageRef];
    // 标识
    NSString *identifier = NSUUID.UUID.UUIDString;
    identifier = [identifier stringByReplacingOccurrencesOfString:@"-" withString:@""];
    // JPG图片
    NSString *jpgPath = [self generateFilePathWithName:identifier extension:@"JPG"];
    MNJPEG *JPEG = [[MNJPEG alloc] initWithImage:thumbnailImage];
    if ([JPEG writeToFile:jpgPath withIdentifier:identifier] == NO) {
        NSLog(@"write jpeg error");
        if (completionHandler) completionHandler(nil, nil);
        return;
    }
    // MOV视频
    NSString *movPath = [self generateFilePathWithName:identifier extension:@"MOV"];
    MNQuickTime *QuickTime = [[MNQuickTime alloc] initWithVideoAsset:videoAsset];
    [QuickTime writeToFileAsynchronously:movPath withIdentifier:identifier progressHandler:progressHandler completionHandler:^(BOOL succeed) {
        if (completionHandler) if (completionHandler) completionHandler(succeed?jpgPath:nil, succeed?movPath:nil);
    }];
}

+ (NSString *)generateFilePathWithName:(NSString *)name extension:(NSString *)extension {
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [directories.lastObject stringByAppendingPathComponent:[NSString stringWithFormat:@"MNLivePhoto/%@.%@", name, extension]];
}

- (void)removeContents {
    [NSFileManager.defaultManager removeItemAtPath:self.videoPath error:nil];
    [NSFileManager.defaultManager removeItemAtPath:self.imagePath error:nil];
}

@end
#endif
