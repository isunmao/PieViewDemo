//
//  PieView.m
//  PieViewDemo
//
//  Created by john on 2017/6/21.
//  Copyright © 2017年 john. All rights reserved.
//

#import "PieView.h"
#import "PieViewAnimationLayer.h"

#define RGBColor(r, g, b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define RGBAColor(r, g, b ,a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:a]
#define RandColor RGBColor(arc4random_uniform(255), arc4random_uniform(255), arc4random_uniform(255))

@interface PieView()<CAAnimationDelegate>

@property (nonatomic) UIView *contentView;
@property (nonatomic, strong) CAShapeLayer *pieLayer;
@property (nonatomic, strong) NSMutableArray<PieViewAnimationLayer *> *animationLayerArr;
@property (nonatomic,assign) CGFloat startAngle;
@property (nonatomic,assign) CGFloat endAngle;
@property (nonatomic,assign) CGPoint centerPoint;
@property (nonatomic, assign) CGFloat totalValue;
@property (nonatomic, strong) NSMutableArray *colors;
@property (nonatomic, copy) ClickCallBack callBack;
@property (nonatomic, strong) UILabel *tipLabel;
@property (nonatomic, strong) PieViewAnimationLayer *currentLayer;
@property (nonatomic, strong) NSMutableArray *lineLayers;
@property (nonatomic, strong) NSMutableArray *textLayers;

@end

@implementation PieView

#pragma mark -- 懒加载
- (UILabel *)tipLabel {
    if (!_tipLabel) {
        _tipLabel = [[UILabel alloc] init];
        [self addSubview:_tipLabel];
    }
    return _tipLabel;
}

- (NSMutableArray *)lineLayers {
    if (!_lineLayers) {
        _lineLayers = [NSMutableArray array];
    }
    return _lineLayers;
}

- (NSMutableArray *)textLayers {
    if (!_textLayers) {
        _textLayers = [NSMutableArray array];
    }
    return _textLayers;
}

- (NSMutableArray *)animationLayerArr {
    if (!_animationLayerArr) {
        _animationLayerArr = [NSMutableArray array];
    }
    return _animationLayerArr;
}

- (NSMutableArray *)colors {
    if (!_colors) {
        _colors = [NSMutableArray array];
    }
    return _colors;
}

#pragma mark - init
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

-(void)awakeFromNib {
    [super awakeFromNib];
    [self setup];
}

- (void)setup {
    self.needAnimation = YES;
    self.pieLayer = [CAShapeLayer layer];
    [self.layer addSublayer:self.pieLayer];
}

- (void)setSectionCount:(NSArray *)sectionCount {
    NSAssert(sectionCount.count != 0, @"sectionCount must not be empty or nil");
    _sectionCount = sectionCount;
    [self.colors removeAllObjects];
    for (int i = 0; i < sectionCount.count; i ++) {
        [self.colors addObject:RandColor];
    }
}

- (NSArray<UIColor *> *)sectionColors {
    if (_sectionColors && (_sectionColors.count >= self.sectionCount.count)) {
        return _sectionColors;
    }
    return self.colors;
}

#pragma mark -- 默认值
- (CGFloat)radius {
    return _radius? _radius : 100.0;
}

- (CGFloat)offset {
    return _offset ? _offset : 15.0;
}

- (CGFloat)offsetSpace {
    return _offsetSpace ? _offsetSpace : 0.0;
}

- (CGFloat)startLineLength {
    return _startLineLength ? _startLineLength : 20.0;
}

- (CGFloat)endLineLength {
    return _endLineLength ? _endLineLength : 10.0 ;
}

- (UIFont *)font {
    return _font ? _font : [UIFont systemFontOfSize:14];
}

- (void)showWithBlock:(ClickCallBack)callBack {
    self.callBack = callBack;
    [self showPieView];
}

