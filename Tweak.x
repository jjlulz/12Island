#import <UIKit/UIKit.h>
#import <Contacts/Contacts.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end
@interface MTTimerManager : NSObject
- (id)timers;
@end
@interface MTTimer : NSObject
- (NSDate *)fireDate;
@end
@interface TUCall : NSObject
- (NSString *)displayName;
- (int)callStatus;
- (BOOL)isVideo;
- (NSString *)contactIdentifier;
@end
@interface TUCallCenter : NSObject
+ (instancetype)sharedInstance;
- (TUCall *)incomingCall;
- (NSArray *)currentCalls;
- (void)answerCall:(TUCall *)call;
- (void)answerCall:(TUCall *)call withSourceIdentifier:(NSString *)src;
- (void)disconnectCall:(TUCall *)call;
@end
@interface TUAudioSystemController : NSObject
+ (instancetype)sharedAudioSystemController;
@end
@interface UIWindow (DISecure)
- (void)_setSecure:(BOOL)secure;
@end
@interface NSObject (DIFuture)
- (void)addSuccessBlock:(void (^)(id))block;
@end

// MediaRemote (private) loaded at runtime so no linking is needed
typedef void (^DIInfoBlock)(CFDictionaryRef info);
typedef void (^DIPlayBlock)(Boolean playing);
static void (*MRRegister)(dispatch_queue_t);
static void (*MRGetInfo)(dispatch_queue_t, DIInfoBlock);
static void (*MRGetPlaying)(dispatch_queue_t, DIPlayBlock);
static Boolean (*MRSendCommand)(int, id);

#define DI_ORANGE [UIColor colorWithRed:1.0 green:0.62 blue:0.04 alpha:1]
#define DI_GREEN  [UIColor colorWithRed:0.19 green:0.82 blue:0.35 alpha:1]

static UIImage *DIIcon(NSString *n, CGSize s, UIColor *c) {
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:s];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [c setFill]; [c setStroke];
        CGFloat w = s.width, h = s.height;
        UIBezierPath *p = [UIBezierPath bezierPath];
        p.lineJoinStyle = kCGLineJoinRound; p.lineWidth = 3;
        if ([n isEqualToString:@"pause"]) {
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(w * 0.12, 0, w * 0.30, h) cornerRadius:3] fill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(w * 0.58, 0, w * 0.30, h) cornerRadius:3] fill];
        } else if ([n isEqualToString:@"play"]) {
            p.lineWidth = 4;
            [p moveToPoint:CGPointMake(w * 0.18, 2)]; [p addLineToPoint:CGPointMake(w * 0.9, h / 2)];
            [p addLineToPoint:CGPointMake(w * 0.18, h - 2)]; [p closePath]; [p fill]; [p stroke];
        } else if ([n isEqualToString:@"next"]) {
            [p moveToPoint:CGPointMake(2, 2)]; [p addLineToPoint:CGPointMake(w / 2, h / 2)]; [p addLineToPoint:CGPointMake(2, h - 2)]; [p closePath];
            [p moveToPoint:CGPointMake(w / 2, 2)]; [p addLineToPoint:CGPointMake(w - 2, h / 2)]; [p addLineToPoint:CGPointMake(w / 2, h - 2)]; [p closePath];
            [p fill]; [p stroke];
        } else if ([n isEqualToString:@"prev"]) {
            [p moveToPoint:CGPointMake(w - 2, 2)]; [p addLineToPoint:CGPointMake(w / 2, h / 2)]; [p addLineToPoint:CGPointMake(w - 2, h - 2)]; [p closePath];
            [p moveToPoint:CGPointMake(w / 2, 2)]; [p addLineToPoint:CGPointMake(2, h / 2)]; [p addLineToPoint:CGPointMake(w / 2, h - 2)]; [p closePath];
            [p fill]; [p stroke];
        } else if ([n isEqualToString:@"star"]) {
            p.lineWidth = 2;
            CGPoint ctr = CGPointMake(w / 2, h / 2 + 1);
            CGFloat R = w * 0.46, rr = R * 0.45;
            for (int i = 0; i < 10; i++) {
                CGFloat ang = -M_PI_2 + i * M_PI / 5;
                CGFloat rad = (i % 2 == 0) ? R : rr;
                CGPoint pt = CGPointMake(ctr.x + cos(ang) * rad, ctr.y + sin(ang) * rad);
                if (i == 0) [p moveToPoint:pt]; else [p addLineToPoint:pt];
            }
            [p closePath]; [p stroke];
        } else if ([n isEqualToString:@"decline"] || [n isEqualToString:@"accept"]) {
            CGContextRef g = ctx.CGContext;
            CGContextTranslateCTM(g, w / 2, h / 2);
            if ([n isEqualToString:@"accept"]) CGContextRotateCTM(g, -M_PI * 0.75);
            p.lineWidth = 6; p.lineCapStyle = kCGLineCapRound;
            [p addArcWithCenter:CGPointMake(0, 7) radius:10 startAngle:M_PI * 1.06 endAngle:M_PI * 1.94 clockwise:YES];
            [p stroke];
        } else if ([n isEqualToString:@"speaker"]) {
            p.lineWidth = 2;
            [p moveToPoint:CGPointMake(1, h * 0.36)]; [p addLineToPoint:CGPointMake(w * 0.26, h * 0.36)];
            [p addLineToPoint:CGPointMake(w * 0.5, h * 0.12)]; [p addLineToPoint:CGPointMake(w * 0.5, h * 0.88)];
            [p addLineToPoint:CGPointMake(w * 0.26, h * 0.64)]; [p addLineToPoint:CGPointMake(1, h * 0.64)];
            [p closePath]; [p fill]; [p stroke];
            UIBezierPath *a = [UIBezierPath bezierPath];
            a.lineWidth = 2; a.lineCapStyle = kCGLineCapRound;
            CGPoint ctr = CGPointMake(w * 0.5, h / 2);
            CGFloat rs[2] = {w * 0.22, w * 0.40};
            for (int i = 0; i < 2; i++) {
                CGPoint st = CGPointMake(ctr.x + cos(-M_PI * 0.3) * rs[i], ctr.y + sin(-M_PI * 0.3) * rs[i]);
                [a moveToPoint:st];
                [a addArcWithCenter:ctr radius:rs[i] startAngle:-M_PI * 0.3 endAngle:M_PI * 0.3 clockwise:YES];
            }
            [a stroke];
        } else if ([n isEqualToString:@"air"]) {
            p.lineWidth = 2; p.lineCapStyle = kCGLineCapRound;
            CGPoint ctr = CGPointMake(w / 2, h * 0.42);
            [p addArcWithCenter:ctr radius:w * 0.44 startAngle:M_PI * 0.75 endAngle:M_PI * 2.25 clockwise:YES];
            [p moveToPoint:CGPointMake(ctr.x + cos(M_PI * 0.75) * w * 0.26, ctr.y + sin(M_PI * 0.75) * w * 0.26)];
            [p addArcWithCenter:ctr radius:w * 0.26 startAngle:M_PI * 0.75 endAngle:M_PI * 2.25 clockwise:YES];
            [p stroke];
            UIBezierPath *t = [UIBezierPath bezierPath];
            [t moveToPoint:CGPointMake(w * 0.26, h - 1)]; [t addLineToPoint:CGPointMake(w * 0.74, h - 1)];
            [t addLineToPoint:CGPointMake(w / 2, h * 0.62)]; [t closePath]; [t fill];
        }
    }];
}

