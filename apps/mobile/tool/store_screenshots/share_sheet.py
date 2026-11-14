# Picture 1 of the App Store set: a song shared from a music player through the
# iOS share sheet, with Songgate among the apps and saved friends as suggestions
# (the app donates them, see AGENTS.md). No Flutter test can render the system
# sheet, so it is drawn here: own simplified app icons, no third-party logos.
# compose.py calls share_screen() and status_bar().
from functools import cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).parent
ROBOTO = '/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF/Roboto-{}.ttf'
SS = 2  # everything is drawn at twice the size and scaled down for smooth edges

TEXTS = {
    'de': dict(apps=['Songgate', 'Nachrichten', 'Mail', 'Notizen', 'Erinnerungen'], copy='Kopieren', edit='Aktionen bearbeiten …', date='Di. 9. Jan.'),
    'en': dict(apps=['Songgate', 'Messages', 'Mail', 'Notes', 'Reminders'], copy='Copy', edit='Edit Actions…', date='Tue Jan 9'),
}
# name, initials (a group shows its members), badge of the app that suggests it
PEOPLE = [('Lena', 'L', 'songgate'), ('Bandprobe', 'LJT', 'songgate'), ('Jonas', 'J', 'messages'), ('Mira', 'M', 'songgate')]
ACCENT = (100, 204, 158)
SHEET = (242, 242, 247)
LABEL = (28, 28, 30)
SECONDARY = (138, 138, 142)
SEPARATOR = (209, 209, 214)


@cache
def roboto(weight, px):
    return ImageFont.truetype(ROBOTO.format(weight), px)


class Pen:
    """Draws in iOS points: k is pixels per point."""

    def __init__(self, image, k):
        self.image, self.k = image, k
        self.draw = ImageDraw.Draw(image)

    def box(self, *v):
        return [x * self.k for x in v]

    def on(self, color):
        """ImageDraw replaces RGBA pixels instead of blending, so translucent colours go through a layer."""
        if color is None or len(color) == 3 or color[3] == 255:
            return lambda paint: paint(self.draw)

        def blend(paint):
            layer = Image.new('RGBA', self.image.size)
            paint(ImageDraw.Draw(layer))
            self.image.alpha_composite(layer)
        return blend

    def rect(self, x0, y0, x1, y1, r, fill=None, outline=None, width=0):
        self.on(fill or outline)(lambda d: d.rounded_rectangle(self.box(x0, y0, x1, y1), radius=r * self.k, fill=fill, outline=outline, width=round(width * self.k)))

    def circle(self, x, y, r, fill):
        self.on(fill)(lambda d: d.ellipse(self.box(x - r, y - r, x + r, y + r), fill=fill))

    def line(self, points, fill, width):
        self.on(fill)(lambda d: d.line([p * self.k for xy in points for p in xy], fill=fill, width=round(width * self.k), joint='curve'))

    def polygon(self, points, fill):
        self.on(fill)(lambda d: d.polygon([(x * self.k, y * self.k) for x, y in points], fill=fill))

    def text(self, x, y, s, size, fill, weight='Regular', anchor='la'):
        self.on(fill)(lambda d: d.text((x * self.k, y * self.k), s, font=roboto(weight, round(size * self.k)), fill=fill, anchor=anchor))

    def width(self, s, size, weight='Regular'):
        return self.draw.textlength(s, font=roboto(weight, round(size * self.k))) / self.k

    def paste(self, image, x, y):
        self.image.alpha_composite(image, (round(x * self.k), round(y * self.k)))


