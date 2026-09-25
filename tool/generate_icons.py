"""Generates PennyPal launcher icons for Android, iOS and the web.

Usage (from the project root):  python3 tool/generate_icons.py
Requires Pillow. Draws the brand mark: a white "P" on PennyPal green.
"""
import glob
import os

from PIL import Image, ImageDraw, ImageFont

GREEN = (30, 142, 78, 255)
FONT = 'assets/fonts/Nunito-800.ttf'


def mark(size, rounded=True, padding=0.0):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0) if rounded else GREEN)
    d = ImageDraw.Draw(img)
    if rounded:
        d.rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * 0.22), fill=GREEN)
    inner = size * (1 - 2 * padding)
    font = ImageFont.truetype(FONT, int(inner * 0.72))
    d.text((size / 2, size / 2), 'P', font=font, fill='white', anchor='mm')
    return img


def save(img, path):
    img.save(path)
    print('wrote', path)


# Android legacy launcher icons.
for folder, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    save(mark(px), f'android/app/src/main/res/mipmap-{folder}/ic_launcher.png')

# iOS: icons must be square and opaque; keep the sizes Xcode expects.
for path in glob.glob('ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png'):
    with Image.open(path) as old:
        px = old.size[0]
    save(mark(px, rounded=False).convert('RGB'), path)

# Web.
save(mark(32), 'web/favicon.png')
save(mark(192), 'web/icons/Icon-192.png')
save(mark(512), 'web/icons/Icon-512.png')
save(mark(192, rounded=False, padding=0.1), 'web/icons/Icon-maskable-192.png')
save(mark(512, rounded=False, padding=0.1), 'web/icons/Icon-maskable-512.png')