static NSString *DIClock(NSTimeInterval t) {
    int s = (int)MAX(0, floor(t));
    return [NSString stringWithFormat:@"%d:%02d", s / 60, s % 60];
}

@interface DIWindow : UIWindow
@end
@implementation DIWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    return (v == self || v == self.rootViewController.view) ? nil : v;
}
@end

typedef NS_ENUM(NSInteger, DIMode) { DIModeCompact, DIModeMedia, DIModeCharging, DIModeCall };

@interface DIController : UIViewController
@property (nonatomic, strong) UIView *pill;
@property (nonatomic, strong) UIImageView *art;
@property (nonatomic, strong) UILabel *titleLabel, *artistLabel, *timerLabel, *chargeLabel, *pctLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIView *lockIcon, *timerIcon, *dot, *battery, *batteryFill;
@property (nonatomic, assign) BOOL expanded, playing, locked, recording, plugged, chargeFlash;
@property (nonatomic, strong) NSDate *timerEnd;
@property (nonatomic, copy) NSString *lastTitle, *lastSig;
@property (nonatomic, strong) NSTimer *collapseTimer, *chargeTimer, *tickTimer;
@property (nonatomic, strong) id timerMgr;
@property (nonatomic, assign) NSInteger tickCount;
@property (nonatomic, strong) UIButton *prevButton, *nextButton, *starButton, *airButton;
@property (nonatomic, strong) UILabel *elapsedLabel, *remainLabel, *badge;
@property (nonatomic, strong) UIView *track, *trackFill, *wave;
@property (nonatomic, assign) double elapsed, duration, rate;
@property (nonatomic, strong) NSDate *stamp;
@property (nonatomic, assign) BOOL trackExplicit;
@property (nonatomic, strong) UIImageView *callAvatar;
@property (nonatomic, strong) UILabel *callInitials, *callKind, *callName;
@property (nonatomic, strong) UIButton *acceptButton, *declineButton;
@property (nonatomic, strong) id incomingCall;
@property (nonatomic, strong) id activeCall;
@property (nonatomic, strong) NSDate *callStart;
@property (nonatomic, strong) UIButton *speakerButton;
@property (nonatomic, assign) BOOL speakerOn;
@end