def status_bar(image, scale, middle, tablet, color=(242, 240, 234), date=None):
    """9:41, four bars, Wi-Fi and a full battery; scale is pixels per point, middle the line's centre in points."""
    w = image.width / scale
    layer = Image.new('RGBA', (image.width * SS, round((middle * 2 + 4) * scale * SS)))
    pen = Pen(layer, scale * SS)
    faint = (*color, 100)
    y = middle
    if tablet:
        pen.text(24, y, '9:41', 15, color, 'Medium', 'lm')
        if date:
            pen.text(24 + pen.width('9:41', 15, 'Medium') + 6, y, date, 15, color, 'Medium', 'lm')
        right = w - 22
    else:
        pen.text(w * 0.165, y, '9:41', 17.5, color, 'Bold', 'mm')
        right = w * 0.935
    # battery
    x1 = right - 2
    x0 = x1 - 25
    pen.rect(x0, y - 6.2, x1, y + 6.2, 4, outline=faint, width=1)
    pen.rect(x0 + 2, y - 4.2, x1 - 2, y + 4.2, 2.4, fill=color)
    pen.rect(x1 + 0.6, y - 2.2, x1 + 2, y + 2.2, 0.7, fill=faint)
    # Wi-Fi: a wedge and two bands, open to the top
    cx, cy = x0 - 6 - 8, y + 5.6
    for r, band in ((11.6, 2.6), (7.5, 2.6)):
        pen.draw.arc(pen.box(cx - r, cy - r, cx + r, cy + r), 222, 318, fill=color, width=round(band * pen.k))
    r = 3.6
    pen.draw.pieslice(pen.box(cx - r, cy - r, cx + r, cy + r), 222, 318, fill=color)
    # signal: four full bars
    bars_right = cx - 8 - 6
    for i, h in enumerate((4.2, 6.6, 9.0, 11.4)):
        bx = bars_right - (3 - i) * 4.6 - 3.1
        pen.rect(bx, y + 5.7 - h, bx + 3.1, y + 5.7, 1, fill=color)
    layer = layer.resize((image.width, layer.height // SS), Image.LANCZOS)
    image.alpha_composite(layer)


def gradient(size, top, bottom):
    mask = Image.linear_gradient('L').resize(size)
    return Image.composite(Image.new('RGBA', size, (*bottom, 255)), Image.new('RGBA', size, (*top, 255)), mask)


def rounded(image, radius):
    mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, image.width - 1, image.height - 1], radius=radius, fill=255)
    out = Image.new('RGBA', image.size)
    out.paste(image, (0, 0), mask)
    return out


def icon(kind, px):
    """An app icon, px wide: Songgate's own, the others simplified drawings."""
    if kind == 'songgate':
        return rounded(Image.open(HERE.parents[1] / 'assets/icon/icon.png').convert('RGBA').resize((px, px), Image.LANCZOS), px * 0.225)
    backgrounds = {'messages': ((104, 240, 128), (18, 192, 54)), 'mail': ((70, 182, 255), (22, 108, 242))}
    image = gradient((px, px), *backgrounds.get(kind, ((255, 255, 255), (246, 246, 248))))
    pen = Pen(image, px)
    white = (255, 255, 255)
    if kind == 'messages':
        pen.draw.ellipse(pen.box(0.16, 0.2, 0.84, 0.74), fill=white)
        pen.polygon([(0.26, 0.6), (0.2, 0.83), (0.44, 0.7)], white)
    elif kind == 'mail':
        pen.rect(0.15, 0.27, 0.85, 0.73, 0.06, fill=white)
        pen.line([(0.17, 0.31), (0.5, 0.56), (0.83, 0.31)], (40, 132, 246), 0.035)
    elif kind == 'notes':
        image.alpha_composite(gradient((px, round(px * 0.27)), (255, 214, 92), (250, 190, 40)))
        for i in range(11):
            pen.circle(0.07 + i * 0.086, 0.33, 0.012, (200, 200, 205))
        for y in (0.48, 0.62, 0.76):
            pen.line([(0.1, y), (0.9, y)], (218, 218, 222), 0.018)
    elif kind == 'reminders':
        for i, colour in enumerate(((10, 132, 255), (255, 69, 58), (255, 159, 10))):
            y = 0.3 + i * 0.2
            pen.circle(0.26, y, 0.075, colour)
            pen.circle(0.26, y, 0.045, white)
            pen.circle(0.26, y, 0.03, colour)
            pen.line([(0.4, y), (0.82, y)], (210, 210, 214), 0.022)
    return rounded(image, px * 0.225)