- (void)showPieView {
    CGFloat startAngle = -M_PI_2;
    CGFloat endAngle = 0.0;
    CGFloat radian = 0.0;
    
    CGPoint center = CGPointMake(self.frame.size.width * 0.5, self.frame.size.height * 0.5);
    self.centerPoint = center;
    CGFloat totalValue = 0.0;
    for (NSString *value in self.sectionCount) {
        totalValue += [value floatValue];
    }
    self.totalValue = totalValue;
    
    for (int i = 0; i < self.sectionCount.count; i ++) {
        radian = [self getRadianWithValue:[self.sectionCount[i] floatValue]
                               totalValue:totalValue];
        endAngle = startAngle + radian;
        self.endAngle = endAngle;
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center
                                                            radius:self.radius
                                                        startAngle:startAngle
                                                          endAngle:endAngle
                                                         clockwise:YES];
        [path addLineToPoint:center];
        [path closePath];
        
        PieViewAnimationLayer *layer = [PieViewAnimationLayer layer];
        layer.startAngle = startAngle;
        layer.endAngle = endAngle;
        layer.centerPoint = center;
        layer.radius = self.radius;
        layer.clickOffset = self.offset;
        layer.path = path.CGPath;
        layer.fillColor = self.sectionColors[i].CGColor;
        [self.animationLayerArr addObject:layer];
        [self.pieLayer addSublayer:layer];
        
        startAngle = endAngle;
        self.startAngle = startAngle;
    }
    
    if (!self.needAnimation) {
        [self drawLineAndText];
        return;
    }
    [self addMaskAnimation];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    // 动画结束，显示折线和文字
    [self drawLineAndText];
}

- (void)updatePieView {
    
    for (CALayer *layer in self.animationLayerArr) {
        [layer removeFromSuperlayer];
    }
    [self.animationLayerArr removeAllObjects];
    
    for (CALayer *layer in self.textLayers) {
        [layer removeFromSuperlayer];
    }
    [self.textLayers removeAllObjects];
    
    for (CALayer *layer in self.lineLayers) {
        [layer removeFromSuperlayer];
    }
    [self.lineLayers removeAllObjects];
    
    self.tipLabel.hidden = YES;

    [self showPieView];
}

- (void)addMaskAnimation {
    CGFloat radius = self.radius;
    CGFloat borderWidth = self.radius * 2;
    CAShapeLayer *maskLayer = [self newCircleLayerWithRadius:radius
                                                 borderWidth:borderWidth
                                                   fillColor:[UIColor clearColor]
                                                 borderColor:RandColor
                                             startPercentage:0
                                               endPercentage:1];
    self.pieLayer.mask = maskLayer;
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    animation.duration  = 3;
    animation.fromValue = @0;
    animation.toValue   = @1;
    animation.delegate = self;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.removedOnCompletion = YES;
    [maskLayer addAnimation:animation forKey:@"circleAnimation"];
}

- (CAShapeLayer *)newCircleLayerWithRadius:(CGFloat)radius
                               borderWidth:(CGFloat)borderWidth
                                 fillColor:(UIColor *)fillColor
                               borderColor:(UIColor *)borderColor
                           startPercentage:(CGFloat)startPercentage
                             endPercentage:(CGFloat)endPercentage{
    
    CAShapeLayer *layer = [CAShapeLayer layer];
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center
                                                        radius:radius
                                                    startAngle:-M_PI_2
                                                      endAngle:M_PI_2 * 3
                                                     clockwise:YES];
    layer.fillColor   = fillColor.CGColor;
    layer.strokeColor = borderColor.CGColor;
    layer.strokeStart = startPercentage;
    layer.strokeEnd   = endPercentage;
    layer.lineWidth   = borderWidth;
    layer.path        = path.CGPath;
    
    return layer;
}

- (void)drawLineAndText {
    if (!self.lineTexts) { return; }
    if (self.lineTexts.count < self.sectionCount.count) { return; }
    
    NSArray *strs = self.lineTexts;
    CGFloat radian = 0.0;
    
    CGFloat startLineX = 0.0;
    CGFloat startLineY = 0.0;
    
    CGFloat kneeLineX = 0.0;
    CGFloat kneeLineY = 0.0;
    
    CGFloat endLineX = 0.0;
    CGFloat endLineY = 0.0;
    
    CGFloat textX = 0.0;
    CGFloat textY = 0.0;
    
    CGFloat lineStartAngle = 0.0;
    CGFloat midAngle = 0.0;
    
    CGSize textSize;
    
    for (int i = 0; i < self.sectionCount.count; i ++) {
        
        radian = [self getRadianWithValue:[self.sectionCount[i] floatValue]
                               totalValue:self.totalValue];
        
        midAngle = lineStartAngle + radian * 0.5;
        
        startLineX = self.centerPoint.x + sin(midAngle) * (self.offsetSpace + self.radius);
        startLineY = self.centerPoint.y - cos(midAngle) * (self.offsetSpace + self.radius);
        
        kneeLineX = self.centerPoint.x + sin(midAngle) * (self.offsetSpace + self.radius + self.startLineLength);
        kneeLineY = self.centerPoint.y - cos(midAngle) * (self.offsetSpace + self.radius + self.startLineLength);
        
        lineStartAngle += radian;
        
        textSize = [strs[i] sizeWithAttributes:@{NSFontAttributeName: self.font}];
        if (startLineX > self.centerPoint.x) {
            endLineX = kneeLineX + self.endLineLength;
            endLineY = kneeLineY;
            
            textX = endLineX + 5;
            textY = endLineY - textSize.height * 0.5;
        } else {
            endLineX = kneeLineX - self.endLineLength;
            endLineY = kneeLineY;
            
            textX = endLineX - textSize.width - 5;
            textY = endLineY - textSize.height * 0.5;
        }
        
        // 折线
        [self drawLineWithStartPoint:CGPointMake(startLineX, startLineY)
                           kneePoint:CGPointMake(kneeLineX, kneeLineY)
                            endPoint:CGPointMake(endLineX, endLineY)
                           lineColor:self.sectionColors[i]];
        // 文本内容
        [self drawText:strs[i] withFrame:CGRectMake(textX, textY, textSize.width, textSize.height)];
        
    }
}