@implementation DIController

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = UIColor.clearColor;
}

- (UILabel *)labelWithFont:(UIFont *)f color:(UIColor *)c {
    UILabel *l = [UILabel new];
    l.font = f; l.textColor = c;
    [self.pill addSubview:l];
    return l;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.pill = [UIView new];
    self.pill.backgroundColor = UIColor.blackColor;
    self.pill.clipsToBounds = YES;
    [self.view addSubview:self.pill];

    self.art = [UIImageView new];
    self.art.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    self.art.clipsToBounds = YES;
    self.art.contentMode = UIViewContentModeScaleAspectFill;
    [self.pill addSubview:self.art];

    self.titleLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:16] color:UIColor.whiteColor];
    self.artistLabel = [self labelWithFont:[UIFont systemFontOfSize:16] color:[UIColor colorWithWhite:0.55 alpha:1]];
    self.timerLabel = [self labelWithFont:[UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold] color:DI_ORANGE];
    self.timerLabel.textAlignment = NSTextAlignmentRight;
    self.chargeLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:13] color:UIColor.whiteColor];
    self.chargeLabel.text = @"Charging";
    self.pctLabel = [self labelWithFont:[UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightSemibold] color:DI_GREEN];
    self.pctLabel.textAlignment = NSTextAlignmentRight;

    UIColor *grey = [UIColor colorWithWhite:0.6 alpha:1];
    self.playButton = [self iconButton:@selector(togglePlay)];
    self.prevButton = [self iconButton:@selector(prevTrack)];
    self.nextButton = [self iconButton:@selector(nextTrack)];
    self.starButton = [self iconButton:nil];
    self.airButton = [self iconButton:nil];
    [self.prevButton setImage:DIIcon(@"prev", CGSizeMake(38, 24), UIColor.whiteColor) forState:UIControlStateNormal];
    [self.nextButton setImage:DIIcon(@"next", CGSizeMake(38, 24), UIColor.whiteColor) forState:UIControlStateNormal];
    [self.starButton setImage:DIIcon(@"star", CGSizeMake(26, 26), grey) forState:UIControlStateNormal];
    [self.airButton setImage:DIIcon(@"air", CGSizeMake(30, 28), grey) forState:UIControlStateNormal];
    [self updatePlayIcon];

    self.track = [UIView new];
    self.track.backgroundColor = [UIColor colorWithWhite:1 alpha:0.22];
    self.track.layer.cornerRadius = 2.5; self.track.clipsToBounds = YES;
    self.trackFill = [UIView new];
    self.trackFill.backgroundColor = [UIColor colorWithWhite:1 alpha:0.65];
    [self.track addSubview:self.trackFill];
    [self.pill addSubview:self.track];
    UIFont *mono = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium];
    self.elapsedLabel = [self labelWithFont:mono color:grey];
    self.remainLabel = [self labelWithFont:mono color:grey];
    self.remainLabel.textAlignment = NSTextAlignmentRight;

    self.badge = [self labelWithFont:[UIFont boldSystemFontOfSize:10] color:UIColor.blackColor];
    self.badge.text = @"E"; self.badge.textAlignment = NSTextAlignmentCenter;
    self.badge.backgroundColor = [UIColor colorWithWhite:0.65 alpha:1];
    self.badge.layer.cornerRadius = 3; self.badge.clipsToBounds = YES; self.badge.alpha = 0;

    self.wave = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 27, 22)];
    CGFloat hs[5] = {12, 20, 16, 22, 10};
    for (int i = 0; i < 5; i++) {
        UIView *b = [[UIView alloc] initWithFrame:CGRectMake(i * 6, (22 - hs[i]) / 2, 3, hs[i])];
        b.backgroundColor = grey; b.layer.cornerRadius = 1.5;
        [self.wave addSubview:b];
    }
    [self.pill addSubview:self.wave];

    // incoming call views
    self.callAvatar = [UIImageView new];
    self.callAvatar.backgroundColor = [UIColor colorWithWhite:0.35 alpha:1];
    self.callAvatar.layer.cornerRadius = 22; self.callAvatar.clipsToBounds = YES;
    self.callAvatar.contentMode = UIViewContentModeScaleAspectFill;
    [self.pill addSubview:self.callAvatar];
    self.callInitials = [UILabel new];
    self.callInitials.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    self.callInitials.textColor = UIColor.whiteColor;
    self.callInitials.textAlignment = NSTextAlignmentCenter;
    self.callInitials.frame = CGRectMake(0, 0, 44, 44);
    [self.callAvatar addSubview:self.callInitials];
    self.callKind = [self labelWithFont:[UIFont systemFontOfSize:12] color:[UIColor colorWithWhite:0.55 alpha:1]];
    self.callName = [self labelWithFont:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold] color:UIColor.whiteColor];
    self.declineButton = [self iconButton:@selector(declineCall)];
    self.declineButton.backgroundColor = [UIColor colorWithRed:1 green:0.27 blue:0.23 alpha:1];
    [self.declineButton setImage:DIIcon(@"decline", CGSizeMake(26, 26), UIColor.whiteColor) forState:UIControlStateNormal];
    self.acceptButton = [self iconButton:@selector(acceptCall)];
    self.acceptButton.backgroundColor = DI_GREEN;
    [self.acceptButton setImage:DIIcon(@"accept", CGSizeMake(26, 26), UIColor.whiteColor) forState:UIControlStateNormal];
    self.declineButton.layer.cornerRadius = self.acceptButton.layer.cornerRadius = 22;
    self.speakerButton = [self iconButton:@selector(toggleSpeaker)];
    self.speakerButton.layer.cornerRadius = 22;
    [self updateSpeakerIcon];

    // lock icon
    self.lockIcon = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 14)];
    UIView *shackle = [[UIView alloc] initWithFrame:CGRectMake(2, 0, 8, 10)];
    shackle.layer.borderColor = UIColor.whiteColor.CGColor;
    shackle.layer.borderWidth = 1.8; shackle.layer.cornerRadius = 4;
    UIView *body = [[UIView alloc] initWithFrame:CGRectMake(0, 5, 12, 9)];
    body.backgroundColor = UIColor.whiteColor; body.layer.cornerRadius = 2.5;
    [self.lockIcon addSubview:shackle]; [self.lockIcon addSubview:body];
    [self.pill addSubview:self.lockIcon];

    // timer icon
    self.timerIcon = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 16)];
    self.timerIcon.layer.borderColor = DI_ORANGE.CGColor;
    self.timerIcon.layer.borderWidth = 2; self.timerIcon.layer.cornerRadius = 8;
    UIView *hand = [[UIView alloc] initWithFrame:CGRectMake(7, 3, 2, 6)];
    hand.backgroundColor = DI_ORANGE; hand.layer.cornerRadius = 1;
    [self.timerIcon addSubview:hand];
    [self.pill addSubview:self.timerIcon];

    // recording dot
    self.dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 12)];
    self.dot.backgroundColor = [UIColor colorWithRed:1 green:0.23 blue:0.19 alpha:1];
    self.dot.layer.cornerRadius = 6;
    [self.pill addSubview:self.dot];

    // battery glyph
    self.battery = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 13)];
    UIView *outline = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 26, 13)];
    outline.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor;
    outline.layer.borderWidth = 1.5; outline.layer.cornerRadius = 4;
    UIView *nub = [[UIView alloc] initWithFrame:CGRectMake(27, 4, 2, 5)];
    nub.backgroundColor = [UIColor colorWithWhite:1 alpha:0.5];
    self.batteryFill = [[UIView alloc] initWithFrame:CGRectMake(2, 2, 22, 9)];
    self.batteryFill.backgroundColor = DI_GREEN; self.batteryFill.layer.cornerRadius = 2.5;
    [self.battery addSubview:outline]; [self.battery addSubview:nub]; [self.battery addSubview:self.batteryFill];
    [self.pill addSubview:self.battery];

    [self.pill addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)]];

    UIDevice.currentDevice.batteryMonitoringEnabled = YES;
    UIDeviceBatteryState s = UIDevice.currentDevice.batteryState;
    self.plugged = (s == UIDeviceBatteryStateCharging || s == UIDeviceBatteryStateFull);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryChanged)
                                                 name:UIDeviceBatteryStateDidChangeNotification object:nil];

    void *h = dlopen("/System/Library/PrivateFrameworks/MobileTimer.framework/MobileTimer", RTLD_NOW);
    (void)h;
    dlopen("/System/Library/PrivateFrameworks/TelephonyUtilities.framework/TelephonyUtilities", RTLD_NOW);

    [self relayout:NO];
    self.tickTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.tickTimer forMode:NSRunLoopCommonModes];
    [self tick];
}

