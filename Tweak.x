#import <UIKit/UIKit.h>
#import <dlfcn.h>

// MediaRemote (private) loaded at runtime so no linking is needed
typedef void (^DIInfoBlock)(CFDictionaryRef info);
typedef void (^DIPlayBlock)(Boolean playing);
static void (*MRRegister)(dispatch_queue_t);
static void (*MRGetInfo)(dispatch_queue_t, DIInfoBlock);
static void (*MRGetPlaying)(dispatch_queue_t, DIPlayBlock);
static Boolean (*MRSendCommand)(int, id);

@interface DIWindow : UIWindow
@end
@implementation DIWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    return (v == self || v == self.rootViewController.view) ? nil : v;
}
@end

@interface DIController : UIViewController
@property (nonatomic, strong) UIView *pill;
@property (nonatomic, strong) UIImageView *art;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, copy) NSString *lastTitle;
@property (nonatomic, strong) NSTimer *collapseTimer;
@end

@implementation DIController

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = UIColor.clearColor;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.pill = [UIView new];
    self.pill.backgroundColor = UIColor.blackColor;
    self.pill.clipsToBounds = YES;
    self.pill.alpha = 0;
    [self.view addSubview:self.pill];

    self.art = [UIImageView new];
    self.art.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    self.art.clipsToBounds = YES;
    self.art.contentMode = UIViewContentModeScaleAspectFill;
    [self.pill addSubview:self.art];

    self.titleLabel = [UILabel new];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.pill addSubview:self.titleLabel];

    self.artistLabel = [UILabel new];
    self.artistLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1];
    self.artistLabel.font = [UIFont systemFontOfSize:12];
    [self.pill addSubview:self.artistLabel];

    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playButton.titleLabel.font = [UIFont systemFontOfSize:20];
    [self.playButton addTarget:self action:@selector(togglePlay) forControlEvents:UIControlEventTouchUpInside];
    [self.pill addSubview:self.playButton];

    [self.pill addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)]];
    [self layoutAnimated:NO];
}

- (void)layoutAnimated:(BOOL)animated {
    CGFloat W = self.view.bounds.size.width;
    BOOL e = self.expanded;
    CGRect f = e ? CGRectMake(10, 8, W - 20, 70) : CGRectMake((W - 126) / 2, 4, 126, 28);
    CGFloat h = f.size.height;
    void (^apply)(void) = ^{
        self.pill.frame = f;
        self.pill.layer.cornerRadius = h / 2;
        CGFloat a = e ? 50 : 20;
        CGFloat pad = e ? 10 : 6;
        self.art.frame = CGRectMake(pad, (h - a) / 2, a, a);
        self.art.layer.cornerRadius = e ? 10 : 10;
        self.titleLabel.frame = CGRectMake(70, 14, f.size.width - 130, 20);
        self.artistLabel.frame = CGRectMake(70, 34, f.size.width - 130, 18);
        self.playButton.frame = CGRectMake(f.size.width - 56, 15, 44, 40);
        self.titleLabel.alpha = self.artistLabel.alpha = self.playButton.alpha = e ? 1 : 0;
    };
    if (animated) {
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.6
                            options:UIViewAnimationOptionAllowUserInteraction animations:apply completion:nil];
    } else apply();
}

- (void)setExpanded:(BOOL)expanded autoCollapse:(BOOL)auto_ {
    _expanded = expanded;
    [self.collapseTimer invalidate];
    [self layoutAnimated:YES];
    if (expanded && auto_) {
        self.collapseTimer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(collapse) userInfo:nil repeats:NO];
    }
}
- (void)collapse { [self setExpanded:NO autoCollapse:NO]; }
- (void)tapped { [self setExpanded:!self.expanded autoCollapse:YES]; }
- (void)togglePlay { if (MRSendCommand) MRSendCommand(2, nil); }

- (void)refresh {
    if (!MRGetInfo || !MRGetPlaying) return;
    MRGetPlaying(dispatch_get_main_queue(), ^(Boolean playing) {
        self.playing = playing;
        [self.playButton setTitle:playing ? @"❚❚" : @"▶" forState:UIControlStateNormal];
        [UIView animateWithDuration:0.3 animations:^{ self.pill.alpha = playing ? 1 : 0; }];
        if (!playing && self.expanded) [self setExpanded:NO autoCollapse:NO];
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
        if (!h) return;
        MRRegister = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications");
        MRGetInfo = dlsym(h, "MRMediaRemoteGetNowPlayingInfo");
        MRGetPlaying = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
        MRSendCommand = dlsym(h, "MRMediaRemoteSendCommand");
        if (MRRegister) MRRegister(dispatch_get_main_queue());

        diController = [DIController new];
        diWindow = [[DIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        diWindow.windowLevel = UIWindowLevelStatusBar + 100;
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
