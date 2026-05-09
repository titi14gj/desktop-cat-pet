#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString * const SizeKey = @"size";
static NSString * const DurationKey = @"durationMinutes";
static NSString * const TopKey = @"alwaysOnTop";
static NSString * const OriginXKey = @"originX";
static NSString * const OriginYKey = @"originY";
static NSString * const AnimationKey = @"animationId";
static NSString * const SpeedKey = @"frameInterval";
static NSString * const LocalMediaPathKey = @"localMediaPath";
static NSString * const MediaItemsKey = @"mediaItems";
static NSString * const CurrentMediaItemKey = @"currentMediaItem";
static NSString * const PlaybackModeKey = @"playbackMode";
static NSString * const RotateSecondsKey = @"rotateSeconds";
static NSString * const BuiltInPrefix = @"builtin:";

@interface PetView : NSView
@property(nonatomic, strong) NSArray<NSImage *> *frames;
@property(nonatomic) NSInteger frameIndex;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) AVPlayer *player;
@property(nonatomic, strong) AVPlayerLayer *playerLayer;
@property(nonatomic, strong) id loopObserver;
@property(nonatomic) BOOL videoMode;
@property(nonatomic) NSPoint dragStart;
@property(nonatomic) BOOL hasDragStart;
- (void)reloadAnimation;
- (void)restartAnimationTimer;
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) PetView *petView;
@property(nonatomic, strong) NSPanel *settingsPanel;
@property(nonatomic, strong) NSPanel *mediaPanel;
@property(nonatomic, strong) NSTableView *mediaTable;
@property(nonatomic, strong) NSImageView *previewImageView;
@property(nonatomic, strong) AVPlayer *previewPlayer;
@property(nonatomic, strong) AVPlayerLayer *previewPlayerLayer;
@property(nonatomic, strong) NSDate *startedAt;
@property(nonatomic, strong) NSTimer *durationTimer;
@property(nonatomic, strong) NSTimer *rotationTimer;
- (void)showSettings:(id)sender;
@end

static CGFloat settingSize(void) {
    CGFloat size = [[NSUserDefaults standardUserDefaults] doubleForKey:SizeKey];
    return size > 0 ? size : 320;
}

static void setSettingSize(CGFloat size) {
    [[NSUserDefaults standardUserDefaults] setDouble:size forKey:SizeKey];
}

static BOOL settingAlwaysOnTop(void) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:TopKey];
    return value == nil ? YES : [[NSUserDefaults standardUserDefaults] boolForKey:TopKey];
}

static NSPoint settingOrigin(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"hasSavedOrigin"]) {
        NSScreen *screen = NSScreen.mainScreen;
        if (screen) {
            NSRect frame = screen.visibleFrame;
            return NSMakePoint(NSMidX(frame) - settingSize() / 2.0, NSMidY(frame) - settingSize() / 2.0);
        }
    }
    CGFloat x = [defaults doubleForKey:OriginXKey];
    CGFloat y = [defaults doubleForKey:OriginYKey];
    if (x == 0 && y == 0) {
        return NSMakePoint(120, 520);
    }
    return NSMakePoint(x, y);
}

static void setSettingOrigin(NSPoint origin) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:origin.x forKey:OriginXKey];
    [defaults setDouble:origin.y forKey:OriginYKey];
    [defaults setBool:YES forKey:@"hasSavedOrigin"];
}

static NSArray<NSString *> *builtInAnimationIds(void) {
    return @[];
}

static BOOL isBuiltInMediaItem(NSString *item) {
    return [item hasPrefix:BuiltInPrefix];
}

static NSString *builtInItem(NSString *animationId) {
    return [BuiltInPrefix stringByAppendingString:animationId];
}

static BOOL isSupportedMediaPath(NSString *path) {
    NSString *extension = path.pathExtension.lowercaseString;
    return [@[@"gif", @"png", @"apng", @"mov", @"m4v"] containsObject:extension];
}