#pragma mark layout

- (DIMode)mode {
    if (self.incomingCall || self.activeCall) return DIModeCall;
    return self.chargeFlash ? DIModeCharging : (self.expanded ? DIModeMedia : DIModeCompact);
}

- (void)relayout:(BOOL)animated {
    CGFloat W = self.view.bounds.size.width;
    DIMode mode = [self mode];
    BOOL timerOn = self.timerEnd != nil;
    // left slot: 0 none, 1 rec dot, 2 timer, 3 lock, 4 artwork
    int left = self.recording ? 1 : timerOn ? 2 : self.locked ? 3 : self.playing ? 4 : 0;
    CGRect f;
    if (mode == DIModeCall) f = CGRectMake(10, 6, W - 20, 62);
    else if (mode == DIModeMedia) f = CGRectMake(10, 8, W - 20, 160);
    else if (mode == DIModeCharging) { CGFloat w = MIN(W - 20, 230); f = CGRectMake((W - w) / 2, 4, w, 30); }
    else { CGFloat w = timerOn ? 190 : (left ? 130 : 112); f = CGRectMake((W - w) / 2, 4, w, 28); }

    void (^apply)(void) = ^{
        CGFloat w = f.size.width, h = f.size.height;
        BOOL media = mode == DIModeMedia, chg = mode == DIModeCharging, comp = mode == DIModeCompact;
        self.pill.frame = f;
        self.pill.layer.cornerRadius = media ? 30 : h / 2;

        self.art.frame = media ? CGRectMake(16, 18, 54, 54) : CGRectMake(9, (h - 20) / 2, 20, 20);
        self.art.layer.cornerRadius = media ? 12 : 6;
        self.art.alpha = (media || (comp && left == 4)) ? 1 : 0;

        [self layoutMedia];
        for (UIView *v in [self mediaViews]) v.alpha = media ? 1 : 0;
        self.badge.alpha = (media && self.trackExplicit) ? 1 : 0;

        BOOL callMode = mode == DIModeCall;
        self.callAvatar.frame = CGRectMake(9, (h - 44) / 2, 44, 44);
        self.callKind.frame = CGRectMake(62, 13, w - 62 - 112, 14);
        self.callName.frame = CGRectMake(62, 28, w - 62 - 112, 22);
        BOOL ringing = self.incomingCall != nil;
        CGFloat bx = w - 9 - 44, by = (h - 44) / 2;
        if (ringing) {
            self.acceptButton.frame = CGRectMake(bx, by, 44, 44);
            self.declineButton.frame = CGRectMake(bx - 54, by, 44, 44);
        } else {
            self.declineButton.frame = CGRectMake(bx, by, 44, 44);
            self.speakerButton.frame = CGRectMake(bx - 54, by, 44, 44);
        }
        for (UIView *v in [self callViews]) v.alpha = callMode ? 1 : 0;
        self.acceptButton.alpha = (callMode && ringing) ? 1 : 0;
        self.speakerButton.alpha = (callMode && !ringing) ? 1 : 0;

        CGPoint c = CGPointMake(19, h / 2);
        self.lockIcon.center = c;  self.lockIcon.alpha = (comp && left == 3) ? 1 : 0;
        self.timerIcon.center = c; self.timerIcon.alpha = (comp && left == 2) ? 1 : 0;
        self.dot.center = c;       self.dot.alpha = (comp && left == 1) ? 1 : 0;
        self.timerLabel.frame = CGRectMake(w - 80, 0, 66, h);
        self.timerLabel.alpha = (comp && timerOn) ? 1 : 0;

        self.chargeLabel.frame = CGRectMake(16, 0, 100, h);
        self.battery.frame = CGRectMake(w - 16 - 30, (h - 13) / 2, 30, 13);
        self.pctLabel.frame = CGRectMake(w - 16 - 30 - 8 - 56, 0, 56, h);
        self.chargeLabel.alpha = self.pctLabel.alpha = self.battery.alpha = chg ? 1 : 0;
    };
    if (animated) {
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.6
                            options:UIViewAnimationOptionAllowUserInteraction animations:apply completion:nil];
    } else apply();
}