def avatar(initials, px):
    """A contact without a photo, or a group with its members' monograms."""
    image = Image.new('RGBA', (px, px))
    pen = Pen(image, px)
    if len(initials) == 1:
        image.alpha_composite(rounded(gradient((px, px), (168, 173, 184), (132, 137, 148)), px / 2))
        pen.text(0.5, 0.52, initials, 0.44, (255, 255, 255), 'Medium', 'mm')
        return image
    pen.circle(0.5, 0.5, 0.5, (222, 223, 228))
    for letter, (x, y) in zip(initials, ((0.33, 0.36), (0.67, 0.36), (0.5, 0.67))):
        part = avatar(letter, round(px * 0.4))
        image.alpha_composite(part, (round((x - 0.2) * px), round((y - 0.2) * px)))
    return image


def share_glyph(pen, x, y, size, color, width):
    """The square with an arrow out of its top."""
    s = size / 2
    pen.line([(x - s * 0.45, y - s * 0.25), (x - s * 0.8, y - s * 0.25), (x - s * 0.8, y + s), (x + s * 0.8, y + s), (x + s * 0.8, y - s * 0.25), (x + s * 0.45, y - s * 0.25)], color, width)
    pen.line([(x, y + s * 0.3), (x, y - s * 1.05)], color, width)
    pen.line([(x - s * 0.4, y - s * 0.65), (x, y - s * 1.08), (x + s * 0.4, y - s * 0.65)], color, width)


def sheet(locale, width, height, k):
    """The share sheet's content in points, as an image at k pixels per point."""
    texts = TEXTS[locale]
    image = Image.new('RGBA', (round(width * k), round(height * k)), (*SHEET, 255))
    pen = Pen(image, k)
    # header: the shared song and the close button
    cover = rounded(Image.open(HERE / 'cover-song.png').convert('RGBA').resize((round(58 * k),) * 2, Image.LANCZOS), 10 * k)
    pen.paste(cover, 20, 20)
    pen.text(92, 34, 'Sommerregen', 17, LABEL, 'Medium', 'ls')
    pen.text(92, 58, 'Die Laternen · Song', 15, SECONDARY, 'Regular', 'ls')
    pen.circle(width - 34, 40, 15, (227, 227, 232))
    for sign in (1, -1):
        pen.line([(width - 39, 40 - 5 * sign), (width - 29, 40 + 5 * sign)], (110, 110, 115), 2.2)
    pen.line([(20, 98), (width, 98)], SEPARATOR, 0.6)
    # one column per suggestion or app; the row scrolls, so the fifth is cut by the edge
    columns = [46 + i * 92 for i in range(5)]
    for x, (name, initials, badge) in zip(columns, PEOPLE):
        pen.paste(avatar(initials, round(64 * k)), x - 32, 114)
        pen.circle(x + 22, 168, 12.5, SHEET)
        pen.paste(icon(badge, round(22 * k)), x + 11, 157)
        pen.text(x, 196, name, 12, LABEL, 'Regular', 'ms')
    pen.line([(20, 218), (width, 218)], SEPARATOR, 0.6)
    for x, kind, name in zip(columns, ['songgate', 'messages', 'mail', 'notes', 'reminders'], texts['apps']):
        if kind == 'songgate':
            pen.rect(x - 36.5, 229.5, x + 36.5, 302.5, 19, outline=(*ACCENT, 255), width=3)
        pen.paste(icon(kind, round(64 * k)), x - 32, 234)
        pen.text(x, 318, name, 12, LABEL, 'Regular', 'ms')
    # actions
    pen.rect(16, 340, width - 16, 444, 20, fill=(255, 255, 255))
    pen.text(34, 366, texts['copy'], 17, LABEL, 'Regular', 'lm')
    pen.rect(width - 50, 358, width - 38, 370, 2.5, outline=(*LABEL, 255), width=1.4)
    pen.rect(width - 45, 363, width - 33, 375, 2.5, fill=(255, 255, 255), outline=(*LABEL, 255), width=1.4)
    pen.line([(34, 392), (width - 16, 392)], SEPARATOR, 0.6)
    pen.text(34, 418, texts['edit'], 17, LABEL, 'Regular', 'lm')
    return image


