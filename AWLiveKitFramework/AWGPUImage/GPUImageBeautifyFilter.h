//
//  GPUImageBeautifyFilter.h
//  BeautifyFaceDemo
//
//  Created by guikz on 16/4/28.
//  Copyright © 2016年 guikz. All rights reserved.
//

#import <GPUImage/GPUImageFramework.h>

@class GPUImageCombinationFilter;

@interface GPUImageBeautifyFilter : GPUImageFilterGroup {
    GPUImageBilateralFilter *bilateralFilter;
    GPUImageCannyEdgeDetectionFilter *cannyEdgeFilter;
    GPUImageCombinationFilter *combinationFilter;
    GPUImageHSBFilter *hsbFilter;
    CGFloat _brightness;
    CGFloat _saturation;
    CGFloat _intensity;
    
}

@property (nonatomic,assign) CGFloat brightness;
@property (nonatomic,assign) CGFloat saturation;
@property (nonatomic,assign) CGFloat intensity;
-(void)setBeauty:(int)beauty;
@end