- (void)syncLayout {
    NSString *sig = [NSString stringWithFormat:@"%d%d%d%d%d%d%d%d", self.locked, self.recording,
                     self.timerEnd != nil, self.playing, self.chargeFlash, self.expanded, self.incomingCall != nil, self.activeCall != nil];
    if ([sig isEqualToString:self.lastSig]) return;
    self.lastSig = sig;
    [self.dot.layer removeAllAnimations];
    if (self.recording) {
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
        a.fromValue = @1; a.toValue = @0.35; a.duration = 0.9;
        a.autoreverses = YES; a.repeatCount = HUGE_VALF;
        [self.dot.layer addAnimation:a forKey:@"pulse"];
    }
    [self relayout:YES];
}

- (UIButton *)iconButton:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    if (sel) [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [self.pill addSubview:b];
    return b;
}

- (NSArray *)mediaViews {
    return @[self.titleLabel, self.artistLabel, self.wave, self.track, self.elapsedLabel, self.remainLabel,
             self.playButton, self.prevButton, self.nextButton, self.starButton, self.airButton];
}

- (void)layoutMedia {
    CGFloat w = self.view.bounds.size.width - 20;
    CGFloat maxW = w - 84 - 60 - (self.trackExplicit ? 20 : 0);
    CGFloat tw = ceil([(self.titleLabel.text ?: @"") sizeWithAttributes:@{NSFontAttributeName: self.titleLabel.font}].width);
    CGFloat showW = MIN(tw, maxW);
    self.titleLabel.frame = CGRectMake(84, 25, showW, 20);
    self.badge.frame = CGRectMake(84 + showW + 6, 28, 14, 14);
    self.artistLabel.frame = CGRectMake(84, 43, w - 84 - 20, 20);
    self.wave.frame = CGRectMake(w - 16 - 27, 24, 27, 22);

    self.track.frame = CGRectMake(46, 76, w - 100, 5);
    self.elapsedLabel.frame = CGRectMake(16, 70, 30, 16);
    self.remainLabel.frame = CGRectMake(w - 16 - 34, 70, 34, 16);

    CGFloat cy = 127;
    CGFloat xs[5] = {0.12, 0.31, 0.50, 0.69, 0.88};
    UIButton *bs[5] = {self.starButton, self.prevButton, self.playButton, self.nextButton, self.airButton};
    for (int i = 0; i < 5; i++) bs[i].frame = CGRectMake(w * xs[i] - 22, cy - 22, 44, 44);
}

