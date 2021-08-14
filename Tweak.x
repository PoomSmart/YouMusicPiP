#import <version.h>
#import "Header.h"
#import "../YouTubeHeader/MLPIPController.h"
#import "../YouTubeHeader/MLVideoDecoderFactory.h"
#import "../YouTubeHeader/MLDefaultPlayerViewFactory.h"
#import "../YouTubeHeader/YTBackgroundabilityPolicy.h"
#import "../YouTubeHeader/YTHotConfig.h"
#import "../YouTubeHeader/YTLocalPlaybackController.h"
#import "../YouTubeHeader/YTPlayerPIPController.h"
#import "../YouTubeHeader/YTPlayerViewController.h"
// #import "../YouTubeHeader/QTMIcon.h"

// @interface QTMButton : UIButton
// + (instancetype)ytm_flatRoundButtonWithImage:(UIImage *)image selectedImage:(UIImage *)selectedImage accessibilityLabel:(NSString *)accessibilityLabel accessibilityIdentifier:(NSString *)accessibilityIdentifier;
// @end

// @interface YTMVideoOverlayViewController : UIViewController
// - (YTPlayerViewController *)delegate;
// @end

// @interface YTMVideoOverlayView : UIView
// @end

BOOL FromUser = NO;
BOOL ForceDisablePiP = NO;

extern BOOL LegacyPiP();

BOOL UsePiPButton() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:PiPActivationMethodKey];
}

BOOL isPictureInPictureActive(MLPIPController *pip) {
    return [pip respondsToSelector:@selector(pictureInPictureActive)] ? [pip pictureInPictureActive] : [pip isPictureInPictureActive];
}

// static NSString *PiPIconPath;

// @interface YTMVideoOverlayView (YMP)
// @property (retain, nonatomic) QTMButton *pipButton;
// - (void)didPressPiP:(id)arg;
// - (UIImage *)pipImage;
// @end

static void forceRenderViewTypeBase(YTIHamplayerConfig *hamplayerConfig) {
    if (LegacyPiP()) return;
    hamplayerConfig.renderViewType = 6;
}

static void forceRenderViewTypeHot(YTIHamplayerHotConfig *hamplayerHotConfig) {
    if (LegacyPiP()) return;
    hamplayerHotConfig.renderViewType = 6;
}

static void forceRenderViewType(YTHotConfig *hotConfig) {
    YTIHamplayerHotConfig *hamplayerHotConfig = [hotConfig hamplayerHotConfig];
    forceRenderViewTypeHot(hamplayerHotConfig);
}


static void forcePictureInPictureInternal(YTHotConfig *hotConfig, BOOL value) {
    [hotConfig mediaHotConfig].enablePictureInPicture = value;
    YTIIosMediaHotConfig *iosMediaHotConfig = [[[hotConfig hotConfigGroup] mediaHotConfig] iosMediaHotConfig];
    iosMediaHotConfig.enablePictureInPicture = value;
}

static void forceEnablePictureInPictureInternal(YTHotConfig *hotConfig) {
    if (ForceDisablePiP && !FromUser)
        return;
    forcePictureInPictureInternal(hotConfig, YES);
}

static void activatePiPBase(YTPlayerPIPController *controller, BOOL playPiP) {
    MLPIPController *pip = [controller valueForKey:@"_pipController"];
    if ([controller respondsToSelector:@selector(maybeEnablePictureInPicture)])
        [controller maybeEnablePictureInPicture];
    else if ([controller respondsToSelector:@selector(maybeInvokePictureInPicture)])
        [controller maybeInvokePictureInPicture];
    else {
        BOOL canPiP = [controller respondsToSelector:@selector(canEnablePictureInPicture)] && [controller canEnablePictureInPicture];
        if (!canPiP)
            canPiP = [controller respondsToSelector:@selector(canInvokePictureInPicture)] && [controller canInvokePictureInPicture];
        if (canPiP) {
            if ([pip respondsToSelector:@selector(activatePiPController)])
                [pip activatePiPController];
            else
                [pip startPictureInPicture];
        }
    }
    AVPictureInPictureController *avpip = [pip valueForKey:@"_pictureInPictureController"];
    if (playPiP) {
        if ([avpip isPictureInPicturePossible])
            [avpip startPictureInPicture];
    } else if (!isPictureInPictureActive(pip)) {
        if ([pip respondsToSelector:@selector(deactivatePiPController)])
            [pip deactivatePiPController];
        else
            [avpip stopPictureInPicture];
    }
}

static void activatePiP(YTLocalPlaybackController *local, BOOL playPiP) {
    if (![local isKindOfClass:%c(YTLocalPlaybackController)])
        return;
    YTPlayerPIPController *controller = [local valueForKey:@"_playerPIPController"];
    activatePiPBase(controller, playPiP);
}

static void bootstrapPiP(YTPlayerViewController *self, BOOL playPiP) {
    YTHotConfig *hotConfig;
    @try {
        hotConfig = [self valueForKey:@"_hotConfig"];
    } @catch (id ex) {
        hotConfig = [[self gimme] instanceForType:%c(YTHotConfig)];
    }
    forceEnablePictureInPictureInternal(hotConfig);
    YTLocalPlaybackController *local = [self valueForKey:@"_playbackController"];
    activatePiP(local, playPiP);
}

// #pragma mark - PiP Button