static NSString *animationIdFromItem(NSString *item) {
    return [item substringFromIndex:BuiltInPrefix.length];
}

static NSString *defaultMediaItem(void) {
    return @"";
}

static NSMutableArray<NSString *> *mediaItems(void) {
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    for (NSString *animationId in builtInAnimationIds()) {
        [items addObject:builtInItem(animationId)];
    }

    NSArray<NSString *> *stored = [[NSUserDefaults standardUserDefaults] arrayForKey:MediaItemsKey];
    for (NSString *path in stored) {
        if (isSupportedMediaPath(path) && [[NSFileManager defaultManager] fileExistsAtPath:path] && ![items containsObject:path]) {
            [items addObject:path];
        }
    }
    return items;
}

static NSString *settingCurrentMediaItem(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *item = [defaults stringForKey:CurrentMediaItemKey];
    if (item.length > 0) {
        if (isBuiltInMediaItem(item) || (isSupportedMediaPath(item) && [[NSFileManager defaultManager] fileExistsAtPath:item])) {
            return item;
        }
    }
    NSString *legacyPath = [defaults stringForKey:LocalMediaPathKey];
    if (legacyPath.length > 0 && isSupportedMediaPath(legacyPath) && [[NSFileManager defaultManager] fileExistsAtPath:legacyPath]) {
        return legacyPath;
    }
    NSArray<NSString *> *items = mediaItems();
    if (items.count > 0) { return items.firstObject; }
    return defaultMediaItem();
}

static NSString *settingAnimationId(void) {
    NSString *item = settingCurrentMediaItem();
    if (isBuiltInMediaItem(item)) {
        return animationIdFromItem(item);
    }
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:AnimationKey];
    return [builtInAnimationIds() containsObject:value] ? value : @"";
}

static NSString *settingLocalMediaPath(void) {
    NSString *item = settingCurrentMediaItem();
    if (isBuiltInMediaItem(item)) { return nil; }
    NSString *path = item;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) { return nil; }
    return path;
}

static NSTimeInterval settingFrameInterval(void) {
    double value = [[NSUserDefaults standardUserDefaults] doubleForKey:SpeedKey];
    return value > 0 ? value : 0.16;
}

static NSString *animationDisplayName(NSString *animationId) {
    NSDictionary *names = @{};
    return names[animationId] ?: [animationId stringByReplacingOccurrencesOfString:@"_" withString:@" "];
}

static NSString *mediaItemDisplayName(NSString *item) {
    if (item.length == 0) { return @"No media selected"; }
    if (isBuiltInMediaItem(item)) {
        return animationDisplayName(animationIdFromItem(item));
    }
    return item.lastPathComponent;
}

static NSString *settingPlaybackMode(void) {
    NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey:PlaybackModeKey];
    if ([mode isEqualToString:@"sequential"] || [mode isEqualToString:@"shuffle"]) { return mode; }
    return @"single";
}

static NSTimeInterval settingRotateSeconds(void) {
    double value = [[NSUserDefaults standardUserDefaults] doubleForKey:RotateSecondsKey];
    return value > 0 ? value : 60;
}

@implementation PetView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (!self) { return nil; }
    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.clearColor.CGColor;
    [self reloadAnimation];
    [self restartAnimationTimer];
    return self;
}

