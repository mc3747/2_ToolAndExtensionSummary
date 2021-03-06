//
//  YLSOTPickerView.h
//  YLSPicker
//
//  Created by yulingsong on 16/9/1.
//  Copyright © 2016年 yulingsong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PlaceModel.h"

NS_ASSUME_NONNULL_BEGIN
typedef void(^TwoPickerBlock)(NSString * pickString);

@interface YLSTwoPickerView : UIView
/** dict */
@property (nonatomic,strong) NSMutableArray<Province*>  *array;
/** title */
@property (nonatomic,strong) NSString *title;
/** 回调block */
@property (nonatomic, copy) TwoPickerBlock pickBlock;
//快速创建
+(instancetype)pickerView;
//弹出
-(void)show;
@end
NS_ASSUME_NONNULL_END
