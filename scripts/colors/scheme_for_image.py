#!/usr/bin/env python3
import sys
import cv2
import numpy as np

# Allowed scheme types
SCHEMES = [
    "scheme-content",
    "scheme-expressive",
    "scheme-fidelity",
    "scheme-fruit-salad",
    "scheme-monochrome",
    "scheme-neutral",
    "scheme-rainbow",
    "scheme-tonal-spot",
]


def image_colorfulness(image):
    # Based on Hasler and Süsstrunk's colorfulness metric
    (B, G, R) = cv2.split(image.astype("float"))
    rg = np.absolute(R - G)
    yb = np.absolute(0.5 * (R + G) - B)
    std_rg = np.std(rg)
    std_yb = np.std(yb)
    mean_rg = np.mean(rg)
    mean_yb = np.mean(yb)
    colorfulness = np.sqrt(std_rg**2 + std_yb**2) + (
        0.3 * np.sqrt(mean_rg**2 + mean_yb**2)
    )
    return colorfulness


def dominant_saturation(image):
    """Average saturation of the image in HSV space."""
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    return float(np.mean(hsv[:, :, 1]))


def color_variety(image):
    """Rough hue spread: std-dev of the hue channel (0-180 in OpenCV)."""
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    return float(np.std(hsv[:, :, 0]))


def pick_scheme(colorfulness, saturation, hue_spread):
    """
    Multi-axis decision tree for scheme variant selection.

    Axes:
      - colorfulness  (Hasler-Süsstrunk metric, 0-~200+)
      - saturation    (mean HSV saturation, 0-255)
      - hue_spread    (hue std-dev, 0-~90)

    Design goals:
      - tonal-spot is the safe default — most images should land here
      - Near-grayscale images → monochrome (preserves intent)
      - Low-color, muted images → neutral (calm palette)
      - Focused moderate color → content (faithful to source)
      - High saturation + focused hue → fidelity (vibrant but faithful)
      - Expressive/rainbow only for genuinely extreme images
    """
    # Near-grayscale: very low saturation regardless of other metrics
    if saturation < 20:
        return "scheme-monochrome"

    # Low colorfulness: muted/desaturated images
    if colorfulness < 30:
        return "scheme-neutral"

    # Low-to-moderate colorfulness — tonal-spot or content
    if colorfulness < 55:
        if hue_spread < 22 and saturation < 100:
            return "scheme-content"
        return "scheme-tonal-spot"

    # Moderate colorfulness — mostly tonal-spot, fidelity for saturated
    if colorfulness < 90:
        if saturation > 140 and hue_spread < 35:
            # Very saturated with focused hue → fidelity
            return "scheme-fidelity"
        if hue_spread < 30:
            # Focused color, moderate saturation → content
            return "scheme-content"
        return "scheme-tonal-spot"

    # High colorfulness (90+) — only here do expressive/rainbow appear
    if hue_spread > 55 and saturation > 150:
        return "scheme-rainbow"
    if saturation > 160:
        return "scheme-fidelity"
    if hue_spread > 45:
        return "scheme-expressive"
    return "scheme-tonal-spot"


def main():
    colorfulness_mode = False
    args = sys.argv[1:]
    if "--colorfulness" in args:
        colorfulness_mode = True
        args.remove("--colorfulness")
    if len(args) < 1:
        print("scheme-tonal-spot")
        sys.exit(1)
    img_path = args[0]
    img = cv2.imread(img_path)
    if img is None:
        print("scheme-tonal-spot")
        sys.exit(1)
    colorfulness = image_colorfulness(img)
    if colorfulness_mode:
        print(f"{colorfulness}")
    else:
        sat = dominant_saturation(img)
        spread = color_variety(img)
        scheme = pick_scheme(colorfulness, sat, spread)
        print(scheme)


if __name__ == "__main__":
    main()