- (void)reloadAnimation {
    [self stopVideo];
    NSMutableArray<NSImage *> *frames = [NSMutableArray array];

    NSString *localPath = settingLocalMediaPath();
    if (localPath.length > 0) {
        NSString *extension = localPath.pathExtension.lowercaseString;
        if ([extension isEqualToString:@"gif"] || [extension isEqualToString:@"png"] || [extension isEqualToString:@"apng"]) {
            [self loadGIFAtURL:[NSURL fileURLWithPath:localPath] intoFrames:frames];
        } else {
            [self loadVideoAtURL:[NSURL fileURLWithPath:localPath]];
            self.frames = @[];
            self.frameIndex = 0;
            self.needsDisplay = YES;
            return;
        }
    }

    if (frames.count > 0) {
        self.frames = frames;
        self.frameIndex = 0;
        self.needsDisplay = YES;
        return;
    }

    NSBundle *bundle = NSBundle.mainBundle;
    NSString *animationId = settingAnimationId();
    if (animationId.length == 0) {
        self.frames = @[];
        self.frameIndex = 0;
        self.needsDisplay = YES;
        return;
    }
    for (NSInteger i = 1; i <= 16; i++) {
        NSString *relativePath = [NSString stringWithFormat:@"Animations/%@/frames/frame_%02ld", animationId, (long)i];
        NSURL *url = [bundle URLForResource:relativePath withExtension:@"png"];
        if (!url) { continue; }
        NSImage *image = [[NSImage alloc] initWithContentsOfURL:url];
        if (image) { [frames addObject:image]; }
    }
    self.frames = frames;
    self.frameIndex = 0;
    self.needsDisplay = YES;
}

- (void)restartAnimationTimer {
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:settingFrameInterval() target:self selector:@selector(nextFrame) userInfo:nil repeats:YES];
    if (self.player) {
        self.player.rate = [self videoPlaybackRate];
    }
}

- (float)videoPlaybackRate {
    NSTimeInterval interval = settingFrameInterval();
    if (interval <= 0) { return 1.0; }
    double rate = 0.16 / interval;
    return (float)MAX(0.25, MIN(2.0, rate));
}

- (void)loadGIFAtURL:(NSURL *)url intoFrames:(NSMutableArray<NSImage *> *)frames {
    NSImage *source = [[NSImage alloc] initWithContentsOfURL:url];
    for (NSImageRep *rep in source.representations) {
        if (![rep isKindOfClass:NSBitmapImageRep.class]) { continue; }
        NSBitmapImageRep *bitmap = (NSBitmapImageRep *)rep;
        NSNumber *countValue = [bitmap valueForProperty:NSImageFrameCount];
        NSInteger count = countValue.integerValue;
        if (count <= 0) { count = 1; }
        for (NSInteger index = 0; index < count; index++) {
            [bitmap setProperty:NSImageCurrentFrame withValue:@(index)];
            NSImage *frame = [[NSImage alloc] initWithSize:NSMakeSize(bitmap.pixelsWide, bitmap.pixelsHigh)];
            [frame addRepresentation:[bitmap copy]];
            [frames addObject:frame];
        }
        if (frames.count > 0) { return; }
    }
    if (source) { [frames addObject:source]; }
}

- (void)loadVideoAtURL:(NSURL *)url {
    self.videoMode = YES;
    self.player = [AVPlayer playerWithURL:url];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = self.bounds;
    self.playerLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.layer addSublayer:self.playerLayer];

    __weak typeof(self) weakSelf = self;
    self.loopObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        [weakSelf.player seekToTime:kCMTimeZero];
        weakSelf.player.rate = [weakSelf videoPlaybackRate];
    }];
    self.player.muted = YES;
    self.player.rate = [self videoPlaybackRate];
}

- (void)stopVideo {
    self.videoMode = NO;
    [self.player pause];
    self.player = nil;
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    if (self.loopObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.loopObserver];
        self.loopObserver = nil;
    }
}