- (NSArray *)callViews {
    return @[self.callAvatar, self.callKind, self.callName, self.declineButton];
}

- (void)loadCaller:(id)call {
    NSString *name = [call respondsToSelector:@selector(displayName)] ? [call displayName] : nil;
    self.callName.text = name.length ? name : @"Unknown";
    BOOL video = [call respondsToSelector:@selector(isVideo)] && [call isVideo];
    self.callKind.text = video ? @"FaceTime" : UIDevice.currentDevice.model;
    self.callAvatar.image = nil;
    NSString *ini = @"?";
    if (name.length && [[NSCharacterSet letterCharacterSet] characterIsMember:[name characterAtIndex:0]]) {
        NSArray *parts = [name componentsSeparatedByString:@" "];
        ini = [[parts.firstObject substringToIndex:1] uppercaseString];
        if (parts.count > 1 && [parts.lastObject length]) ini = [ini stringByAppendingString:[[parts.lastObject substringToIndex:1] uppercaseString]];
    }
    self.callInitials.text = ini;
    self.callInitials.hidden = NO;
    NSString *ident = [call respondsToSelector:@selector(contactIdentifier)] ? [call contactIdentifier] : nil;
    if (ident.length) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSData *d = nil;
            @try {
                CNContact *ct = [[CNContactStore new] unifiedContactWithIdentifier:ident
                                                                      keysToFetch:@[CNContactThumbnailImageDataKey] error:nil];
                d = ct.thumbnailImageData;
            } @catch (NSException *e) {}
            if (!d) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.incomingCall == call || self.activeCall == call) {
                    self.callAvatar.image = [UIImage imageWithData:d];
                    self.callInitials.hidden = YES;
                }
            });
        });
    }
}

- (void)pollCall {
    id center = [objc_getClass("TUCallCenter") sharedInstance];
    if (!center) return;
    id call = nil;
    if ([center respondsToSelector:@selector(incomingCall)]) call = [center incomingCall];
    if (!call && [center respondsToSelector:@selector(currentCalls)]) {
        for (id c in [center currentCalls]) {
            if ([c respondsToSelector:@selector(callStatus)] && [c callStatus] == 4) { call = c; break; }
        }
    }
    if (call != self.incomingCall) {
        self.incomingCall = call;
        if (call) [self loadCaller:call];
    }

    // call in progress (active = 1, dialing = 3)
    id live = nil;
    if (!call && [center respondsToSelector:@selector(currentCalls)]) {
        for (id c in [center currentCalls]) {
            if (![c respondsToSelector:@selector(callStatus)]) continue;
            int st = [c callStatus];
            if (st == 1) { live = c; break; }
            if (st == 3 && !live) live = c;
        }
    }
    if (live != self.activeCall) {
        self.activeCall = live;
        self.callStart = nil;
        self.speakerOn = NO;
        [self updateSpeakerIcon];
        if (live) [self loadCaller:live];
    }
    if (live && [live callStatus] == 1 && !self.callStart) self.callStart = [NSDate date];
    if (live) {
        self.callKind.textColor = DI_GREEN;
        self.callKind.text = self.callStart ? DIClock([[NSDate date] timeIntervalSinceDate:self.callStart]) : @"calling…";
    } else {
        self.callKind.textColor = [UIColor colorWithWhite:0.55 alpha:1];
    }
}

- (void)updateSpeakerIcon {
    self.speakerButton.backgroundColor = self.speakerOn ? UIColor.whiteColor : [UIColor colorWithWhite:0.3 alpha:1];
    [self.speakerButton setImage:DIIcon(@"speaker", CGSizeMake(26, 24), self.speakerOn ? UIColor.blackColor : UIColor.whiteColor)
                        forState:UIControlStateNormal];
}

