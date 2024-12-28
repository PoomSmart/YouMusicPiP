#import "Header.h"
#import <PSHeader/iOSVersions.h>
#import <YouTubeHeader/MLAVPlayer.h>
#import <YouTubeHeader/MLHAMQueuePlayer.h>
#import <YouTubeHeader/MLPIPController.h>
#import <YouTubeHeader/MLPlayerPoolImpl.h>
#import <YouTubeHeader/MLDefaultPlayerViewFactory.h>
#import <YouTubeHeader/YTHotConfig.h>
#import <YouTubeHeader/YTPlayerPIPController.h>
#import <YouTubeHeader/YTBackgroundabilityPolicy.h>
#import <YouTubeHeader/YTPlayerViewControllerConfig.h>
#import <YouTubeHeader/YTSystemNotifications.h>

extern BOOL isPictureInPictureActive(MLPIPController *);

BOOL LegacyPiP() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:CompatibilityModeKey];
}

MLPIPController *pip;
YTHotConfig *hotConfig;
YTPlayerViewControllerConfig *playerConfig;
YTSystemNotifications *systemNotifications;
YTBackgroundabilityPolicy *bgPolicy;

MLPIPController *InjectMLPIPController() {
    if (pip == nil)
        pip = [[%c(MLPIPController) alloc] init];
    return pip;
}

%hook YTHotConfig

- (id)init {
    self = %orig;
    hotConfig = self;
    return self;
}

%end

%hook YTPlayerViewControllerConfig

- (id)init {
    self = %orig;
    playerConfig = self;
    return self;
}

%end

%hook YTSystemNotifications

- (id)init {
    self = %orig;
    systemNotifications = self;
    return self;
}

%end

%hook YTBackgroundabilityPolicy

- (id)init {
    self = %orig;
    bgPolicy = self;
    return self;
}

%end

%hook YTPlayerPIPController

- (instancetype)initWithDelegate:(id)delegate {
    id controller = %orig;
    if (controller == nil) {
        controller = [[%c(YTPlayerPIPController) alloc] init];
        [controller setValue:InjectMLPIPController() forKey:@"_pipController"];
        [controller setValue:bgPolicy forKey:@"_backgroundabilityPolicy"];
        [controller setValue:playerConfig forKey:@"_config"];
        [controller setValue:hotConfig forKey:@"_hotConfig"];
        [controller setValue:delegate forKey:@"_delegate"];
        [bgPolicy addBackgroundabilityPolicyObserver:controller];
        [pip addPIPControllerObserver:controller];
        [systemNotifications addSystemNotificationsObserver:controller];
    }
    return controller;
}

%end

%hook MLHAMQueuePlayer

- (instancetype)initWithStickySettings:(MLPlayerStickySettings *)stickySettings playerViewProvider:(MLPlayerPoolImpl *)playerViewProvider playerConfiguration:(void *)playerConfiguration {
    self = %orig;
    if ([self valueForKey:@"_pipController"] == nil)
        [self setValue:InjectMLPIPController() forKey:@"_pipController"];
    return self;
}

- (instancetype)initWithStickySettings:(MLPlayerStickySettings *)stickySettings playerViewProvider:(MLPlayerPoolImpl *)playerViewProvider playerConfiguration:(void *)playerConfiguration mediaPlayerResources:(id)mediaPlayerResources {
    self = %orig;
    if ([self valueForKey:@"_pipController"] == nil)
        [self setValue:InjectMLPIPController() forKey:@"_pipController"];
    return self;
}

%end

%hook MLAVPlayer

- (bool)isPictureInPictureActive {
    return isPictureInPictureActive(InjectMLPIPController());
}

%end

%hook MLPlayerPoolImpl

- (instancetype)init {
    self = %orig;
    [self setValue:InjectMLPIPController() forKey:@"_pipController"];
    return self;
}

%end

%group Legacy

%hook MLPIPController

- (void)activatePiPController {
    if (isPictureInPictureActive(self)) return;
    AVPictureInPictureController *avpip = [self valueForKey:@"_pictureInPictureController"];
    if (!avpip) {
        MLAVPIPPlayerLayerView *playerLayerView = [self valueForKey:@"_AVPlayerView"];
        if (playerLayerView) {
            AVPlayerLayer *playerLayer = [playerLayerView playerLayer];
            avpip = [[AVPictureInPictureController alloc] initWithPlayerLayer:playerLayer];
            [self setValue:avpip forKey:@"_pictureInPictureController"];
            avpip.delegate = self;
        }
    }
}

- (void)deactivatePiPController {
    AVPictureInPictureController *pip = [self valueForKey:@"_pictureInPictureController"];
    [pip stopPictureInPicture];
    [self setValue:nil forKey:@"_pictureInPictureController"];
}

%end

%hook MLPlayerPoolImpl

- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings {
    BOOL externalPlaybackActive = [(MLAVPlayer *)[self valueForKey:@"_activePlayer"] externalPlaybackActive];
    MLAVPlayer *player = [[%c(MLAVPlayer) alloc] initWithVideo:video playerConfig:playerConfig stickySettings:stickySettings externalPlaybackActive:externalPlaybackActive];
    if (stickySettings)
        player.rate = stickySettings.rate;
    return player;
}

- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings latencyLogger:(id)latencyLogger {
    BOOL externalPlaybackActive = [(MLAVPlayer *)[self valueForKey:@"_activePlayer"] externalPlaybackActive];
    MLAVPlayer *player = [[%c(MLAVPlayer) alloc] initWithVideo:video playerConfig:playerConfig stickySettings:stickySettings externalPlaybackActive:externalPlaybackActive];
    if (stickySettings)
        player.rate = stickySettings.rate;
    return player;
}

- (MLAVPlayerLayerView *)playerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    MLDefaultPlayerViewFactory *factory = [self valueForKey:@"_playerViewFactory"];
    return [factory AVPlayerViewForVideo:video playerConfig:playerConfig];
}

- (BOOL)canQueuePlayerPlayVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    return NO;
}

%end

%end

%group Compat

%hook AVPictureInPictureController

%new(v@:)
- (void)invalidatePlaybackState {}

%new(v@:)
- (void)sampleBufferDisplayLayerDidDisappear {}

%new(v@:)
- (void)sampleBufferDisplayLayerDidAppear {}

%new(v@:{CGSize=dd})
- (void)sampleBufferDisplayLayerRenderSizeDidChangeToSize:(CGSize)size {}

%new(v@:B)
- (void)setRequiresLinearPlayback:(BOOL)linear {}

%new(v@:)
- (void)reloadPrerollAttributes {}

%end

%end

%ctor {
    if (IS_IOS_OR_NEWER(iOS_15_0)) return;
    %init;
    if (!IS_IOS_OR_NEWER(iOS_14_0)) {
        %init(Compat);
    }
    if (LegacyPiP()) {
        %init(Legacy);
    }
}
