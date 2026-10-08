#!/usr/bin/env python3
# Disclaimer: This script was ai-generated and went through minimal revision.

import os
os.environ["OPENCV_LOG_LEVEL"] = "SILENT"
# Per-widget samples are tiny; library thread pools spinning on every core cost more than the work.
for _var in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(_var, "1")
import cv2
import numpy as np
import argparse
import fcntl
import hashlib
import json
import tempfile

cv2.setNumThreads(1)

CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "inir", "region-sampling")
CACHE_KEEP = 8

def center_crop(img, target_w, target_h):
    h, w = img.shape[:2]
    if w == target_w and h == target_h:
        return img
    x1 = max(0, (w - target_w) // 2)
    y1 = max(0, (h - target_h) // 2)
    x2 = x1 + target_w
    y2 = y1 + target_h
    return img[y1:y2, x1:x2]

def center_on_black(img, target_w, target_h):
    """The picture centred on a black screen, cut where it overflows (fit's and center's bars)."""
    img = center_crop(img, target_w, target_h)
    h, w = img.shape[:2]
    out = np.zeros((target_h, target_w) + img.shape[2:], dtype=img.dtype)
    x, y = (target_w - w) // 2, (target_h - h) // 2
    out[y:y + h, x:x + w] = img
    return out

def _read_screen_image(image_path, flags, screen_width, screen_height, screen_mode):
    """The wallpaper as the screen shows it in each scaling mode (Wallpapers.fillMode)."""
    img = cv2.imread(image_path, flags)
    if img is None:
        return None
    orig_h, orig_w = img.shape[:2]
    if screen_mode == "stretch":
        return cv2.resize(img, (screen_width, screen_height), interpolation=cv2.INTER_AREA)
    if screen_mode == "center":
        return center_on_black(img, screen_width, screen_height)
    if screen_mode == "tile":
        # Qt tiles from a centred copy (Image.Tile with the default centre alignment).
        reps_y, reps_x = -(-screen_height // orig_h) + 2, -(-screen_width // orig_w) + 2
        tiled = np.tile(img, (reps_y, reps_x) + (1,) * (img.ndim - 2))
        x = (orig_w - ((screen_width - orig_w) // 2) % orig_w) % orig_w
        y = (orig_h - ((screen_height - orig_h) // 2) % orig_h) % orig_h
        return tiled[y:y + screen_height, x:x + screen_width]
    scale_w = screen_width / orig_w
    scale_h = screen_height / orig_h
    scale = min(scale_w, scale_h) if screen_mode == "fit" else max(scale_w, scale_h)
    img = cv2.resize(img, (max(1, int(orig_w * scale)), max(1, int(orig_h * scale))), interpolation=cv2.INTER_LANCZOS4)
    return center_on_black(img, screen_width, screen_height) if screen_mode == "fit" else center_crop(img, screen_width, screen_height)

def load_screen_image(image_path, screen_width=None, screen_height=None, screen_mode="fill", grayscale=False):
    """Wallpaper scaled and cropped to the screen, cached per file revision and screen geometry."""
    flags = cv2.IMREAD_GRAYSCALE if grayscale else cv2.IMREAD_COLOR
    if screen_width is None or screen_height is None:
        return cv2.imread(image_path, flags)
    try:
        st = os.stat(image_path)
        key = hashlib.sha1(f"{os.path.realpath(image_path)}|{st.st_mtime_ns}|{st.st_size}|{screen_width}x{screen_height}|{screen_mode}|{'gray' if grayscale else 'bgr'}".encode()).hexdigest()
        os.makedirs(CACHE_DIR, exist_ok=True)
        cache_path = os.path.join(CACHE_DIR, key + ".npy")
        lock = open(os.path.join(CACHE_DIR, key + ".lock"), "w")
    except OSError:
        return _read_screen_image(image_path, flags, screen_width, screen_height, screen_mode)
    with lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            return np.load(cache_path)
        except (OSError, ValueError):
            pass
        img = _read_screen_image(image_path, flags, screen_width, screen_height, screen_mode)
        if img is None:
            return None
        try:
            with tempfile.NamedTemporaryFile(dir=CACHE_DIR, suffix=".tmp", delete=False) as tmp:
                np.save(tmp, img)
            os.replace(tmp.name, cache_path)
            entries = sorted((e for e in os.scandir(CACHE_DIR) if e.name.endswith(".npy")), key=lambda e: e.stat().st_mtime, reverse=True)
            for stale in entries[CACHE_KEEP:]:
                for suffix in (".npy", ".lock"):
                    try:
                        os.unlink(stale.path[:-4] + suffix)
                    except OSError:
                        pass
        except OSError:
            pass
        return img

def find_least_busy_region(image_path, region_width=300, region_height=200, screen_width=None, screen_height=None, verbose=False, stride=2, screen_mode="fill", horizontal_padding=50, vertical_padding=50, busiest=False):
    img = load_screen_image(image_path, screen_width, screen_height, screen_mode, grayscale=True)
    if img is None:
        raise FileNotFoundError(f"Image not found: {image_path}")
    if verbose:
        print(f"Using screen image of {img.shape[1]}x{img.shape[0]} (mode: {screen_mode})")
    arr = img.astype(np.float64)
    h, w = arr.shape
    # Validate & adjust stride
    stride = max(1, int(stride) if stride else 1)
    # Adjust region size if it does not fit given padding
    if horizontal_padding * 2 >= w or vertical_padding * 2 >= h:
        # Reduce padding to fit at least a 1x1 region
        horizontal_padding = max(0, min(horizontal_padding, (w - 1) // 2))
        vertical_padding = max(0, min(vertical_padding, (h - 1) // 2))
    max_region_w = w - 2 * horizontal_padding
    max_region_h = h - 2 * vertical_padding
    if max_region_w <= 0 or max_region_h <= 0:
        raise ValueError("Image too small for the specified padding.")
    if region_width > max_region_w:
        if verbose:
            print(f"Requested region_width {region_width} too large; clamping to {max_region_w}")
        region_width = max_region_w
    if region_height > max_region_h:
        if verbose:
            print(f"Requested region_height {region_height} too large; clamping to {max_region_h}")
        region_height = max_region_h
    # Use OpenCV's integral for fast computation
    integral = cv2.integral(arr, sdepth=cv2.CV_64F)[1:,1:]
    integral_sq = cv2.integral(arr**2, sdepth=cv2.CV_64F)[1:,1:]
    def region_sum(ii, x1, y1, x2, y2):
        # Assume bounds have been checked before calling
        total = ii[y2, x2]
        if x1 > 0:
            total -= ii[y2, x1-1]
        if y1 > 0:
            total -= ii[y1-1, x2]
        if x1 > 0 and y1 > 0:
            total += ii[y1-1, x1-1]
        return total
    min_var = None
    max_var = None
    min_coords = (horizontal_padding, vertical_padding)
    max_coords = (horizontal_padding, vertical_padding)
    area = region_width * region_height
    x_start = horizontal_padding
    y_start = vertical_padding
    x_end = w - region_width - horizontal_padding + 1
    y_end = h - region_height - vertical_padding + 1
    if x_end < x_start:
        x_end = x_start
    if y_end < y_start:
        y_end = y_start
    for y in range(y_start, y_end + 1, stride):
        for x in range(x_start, x_end + 1, stride):
            x1, y1 = x, y
            x2, y2 = x + region_width - 1, y + region_height - 1
            if x2 >= w or y2 >= h:
                continue  # Skip out-of-bounds window
            s = region_sum(integral, x1, y1, x2, y2)
            s2 = region_sum(integral_sq, x1, y1, x2, y2)
            mean = s / area
            var = (s2 / area) - (mean ** 2)
            if (min_var is None) or (var < min_var):
                min_var = var
                min_coords = (x, y)
            if (max_var is None) or (var > max_var):
                max_var = var
                max_coords = (x, y)
    if busiest:
        return max_coords, max_var
    else:
        return min_coords, min_var

def find_largest_region(image_path, screen_width=None, screen_height=None, verbose=False, stride=2, screen_mode="fill", threshold=100.0, aspect_ratio=1.0, horizontal_padding=50, vertical_padding=50):
    img = load_screen_image(image_path, screen_width, screen_height, screen_mode, grayscale=True)
    if img is None:
        raise FileNotFoundError(f"Image not found: {image_path}")
    if verbose:
        print(f"Using screen image of {img.shape[1]}x{img.shape[0]} (mode: {screen_mode})")
    arr = img.astype(np.float64)
    h, w = arr.shape
    stride = max(1, int(stride) if stride else 1)
    threshold = max(0.0, float(threshold))
    # Adjust padding if image too small
    if horizontal_padding * 2 >= w or vertical_padding * 2 >= h:
        horizontal_padding = max(0, min(horizontal_padding, (w - 1) // 2))
        vertical_padding = max(0, min(vertical_padding, (h - 1) // 2))
    # Use OpenCV's integral for fast computation
    integral = cv2.integral(arr, sdepth=cv2.CV_64F)[1:,1:]
    integral_sq = cv2.integral(arr**2, sdepth=cv2.CV_64F)[1:,1:]
    def region_sum(ii, x1, y1, x2, y2):
        total = ii[y2, x2]
        if x1 > 0:
            total -= ii[y2, x1-1]
        if y1 > 0:
            total -= ii[y1-1, x2]
        if x1 > 0 and y1 > 0:
            total += ii[y1-1, x1-1]
        return total
    min_size = 10
    # Determine maximum feasible size respecting padding
    effective_w = w - 2 * horizontal_padding
    effective_h = h - 2 * vertical_padding
    if effective_w <= 0 or effective_h <= 0:
        return None, (0, 0), None
    # Largest square-ish dimension given aspect ratio and effective space
    if aspect_ratio >= 1.0:
        max_size = min(effective_h, int(effective_w / aspect_ratio))
    else:
        max_size = min(int(effective_h * aspect_ratio), effective_w)
    if max_size < min_size:
        min_size = 1
        max_size = max(1, max_size)
    best = None
    while min_size <= max_size:
        mid = (min_size + max_size) // 2
        if aspect_ratio >= 1.0:
            region_h = mid
            region_w = int(round(mid * aspect_ratio))
        else:
            region_w = mid
            region_h = int(round(mid / aspect_ratio if aspect_ratio != 0 else mid))
        if region_w <= 0 or region_h <= 0:
            break
        if region_w > effective_w or region_h > effective_h:
            max_size = mid - 1
            continue
        found = False
        x_start = horizontal_padding
        y_start = vertical_padding
        x_end = w - region_w - horizontal_padding
        y_end = h - region_h - vertical_padding
        for y in range(y_start, y_end + 1, stride):
            for x in range(x_start, x_end + 1, stride):
                x1, y1 = x, y
                x2, y2 = x + region_w - 1, y + region_h - 1
                if x2 >= w or y2 >= h:
                    continue
                s = region_sum(integral, x1, y1, x2, y2)
                s2 = region_sum(integral_sq, x1, y1, x2, y2)
                area = region_w * region_h
                mean = s / area
                var = (s2 / area) - (mean ** 2)
                if var <= threshold:
                    found = True
                    best = (x, y, region_w, region_h, var)
                    break
            if found:
                break
        if found:
            min_size = mid + 1
        else:
            max_size = mid - 1
    if best:
        x, y, region_w, region_h, var = best
        center_x = x + region_w // 2
        center_y = y + region_h // 2
        return (center_x, center_y), (region_w, region_h), var
    else:
        return None, (0, 0), None

def draw_region(image_path, coords, region_width=300, region_height=200, output_path='output.png', screen_width=None, screen_height=None, screen_mode="fill"):
    img = cv2.imread(image_path)
    if img is None:
        raise FileNotFoundError(f"Image not found: {image_path}")
    orig_h, orig_w = img.shape[:2]
    if screen_width is not None and screen_height is not None:
        scale_w = screen_width / orig_w
        scale_h = screen_height / orig_h
        if screen_mode == "fill":
            scale = max(scale_w, scale_h)
        else:
            scale = min(scale_w, scale_h)
        new_w = int(orig_w * scale)
        new_h = int(orig_h * scale)
        img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LANCZOS4)
        img = center_crop(img, screen_width, screen_height)
    x, y = coords
    cv2.rectangle(img, (x, y), (x+region_width-1, y+region_height-1), (0,0,255), 3)
    cv2.imwrite(output_path, img)
    # print removed for quieter operation

def draw_largest_region(image_path, center, size, output_path='output.png', screen_width=None, screen_height=None, screen_mode="fill"):
    img = cv2.imread(image_path)
    if img is None:
        raise FileNotFoundError(f"Image not found: {image_path}")
    orig_h, orig_w = img.shape[:2]
    if screen_width is not None and screen_height is not None:
        scale_w = screen_width / orig_w
        scale_h = screen_height / orig_h
        if screen_mode == "fill":
            scale = max(scale_w, scale_h)
        else:
            scale = min(scale_w, scale_h)
        new_w = int(orig_w * scale)
        new_h = int(orig_h * scale)
        img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LANCZOS4)
        img = center_crop(img, screen_width, screen_height)
    cx, cy = center
    region_w, region_h = size
    x1 = cx - region_w // 2
    y1 = cy - region_h // 2
    x2 = cx + region_w // 2 - 1
    y2 = cy + region_h // 2 - 1
    cv2.rectangle(img, (x1, y1), (x2, y2), (255,0,0), 3)
    cv2.imwrite(output_path, img)
    # print removed for quieter operation

def get_region_brightness(image_path, x, y, w, h, screen_width=None, screen_height=None, screen_mode="fill"):
    """Get average brightness and brightness std-dev (both 0-255) of a region.

    Returns a (mean, std) tuple. The std-dev measures how "busy"/high-contrast
    the region is, so consumers can target worst-case legibility instead of
    trusting the mean (which lies on textured wallpapers).
    """
    img = load_screen_image(image_path, screen_width, screen_height, screen_mode, grayscale=True)
    if img is None:
        return 128.0, 0.0
    x = max(0, x)
    y = max(0, y)
    w = max(1, min(w, img.shape[1] - x))
    h = max(1, min(h, img.shape[0] - y))
    region = img[y:y+h, x:x+w]
    if region.size == 0:
        return 128.0, 0.0
    return float(np.mean(region)), float(np.std(region))

def get_dominant_color(image_path, x, y, w, h, screen_width=None, screen_height=None, screen_mode="fill"):
    img = load_screen_image(image_path, screen_width, screen_height, screen_mode)
    if img is None:
        raise FileNotFoundError(f"Image not found: {image_path}")
    # Ensure region is within bounds
    x = max(0, x)
    y = max(0, y)
    w = max(1, min(w, img.shape[1] - x))
    h = max(1, min(h, img.shape[0] - y))
    region = img[y:y+h, x:x+w]
    if region.size == 0 or region.shape[0] == 0 or region.shape[1] == 0:
        return [0, 0, 0]
    # Keep the full sampled region. Discarding dark pixels biases mixed/dark
    # wallpapers toward their bright highlights, which made desktop widgets
    # choose an accent as if the backdrop were much brighter than it really is.
    region = np.float32(region.reshape((-1, 3)))
    if region.shape[0] < 3:
        return [int(x) for x in np.mean(region, axis=0)]
    # K-means to find dominant color
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0)
    K = min(3, region.shape[0])
    # OpenCV's random centers otherwise make the same widget position capable of
    # returning a different dominant cluster on consecutive analyses. Stable
    # editing needs identical input geometry to produce identical color output.
    cv2.setRNGSeed(0)
    _, labels, centers = cv2.kmeans(region, K, None, criteria, 10, cv2.KMEANS_PP_CENTERS)
    counts = np.bincount(labels.flatten())
    dominant = centers[np.argmax(counts)]
    # Reverse from BGR to RGB
    return [int(x) for x in reversed(dominant)]

def luma_grid(image_path, cell, screen_width, screen_height, screen_mode="fill"):
    """Per-cell mean luma, mean squared luma and mean colour of the wallpaper as the screen shows it.

    One run serves every widget on that screen: a widget sums the cells under its rect, so its
    brightness, spread and mean colour are exact for any position without another process.
    """
    img = load_screen_image(image_path, screen_width, screen_height, screen_mode)
    if img is None:
        raise FileNotFoundError(f"Image not found: {image_path}")
    h, w = img.shape[:2]
    cols = max(1, -(-w // cell))
    rows = max(1, -(-h // cell))
    pad_w = cols * cell - w
    pad_h = rows * cell - h
    if pad_w or pad_h:
        img = cv2.copyMakeBorder(img, 0, pad_h, 0, pad_w, cv2.BORDER_REPLICATE)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32)
    shape = (rows, cell, cols, cell)
    mean = gray.reshape(shape).mean(axis=(1, 3))
    sq = (gray * gray).reshape(shape).mean(axis=(1, 3))
    bgr = img.astype(np.float32).reshape(rows, cell, cols, cell, 3).mean(axis=(1, 3))
    return {
        "cols": int(cols),
        "rows": int(rows),
        "cell": int(cell),
        "width": int(w),
        "height": int(h),
        "mean": [int(round(v)) for v in mean.flatten()],
        "sq": [int(round(v)) for v in sq.flatten()],
        "r": [int(round(v)) for v in bgr[..., 2].flatten()],
        "g": [int(round(v)) for v in bgr[..., 1].flatten()],
        "b": [int(round(v)) for v in bgr[..., 0].flatten()],
    }

def main():
    parser = argparse.ArgumentParser(description="Find least busy region in an image and output a JSON. Made for determining a suitable position for a wallpaper widget.")
    parser.add_argument("image_path", help="Path to the input image")
    parser.add_argument("--width", type=int, default=300, help="Region width")
    parser.add_argument("--height", type=int, default=200, help="Region height")
    parser.add_argument("-v", "--visual-output", action="store_true", help="Output image with rectangle")
    parser.add_argument("--screen-width", type=int, default=1920, help="Screen width for wallpaper scaling")
    parser.add_argument("--screen-height", type=int, default=1080, help="Screen height for wallpaper scaling")
    parser.add_argument("--stride", type=int, default=10, help="Step size for sliding window (higher is faster, less precise)")
    parser.add_argument("--screen-mode", choices=["fill", "fit", "stretch", "center", "tile"], default="fill", help="Wallpaper scaling mode as the desktop draws it (span is fill on the whole canvas)")
    parser.add_argument("--verbose", action="store_true", help="Print verbose output")
    parser.add_argument("-l", "--largest-region", action="store_true", help="Find the largest region under the variance threshold and output its center")
    parser.add_argument("-t", "--variance-threshold", type=float, default=1000.0, help="Variance threshold for largest region mode")
    parser.add_argument("--aspect-ratio", type=float, default=1.78, help="Aspect ratio (width/height) for largest region mode")
    parser.add_argument("--horizontal-padding", "-hp", type=int, default=50, help="Minimum horizontal distance from region to image edge")
    parser.add_argument("--vertical-padding", "-vp", type=int, default=50, help="Minimum vertical distance from region to image edge")
    parser.add_argument("--busiest", action="store_true", help="Find the busiest region instead of the least busy")
    parser.add_argument("--color-only", action="store_true", help="Skip region search; analyze color/brightness at a specific position")
    parser.add_argument("--position-x", type=int, default=0, help="Widget X position for --color-only mode")
    parser.add_argument("--position-y", type=int, default=0, help="Widget Y position for --color-only mode")
    parser.add_argument("--luma-grid", type=int, default=0, metavar="CELL", help="Print per-cell luma and colour of the whole screen in CELL-pixel cells")
    args = parser.parse_args()

    if args.luma_grid > 0:
        print(json.dumps(luma_grid(args.image_path, args.luma_grid, args.screen_width, args.screen_height, args.screen_mode), separators=(",", ":")))
        return

    # Color-only mode: analyze the region at the widget's actual position
    if args.color_only:
        dominant_color = get_dominant_color(
            args.image_path, args.position_x, args.position_y, args.width, args.height,
            screen_width=args.screen_width, screen_height=args.screen_height, screen_mode=args.screen_mode
        )
        brightness, brightness_std = get_region_brightness(
            args.image_path, args.position_x, args.position_y, args.width, args.height,
            screen_width=args.screen_width, screen_height=args.screen_height, screen_mode=args.screen_mode
        )
        dominant_color_hex = '#{:02x}{:02x}{:02x}'.format(*dominant_color)
        print(json.dumps({
            "center_x": args.position_x + args.width // 2,
            "center_y": args.position_y + args.height // 2,
            "width": args.width,
            "height": args.height,
            "dominant_color": dominant_color_hex,
            "brightness": round(brightness, 1),
            "brightness_std": round(brightness_std, 1)
        }))
        return

    if args.largest_region:
        center, size, var = find_largest_region(
            args.image_path,
            screen_width=args.screen_width,
            screen_height=args.screen_height,
            verbose=args.verbose,
            stride=args.stride,
            screen_mode=args.screen_mode,
            threshold=args.variance_threshold,
            aspect_ratio=args.aspect_ratio,
            horizontal_padding=args.horizontal_padding,
            vertical_padding=args.vertical_padding
        )
        if center:
            if args.visual_output:
                draw_largest_region(args.image_path, center, size, screen_width=args.screen_width, screen_height=args.screen_height, screen_mode=args.screen_mode)
            # Extract dominant color
            cx, cy = center
            region_w, region_h = size
            x1 = cx - region_w // 2
            y1 = cy - region_h // 2
            dominant_color = get_dominant_color(
                args.image_path, x1, y1, region_w, region_h,
                screen_width=args.screen_width, screen_height=args.screen_height, screen_mode=args.screen_mode
            )
            brightness, brightness_std = get_region_brightness(
                args.image_path, x1, y1, region_w, region_h,
                screen_width=args.screen_width, screen_height=args.screen_height, screen_mode=args.screen_mode
            )
            dominant_color_hex = '#{:02x}{:02x}{:02x}'.format(*dominant_color)
            print(json.dumps({
                "center_x": center[0],
                "center_y": center[1],
                "width": size[0],
                "height": size[1],
                "variance": var,
                "dominant_color": dominant_color_hex,
                "brightness": round(brightness, 1),
                "brightness_std": round(brightness_std, 1)
            }))
        else:
            print(json.dumps({"error": "No region found under the threshold."}))
        return

    coords, variance = find_least_busy_region(
        args.image_path,
        region_width=args.width,
        region_height=args.height,
        screen_width=args.screen_width,
        screen_height=args.screen_height,
        verbose=args.verbose,
        stride=args.stride,
        screen_mode=args.screen_mode,
        horizontal_padding=args.horizontal_padding,
        vertical_padding=args.vertical_padding,
        busiest=args.busiest
    )
    if args.visual_output:
        draw_region(args.image_path, coords, region_width=args.width, region_height=args.height, screen_width=args.screen_width, screen_height=args.screen_height, screen_mode=args.screen_mode)
    # Output JSON with center point
    center_x = coords[0] + args.width // 2
    center_y = coords[1] + args.height // 2
    dominant_color = get_dominant_color(
        args.image_path, coords[0], coords[1], args.width, args.height,
        screen_width=args.screen_width, screen_height=args.screen_height, screen_mode=args.screen_mode
    )
    brightness, brightness_std = get_region_brightness(
        args.image_path, coords[0], coords[1], args.width, args.height,
        screen_width=args.screen_width, screen_height=args.screen_height, screen_mode=args.screen_mode
    )
    dominant_color_hex = '#{:02x}{:02x}{:02x}'.format(*dominant_color)
    print(json.dumps({
        "center_x": center_x,
        "center_y": center_y,
        "width": args.width,
        "height": args.height,
        "variance": variance,
        "dominant_color": dominant_color_hex,
        "brightness": round(brightness, 1),
        "brightness_std": round(brightness_std, 1)
    }))

if __name__ == "__main__":
    main()