- (void)drawLineWithStartPoint:(CGPoint)startPoint
                     kneePoint:(CGPoint)kneePoint
                      endPoint:(CGPoint)endPoint
                     lineColor:(UIColor *)lineColor {
    UIBezierPath *linePath = [UIBezierPath bezierPath];
    [linePath moveToPoint:startPoint];
    [linePath addLineToPoint:kneePoint];
    [linePath addLineToPoint:endPoint];
    linePath.lineWidth = 1;
    
    CAShapeLayer *lineLayer = [CAShapeLayer layer];
    lineLayer.path = linePath.CGPath;
    lineLayer.strokeColor = lineColor.CGColor;
    lineLayer.fillColor = [UIColor clearColor].CGColor;
    [self.lineLayers addObject:lineLayer];
    [self.layer addSublayer:lineLayer];
}

- (void)drawText:(NSString *)str withFrame:(CGRect)frame {
    CATextLayer *textLayer = [CATextLayer layer];
    textLayer.string = str;
    textLayer.frame = frame;
    textLayer.fontSize = self.font.pointSize;
    textLayer.alignmentMode = kCAAlignmentLeft;
    textLayer.foregroundColor = [UIColor colorWithWhite:0 alpha:0.8].CGColor;
    [self.textLayers addObject:textLayer];
    [self.layer addSublayer:textLayer];
}

- (CGFloat)getRadianWithValue:(CGFloat)value totalValue:(CGFloat)totalValue {
    CGFloat scale = value / totalValue;
    CGFloat radian = scale * M_PI * 2;
    return radian;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    UITouch *touch = [touches anyObject];
    CGPoint currentP = [touch locationInView:self];
    
    [self.animationLayerArr enumerateObjectsUsingBlock:^(PieViewAnimationLayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if (CGPathContainsPoint(obj.path, NULL, currentP, YES)) {
            obj.isSelected = !obj.isSelected;
            self.currentLayer = obj;
            if (self.callBack) { self.callBack(idx); }
            [self drawTextWithTitle:self.lineTexts[idx]
                          textColor:self.sectionColors[idx]
                         textCenter:currentP
                             isShow:!obj.isSelected];
            return ;
        } else {
            obj.isSelected = NO;
        }
        
    }];
    
    if (!self.currentLayer.isSelected) {
        self.tipLabel.hidden = YES;
    }
}

/*
 添加UILabel
 */

- (void)drawTextWithTitle:(NSString *)title
                textColor:(UIColor *)textColor
               textCenter:(CGPoint)textCenter
                   isShow:(BOOL)isShow {
    self.tipLabel.text = title;
    [self.tipLabel sizeToFit];
    [UIView animateWithDuration:0.5 animations:^{
        self.tipLabel.center = textCenter;
    }];
    [self.tipLabel sizeToFit];
    self.tipLabel.hidden = isShow;
    self.tipLabel.textColor = textColor;
    self.tipLabel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.8];
    self.tipLabel.textAlignment = NSTextAlignmentCenter;
    
    self.tipLabel.layer.bounds = CGRectMake(0, 0, self.tipLabel.bounds.size.width + 10, self.tipLabel.bounds.size.height + 10);
    self.tipLabel.layer.borderWidth = 1;
    self.tipLabel.layer.borderColor = textColor.CGColor;
}

@end
