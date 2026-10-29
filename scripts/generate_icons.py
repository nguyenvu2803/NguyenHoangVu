"""Generate the code-native Workroom dotted mark without external dependencies."""
from pathlib import Path
import json
import math
import struct
import zlib

root = Path(__file__).resolve().parents[1] / 'mobile'


def png(path, size):
    pixels = bytearray()
    for y in range(size):
        pixels.append(0)
        for x in range(size):
            gx = round((x - size / 2) / (size * .13))
            gy = round((y - size / 2) / (size * .13))
            radius = size * (.036 - .006 * math.hypot(gx, gy))
            dist = math.hypot(x - (size / 2 + gx * size * .13), y - (size / 2 + gy * size * .13))
            alpha = max(0, min(1, radius - dist + .5)) if abs(gx) <= 2 and abs(gy) <= 2 and abs(gx) + abs(gy) <= 3 else 0
            base = (18, 91, 75)
            dot = (237, 241, 215)
            pixels.extend(int(b + (d - b) * alpha) for b, d in zip(base, dot))
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)
    content = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(pixels))) + chunk(b'IEND', b'')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


for density, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    png(root / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', size)
asset = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((asset / 'Contents.json').read_text())['images']:
    if 'filename' in item:
        size = round(float(item['size'].split('x')[0]) * float(item['scale'].rstrip('x')))
        png(asset / item['filename'], size)
for size in [192, 512]:
    for name in [f'Icon-{size}.png', f'Icon-maskable-{size}.png']:
        png(root / 'web/icons' / name, size)
png(root / 'web/favicon.png', 32)
print('Generated Android, iOS and web icons.')