- (void)toggleSpeaker {
    id ctl = [objc_getClass("TUAudioSystemController") sharedAudioSystemController];
    if (!ctl) return;
    BOOL on = !self.speakerOn;
    for (NSString *n in @[@"setSpeakerEnabled:", @"setSpeakerphoneEnabled:", @"setSpeakerOn:"]) {
        SEL sel = NSSelectorFromString(n);
        if ([ctl respondsToSelector:sel]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(ctl, sel, on);
            self.speakerOn = on;
            [self updateSpeakerIcon];
            break;
        }
    }
}

- (void)acceptCall {
    id center = [objc_getClass("TUCallCenter") sharedInstance];
    id call = self.incomingCall;
    if (!call) return;
    if ([center respondsToSelector:@selector(answerCall:)]) [center answerCall:call];
    else if ([center respondsToSelector:@selector(answerCall:withSourceIdentifier:)]) [center answerCall:call withSourceIdentifier:nil];
}

- (void)declineCall {
    id center = [objc_getClass("TUCallCenter") sharedInstance];
    id call = self.incomingCall ?: self.activeCall;
    if (call && [center respondsToSelector:@selector(disconnectCall:)]) [center disconnectCall:call];
}

- (void)updatePlayIcon {
    [self.playButton setImage:DIIcon(self.playing ? @"pause" : @"play", CGSizeMake(30, 34), UIColor.whiteColor)
                     forState:UIControlStateNormal];
}

- (void)updateWave {
    NSUInteger i = 0;
    for (UIView *b in self.wave.subviews) {
        [b.layer removeAnimationForKey:@"wave"];
        if (self.playing) {
            CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.scale.y"];
            a.fromValue = @0.35; a.toValue = @1.0; a.duration = 0.35 + 0.08 * i;
            a.autoreverses = YES; a.repeatCount = HUGE_VALF;
            [b.layer addAnimation:a forKey:@"wave"];
        }
        i++;
    }
}

- (void)updateProgress {
    double dur = self.duration, e = self.elapsed;
    if (self.playing && self.stamp) e += [[NSDate date] timeIntervalSinceDate:self.stamp] * (self.rate > 0 ? self.rate : 1);
    e = MAX(0, dur > 0 ? MIN(e, dur) : e);
    self.elapsedLabel.text = DIClock(e);
    self.remainLabel.text = dur > 0 ? [@"-" stringByAppendingString:DIClock(dur - e)] : @"";
    CGFloat f = dur > 0 ? e / dur : 0;
    self.trackFill.frame = CGRectMake(0, 0, self.track.bounds.size.width * f, 5);
}

#pragma mark state

static NSString *DIFormat(NSTimeInterval r) {
    int s = (int)ceil(r);
    if (s >= 3600) return [NSString stringWithFormat:@"%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60];
    return [NSString stringWithFormat:@"%d:%02d", s / 60, s % 60];
}

- (void)fetchTimers {
    Class c = objc_getClass("MTTimerManager");
    if (!c) return;
    if (!self.timerMgr) self.timerMgr = [[c alloc] init];
    id r = [self.timerMgr timers];
    void (^handle)(NSArray *) = ^(NSArray *arr) {
        NSDate *best = nil;
        for (id t in arr) {
            if (![t respondsToSelector:@selector(fireDate)]) continue;
            NSDate *fd = [t fireDate];
            if (fd && [fd timeIntervalSinceNow] > 0 && (!best || [fd compare:best] == NSOrderedAscending)) best = fd;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ self.timerEnd = best; });
    };
    if ([r isKindOfClass:[NSArray class]]) handle(r);
    else if ([r respondsToSelector:@selector(addSuccessBlock:)]) {
        [r addSuccessBlock:^(id res) { if ([res isKindOfClass:[NSArray class]]) handle(res); }];
    }
}

- (void)tick {
    self.tickCount++;
    id lsm = [objc_getClass("SBLockScreenManager") sharedInstance];
    self.locked = [lsm respondsToSelector:@selector(isUILocked)] ? [lsm isUILocked] : NO;
    self.recording = [UIScreen mainScreen].isCaptured;
    [self pollCall];
    if (self.tickCount % 4 == 1) [self fetchTimers];

    if (self.timerEnd) {
        NSTimeInterval r = [self.timerEnd timeIntervalSinceNow];
        if (r <= 0) self.timerEnd = nil; else self.timerLabel.text = DIFormat(r);
    }

    float lvl = UIDevice.currentDevice.batteryLevel;
    if (lvl < 0) lvl = 0;
    self.pctLabel.text = [NSString stringWithFormat:@"%d%%", (int)roundf(lvl * 100)];
    CGRect bf = self.batteryFill.frame; bf.size.width = MAX(2, 22 * lvl);
    self.batteryFill.frame = bf;
    UIColor *col = self.plugged ? DI_GREEN : (lvl <= 0.2 ? [UIColor colorWithRed:1 green:0.23 blue:0.19 alpha:1] : UIColor.whiteColor);
    self.batteryFill.backgroundColor = col;
    self.pctLabel.textColor = col;

    [self syncLayout];
    if ([self mode] == DIModeMedia) [self updateProgress];
}