- (void)nextFrame {
    if (self.videoMode) { return; }
    if (self.frames.count > 0) {
        self.frameIndex = (self.frameIndex + 1) % self.frames.count;
    }
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [NSColor.clearColor setFill];
    NSRectFill(dirtyRect);

    if (self.videoMode) { return; }

    if (self.frames.count == 0) {
        [[NSColor colorWithCalibratedRed:0.70 green:0.71 blue:0.67 alpha:1] setFill];
        NSBezierPath *body = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(self.bounds, self.bounds.size.width * 0.24, self.bounds.size.height * 0.18)];
        [body fill];
        return;
    }

    NSImage *image = self.frames[self.frameIndex];
    CGFloat maxSide = MAX(image.size.width, image.size.height);
    CGFloat scale = MIN(self.bounds.size.width, self.bounds.size.height) / maxSide;
    NSSize drawSize = NSMakeSize(image.size.width * scale, image.size.height * scale);
    NSRect drawRect = NSMakeRect(
        (self.bounds.size.width - drawSize.width) / 2.0,
        (self.bounds.size.height - drawSize.height) / 2.0,
        drawSize.width,
        drawSize.height
    );
    [image drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
}

- (void)mouseDown:(NSEvent *)event {
    self.dragStart = event.locationInWindow;
    self.hasDragStart = YES;
}

- (void)mouseDragged:(NSEvent *)event {
    if (!self.window || !self.hasDragStart) { return; }
    NSPoint current = event.locationInWindow;
    NSRect frame = self.window.frame;
    frame.origin.x += current.x - self.dragStart.x;
    frame.origin.y += current.y - self.dragStart.y;
    [self.window setFrameOrigin:frame.origin];
    setSettingOrigin(frame.origin);
}

- (void)rightMouseDown:(NSEvent *)event {
    AppDelegate *delegate = (AppDelegate *)NSApp.delegate;
    [delegate showSettings:nil];
}

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    self.startedAt = NSDate.date;
    [self createWindow];
    [self createMenu];
    self.durationTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkDuration) userInfo:nil repeats:YES];
    [self restartRotationTimer];
}

- (void)createWindow {
    CGFloat size = settingSize();
    NSRect frame = NSMakeRect(settingOrigin().x, settingOrigin().y, size, size);
    self.window = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    self.window.opaque = NO;
    self.window.backgroundColor = NSColor.clearColor;
    self.window.hasShadow = YES;
    self.window.ignoresMouseEvents = NO;
    self.window.level = settingAlwaysOnTop() ? NSFloatingWindowLevel : NSNormalWindowLevel;
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorStationary;

    self.petView = [[PetView alloc] initWithFrame:NSMakeRect(0, 0, size, size)];
    self.window.contentView = self.petView;
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)createMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Desktop Cat Pet"];
    [menu addItemWithTitle:@"Settings" action:@selector(showSettings:) keyEquivalent:@","];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItemWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@"q"];
    NSApp.mainMenu = menu;
}

- (void)checkDuration {
    double minutes = [[NSUserDefaults standardUserDefaults] doubleForKey:DurationKey];
    if (minutes > 0 && [NSDate.date timeIntervalSinceDate:self.startedAt] >= minutes * 60) {
        [NSApp terminate:nil];
    }
}

- (void)restartRotationTimer {
    [self.rotationTimer invalidate];
    self.rotationTimer = nil;
    if ([settingPlaybackMode() isEqualToString:@"single"]) { return; }
    self.rotationTimer = [NSTimer scheduledTimerWithTimeInterval:settingRotateSeconds() target:self selector:@selector(advanceMedia) userInfo:nil repeats:YES];
}

- (void)advanceMedia {
    NSArray<NSString *> *items = mediaItems();
    if (items.count <= 1) { return; }
    NSString *current = settingCurrentMediaItem();
    NSInteger index = [items indexOfObject:current];
    if (index == NSNotFound) { index = 0; }

    NSInteger next = index;
    if ([settingPlaybackMode() isEqualToString:@"shuffle"]) {
        while (next == index && items.count > 1) {
            next = arc4random_uniform((uint32_t)items.count);
        }
    } else {
        next = (index + 1) % items.count;
    }
    [[NSUserDefaults standardUserDefaults] setObject:items[next] forKey:CurrentMediaItemKey];
    [self.petView reloadAnimation];
    [self.petView restartAnimationTimer];
    [self refreshMediaControls];
}