// static void createPiPButton(YTMVideoOverlayView *self) {
//     if (self) {
//         UIImage *image = [self pipImage];
//         self.pipButton = [%c(QTMIcon) ytm_flatRoundButtonWithImage:image selectedImage:image accessibilityLabel:@"pip" accessibilityIdentifier:@"pip"];
//         self.pipButton.hidden = YES;
//         self.pipButton.alpha = 0;
//         [self.pipButton addTarget:self action:@selector(didPressPiP:) forControlEvents:64];
//         [[self valueForKey:@"_containerView"] addSubview:self.pipButton];
//     }
// }

// %hook YTMVideoOverlayView

// %property (retain, nonatomic) QTMButton *pipButton;

// - (id)initWithDelegate:(id)delegate doubleTapToSeekEnabled:(BOOL)doubleTapToSeekEnabled {
//     self = %orig;
//     createPiPButton(self);
//     return self;
// }

// %new
// - (UIImage *)pipImage {
//     static UIImage *image = nil;
//     static dispatch_once_t onceToken;
//     dispatch_once(&onceToken, ^{
//         image = [%c(QTMIcon) tintImage:[UIImage imageWithContentsOfFile:PiPIconPath] color:UIColor.whiteColor];
//         if ([image respondsToSelector:@selector(imageFlippedForRightToLeftLayoutDirection)])
//             image = [image imageFlippedForRightToLeftLayoutDirection];
//     });
//     return image;
// }

// %new
// - (void)didPressPiP:(id)arg {
//     YTMVideoOverlayViewController *c = [self valueForKey:@"_delegate"];
//     FromUser = YES;
//     bootstrapPiP([c delegate], YES);
// }

// %end

#pragma mark - PiP Bootstrapping

%hook YTPlayerViewController

%new
- (void)appWillResignActive:(id)arg1 {
    if (!IS_IOS_OR_NEWER(iOS_14_0) && !UsePiPButton())
        bootstrapPiP(self, YES);
}

%end

#pragma mark - PiP Support

%hook AVPictureInPictureController

+ (BOOL)isPictureInPictureSupported {
    return YES;
}

- (void)setCanStartPictureInPictureAutomaticallyFromInline:(BOOL)canStartFromInline {
    %orig(UsePiPButton() ? NO : canStartFromInline);
}

%end

%hook MLPIPController

- (BOOL)isPictureInPictureSupported {
    return YES;
}

%end

%hook MLDefaultPlayerViewFactory

- (MLAVPlayerLayerView *)AVPlayerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceEnablePictureInPictureInternal([self valueForKey:@"_hotConfig"]);
    return %orig;
}

- (id)hamPlayerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewType([self valueForKey:@"_hotConfig"]);
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (BOOL)canUsePlayerView:(id)playerView forVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

%end

%hook MLVideoDecoderFactory

- (void)prepareDecoderForFormatDescription:(id)formatDescription delegateQueue:(id)delegateQueue {
    forceRenderViewTypeHot([self valueForKey:@"_hotConfig"]);
    %orig;
}

%end

#pragma mark - PiP Support, Backgroundable

%hook YTBackgroundabilityPolicy

- (void)updateIsBackgroundableByUserSettings {
    %orig;
    [self setValue:@(YES) forKey:@"_backgroundableByUserSettings"];
}

- (void)updateIsPictureInPicturePlayableByUserSettings {
    %orig;
    [self setValue:@(YES) forKey:@"_playableInPiPByUserSettings"];
}

%end

#pragma mark - Hacks

BOOL YTSingleVideo_isLivePlayback_override = NO;

%hook YTSingleVideo

- (BOOL)isLivePlayback {
    return YTSingleVideo_isLivePlayback_override ? NO : %orig;
}

%end

static YTHotConfig *getHotConfig(YTPlayerPIPController *self) {
    @try {
        return [self valueForKey:@"_hotConfig"];
    } @catch (id ex) {
        return [[self valueForKey:@"_config"] valueForKey:@"_hotConfig"];
    }
}

%hook YTPlayerPIPController

- (BOOL)canInvokePictureInPicture {
    forceEnablePictureInPictureInternal(getHotConfig(self));
    YTSingleVideo_isLivePlayback_override = YES;
    BOOL value = %orig;
    YTSingleVideo_isLivePlayback_override = NO;
    return value;
}

- (BOOL)canEnablePictureInPicture {
    forceEnablePictureInPictureInternal(getHotConfig(self));
    YTSingleVideo_isLivePlayback_override = YES;
    BOOL value = %orig;
    YTSingleVideo_isLivePlayback_override = NO;
    return value;
}

- (void)appWillResignActive:(id)arg1 {
    forcePictureInPictureInternal(getHotConfig(self), !UsePiPButton());
    ForceDisablePiP = YES;
    if (UsePiPButton())
        activatePiPBase(self, NO);
    %orig;
    ForceDisablePiP = FromUser = NO;
}

%end

%hook YTIPlayabilityStatus

- (BOOL)isPlayableInBackground {
    return YES;
}

- (BOOL)isPlayableInPictureInPicture {
    return YES;
}

- (BOOL)hasPictureInPicture {
    return YES;
}

%end

%ctor {
    // NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YouMusicPiP" ofType:@"bundle"];
    // if (tweakBundlePath) {
    //     NSBundle *tweakBundle = [NSBundle bundleWithPath:tweakBundlePath];
    //     PiPIconPath = [tweakBundle pathForResource:@"yt-pip-overlay" ofType:@"png"];
    // } else
    //     PiPIconPath = @"/Library/Application Support/YouMusicPiP.bundle/yt-pip-overlay.png";
    %init;
}