- (void)batteryChanged {
    UIDeviceBatteryState s = UIDevice.currentDevice.batteryState;
    BOOL now = (s == UIDeviceBatteryStateCharging || s == UIDeviceBatteryStateFull);
    if (now && !self.plugged) {
        self.chargeFlash = YES;
        [self.chargeTimer invalidate];
        self.chargeTimer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(endChargeFlash) userInfo:nil repeats:NO];
    }
    self.plugged = now;
    [self tick];
}
- (void)endChargeFlash { self.chargeFlash = NO; [self syncLayout]; }

#pragma mark media

- (void)setExpanded:(BOOL)expanded autoCollapse:(BOOL)auto_ {
    _expanded = expanded;
    [self.collapseTimer invalidate];
    [self syncLayout];
    if (expanded && auto_) {
        self.collapseTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(collapse) userInfo:nil repeats:NO];
    }
}
- (void)collapse { [self setExpanded:NO autoCollapse:NO]; }
- (void)tapped { if (!self.playing || self.chargeFlash || self.incomingCall || self.activeCall) return; [self setExpanded:!self.expanded autoCollapse:YES]; }
- (void)togglePlay { if (MRSendCommand) MRSendCommand(2, nil); }
- (void)prevTrack { if (MRSendCommand) MRSendCommand(5, nil); }
- (void)nextTrack { if (MRSendCommand) MRSendCommand(4, nil); }

- (void)refresh {
    if (!MRGetInfo || !MRGetPlaying) return;
    MRGetPlaying(dispatch_get_main_queue(), ^(Boolean playing) {
        self.playing = playing;
        [self updatePlayIcon];
        [self updateWave];
        if (!playing && self.expanded) [self setExpanded:NO autoCollapse:NO];
        [self syncLayout];
    });
    MRGetInfo(dispatch_get_main_queue(), ^(CFDictionaryRef info) {
        NSDictionary *d = (__bridge NSDictionary *)info;
        NSString *t = d[@"kMRMediaRemoteNowPlayingInfoTitle"];
        NSString *a = d[@"kMRMediaRemoteNowPlayingInfoArtist"];
        NSData *img = d[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
        self.titleLabel.text = t ?: @"";
        self.artistLabel.text = a ?: @"";
        self.art.image = img ? [UIImage imageWithData:img] : nil;
        self.elapsed = [d[@"kMRMediaRemoteNowPlayingInfoElapsedTime"] doubleValue];
        self.duration = [d[@"kMRMediaRemoteNowPlayingInfoDuration"] doubleValue];
        self.rate = [d[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] doubleValue];
        self.stamp = d[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
        self.trackExplicit = [d[@"kMRMediaRemoteNowPlayingInfoIsExplicit"] boolValue];
        [self layoutMedia];
        if ([self mode] == DIModeMedia) { self.badge.alpha = self.trackExplicit ? 1 : 0; [self updateProgress]; }
        if (t && ![t isEqualToString:self.lastTitle]) {
            self.lastTitle = t;
            if (self.playing) [self setExpanded:YES autoCollapse:YES];
        }
    });
}
@end

static DIWindow *diWindow;
static DIController *diController;

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)app {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        void *h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
        if (h) {
            MRRegister = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications");
            MRGetInfo = dlsym(h, "MRMediaRemoteGetNowPlayingInfo");
            MRGetPlaying = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
            MRSendCommand = dlsym(h, "MRMediaRemoteSendCommand");
            if (MRRegister) MRRegister(dispatch_get_main_queue());
        }

        diController = [DIController new];
        diWindow = [[DIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        if ([diWindow respondsToSelector:@selector(_setSecure:)]) [diWindow _setSecure:YES]; // lets it draw on the lock screen
        diWindow.windowLevel = 10000; // above the lock screen
        diWindow.backgroundColor = UIColor.clearColor;
        diWindow.rootViewController = diController;
        diWindow.hidden = NO;

        for (NSString *n in @[@"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                              @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"]) {
            [[NSNotificationCenter defaultCenter] addObserverForName:n object:nil queue:NSOperationQueue.mainQueue
                                                          usingBlock:^(NSNotification *x) { [diController refresh]; }];
        }
        [diController refresh];
    });
}
%end
