# Puts the screens from store_screenshots_test.dart into a device frame under a
# caption, at the App Store sizes for 6.9" iPhones and 13" iPads:
#
#   python3 tool/store_screenshots/compose.py
#
# writes build/store_screenshots/out/<locale>/<device>-<n>.png. share-<device>.png
# here is the iOS share sheet, which no Flutter test can render.
import json
from functools import cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).parent
RAW = Path('build/store_screenshots')
FONT = 'assets/fonts/BricolageGrotesque.ttf'
EMOJI = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'
STATUS_FONT = ImageFont.truetype('/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf', 1)

BACKGROUND = (14, 13, 18)
TEXT = (242, 240, 234)
ACCENT = (100, 204, 158)
BEZEL = (23, 23, 26)

DEVICES = {
    # canvas, screen width, top of the frame, frame width, corner radius, safe area of the raw screen in px
    'iphone': dict(canvas=(1320, 2868), screen=1100, top=720, frame=30, radius=150, status=186),
    'ipad': dict(canvas=(2064, 2752), screen=1628, top=720, frame=34, radius=70, status=48),
}

SLIDES = ['share', 'song', 'group', 'album', 'friends']
CAPTIONS = {
    'de': {
        'share': ('Teilen wie immer.\nSonggate wählen.', 'Direkt aus deiner Musik-App'),
        'song': ('Derselbe Song,\nauf jedem Dienst.', 'Spotify, Apple Music, YouTube Music, Deezer'),
        'group': ('Jeder bekommt\nseinen Link.', 'Für Freunde und ganze Gruppen'),
        'album': ('Ganze Alben\ngehen genauso.', 'Mit Cover, Künstler und Titel'),
        'friends': ('Freunde bleiben\nauf deinem Gerät.', 'Ohne Anmeldung, ohne Tracking'),
    },
    'en': {
        'share': ('Share as usual.\nChoose Songgate.', 'Directly from your music app'),
        'song': ('Same song.\nEvery service.', 'Spotify, Apple Music, YouTube Music, Deezer'),
        'group': ('A link for\nevery friend.', 'For friends and whole groups'),
        'album': ('Whole albums\nwork the same.', 'With cover, artist and title'),
        'friends': ('Your friends stay\non your device.', 'No sign-up. No tracking.'),
    },
}
STORE_LOCALES = {'de': 'de-DE', 'en': 'en-US'}


def font(size, weight=780, width=80):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([96, weight, width])
    return f


def paint_emoji(screen, boxes):
    """The test fonts have no emoji, so the 🎵 or 💿 in the message is drawn here."""
    draw = ImageDraw.Draw(screen)
    for kind, left, top, right, bottom in boxes:
        glyph = Image.new('RGBA', (136, 128))
        ImageDraw.Draw(glyph).text((0, 0), '🎵💿'[int(kind)], font=ImageFont.truetype(EMOJI, 109), embedded_color=True)
        glyph = glyph.crop(glyph.getbbox())
        height = bottom - top
        # The missing glyph is narrower than an emoji: use it and the space after it
        size = round(min(height * 0.5, (right - left) * 1.5))
        # Cover the missing glyph with the message box's colour just left of it
        draw.rectangle([left, top, right, bottom], fill=screen.getpixel((max(0, left - 4), top + height / 2)))
        scaled = glyph.resize((round(glyph.width * size / glyph.height), size), Image.LANCZOS)
        screen.alpha_composite(scaled, (round(left), round(top + (height - size) / 2)))


def status_bar(screen, height, scale):
    """9:41, signal, Wi-Fi and battery like an iPhone or iPad in the store pictures."""
    draw = ImageDraw.Draw(screen)
    middle = height * 0.55
    clock = STATUS_FONT.font_variant(size=round(17 * scale))
    draw.text((round(screen.width * 0.11), middle), '9:41', font=clock, fill=TEXT, anchor='mm')
    right = screen.width * 0.9
    unit = 4 * scale
    battery = [right - 7 * unit, middle - 1.6 * unit, right, middle + 1.6 * unit]
    draw.rounded_rectangle(battery, radius=unit, outline=TEXT, width=max(2, round(scale / 1.2)))
    draw.rounded_rectangle([battery[0] + unit * 0.6, battery[1] + unit * 0.6, battery[2] - unit * 1.6, battery[3] - unit * 0.6], radius=unit / 2, fill=TEXT)
    wifi = right - 10.5 * unit
    for i, radius in enumerate([2.6, 1.8, 1.0]):
        r = radius * unit
        draw.arc([wifi - r, middle + unit - r, wifi + r, middle + unit + r], 225, 315, fill=TEXT, width=round(unit * 0.55))
    for i in range(4):
        x = right - (17 - i * 1.3) * unit
        h = (0.9 + i * 0.6) * unit
        draw.rounded_rectangle([x, middle + 1.4 * unit - h, x + unit * 0.9, middle + 1.4 * unit], radius=unit / 4, fill=TEXT)


@cache
def background(size):
    image = Image.new('RGB', size, BACKGROUND)
    glow = Image.new('RGB', size, BACKGROUND)
    draw = ImageDraw.Draw(glow)
    w, h = size
    draw.ellipse([-w * 0.3, -h * 0.25, w * 0.75, h * 0.35], fill=(36, 82, 64))
    draw.ellipse([w * 0.45, -h * 0.15, w * 1.3, h * 0.3], fill=(28, 70, 84))
    return Image.blend(image, glow.filter(ImageFilter.GaussianBlur(w * 0.18)), 0.9)


def compose(locale, device, slide, n):
    spec = DEVICES[device]
    canvas = background(spec['canvas']).convert('RGBA')
    w, h = spec['canvas']
    draw = ImageDraw.Draw(canvas)
    title, subtitle = CAPTIONS[locale][slide]
    draw.multiline_text((w / 2, 150), title, font=font(118), fill=TEXT, anchor='ma', align='center', spacing=4)
    draw.text((w / 2, 470), subtitle, font=font(50, weight=500, width=100), fill=ACCENT, anchor='ma')

    screen_w = spec['screen']
    if slide == 'share':
        screen = Image.open(HERE / f'share-{device}.png').convert('RGBA')
    else:
        raw = Image.open(RAW / f'{locale}-{device}-{slide}.png').convert('RGBA')
        boxes = RAW / f'{locale}-{device}-{slide}.json'
        paint_emoji(raw, json.loads(boxes.read_text()) if boxes.exists() else [])
        status_bar(raw, spec['status'], raw.width / (440 if device == 'iphone' else 1032))
        screen = raw.resize((screen_w, round(raw.height * screen_w / raw.width)), Image.LANCZOS)
    left = (w - screen_w) // 2
    top = spec['top']
    frame = spec['frame']
    draw.rounded_rectangle([left - frame, top - frame, left + screen_w + frame, h + spec['radius'] * 2], radius=spec['radius'] + frame, fill=BEZEL)
    mask = Image.new('L', (screen_w, h - top), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen_w, h - top + spec['radius'] * 2], radius=spec['radius'], fill=255)
    canvas.paste(screen.crop((0, 0, screen_w, h - top)), (left, top), mask)
    out = RAW / 'out' / STORE_LOCALES[locale] / f'{device}-{n}.png'
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert('RGB').save(out)


for locale in CAPTIONS:
    for device in DEVICES:
        for n, slide in enumerate(SLIDES, 1):
            compose(locale, device, slide, n)
print('written to', RAW / 'out')
