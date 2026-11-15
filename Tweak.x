#import <UIKit/UIKit.h>
#import <objc/runtime.h>
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

@interface DIWindow : UIWindow
@end
@implementation DIWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    return (v == self || v == self.rootViewController.view) ? nil : v;
}
@end

typedef NS_ENUM(NSInteger, DIMode) { DIModeCompact, DIModeMedia, DIModeCharging };

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

    self.titleLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:14] color:UIColor.whiteColor];
    self.artistLabel = [self labelWithFont:[UIFont systemFontOfSize:12] color:[UIColor colorWithWhite:0.7 alpha:1]];
    self.timerLabel = [self labelWithFont:[UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold] color:DI_ORANGE];
    self.timerLabel.textAlignment = NSTextAlignmentRight;
    self.chargeLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:13] color:UIColor.whiteColor];
    self.chargeLabel.text = @"Charging";
    self.pctLabel = [self labelWithFont:[UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightSemibold] color:DI_GREEN];
    self.pctLabel.textAlignment = NSTextAlignmentRight;

    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playButton.titleLabel.font = [UIFont systemFontOfSize:20];
    [self.playButton addTarget:self action:@selector(togglePlay) forControlEvents:UIControlEventTouchUpInside];
    [self.pill addSubview:self.playButton];

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

    [self relayout:NO];
    self.tickTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.tickTimer forMode:NSRunLoopCommonModes];
    [self tick];
}

#pragma mark layout

- (DIMode)mode {
    return self.chargeFlash ? DIModeCharging : (self.expanded ? DIModeMedia : DIModeCompact);
}

- (void)relayout:(BOOL)animated {
    CGFloat W = self.view.bounds.size.width;
    DIMode mode = [self mode];
    BOOL timerOn = self.timerEnd != nil;
    // left slot: 0 none, 1 rec dot, 2 timer, 3 lock, 4 artwork
    int left = self.recording ? 1 : timerOn ? 2 : self.locked ? 3 : self.playing ? 4 : 0;
    CGRect f;
    if (mode == DIModeMedia) f = CGRectMake(10, 8, W - 20, 70);
    else if (mode == DIModeCharging) { CGFloat w = MIN(W - 20, 230); f = CGRectMake((W - w) / 2, 4, w, 30); }
    else { CGFloat w = timerOn ? 190 : (left ? 130 : 112); f = CGRectMake((W - w) / 2, 4, w, 28); }

    void (^apply)(void) = ^{
        CGFloat w = f.size.width, h = f.size.height;
        BOOL media = mode == DIModeMedia, chg = mode == DIModeCharging, comp = mode == DIModeCompact;
        self.pill.frame = f;
        self.pill.layer.cornerRadius = h / 2;

        self.art.frame = media ? CGRectMake(10, 10, 50, 50) : CGRectMake(9, (h - 20) / 2, 20, 20);
        self.art.layer.cornerRadius = media ? 10 : 6;
        self.art.alpha = (media || (comp && left == 4)) ? 1 : 0;

        self.titleLabel.frame = CGRectMake(70, 14, w - 130, 20);
        self.artistLabel.frame = CGRectMake(70, 34, w - 130, 18);
        self.playButton.frame = CGRectMake(w - 56, 15, 44, 40);
        self.titleLabel.alpha = self.artistLabel.alpha = self.playButton.alpha = media ? 1 : 0;

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
    NSString *sig = [NSString stringWithFormat:@"%d%d%d%d%d%d", self.locked, self.recording,
                     self.timerEnd != nil, self.playing, self.chargeFlash, self.expanded];
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
        self.collapseTimer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(collapse) userInfo:nil repeats:NO];
    }
}
- (void)collapse { [self setExpanded:NO autoCollapse:NO]; }
- (void)tapped { if (!self.playing || self.chargeFlash) return; [self setExpanded:!self.expanded autoCollapse:YES]; }
- (void)togglePlay { if (MRSendCommand) MRSendCommand(2, nil); }

- (void)refresh {
    if (!MRGetInfo || !MRGetPlaying) return;
    MRGetPlaying(dispatch_get_main_queue(), ^(Boolean playing) {
        self.playing = playing;
        [self.playButton setTitle:playing ? @"❚❚" : @"▶" forState:UIControlStateNormal];
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
