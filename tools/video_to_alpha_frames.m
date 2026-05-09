#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

static double colorDistance(unsigned char *p, double r, double g, double b) {
    double dr = (double)p[0] - r;
    double dg = (double)p[1] - g;
    double db = (double)p[2] - b;
    return sqrt(dr * dr + dg * dg + db * db);
}

static void estimateCornerColor(unsigned char *data, size_t width, size_t height, size_t stride, double *r, double *g, double *b) {
    int samples = 0;
    double rr = 0, gg = 0, bb = 0;
    int patch = (int)MAX(4, MIN(width, height) / 16);
    int origins[4][2] = {
        {0, 0},
        {(int)width - patch, 0},
        {0, (int)height - patch},
        {(int)width - patch, (int)height - patch}
    };
    for (int corner = 0; corner < 4; corner++) {
        for (int y = 0; y < patch; y++) {
            for (int x = 0; x < patch; x++) {
                unsigned char *p = data + (origins[corner][1] + y) * stride + (origins[corner][0] + x) * 4;
                rr += p[0];
                gg += p[1];
                bb += p[2];
                samples++;
            }
        }
    }
    *r = rr / samples;
    *g = gg / samples;
    *b = bb / samples;
}

static NSMutableArray<NSArray<NSNumber *> *> *edgePalette(unsigned char *data, size_t width, size_t height, size_t stride) {
    NSMutableArray<NSArray<NSNumber *> *> *palette = [NSMutableArray array];
    size_t step = MAX((size_t)2, MIN(width, height) / 80);
    for (size_t x = 0; x < width; x += step) {
        unsigned char *top = data + x * 4;
        unsigned char *bottom = data + (height - 1) * stride + x * 4;
        [palette addObject:@[@(top[0]), @(top[1]), @(top[2])]];
        [palette addObject:@[@(bottom[0]), @(bottom[1]), @(bottom[2])]];
    }
    for (size_t y = 0; y < height; y += step) {
        unsigned char *left = data + y * stride;
        unsigned char *right = data + y * stride + (width - 1) * 4;
        [palette addObject:@[@(left[0]), @(left[1]), @(left[2])]];
        [palette addObject:@[@(right[0]), @(right[1]), @(right[2])]];
    }
    return palette;
}

static BOOL matchesPalette(unsigned char *p, NSArray<NSArray<NSNumber *> *> *palette, double threshold) {
    for (NSArray<NSNumber *> *color in palette) {
        double d = colorDistance(p, color[0].doubleValue, color[1].doubleValue, color[2].doubleValue);
        if (d <= threshold) { return YES; }
    }
    return NO;
}

static void removeConnectedBackground(unsigned char *data, size_t width, size_t height, size_t stride, double threshold) {
    NSArray<NSArray<NSNumber *> *> *palette = edgePalette(data, width, height, stride);
    size_t total = width * height;
    unsigned char *visited = calloc(total, 1);
    size_t *queue = malloc(sizeof(size_t) * total);
    size_t head = 0;
    __block size_t tail = 0;

    void (^tryAdd)(size_t, size_t) = ^(size_t x, size_t y) {
        size_t idx = y * width + x;
        if (visited[idx]) { return; }
        unsigned char *p = data + y * stride + x * 4;
        if (!matchesPalette(p, palette, threshold)) { return; }
        visited[idx] = 1;
        queue[tail++] = idx;
    };

    for (size_t x = 0; x < width; x++) {
        tryAdd(x, 0);
        tryAdd(x, height - 1);
    }
    for (size_t y = 0; y < height; y++) {
        tryAdd(0, y);
        tryAdd(width - 1, y);
    }

    while (head < tail) {
        size_t idx = queue[head++];
        size_t x = idx % width;
        size_t y = idx / width;
        if (x > 0) { tryAdd(x - 1, y); }
        if (x + 1 < width) { tryAdd(x + 1, y); }
        if (y > 0) { tryAdd(x, y - 1); }
        if (y + 1 < height) { tryAdd(x, y + 1); }
    }

    for (size_t i = 0; i < tail; i++) {
        size_t idx = queue[i];
        size_t x = idx % width;
        size_t y = idx / width;
        unsigned char *p = data + y * stride + x * 4;
        p[0] = 0;
        p[1] = 0;
        p[2] = 0;
        p[3] = 0;
    }

    free(queue);
    free(visited);
}

static BOOL writePNG(NSString *path, CGImageRef image) {
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)url, CFSTR("public.png"), 1, NULL);
    if (!dest) { return NO; }
    CGImageDestinationAddImage(dest, image, NULL);
    BOOL ok = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    return ok;
}

static CGImageRef processedImage(CGImageRef source, size_t maxSide, double threshold, double soft) {
    size_t width = CGImageGetWidth(source);
    size_t height = CGImageGetHeight(source);
    double scale = MIN(1.0, (double)maxSide / (double)MAX(width, height));
    size_t outW = MAX(1, (size_t)round(width * scale));
    size_t outH = MAX(1, (size_t)round(height * scale));
    size_t stride = outW * 4;
    unsigned char *data = calloc(outH, stride);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(data, outW, outH, 8, stride, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextDrawImage(ctx, CGRectMake(0, 0, outW, outH), source);

    removeConnectedBackground(data, outW, outH, stride, threshold);

    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    free(data);
    return image;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 3) {
            fprintf(stderr, "usage: video_to_alpha_frames <input.mp4> <out_dir> [fps=12] [max_side=512] [threshold=42]\n");
            return 2;
        }

        NSString *input = [NSString stringWithUTF8String:argv[1]];
        NSString *outDir = [NSString stringWithUTF8String:argv[2]];
        double fps = argc > 3 ? atof(argv[3]) : 12.0;
        size_t maxSide = argc > 4 ? (size_t)atoi(argv[4]) : 512;
        double threshold = argc > 5 ? atof(argv[5]) : 42.0;

        [[NSFileManager defaultManager] createDirectoryAtPath:outDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url = [NSURL fileURLWithPath:input];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        CMTime duration = asset.duration;
        Float64 seconds = CMTimeGetSeconds(duration);
        if (!isfinite(seconds) || seconds <= 0) {
            fprintf(stderr, "Could not read video duration.\n");
            return 1;
        }

        AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        generator.requestedTimeToleranceBefore = kCMTimeZero;
        generator.requestedTimeToleranceAfter = CMTimeMakeWithSeconds(1.0 / fps / 2.0, 600);

        NSInteger frameCount = (NSInteger)ceil(seconds * fps);
        for (NSInteger i = 0; i < frameCount; i++) {
            @autoreleasepool {
                CMTime time = CMTimeMakeWithSeconds((double)i / fps, 600);
                NSError *error = nil;
                CGImageRef source = [generator copyCGImageAtTime:time actualTime:nil error:&error];
                if (!source) {
                    fprintf(stderr, "Frame %ld failed: %s\n", (long)i, error.localizedDescription.UTF8String);
                    continue;
                }
                CGImageRef out = processedImage(source, maxSide, threshold, 36.0);
                NSString *path = [outDir stringByAppendingPathComponent:[NSString stringWithFormat:@"frame_%04ld.png", (long)i + 1]];
                writePNG(path, out);
                CGImageRelease(out);
                CGImageRelease(source);
            }
        }
        printf("%ld\n", (long)frameCount);
    }
    return 0;
}