def player(size, k, cover_box, tablet):
    """A dark now-playing screen behind the sheet, coloured by the cover."""
    w, h = size
    image = gradient((round(w * k), round(h * k)), (64, 32, 54), (22, 17, 28))
    glow = Image.new('RGBA', image.size)
    x0, y0, x1, y1 = cover_box
    ImageDraw.Draw(glow).ellipse([(x0 - 40) * k, (y0 - 60) * k, (x1 + 40) * k, (y1 + 20) * k], fill=(178, 92, 70, 110))
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(90 * k)))
    pen = Pen(image, k)
    shadow = Image.new('RGBA', image.size)
    ImageDraw.Draw(shadow).rounded_rectangle([x0 * k, (y0 + 16) * k, x1 * k, (y1 + 16) * k], radius=14 * k, fill=(0, 0, 0, 120))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(24 * k)))
    side = round((x1 - x0) * k)
    pen.paste(rounded(Image.open(HERE / 'cover-song.png').convert('RGBA').resize((side, side), Image.LANCZOS), 14 * k), x0, y0)
    white = (255, 255, 255)
    if tablet:
        pen.text(x0, y1 + 50, 'Sommerregen', 28, white, 'Bold', 'ls')
        pen.text(x0, y1 + 82, 'Die Laternen', 22, (*white, 150), 'Regular', 'ls')
        pen.rect(x0, y1 + 112, x1, y1 + 118, 3, fill=(*white, 60))
        pen.rect(x0, y1 + 112, x0 + (x1 - x0) * 0.4, y1 + 118, 3, fill=(*white, 200))
        pen.text(x0, y1 + 138, '1:24', 13, (*white, 150), 'Medium', 'ls')
        pen.text(x1, y1 + 138, '-2:07', 13, (*white, 150), 'Medium', 'rs')
        mid, cy = (x0 + x1) / 2, y1 + 210
        pen.rect(mid - 13, cy - 18, mid - 4, cy + 18, 2, fill=white)
        pen.rect(mid + 4, cy - 18, mid + 13, cy + 18, 2, fill=white)
        for sign in (-1, 1):
            cx = mid + sign * 120
            for dx in (0, 22):
                tip = cx + sign * (dx + 2)
                pen.polygon([(tip - sign * 26, cy - 15), (tip, cy), (tip - sign * 26, cy + 15)], white)
    return image


DEVICES = {
    # logical size, pixels per point in the composed picture
    'iphone': dict(size=(440, 956), cover=(34, 100, 406, 472), sheet=(8, 392), tablet=False),
    'ipad': dict(size=(1032, 1376), cover=(110, 330, 570, 790), sheet=(608, 104), tablet=True),
}


def share_screen(locale, device, width_px):
    spec = DEVICES[device]
    w, h = spec['size']
    k = width_px / w * SS
    image = player(spec['size'], k, spec['cover'], spec['tablet'])
    pen = Pen(image, k)
    left, top = spec['sheet']
    if spec['tablet']:
        # popover under the share button, arrow pointing at it
        button = (996, 56)
        pen.circle(*button, 22, (255, 255, 255, 40))
        share_glyph(pen, button[0], button[1] + 1, 18, (255, 255, 255), 2)
        sheet_w, sheet_h = 400, 456
    else:
        pen.rect(w / 2 - 20, 58, w / 2 + 20, 63, 2.5, fill=(255, 255, 255, 90))
        pen.circle(w - 46, 72, 18, (255, 255, 255, 40))
        share_glyph(pen, w - 46, 73, 16, (255, 255, 255), 2)
        sheet_w, sheet_h = w - 2 * left, h - top - left
    content = rounded(sheet(locale, sheet_w, sheet_h, k), (26 if spec['tablet'] else 38) * k)
    shadow = Image.new('RGBA', image.size)
    ImageDraw.Draw(shadow).rounded_rectangle([left * k, (top + 10) * k, (left + sheet_w) * k, (top + sheet_h) * k], radius=36 * k, fill=(0, 0, 0, 140))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(30 * k)))
    if spec['tablet']:
        tip = button[0] - left
        pen.polygon([(left + tip - 14, top + 1), (left + tip, top - 14), (left + tip + 14, top + 1)], SHEET)
    pen.paste(content, left, top)
    image = image.resize((width_px, round(h * width_px / w)), Image.LANCZOS)
    status_bar(image, width_px / w, 12 if spec['tablet'] else 31, spec['tablet'], date=TEXTS[locale]['date'] if spec['tablet'] else None)
    return image
