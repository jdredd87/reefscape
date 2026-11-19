"""Losslessly recompress PNGs (same pixels, smaller files) so the package stays under Roku's 4 MB limit.
   python tools/optimize-png.py [files...]     default: every PNG in images/ocean
Needs: python -m pip install pyoxipng pillow. Each result is checked pixel-for-pixel against the original."""
import glob, os, sys
import oxipng
from PIL import Image, ImageChops

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
files = sys.argv[1:] or sorted(glob.glob(os.path.join(root, 'images', 'ocean', '*.png')))
before = after = 0
for f in files:
    data = open(f, 'rb').read()
    # no alpha optimisation: fully transparent pixels keep their colour, so scaled edges look the same
    out = oxipng.optimize_from_memory(data, level=6, deflate=oxipng.Deflaters.zopfli(15), strip=oxipng.StripChunks.safe())
    before += len(data)
    if len(out) < len(data):
        tmp = f + '.tmp'
        open(tmp, 'wb').write(out)
        a, b = Image.open(f).convert('RGBA'), Image.open(tmp).convert('RGBA')
        if a.size != b.size or ImageChops.difference(a, b).getbbox() is not None:
            os.remove(tmp)
            sys.exit('pixels changed in ' + f)
        a.close(); b.close()
        os.replace(tmp, f)
        after += len(out)
    else:
        after += len(data)
print(f'{len(files)} PNGs: {before} -> {after} bytes (saved {before - after})')