- (void)showSettings:(id)sender {
    if (self.settingsPanel) {
        [self.settingsPanel makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        return;
    }

    self.settingsPanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 390, 332) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.settingsPanel.title = @"Desktop Cat Settings";
    self.settingsPanel.releasedWhenClosed = NO;
    self.settingsPanel.level = NSFloatingWindowLevel;
    [self.settingsPanel center];

    NSView *content = [[NSView alloc] initWithFrame:self.settingsPanel.contentView.bounds];

    NSTextField *mediaLabel = [NSTextField labelWithString:@"Current media"];
    mediaLabel.frame = NSMakeRect(20, 278, 90, 22);
    [content addSubview:mediaLabel];

    NSTextField *mediaValue = [NSTextField labelWithString:[self currentMediaDisplayName]];
    mediaValue.frame = NSMakeRect(120, 278, 245, 22);
    mediaValue.lineBreakMode = NSLineBreakByTruncatingMiddle;
    mediaValue.tag = 902;
    [content addSubview:mediaValue];

    NSButton *libraryButton = [NSButton buttonWithTitle:@"Media Library..." target:self action:@selector(showMediaLibrary:)];
    libraryButton.frame = NSMakeRect(120, 238, 150, 30);
    [content addSubview:libraryButton];

    NSTextField *modeLabel = [NSTextField labelWithString:@"Playback"];
    modeLabel.frame = NSMakeRect(20, 202, 90, 22);
    [content addSubview:modeLabel];

    NSPopUpButton *modePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(120, 198, 160, 28) pullsDown:NO];
    [modePopup addItemWithTitle:@"Single"];
    modePopup.lastItem.representedObject = @"single";
    [modePopup addItemWithTitle:@"Sequential"];
    modePopup.lastItem.representedObject = @"sequential";
    [modePopup addItemWithTitle:@"Shuffle"];
    modePopup.lastItem.representedObject = @"shuffle";
    NSString *mode = settingPlaybackMode();
    for (NSInteger i = 0; i < modePopup.numberOfItems; i++) {
        if ([[modePopup itemAtIndex:i].representedObject isEqualToString:mode]) {
            [modePopup selectItemAtIndex:i];
            break;
        }
    }
    modePopup.target = self;
    modePopup.action = @selector(playbackModeChanged:);
    [content addSubview:modePopup];

    NSTextField *rotateLabel = [NSTextField labelWithString:@"Rotate sec"];
    rotateLabel.frame = NSMakeRect(20, 166, 90, 22);
    [content addSubview:rotateLabel];

    NSTextField *rotateField = [NSTextField textFieldWithString:[NSString stringWithFormat:@"%.0f", settingRotateSeconds()]];
    rotateField.frame = NSMakeRect(120, 166, 80, 24);
    rotateField.target = self;
    rotateField.action = @selector(rotateSecondsChanged:);
    [content addSubview:rotateField];

    NSTextField *speedLabel = [NSTextField labelWithString:@"Frame delay"];
    speedLabel.frame = NSMakeRect(20, 130, 90, 22);
    [content addSubview:speedLabel];

    NSSlider *speedSlider = [NSSlider sliderWithValue:settingFrameInterval() minValue:0.08 maxValue:0.32 target:self action:@selector(speedChanged:)];
    speedSlider.frame = NSMakeRect(120, 130, 160, 22);
    [content addSubview:speedSlider];

    NSTextField *speedValue = [NSTextField labelWithString:[NSString stringWithFormat:@"%.0f ms", settingFrameInterval() * 1000]];
    speedValue.frame = NSMakeRect(286, 130, 58, 22);
    speedValue.tag = 901;
    [content addSubview:speedValue];

    NSTextField *sizeLabel = [NSTextField labelWithString:@"Size"];
    sizeLabel.frame = NSMakeRect(20, 92, 80, 22);
    [content addSubview:sizeLabel];

    NSSlider *sizeSlider = [NSSlider sliderWithValue:settingSize() minValue:96 maxValue:460 target:self action:@selector(sizeChanged:)];
    sizeSlider.frame = NSMakeRect(120, 92, 210, 22);
    [content addSubview:sizeSlider];

    NSTextField *durationLabel = [NSTextField labelWithString:@"Run minutes"];
    durationLabel.frame = NSMakeRect(20, 56, 90, 22);
    [content addSubview:durationLabel];

    NSTextField *durationField = [NSTextField textFieldWithString:[NSString stringWithFormat:@"%.0f", [[NSUserDefaults standardUserDefaults] doubleForKey:DurationKey]]];
    durationField.frame = NSMakeRect(120, 56, 80, 24);
    durationField.target = self;
    durationField.action = @selector(durationChanged:);
    [content addSubview:durationField];

    NSButton *topBox = [NSButton checkboxWithTitle:@"Always on top" target:self action:@selector(topChanged:)];
    topBox.state = settingAlwaysOnTop() ? NSControlStateValueOn : NSControlStateValueOff;
    topBox.frame = NSMakeRect(20, 20, 160, 24);
    [content addSubview:topBox];

    NSButton *quitButton = [NSButton buttonWithTitle:@"Quit" target:self action:@selector(quit:)];
    quitButton.frame = NSMakeRect(258, 16, 72, 30);
    [content addSubview:quitButton];

    self.settingsPanel.contentView = content;
    [self.settingsPanel makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (NSString *)currentMediaDisplayName {
    return mediaItemDisplayName(settingCurrentMediaItem());
}

- (void)refreshMediaControls {
    NSTextField *mediaValue = [self.settingsPanel.contentView viewWithTag:902];
    if ([mediaValue isKindOfClass:NSTextField.class]) {
        mediaValue.stringValue = [self currentMediaDisplayName];
    }
}

- (void)showMediaLibrary:(id)sender {
    if (self.mediaPanel) {
        [self.mediaPanel makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        return;
    }

    self.mediaPanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 660, 380) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.mediaPanel.title = @"Media Library";
    self.mediaPanel.releasedWhenClosed = NO;
    self.mediaPanel.level = NSFloatingWindowLevel;
    [self.mediaPanel center];

    NSView *content = [[NSView alloc] initWithFrame:self.mediaPanel.contentView.bounds];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 64, 260, 286)];
    scroll.hasVerticalScroller = YES;
    self.mediaTable = [[NSTableView alloc] initWithFrame:scroll.bounds];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"media"];
    column.title = @"Media";
    column.width = 250;
    [self.mediaTable addTableColumn:column];
    self.mediaTable.headerView = nil;
    self.mediaTable.delegate = self;
    self.mediaTable.dataSource = self;
    scroll.documentView = self.mediaTable;
    [content addSubview:scroll];

    self.previewImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(310, 92, 320, 240)];
    self.previewImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    self.previewImageView.wantsLayer = YES;
    self.previewImageView.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
    [content addSubview:self.previewImageView];

    NSButton *addButton = [NSButton buttonWithTitle:@"Add Local..." target:self action:@selector(addLocalMedia:)];
    addButton.frame = NSMakeRect(20, 22, 104, 30);
    [content addSubview:addButton];

    NSButton *removeButton = [NSButton buttonWithTitle:@"Remove" target:self action:@selector(removeSelectedMedia:)];
    removeButton.frame = NSMakeRect(132, 22, 82, 30);
    [content addSubview:removeButton];

    NSButton *useButton = [NSButton buttonWithTitle:@"Use Selected" target:self action:@selector(useSelectedMedia:)];
    useButton.frame = NSMakeRect(510, 22, 120, 30);
    [content addSubview:useButton];

    self.mediaPanel.contentView = content;
    [self.mediaTable reloadData];
    NSInteger selected = [mediaItems() indexOfObject:settingCurrentMediaItem()];
    if (selected != NSNotFound) {
        [self.mediaTable selectRowIndexes:[NSIndexSet indexSetWithIndex:selected] byExtendingSelection:NO];
    } else if (mediaItems().count > 0) {
        [self.mediaTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
    [self updatePreviewForSelectedMedia];
    [self.mediaPanel makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)addLocalMedia:(id)sender {
    NSOpenPanel *panel = NSOpenPanel.openPanel;
    panel.title = @"Choose transparent media";
    panel.canChooseDirectories = NO;
    panel.canChooseFiles = YES;
    panel.allowsMultipleSelection = YES;
    NSMutableArray<UTType *> *types = [NSMutableArray array];
    for (NSString *extension in @[@"gif", @"png", @"apng", @"mov", @"m4v"]) {
        UTType *type = [UTType typeWithFilenameExtension:extension];
        if (type) { [types addObject:type]; }
    }
    panel.allowedContentTypes = types;
    if ([panel runModal] != NSModalResponseOK) { return; }

    BOOL hasVideo = NO;
    NSMutableArray<NSString *> *stored = [[[NSUserDefaults standardUserDefaults] arrayForKey:MediaItemsKey] mutableCopy] ?: [NSMutableArray array];
    for (NSURL *url in panel.URLs) {
        NSString *extension = url.pathExtension.lowercaseString;
        if ([extension isEqualToString:@"mov"] || [extension isEqualToString:@"m4v"]) {
            hasVideo = YES;
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) { continue; }
        if (![stored containsObject:url.path]) { [stored addObject:url.path]; }
    }

    if (hasVideo) {
        NSAlert *alert = NSAlert.new;
        alert.messageText = @"Transparent video required";
        alert.informativeText = @"MOV/M4V files must actually contain an alpha channel, such as ProRes 4444 or HEVC with Alpha. Normal videos will still show their background.";
        [alert runModal];
    }

    [[NSUserDefaults standardUserDefaults] setObject:stored forKey:MediaItemsKey];
    [self.mediaTable reloadData];
}

- (void)removeSelectedMedia:(id)sender {
    NSInteger row = self.mediaTable.selectedRow;
    NSArray<NSString *> *items = mediaItems();
    if (row < 0 || row >= items.count) { return; }
    NSString *item = items[row];
    if (isBuiltInMediaItem(item)) { return; }
    NSMutableArray<NSString *> *stored = [[[NSUserDefaults standardUserDefaults] arrayForKey:MediaItemsKey] mutableCopy] ?: [NSMutableArray array];
    [stored removeObject:item];
    [[NSUserDefaults standardUserDefaults] setObject:stored forKey:MediaItemsKey];
    if ([settingCurrentMediaItem() isEqualToString:item]) {
        [[NSUserDefaults standardUserDefaults] setObject:defaultMediaItem() forKey:CurrentMediaItemKey];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:LocalMediaPathKey];
        [self.petView reloadAnimation];
    }
    [self.mediaTable reloadData];
    [self updatePreviewForSelectedMedia];
    [self refreshMediaControls];
}

- (void)useSelectedMedia:(id)sender {
    NSInteger row = self.mediaTable.selectedRow;
    NSArray<NSString *> *items = mediaItems();
    if (row < 0 || row >= items.count) { return; }
    NSString *item = items[row];
    [[NSUserDefaults standardUserDefaults] setObject:item forKey:CurrentMediaItemKey];
    [self.petView reloadAnimation];
    [self.petView restartAnimationTimer];
    [self refreshMediaControls];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return mediaItems().count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTextField *cell = [tableView makeViewWithIdentifier:@"mediaCell" owner:self];
    if (!cell) {
        cell = [NSTextField labelWithString:@""];
        cell.identifier = @"mediaCell";
        cell.lineBreakMode = NSLineBreakByTruncatingMiddle;
    }
    NSArray<NSString *> *items = mediaItems();
    if (row >= 0 && row < items.count) {
        NSString *item = items[row];
        NSString *prefix = isBuiltInMediaItem(item) ? @"Built-in" : @"Local";
        cell.stringValue = [NSString stringWithFormat:@"%@  %@", prefix, mediaItemDisplayName(item)];
    }
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self updatePreviewForSelectedMedia];
}

- (void)clearPreviewPlayer {
    [self.previewPlayer pause];
    self.previewPlayer = nil;
    [self.previewPlayerLayer removeFromSuperlayer];
    self.previewPlayerLayer = nil;
}

- (void)updatePreviewForSelectedMedia {
    [self clearPreviewPlayer];
    self.previewImageView.image = nil;

    NSInteger row = self.mediaTable.selectedRow;
    NSArray<NSString *> *items = mediaItems();
    if (row < 0 || row >= items.count) { return; }
    NSString *item = items[row];

    if (isBuiltInMediaItem(item)) {
        NSString *relativePath = [NSString stringWithFormat:@"Animations/%@/frames/frame_01", animationIdFromItem(item)];
        NSURL *url = [NSBundle.mainBundle URLForResource:relativePath withExtension:@"png"];
        self.previewImageView.image = url ? [[NSImage alloc] initWithContentsOfURL:url] : nil;
        return;
    }

    NSString *extension = item.pathExtension.lowercaseString;
    NSURL *url = [NSURL fileURLWithPath:item];
    if ([extension isEqualToString:@"gif"] || [extension isEqualToString:@"png"] || [extension isEqualToString:@"apng"]) {
        self.previewImageView.image = [[NSImage alloc] initWithContentsOfURL:url];
        return;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    CGImageRef frame = [generator copyCGImageAtTime:kCMTimeZero actualTime:nil error:nil];
    if (frame) {
        self.previewImageView.image = [[NSImage alloc] initWithCGImage:frame size:NSZeroSize];
        CGImageRelease(frame);
    }
}

- (void)playbackModeChanged:(NSPopUpButton *)sender {
    NSString *mode = sender.selectedItem.representedObject;
    if (mode.length == 0) { return; }
    [[NSUserDefaults standardUserDefaults] setObject:mode forKey:PlaybackModeKey];
    [self restartRotationTimer];
}

- (void)rotateSecondsChanged:(NSTextField *)sender {
    [[NSUserDefaults standardUserDefaults] setDouble:MAX(5, sender.doubleValue) forKey:RotateSecondsKey];
    [self restartRotationTimer];
}

- (void)speedChanged:(NSSlider *)sender {
    [[NSUserDefaults standardUserDefaults] setDouble:sender.doubleValue forKey:SpeedKey];
    [self.petView restartAnimationTimer];
    NSTextField *value = [self.settingsPanel.contentView viewWithTag:901];
    if ([value isKindOfClass:NSTextField.class]) {
        value.stringValue = [NSString stringWithFormat:@"%.0f ms", sender.doubleValue * 1000];
    }
}

- (void)sizeChanged:(NSSlider *)sender {
    CGFloat size = sender.doubleValue;
    setSettingSize(size);
    NSRect frame = self.window.frame;
    frame.size = NSMakeSize(size, size);
    [self.window setFrame:frame display:YES];
    self.petView.frame = NSMakeRect(0, 0, size, size);
    self.petView.needsDisplay = YES;
}

- (void)durationChanged:(NSTextField *)sender {
    [[NSUserDefaults standardUserDefaults] setDouble:MAX(0, sender.doubleValue) forKey:DurationKey];
    self.startedAt = NSDate.date;
}

- (void)topChanged:(NSButton *)sender {
    BOOL onTop = sender.state == NSControlStateValueOn;
    [[NSUserDefaults standardUserDefaults] setBool:onTop forKey:TopKey];
    self.window.level = onTop ? NSFloatingWindowLevel : NSNormalWindowLevel;
}

- (void)quit:(id)sender {
    [NSApp terminate:nil];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        static AppDelegate *delegate = nil;
        delegate = [AppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
