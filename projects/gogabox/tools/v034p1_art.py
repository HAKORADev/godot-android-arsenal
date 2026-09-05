#!/usr/bin/env python3
# COSMIC SPUD v0.3.4-1 - THE ART REBIRTH.
# The owner's verdict on the v0.3.4 blobs: "totally shit". This script
# regenerates EVERY sprite with a real shading engine:
#   silhouette -> gradient base -> top-left light band -> bottom-right
#   shadow band -> dark outline -> rim light -> hand-drawn details.
# Everything is supersampled 4x and downscaled with Lanczos.
# Run: python3 tools/v034p1_art.py   (from projects/gogabox)
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "games", "cosmic_spud")
ZIP = "/home/z/my-project/asset_trials/twin_stick/sprites"
SS = 4  # supersample

# ------------------------------------------------------------------ engine
def C(x):
    return tuple(max(0, min(255, int(v))) for v in x)

def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

def finish(img, w, h):
    return img.resize((w, h), Image.LANCZOS)

def save(img, path, w, h):
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    finish(img, w, h).save(full)
    print("art:", path)

def arr(img):
    return np.asarray(img).astype(np.float32)

def img_from(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")

def mask_of(img):
    """the alpha mask as float 0..1, h-first numpy array"""
    a = arr(img)[:, :, 3]
    return a / 255.0

def tint_mask(mask, color, alpha=1.0):
    """mask (h,w) 0..1 -> RGBA layer painted `color` (RGB masked too)"""
    h, w = mask.shape
    layer = np.zeros((h, w, 4), np.float32)
    layer[:, :, 0] = color[0] * mask
    layer[:, :, 1] = color[1] * mask
    layer[:, :, 2] = color[2] * mask
    layer[:, :, 3] = mask * 255.0 * alpha
    return layer

def shift_mask(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys0, ys1 = max(0, dy), h + min(0, dy)
    xs0, xs1 = max(0, dx), w + min(0, dx)
    out[ys0:ys1, xs0:xs1] = mask[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out

def shade(mask, base, light=None, dark=None, seed=0, grad=0.45,
          light_a=0.55, dark_a=0.5, band=None):
    """THE SHADING ENGINE: flat mask -> shaded body.
    base: (r,g,b); the light comes from the TOP-LEFT."""
    h, w = mask.shape
    light = light or C((min(255, base[0] + 52), min(255, base[1] + 48), min(255, base[2] + 40)))
    dark = dark or C((base[0] * 0.52, base[1] * 0.5, base[2] * 0.5))
    # the diagonal gradient: bright top-left -> dark bottom-right
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    diag = (xx / max(1, w)) * 0.65 + (yy / max(1, h)) * 0.35
    diag = (diag - diag.min()) / max(0.001, diag.max() - diag.min())
    g = 1.0 + grad * (0.5 - diag) * 2.0
    body = np.zeros((h, w, 4), np.float32)
    for i in range(3):
        body[:, :, i] = np.clip(base[i] * g, 0, 255)
    body[:, :, 3] = mask * 255
    d = band or max(3, (w // 22))
    # the TOP-LEFT light band (the lit rim)
    hl = np.clip(mask - shift_mask(mask, d, d), 0, 1)
    body += tint_mask(hl, light, light_a)
    # the BOTTOM-RIGHT shadow band
    sh = np.clip(mask - shift_mask(mask, -d, -d), 0, 1)
    body += tint_mask(sh, dark, dark_a)
    return body

def outline_layer(mask, color=(24, 16, 20, 255), width=None):
    """the dark outline around a silhouette"""
    h, w = mask.shape
    k = width or max(2, w // 40)
    big = Image.fromarray((mask * 255).astype(np.uint8), "L")
    big = big.filter(ImageFilter.MaxFilter(k * 2 + 1))
    dil = np.asarray(big).astype(np.float32) / 255.0
    ring = np.clip(dil - mask, 0, 1)
    return tint_mask(ring, color[:3], 1.0)

def rim_light(mask, color=(255, 240, 200), a=0.35, k=None):
    h, w = mask.shape
    k = k or max(2, w // 34)
    small = Image.fromarray((mask * 255).astype(np.uint8), "L")
    small = small.filter(ImageFilter.MinFilter(k * 2 + 1))
    er = np.asarray(small).astype(np.float32) / 255.0
    inner_edge = np.clip(mask - er, 0, 1)
    # only the top-left half of the edge
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    diag = (xx / max(1, w)) * 0.6 + (yy / max(1, h)) * 0.4
    side = np.clip(0.55 - diag, 0, 1) * 2.0
    return tint_mask(inner_edge * side, color, a)

def flatten(layers, size):
    """compose RGBA float layers onto one image"""
    h, w = size
    out = np.zeros((h, w, 4), np.float32)
    for L in layers:
        a = L[:, :, 3:4] / 255.0
        out[:, :, :3] = out[:, :, :3] * (1 - a) + L[:, :, :3] * a
        out[:, :, 3:4] = np.clip(out[:, :, 3:4] + L[:, :, 3:4] * (1 - out[:, :, 3:4] / 255.0), 0, 255)
    return img_from(out)

def speckle(mask, rng, n, color, a=0.5, rmin=1, rmax=3):
    """random dots INSIDE the silhouette"""
    h, w = mask.shape
    layer = np.zeros((h, w, 4), np.float32)
    mimg = Image.fromarray((mask * 255).astype(np.uint8), "L")
    pts = []
    tries = 0
    while len(pts) < n and tries < n * 40:
        tries += 1
        x, y = rng.randint(0, w - 1), rng.randint(0, h - 1)
        if mask[y, x] > 0.5:
            pts.append((x, y))
    dr = ImageDraw.Draw(Image.new("L", (w, h), 0))
    for (x, y) in pts:
        r = rng.randint(rmin, rmax)
        dr.ellipse([x - r, y - r, x + r, y + r], fill=255)
    sp = np.asarray(dr.image if hasattr(dr, "image") else dr._image).astype(np.float32) / 255.0
    return tint_mask(sp, color, a)

def speckle_draw(base_img, mask, rng, n, color, a=0.5, rmin=1, rmax=3):
    """same but returns an RGBA layer built with PIL draw (reliable)"""
    h, w = mask.shape
    dr_img = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(dr_img)
    tries = 0
    done = 0
    while done < n and tries < n * 60:
        tries += 1
        x, y = rng.randint(0, w - 1), rng.randint(0, h - 1)
        if mask[y, x] > 0.5:
            r = rng.randint(rmin, rmax) * 1
            dr.ellipse([x - r, y - r, x + r, y + r], fill=int(255 * a))
            done += 1
    sp = np.asarray(dr_img).astype(np.float32) / 255.0
    return tint_mask(sp, color, a)

def eyes_pair(layer_img, cx, cy, r, look=(0.2, 0.0), sclera=(255, 255, 255),
              pupil=(30, 24, 30), angry=0.0, d=None):
    """a pair of cartoon eyes at (cx,cy) spaced 2.2r apart; `angry` slants brows"""
    dd = ImageDraw.Draw(layer_img)
    sp = r * 2.2
    for sx in (-1, 1):
        ex, ey = cx + sx * sp / 2.0, cy
        dd.ellipse([ex - r, ey - r, ex + r, ey + r], fill=C(sclera) + (255,))
        px, py = ex + look[0] * r * 0.55, ey + look[1] * r * 0.55
        pr = r * 0.52
        dd.ellipse([px - pr, py - pr, px + pr, py + pr], fill=C(pupil) + (255,))
        gr = pr * 0.34
        dd.ellipse([px - pr * 0.4, py - pr * 0.7, px - pr * 0.4 + gr * 2, py - pr * 0.7 + gr * 2],
                   fill=(255, 255, 255, 230))
        if angry > 0:
            bw = r * 2.1
            by = ey - r * 1.25
            inner_y = by + r * angry * 1.1
            if sx < 0:
                dd.polygon([(ex - bw / 2, by - r * 0.5 * angry), (ex + bw / 2, inner_y),
                            (ex + bw / 2, inner_y + r * 0.32), (ex - bw / 2, by - r * 0.5 * angry + r * 0.32)],
                           fill=C(pupil) + (255,))
            else:
                dd.polygon([(ex - bw / 2, inner_y), (ex + bw / 2, by - r * 0.5 * angry),
                            (ex + bw / 2, by - r * 0.5 * angry + r * 0.32), (ex - bw / 2, inner_y + r * 0.32)],
                           fill=C(pupil) + (255,))

def outline_of_mask_image(mask_img, color=(24, 16, 20), width=None):
    """outline for a PIL-drawn detail layer given its L mask"""
    m = mask_of(mask_img.convert("RGBA"))
    return outline_layer(m, color + (255,), width)

import os, math, random, zlib

def seed_of(*parts) -> int:
    return zlib.crc32("|".join(str(p) for p in parts).encode())

TAU = math.tau

# ================================================================ THE POTATO
POTATO_BASE = (176, 128, 70)
POTATO_DARK = (94, 64, 32)

def potato_mask(W, H, rng, cx=None, cy=None, rx=None, ry=None):
    """a lumpy potato silhouette (the owner: 'design a real potato')"""
    m = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(m)
    cx = W * 0.5 if cx is None else cx
    cy = H * 0.46 if cy is None else cy
    rx = W * 0.30 if rx is None else rx
    ry = H * 0.34 if ry is None else ry
    n = 26
    offs = [rng.uniform(-0.10, 0.10) for _ in range(n)]
    offs[0] = offs[n // 2] = offs[3 * n // 4]  # smooth the seam
    pts = []
    for i in range(n):
        a = i / n * TAU
        lump = 1.0 + offs[i]
        # potatoes bulge a touch at the bottom
        bulge = 1.0 + 0.06 * math.sin(a * 0.5 + 0.6)
        x = (cx + math.cos(a) * rx * lump) * SS
        y = (cy + math.sin(a) * ry * lump * bulge) * SS
        pts.append((x, y))
    d.polygon(pts, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(2 * SS))
    return np.asarray(m).astype(np.float32) / 255.0

def boot(layer_img, x, y, w, h, col=(94, 58, 38), flip=False):
    """a little boot with a sole"""
    dd = ImageDraw.Draw(layer_img)
    x0 = x - w / 2
    top = y - h / 2
    dd.rounded_rectangle([x0, top, x0 + w, y + h * 0.18], radius=w * 0.28, fill=C(col) + (255,))
    sole_col = C((col[0] * 0.55, col[1] * 0.5, col[2] * 0.5))
    dd.rounded_rectangle([x0 - (w * 0.12 if flip else 0), y + h * 0.02,
                          x0 + w + (w * 0.12 if flip else 0), y + h * 0.3],
                         radius=w * 0.2, fill=sole_col + (255,))

def hero_sprite(variant, frame):
    """96x96. frame 0..3 of the walk cycle. faces RIGHT (flip_h in engine)."""
    W = H = 96 * SS
    rng = random.Random(seed_of("potato", variant))
    bob = [0, -2, 0, -2][frame] * SS
    leg_ph = [[7, -7], [3, -3], [-7, 7], [-3, 3]][frame]  # fwd/back offsets
    cx, cy = W * 0.5, H * 0.44 + bob
    layers = []
    # ---- the legs UNDER the body
    leg_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    boot(leg_img, W * 0.5 - 13 * SS, H * 0.80 + bob - leg_ph[0] * SS * 0.4, 13 * SS, 12 * SS)
    boot(leg_img, W * 0.5 + 13 * SS, H * 0.80 + bob - leg_ph[1] * SS * 0.4, 13 * SS, 12 * SS, flip=True)
    layers.append(arr(leg_img))
    # ---- the body
    mask = potato_mask(96, 96, rng)          # already at the working res
    mask = mask[:W, :H]
    body = shade(mask, POTATO_BASE, light=(214, 172, 112), dark=POTATO_DARK,
                 grad=0.38, band=4 * SS, light_a=0.38, dark_a=0.42)
    layers.append(body)
    # potato dimples (the eyes of the potato itself)
    dim_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dim_img)
    rng2 = random.Random(seed_of("dimp", variant))
    for _ in range(9):
        a = rng2.uniform(0, TAU)
        rr = rng2.uniform(0.45, 0.95)
        px = cx + math.cos(a) * W * 0.24 * rr
        py = cy + math.sin(a) * H * 0.27 * rr
        r = rng2.uniform(1.6, 3.4) * SS
        dd.ellipse([px - r, py - r, px + r, py + r], fill=(120, 84, 44, 110))
    layers.append(arr(dim_img))   # composite (NOT += - the alpha must weight it)
    # rim light (subtle - the pale wash was killing the tan)
    layers.append(rim_light(mask, (255, 236, 190), 0.15))
    # ---- the face + variant gear
    face = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    eyes_pair(face, cx, cy - 2 * SS, 6.4 * SS, look=(0.25, -0.05),
              angry=0.55 if variant in ("soldier", "brawler", "pyro") else 0.15)
    dd = ImageDraw.Draw(face)
    # the determined little mouth
    my = cy + 12 * SS
    dd.arc([cx - 5 * SS, my - 3 * SS, cx + 7 * SS, my + 5 * SS], 20, 160, fill=(70, 40, 30, 255), width=3 * SS)
    # the cheeks (a tiny blush)
    dd.ellipse([cx - 17 * SS, cy + 7 * SS, cx - 11 * SS, cy + 12 * SS], fill=(226, 130, 100, 90))
    dd.ellipse([cx + 11 * SS, cy + 7 * SS, cx + 17 * SS, cy + 12 * SS], fill=(226, 130, 100, 90))
    if variant == "soldier":
        # the green bandana across the forehead + knot tails
        dd.polygon([(cx - 22 * SS, cy - 14 * SS), (cx + 22 * SS, cy - 15 * SS),
                    (cx + 20 * SS, cy - 24 * SS), (cx - 20 * SS, cy - 23 * SS)],
                   fill=(64, 122, 58, 255))
        dd.polygon([(cx - 20 * SS, cy - 18 * SS), (cx - 34 * SS, cy - 10 * SS),
                    (cx - 30 * SS, cy - 4 * SS), (cx - 18 * SS, cy - 12 * SS)],
                   fill=(52, 104, 48, 255))
        dd.polygon([(cx + 18 * SS, cy - 18 * SS), (cx + 33 * SS, cy - 14 * SS),
                    (cx + 31 * SS, cy - 7 * SS), (cx + 16 * SS, cy - 12 * SS)],
                   fill=(52, 104, 48, 255))
    elif variant == "ranger":
        # the hood shadow + a leaf pin
        dd.polygon([(cx - 24 * SS, cy - 10 * SS), (cx - 10 * SS, cy - 34 * SS),
                    (cx + 12 * SS, cy - 36 * SS), (cx + 24 * SS, cy - 10 * SS)],
                   fill=(46, 84, 52, 235))
        dd.ellipse([cx + 14 * SS, cy - 30 * SS, cx + 22 * SS, cy - 20 * SS], fill=(210, 190, 90, 255))
    elif variant == "brawler":
        # the red headband + gloves
        dd.rounded_rectangle([cx - 22 * SS, cy - 22 * SS, cx + 22 * SS, cy - 14 * SS],
                             radius=4 * SS, fill=(188, 52, 44, 255))
        dd.rounded_rectangle([cx - 27 * SS, cy + 4 * SS, cx - 13 * SS, cy + 18 * SS],
                             radius=5 * SS, fill=(208, 62, 50, 255))
        dd.rounded_rectangle([cx + 13 * SS, cy + 4 * SS, cx + 27 * SS, cy + 18 * SS],
                             radius=5 * SS, fill=(208, 62, 50, 255))
    elif variant == "engineer":
        # the goggles on a strap
        dd.rounded_rectangle([cx - 23 * SS, cy - 20 * SS, cx + 23 * SS, cy - 12 * SS],
                             radius=3 * SS, fill=(70, 56, 44, 255))
        for sx in (-1, 1):
            gx = cx + sx * 11 * SS
            dd.ellipse([gx - 9 * SS, cy - 24 * SS, gx + 9 * SS, cy - 8 * SS],
                       fill=(250, 176, 60, 255), outline=(60, 48, 40, 255), width=3 * SS)
            dd.ellipse([gx - 5 * SS, cy - 21 * SS, gx - 1 * SS, cy - 17 * SS], fill=(255, 240, 200, 200))
    elif variant == "pyro":
        # the scarf + an ember paint
        dd.rounded_rectangle([cx - 18 * SS, cy + 16 * SS, cx + 18 * SS, cy + 23 * SS],
                             radius=4 * SS, fill=(226, 96, 40, 255))
        dd.polygon([(cx + 8 * SS, cy + 20 * SS), (cx + 24 * SS, cy + 28 * SS),
                    (cx + 20 * SS, cy + 34 * SS), (cx + 6 * SS, cy + 26 * SS)],
                   fill=(198, 80, 34, 255))
        dd.polygon([(cx - 6 * SS, cy - 2 * SS), (cx + 2 * SS, cy - 12 * SS),
                    (cx + 8 * SS, cy - 2 * SS), (cx + 1 * SS, cy + 6 * SS)],
                   fill=(240, 140, 50, 160))
    elif variant == "frostbite":
        # frost crystals on the skin + a cold rim
        for (fx, fy, fs) in [(-14, -18, 5), (10, -24, 4), (-4, 22, 4), (16, 10, 5)]:
            fx, fy, fs = cx + fx * SS, cy + fy * SS, fs * SS
            dd.polygon([(fx, fy - fs), (fx + fs * 0.5, fy), (fx, fy + fs), (fx - fs * 0.5, fy)],
                       fill=(190, 226, 255, 200))
        layers.append(rim_light(mask, (170, 220, 255), 0.5))
    layers.append(arr(face))
    # ---- the cosmonaut dome (the glass helmet) with a metal collar
    dome = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dome)
    dr_ = 27 * SS
    dcx, dcy = cx, cy - 5 * SS
    dd.ellipse([dcx - dr_, dcy - dr_ * 0.92, dcx + dr_, dcy + dr_ * 0.92],
               fill=(190, 225, 255, 34))
    dd.ellipse([dcx - dr_, dcy - dr_ * 0.92, dcx + dr_, dcy + dr_ * 0.92],
               outline=(205, 232, 255, 130), width=2 * SS)
    dd.arc([dcx - dr_ * 0.7, dcy - dr_ * 0.75, dcx + dr_ * 0.25, dcy + dr_ * 0.15],
           200, 300, fill=(255, 255, 255, 110), width=3 * SS)
    # the collar (dark steel, LOW - it was eating the mouth)
    dd.rounded_rectangle([dcx - 16 * SS, dcy + 24 * SS, dcx + 16 * SS, dcy + 30 * SS],
                         radius=4 * SS, fill=(118, 124, 138, 255), outline=(50, 52, 60, 255), width=2 * SS)
    layers.append(arr(dome))
    # ---- the outline over everything opaque so far
    all_a = np.zeros((H, W), np.float32)
    for L in layers:
        all_a = np.maximum(all_a, L[:, :, 3] / 255.0)
    layers.append(outline_layer(all_a, (30, 20, 24, 255), 2 * SS))
    return flatten(layers, (H, W))

def build_heroes():
    for variant in ["soldier", "ranger", "brawler", "engineer", "pyro", "frostbite"]:
        for frame in range(4):
            img = hero_sprite(variant, frame)
            save(img, f"hero/hero_{variant}_f{frame}.png", 96, 96)
        # the shop card portrait (frame 0 at 2x quality is the same file)
    print("heroes done")

# ================================================================ ENEMIES
def blob_mask(W, H, cx, cy, rx, ry, seed, lumps=10, lump_a=0.09,
              hem=None, hem_n=6, hem_d=None, flat=0.0):
    """a shaped silhouette. hem: 'drip' (slime skirt), 'zig' (ghost hem),
    flat: squashes the bottom (0..1) for sitting bodies."""
    rng = random.Random(seed_of(seed))
    m = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(m)
    n = 30
    offs = [rng.uniform(-lump_a, lump_a) for _ in range(n)]
    pts = []
    for i in range(n):
        a = i / n * TAU
        lump = 1.0 + offs[i % n]
        x = (cx + math.cos(a) * rx * lump) * W * SS
        y = (cy + math.sin(a) * ry * lump) * H * SS
        if flat > 0 and y > (cy + ry * (1 - flat)) * H * SS:
            y = (cy + ry * (1 - flat)) * H * SS
        pts.append((x, y))
    d.polygon(pts, fill=255)
    if hem == "drip":
        # slime drips hang from the bottom
        hw = rx * W * SS * 0.92
        for i in range(hem_n):
            t = (i + 0.5) / hem_n
            dx = cx * W * SS - hw + 2 * hw * t
            dl = (0.12 + 0.16 * rng.random()) * ry * H * SS
            wdt = (0.16 + 0.1 * rng.random()) * rx * W * SS
            d.ellipse([dx - wdt, cy * H * SS + ry * H * SS * 0.55 - wdt,
                       dx + wdt, cy * H * SS + ry * H * SS * 0.55 + dl], fill=255)
    elif hem == "zig":
        # the ghost's tattered hem: cut triangles OUT of the bottom
        base_y = (cy + ry * 1.0) * H * SS
        hw = rx * W * SS * 1.02
        for i in range(hem_n):
            t0 = i / hem_n
            t1 = (i + 0.5) / hem_n
            t2 = (i + 1.0) / hem_n
            x0 = cx * W * SS - hw + 2 * hw * t0
            x1 = cx * W * SS - hw + 2 * hw * t1
            x2 = cx * W * SS - hw + 2 * hw * t2
            depth = (0.10 + 0.12 * rng.random()) * ry * H * SS
            d.polygon([(x0 - 1, base_y + 2), (x2 + 1, base_y + 2), (x1, base_y - depth)], fill=0)
    m = m.filter(ImageFilter.GaussianBlur(2))
    return np.asarray(m).astype(np.float32) / 255.0

def E(name, w, h, fn):
    """build + save an enemy sprite"""
    img = fn(w * SS, h * SS)
    save(img, f"enemies/{name}.png", w, h)

def std_body(mask, base, seedname, light=None, dark=None, **kw):
    body = shade(mask, base, light=light, dark=dark, band=5 * SS, **kw)
    rim = rim_light(mask, (255, 244, 220), 0.35)
    return body, rim

def finish_creature(W, H, layers, mask):
    all_a = np.zeros((H, W), np.float32)
    for L in layers:
        all_a = np.maximum(all_a, L[:, :, 3] / 255.0)
    layers.append(outline_layer(all_a, (26, 18, 26, 255), 2 * SS))
    return flatten(layers, (H, W))

# --------------------------------------------------------------- each kind
def e_blab(W, H):
    mask = blob_mask(W // SS, H // SS, 0.5, 0.52, 0.34, 0.32, "blab", hem="drip", hem_n=5)
    body, rim = std_body(mask, (196, 60, 54), "blab", light=(255, 120, 100))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the gloss (a wet shine on the dome)
    dd.ellipse([W * 0.30, H * 0.16, W * 0.52, H * 0.34], fill=(255, 255, 255, 90))
    dd.ellipse([W * 0.55, H * 0.22, W * 0.62, H * 0.30], fill=(255, 255, 255, 70))
    eyes_pair(d, W * 0.5, H * 0.48, 7 * SS, angry=0.8, sclera=(255, 236, 214))
    dd.arc([W * 0.38, H * 0.62, W * 0.62, H * 0.78], 30, 150, fill=(90, 20, 24, 255), width=3 * SS)
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_sprinter(W, H):
    # a lean forward wedge on runner legs
    mask = blob_mask(W // SS, H // SS, 0.55, 0.5, 0.36, 0.26, "sprint", lumps=12, lump_a=0.07)
    body, rim = std_body(mask, (232, 140, 52), "sprint", light=(255, 190, 110))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the snout
    dd.polygon([(W * 0.84, H * 0.48), (W * 0.96, H * 0.54), (W * 0.84, H * 0.60)],
               fill=(210, 118, 40, 255))
    # the runner legs (a stride)
    dd.line([(W * 0.42, H * 0.72), (W * 0.30, H * 0.94)], fill=(150, 82, 26, 255), width=4 * SS)
    dd.line([(W * 0.60, H * 0.72), (W * 0.74, H * 0.92)], fill=(150, 82, 26, 255), width=4 * SS)
    dd.ellipse([W * 0.24, H * 0.90, W * 0.34, H * 0.99], fill=(150, 82, 26, 255))
    dd.ellipse([W * 0.70, H * 0.88, W * 0.80, H * 0.97], fill=(150, 82, 26, 255))
    # the speed crest
    dd.polygon([(W * 0.30, H * 0.30), (W * 0.44, H * 0.14), (W * 0.50, H * 0.32)],
               fill=(255, 210, 130, 255))
    eyes_pair(d, W * 0.62, H * 0.44, 5 * SS, angry=0.9)
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_chunk(W, H):
    # a heavy stone brute: a rounded SQUARE
    rng = random.Random(seed_of("chunk-mask"))
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    dd.rounded_rectangle([W * 0.14, H * 0.14, W * 0.86, H * 0.86], radius=int(W * 0.18), fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    body, rim = std_body(mask, (142, 92, 168), "chunk", light=(188, 140, 210))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the stone cracks
    for (x0, y0, x1, y1) in [(0.2, 0.2, 0.32, 0.4), (0.75, 0.62, 0.62, 0.8), (0.5, 0.86, 0.56, 0.7)]:
        dd.line([(W * x0, H * y0), (W * x1, H * y1)], fill=(84, 50, 104, 200), width=2 * SS)
    # the heavy brow + small angry eyes
    dd.rounded_rectangle([W * 0.24, H * 0.34, W * 0.76, H * 0.42], radius=3 * SS,
                         fill=(96, 58, 118, 255))
    eyes_pair(d, W * 0.5, H * 0.52, 5.4 * SS, angry=1.0, sclera=(255, 220, 160))
    dd.line([(W * 0.40, H * 0.72), (W * 0.60, H * 0.72)], fill=(70, 40, 90, 255), width=3 * SS)
    # the knuckle arms
    dd.ellipse([W * 0.04, H * 0.5, W * 0.2, H * 0.74], fill=(120, 74, 142, 255))
    dd.ellipse([W * 0.8, H * 0.5, W * 0.96, H * 0.74], fill=(120, 74, 142, 255))
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_spitter(W, H):
    mask = blob_mask(W // SS, H // SS, 0.5, 0.54, 0.33, 0.31, "spit")
    body, rim = std_body(mask, (96, 168, 72), "spit", light=(150, 214, 110))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the leaves
    dd.polygon([(W * 0.5, H * 0.2), (W * 0.28, H * 0.04), (W * 0.44, H * 0.2)],
               fill=(70, 140, 56, 255))
    dd.polygon([(W * 0.5, H * 0.2), (W * 0.72, H * 0.06), (W * 0.58, H * 0.2)],
               fill=(56, 120, 48, 255))
    # the JAW: a wide open dark mouth with teeth
    dd.polygon([(W * 0.28, H * 0.56), (W * 0.72, H * 0.56), (W * 0.62, H * 0.84), (W * 0.38, H * 0.84)],
               fill=(40, 20, 24, 255))
    for i in range(4):
        tx = W * (0.32 + 0.11 * i)
        dd.polygon([(tx, H * 0.57), (tx + W * 0.05, H * 0.57), (tx + W * 0.025, H * 0.66)],
                   fill=(240, 238, 220, 255))
    eyes_pair(d, W * 0.5, H * 0.42, 5 * SS, angry=0.7)
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_wraith(W, H):
    mask = blob_mask(W // SS, H // SS, 0.5, 0.44, 0.32, 0.36, "wraith", hem="zig", hem_n=5)
    body, rim = std_body(mask, (108, 78, 160), "wraith", light=(160, 130, 220), grad=0.6)
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the wispy arms
    dd.arc([W * 0.06, H * 0.36, W * 0.36, H * 0.66], 90, 250, fill=(140, 106, 200, 255), width=5 * SS)
    dd.arc([W * 0.64, H * 0.36, W * 0.94, H * 0.66], 290, 90, fill=(140, 106, 200, 255), width=5 * SS)
    # the HOLLOW eyes (void with a glow ring)
    for sx in (-1, 1):
        ex = W * 0.5 + sx * 11 * SS
        dd.ellipse([ex - 7 * SS, H * 0.40 - 8 * SS, ex + 7 * SS, H * 0.40 + 8 * SS],
                   fill=(24, 12, 36, 255))
        dd.ellipse([ex - 7 * SS, H * 0.40 - 8 * SS, ex + 7 * SS, H * 0.40 + 8 * SS],
                   outline=(210, 170, 255, 220), width=2 * SS)
    dd.ellipse([W * 0.42, H * 0.62, W * 0.58, H * 0.70], fill=(24, 12, 36, 220))
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_brood(W, H):
    mask = blob_mask(W // SS, H // SS, 0.5, 0.52, 0.35, 0.32, "brood")
    body, rim = std_body(mask, (168, 84, 120), "brood", light=(214, 130, 168))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the egg sac cluster on the back
    for (ex, ey, er) in [(0.68, 0.30, 0.10), (0.78, 0.44, 0.08), (0.62, 0.22, 0.07)]:
        dd.ellipse([W * (ex - er), H * (ey - er), W * (ex + er), H * (ey + er)],
                   fill=(240, 200, 214, 210), outline=(150, 70, 100, 255), width=2 * SS)
    # the crown of small eyes (the broodmother glare)
    for sx in (-1, 0, 1):
        ex = W * 0.5 + sx * 12 * SS
        er = (4 if sx == 0 else 3) * SS
        dd.ellipse([ex - er, H * 0.42 - er, ex + er, H * 0.42 + er], fill=(255, 232, 200, 255))
        dd.ellipse([ex - er * 0.4, H * 0.42 - er * 0.4, ex + er * 0.5, H * 0.42 + er * 0.5],
                   fill=(40, 16, 30, 255))
    dd.arc([W * 0.40, H * 0.56, W * 0.60, H * 0.68], 20, 160, fill=(90, 30, 56, 255), width=3 * SS)
    # the legs
    for sx in (-1, 1):
        dd.line([(W * (0.5 + sx * 0.2), H * 0.78), (W * (0.5 + sx * 0.32), H * 0.96)],
                fill=(110, 50, 78, 255), width=3 * SS)
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_trishield(W, H):
    # the armored hexagonal core (its 3 rings are drawn by the game)
    rng = random.Random(seed_of("tri-mask"))
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    n = 6
    R = W * 0.40
    pts = [(W * 0.5 + math.cos(i / n * TAU + 0.52) * R,
            H * 0.5 + math.sin(i / n * TAU + 0.52) * R) for i in range(n)]
    dd.polygon(pts, fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    body, rim = std_body(mask, (110, 128, 150), "tri", light=(170, 190, 214))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the plating seams
    for i in range(n):
        a = i / n * TAU + 0.52
        dd.line([(W * 0.5, H * 0.5),
                 (W * 0.5 + math.cos(a) * R * 0.92, H * 0.5 + math.sin(a) * R * 0.92)],
                fill=(70, 84, 102, 255), width=3 * SS)
    # the glowing slit eye
    dd.rounded_rectangle([W * 0.30, H * 0.44, W * 0.70, H * 0.56], radius=6 * SS,
                         fill=(255, 120, 80, 255))
    dd.rounded_rectangle([W * 0.34, H * 0.47, W * 0.52, H * 0.53], radius=4 * SS,
                         fill=(255, 210, 160, 255))
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_mender(W, H):
    mask = blob_mask(W // SS, H // SS, 0.5, 0.52, 0.33, 0.31, "mend")
    body, rim = std_body(mask, (150, 196, 130), "mend", light=(200, 236, 172))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the medic crest (a white cross disc on an antenna)
    dd.line([(W * 0.5, H * 0.24), (W * 0.5, H * 0.08)], fill=(90, 110, 90, 255), width=3 * SS)
    dd.ellipse([W * 0.38, H * 0.0, W * 0.62, H * 0.18], fill=(246, 248, 240, 255),
               outline=(120, 130, 120, 255), width=2 * SS)
    dd.rectangle([W * 0.475, H * 0.035, W * 0.525, H * 0.145], fill=(210, 60, 60, 255))
    dd.rectangle([W * 0.455, H * 0.055, W * 0.545, H * 0.125], fill=(210, 60, 60, 255))
    dd.rectangle([W * 0.475, H * 0.055, W * 0.525, H * 0.125], fill=(246, 248, 240, 255))
    eyes_pair(d, W * 0.5, H * 0.46, 6 * SS, angry=0.0, look=(0.0, 0.2))
    # the gentle smile + the chest cross
    dd.arc([W * 0.42, H * 0.6, W * 0.58, H * 0.7], 20, 160, fill=(60, 90, 56, 255), width=3 * SS)
    px, py, ps = W * 0.5, H * 0.8, W * 0.05
    dd.rectangle([px - ps * 0.3, py - ps, px + ps * 0.3, py + ps], fill=(246, 248, 240, 255))
    dd.rectangle([px - ps, py - ps * 0.3, px + ps, py + ps * 0.3], fill=(246, 248, 240, 255))
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_charger(W, H):
    # the rhino wedge: a triangle-ish body pointing RIGHT
    rng = random.Random(seed_of("chg-mask"))
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    dd.polygon([(W * 0.1, H * 0.3), (W * 0.78, H * 0.2), (W * 0.95, H * 0.5),
                (W * 0.78, H * 0.8), (W * 0.1, H * 0.7)], fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    body, rim = std_body(mask, (172, 86, 60), "chg", light=(220, 130, 96))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the horn
    dd.polygon([(W * 0.78, H * 0.36), (W * 1.0, H * 0.44), (W * 0.78, H * 0.5)],
               fill=(246, 238, 220, 255))
    # the armor plates
    for i in range(3):
        x0 = W * (0.16 + 0.14 * i)
        dd.arc([x0, H * 0.24, x0 + W * 0.2, H * 0.76], 60, 300, fill=(120, 54, 38, 200), width=3 * SS)
    eyes_pair(d, W * 0.52, H * 0.44, 5 * SS, angry=1.0)
    dd.line([(W * 0.36, H * 0.66), (W * 0.56, H * 0.66)], fill=(80, 34, 24, 255), width=3 * SS)
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_boomling(W, H):
    mask = blob_mask(W // SS, H // SS, 0.5, 0.55, 0.3, 0.3, "boom")
    body, rim = std_body(mask, (52, 46, 56), "boom", light=(110, 100, 118), grad=0.5)
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the fuse + the spark
    dd.line([(W * 0.5, H * 0.26), (W * 0.6, H * 0.1)], fill=(160, 130, 90, 255), width=4 * SS)
    dd.ellipse([W * 0.54, H * 0.02, W * 0.68, H * 0.16], fill=(255, 190, 60, 255))
    dd.ellipse([W * 0.58, H * 0.05, W * 0.64, H * 0.11], fill=(255, 250, 210, 255))
    # the devil grin + eyes
    eyes_pair(d, W * 0.5, H * 0.48, 6 * SS, angry=1.0, sclera=(255, 210, 120), pupil=(40, 10, 10))
    dd.arc([W * 0.34, H * 0.6, W * 0.66, H * 0.8], 10, 170, fill=(255, 200, 90, 255), width=4 * SS)
    # the warning stripes band
    dd.rounded_rectangle([W * 0.3, H * 0.78, W * 0.7, H * 0.86], radius=3 * SS, fill=(70, 60, 76, 255))
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_splitter(W, H):
    # the mitosis amoeba: two lobes + nuclei
    rng = random.Random(seed_of("split-mask"))
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    dd.ellipse([W * 0.06, H * 0.18, W * 0.62, H * 0.9], fill=255)
    dd.ellipse([W * 0.38, H * 0.1, W * 0.94, H * 0.82], fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8), "L")
                      .filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255.0
    body, rim = std_body(mask, (198, 78, 150), "split", light=(240, 130, 196))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the nuclei
    for (nx, ny) in [(0.32, 0.52), (0.68, 0.46)]:
        dd.ellipse([W * (nx - 0.09), H * (ny - 0.09), W * (nx + 0.09), H * (ny + 0.09)],
                   fill=(150, 40, 110, 220))
        dd.ellipse([W * (nx - 0.035), H * (ny - 0.035), W * (nx + 0.035), H * (ny + 0.035)],
                   fill=(255, 170, 220, 255))
    eyes_pair(d, W * 0.5, H * 0.28, 5 * SS, angry=0.5)
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_orbiter(W, H):
    rng = random.Random(seed_of("orb-mask"))
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    dd.ellipse([W * 0.08, H * 0.42, W * 0.92, H * 0.78], fill=255)     # the saucer
    dd.ellipse([W * 0.34, H * 0.14, W * 0.66, H * 0.52], fill=255)     # the dome
    mask = np.asarray(m).astype(np.float32) / 255.0
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8), "L")
                      .filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255.0
    body, rim = std_body(mask, (150, 158, 178), "orb", light=(210, 218, 236))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the glass dome
    dd.ellipse([W * 0.38, H * 0.18, W * 0.62, H * 0.48], fill=(140, 210, 255, 120),
               outline=(210, 235, 255, 200), width=2 * SS)
    eyes_pair(d, W * 0.5, H * 0.34, 4 * SS, angry=0.6)
    # the rim lights (running lights)
    for i in range(5):
        lx = W * (0.2 + 0.15 * i)
        col = (255, 190, 70, 255) if i % 2 == 0 else (90, 220, 255, 255)
        dd.ellipse([lx - 3 * SS, H * 0.56 - 3 * SS, lx + 3 * SS, H * 0.56 + 3 * SS], fill=col)
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_minion(W, H):
    mask = blob_mask(W // SS, H // SS, 0.5, 0.52, 0.3, 0.3, "min", lumps=8, lump_a=0.07)
    body, rim = std_body(mask, (110, 190, 96), "min", light=(170, 230, 140))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    eyes_pair(d, W * 0.5, H * 0.44, 6 * SS, angry=0.4)
    dd.ellipse([W * 0.44, H * 0.66, W * 0.56, H * 0.74], fill=(50, 90, 44, 255))
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

# ------------------------------------------------------------------ bosses
def e_boss_heap(W, H):
    # THE HEAP: a golem of stacked junk plates with a furnace core
    rng = random.Random(seed_of("heap-mask"))
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    dd.rounded_rectangle([W * 0.1, H * 0.42, W * 0.9, H * 0.86], radius=int(W * 0.1), fill=255)
    dd.rounded_rectangle([W * 0.22, H * 0.14, W * 0.78, H * 0.5], radius=int(W * 0.08), fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8), "L")
                      .filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255.0
    body, rim = std_body(mask, (110, 104, 96), "heap", light=(170, 162, 148))
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the junk plates
    for i in range(5):
        x0 = W * (0.12 + 0.16 * i)
        dd.rounded_rectangle([x0, H * 0.5, x0 + W * 0.13, H * 0.84], radius=4 * SS,
                             fill=(90 + (i % 2) * 18, 86 + (i % 2) * 14, 80 + (i % 2) * 12, 255),
                             outline=(46, 42, 40, 255), width=2 * SS)
    # the furnace core (the mouth)
    dd.rounded_rectangle([W * 0.36, H * 0.6, W * 0.64, H * 0.76], radius=6 * SS,
                         fill=(255, 120, 40, 255))
    dd.rounded_rectangle([W * 0.40, H * 0.64, W * 0.60, H * 0.72], radius=5 * SS,
                         fill=(255, 220, 120, 255))
    # the eyes
    eyes_pair(d, W * 0.5, H * 0.3, 8 * SS, angry=1.0, sclera=(255, 190, 90), pupil=(30, 16, 10))
    # the chimney stacks
    dd.rectangle([W * 0.26, H * 0.06, W * 0.36, H * 0.2], fill=(96, 90, 84, 255))
    dd.rectangle([W * 0.64, H * 0.04, W * 0.74, H * 0.18], fill=(96, 90, 84, 255))
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_boss_prism(W, H):
    # THE PRISM MATRIARCH: a dark core wearing a crown of crystals
    mask = blob_mask(W // SS, H // SS, 0.5, 0.56, 0.3, 0.28, "prism", lumps=8, lump_a=0.05)
    body, rim = std_body(mask, (60, 40, 84), "prism", light=(120, 90, 160), grad=0.6)
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the crystal crown
    for (cx_, hgt, wd, col) in [(-0.24, 0.34, 0.1, (170, 120, 255)), (0.0, 0.46, 0.12, (210, 150, 255)),
                                (0.24, 0.34, 0.1, (170, 120, 255)), (-0.12, 0.24, 0.08, (140, 90, 220)),
                                (0.12, 0.24, 0.08, (140, 90, 220))]:
        tip = (W * (0.5 + cx_), H * (0.42 - hgt))
        base_y = H * 0.46
        dd.polygon([(W * (0.5 + cx_ - wd), base_y), (W * (0.5 + cx_ + wd), base_y), tip],
                   fill=col + (255,))
        dd.polygon([(W * (0.5 + cx_ - wd * 0.3), base_y), tip,
                    (W * (0.5 + cx_ + wd * 0.1), base_y)], fill=(240, 220, 255, 140))
    # the eye (one big beautiful iris)
    ex, ey, er = W * 0.5, H * 0.62, 13 * SS
    dd.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(250, 244, 255, 255))
    iris = er * 0.62
    dd.ellipse([ex - iris, ey - iris, ex + iris, ey + iris], fill=(190, 90, 255, 255))
    dd.ellipse([ex - iris * 0.45, ey - iris * 0.45, ex + iris * 0.45, ey + iris * 0.45],
               fill=(30, 14, 40, 255))
    dd.ellipse([ex - iris * 0.5, ey - iris * 0.6, ex - iris * 0.1, ey - iris * 0.2],
               fill=(255, 255, 255, 220))
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def e_boss_reaper(W, H):
    # SPUD REAPER: a hooded cloak with a scythe and glowing eyes
    rng = random.Random(seed_of("reap-mask"))
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    dd.polygon([(W * 0.2, H * 0.34), (W * 0.5, H * 0.06), (W * 0.8, H * 0.34),
                (W * 0.92, H * 0.9), (W * 0.5, H * 0.98), (W * 0.08, H * 0.9)], fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8), "L")
                      .filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255.0
    body, rim = std_body(mask, (44, 36, 52), "reap", light=(96, 82, 116), grad=0.55)
    layers = [body, rim]
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the hood void + the eyes
    dd.ellipse([W * 0.3, H * 0.22, W * 0.7, H * 0.56], fill=(16, 10, 20, 255))
    for sx in (-1, 1):
        ex = W * 0.5 + sx * 9 * SS
        dd.ellipse([ex - 5 * SS, H * 0.36 - 4 * SS, ex + 5 * SS, H * 0.36 + 4 * SS],
                   fill=(255, 70, 60, 255))
        dd.ellipse([ex - 2 * SS, H * 0.36 - 2 * SS, ex + 2 * SS, H * 0.36 + 2 * SS],
                   fill=(255, 220, 180, 255))
    # the scythe (behind the right shoulder)
    dd.line([(W * 0.84, H * 0.2), (W * 0.7, H * 0.86)], fill=(120, 100, 80, 255), width=4 * SS)
    dd.arc([W * 0.5, H * 0.06, W * 1.0, H * 0.4], 180, 300, fill=(210, 220, 235, 255), width=5 * SS)
    # the little potato hands
    dd.ellipse([W * 0.16, H * 0.5, W * 0.28, H * 0.62], fill=(190, 148, 92, 255))
    dd.ellipse([W * 0.72, H * 0.5, W * 0.84, H * 0.62], fill=(190, 148, 92, 255))
    layers.append(arr(d))
    return finish_creature(W, H, layers, mask)

def build_enemies():
    E("blab", 96, 96, e_blab)
    E("sprinter", 96, 96, e_sprinter)
    E("chunk", 96, 96, e_chunk)
    E("spitter", 96, 96, e_spitter)
    E("wraith", 96, 96, e_wraith)
    E("brood", 96, 96, e_brood)
    E("trishield", 96, 96, e_trishield)
    E("mender", 96, 96, e_mender)
    E("charger", 96, 96, e_charger)
    E("boomling", 96, 96, e_boomling)
    E("splitter", 96, 96, e_splitter)
    E("orbiter", 96, 96, e_orbiter)
    E("minion", 64, 64, e_minion)
    E("boss_heap", 160, 160, e_boss_heap)
    E("boss_prism", 160, 160, e_boss_prism)
    E("boss_reaper", 160, 160, e_boss_reaper)
    print("enemies done")

# ================================================================ GROUNDS
def wrap_tile(w, h):
    """a draw helper whose every call repeats at the 4 wrap offsets"""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img

class WrapDraw:
    def __init__(self, w, h):
        self.w, self.h = w * SS, h * SS
        self.img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
    def _offsets(self, x, y, r):
        offs = [(0, 0)]
        if x - r < 0: offs.append((self.w, 0))
        if x + r > self.w: offs.append((-self.w, 0))
        if y - r < 0: offs.append((0, self.h))
        if y + r > self.h: offs.append((0, -self.h))
        if (x - r < 0 or x + r > self.w) and (y - r < 0 or y + r > self.h):
            dx = offs[1][0] if len(offs) > 1 else (self.w if x - r < 0 else -self.w)
            dy = offs[-1][1]
            offs.append((dx, dy))
        return offs
    def ellipse(self, x, y, rx, ry, **kw):
        dd = ImageDraw.Draw(self.img)
        for (ox, oy) in self._offsets(x * SS, y * SS, max(rx, ry) * SS):
            dd.ellipse([(x - rx) * SS + ox, (y - ry) * SS + oy,
                        (x + rx) * SS + ox, (y + ry) * SS + oy], **kw)
    def line(self, pts, **kw):
        dd = ImageDraw.Draw(self.img)
        w_est = kw.get("width", 1)
        for (ox, oy) in self._offsets(pts[0][0] * SS, pts[0][1] * SS, w_est * 2):
            dd.line([(px * SS + ox, py * SS + oy) for (px, py) in pts], **kw)
    def poly(self, pts, **kw):
        dd = ImageDraw.Draw(self.img)
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        for (ox, oy) in self._offsets(sum(xs) / len(xs) * SS, sum(ys) / len(ys) * SS,
                                      max(max(xs) - min(xs), max(ys) - min(ys)) * SS):
            dd.polygon([(px * SS + ox, py * SS + oy) for (px, py) in pts], **kw)
    def done(self):
        return self.img

def ground_tile(kind):
    """512x512 SEAMLESS. math bands (seamless by construction) + wrapped bits."""
    W = 512
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
    rng = random.Random(seed_of("ground", kind))
    if kind == "desert_day":
        base = (208, 178, 128); band_col = (192, 160, 108); nip = (222, 198, 150)
    elif kind == "desert_night":
        base = (54, 56, 88); band_col = (46, 48, 76); nip = (70, 74, 112)
    elif kind == "park_day":
        base = (98, 156, 74); band_col = (86, 142, 64); nip = (116, 176, 88)
    else:  # park_night
        base = (36, 60, 50); band_col = (30, 52, 44); nip = (46, 76, 62)
    # the ripple bands: 6 integer cycles = seamless
    t = (np.sin((xx / W) * TAU * 6.0 + np.sin((yy / W) * TAU * 2.0) * 1.2) + 1) * 0.5
    out = np.zeros((W, W, 4), np.float32)
    out[:, :, :3] = base
    out[:, :, 3] = 255
    # band lightness
    lum = (t - 0.5) * 22
    for i in range(3):
        out[:, :, i] = np.clip(out[:, :, i] + lum, 0, 255)
    # fine grain noise
    noise = (np.random.default_rng(seed_of("grain", kind)).random((W, W)) - 0.5) * 9
    for i in range(3):
        out[:, :, i] = np.clip(out[:, :, i] + noise, 0, 255)
    img = img_from(out)
    wd = WrapDraw(W, W)
    if kind.startswith("desert"):
        peb_col = (154, 128, 88, 255) if kind == "desert_day" else (86, 90, 122, 255)
        peb_sh = (120, 96, 62, 120) if kind == "desert_day" else (34, 36, 60, 140)
        for _ in range(46):
            x, y = rng.uniform(0, W), rng.uniform(0, W)
            r = rng.uniform(2.2, 6.5)
            wd.ellipse(x + r * 0.25, y + r * 0.3, r, r * 0.75, fill=peb_sh)
            wd.ellipse(x, y, r, r * 0.75, fill=peb_col)
            wd.ellipse(x - r * 0.25, y - r * 0.3, r * 0.4, r * 0.3,
                       fill=(255, 244, 210, 70) if kind == "desert_day" else (150, 158, 200, 60))
        # the dry cracks
        for _ in range(7):
            x, y = rng.uniform(0, W), rng.uniform(0, W)
            pts = [(x, y)]
            ang = rng.uniform(0, TAU)
            for s in range(5):
                ang += rng.uniform(-0.7, 0.7)
                x += math.cos(ang) * rng.uniform(14, 30)
                y += math.sin(ang) * rng.uniform(14, 30)
                pts.append((x, y))
            wd.line(pts, fill=(140, 112, 74, 130) if kind == "desert_day" else (30, 30, 52, 150),
                    width=2)
        if kind == "desert_day":
            # sun-bleached bones
            for _ in range(3):
                x, y = rng.uniform(0, W), rng.uniform(0, W)
                ang = rng.uniform(0, TAU)
                dx2, dy2 = math.cos(ang) * 12, math.sin(ang) * 12
                wd.line([(x - dx2, y - dy2), (x + dx2, y + dy2)], fill=(232, 222, 196, 200), width=3)
                wd.ellipse(x + dx2, y + dy2, 3.2, 2.6, fill=(232, 222, 196, 220))
        else:
            # moonlit glow dots
            for _ in range(9):
                x, y = rng.uniform(0, W), rng.uniform(0, W)
                wd.ellipse(x, y, 2.0, 2.0, fill=(190, 200, 255, 90))
    else:
        # the mow stripes (wide diagonal, seamless: 8 cycles)
        stripe = (np.sin(((xx + yy) / (2 * W)) * TAU * 8.0) > 0).astype(np.float32)
        for i in range(3):
            out[:, :, i] = np.clip(out[:, :, i] + stripe * 10 - 5, 0, 255)
        img = img_from(out)
        wd = WrapDraw(W, W)
        leaf = (176, 96, 48, 235) if kind == "park_day" else (70, 52, 44, 200)
        for _ in range(30):
            x, y = rng.uniform(0, W), rng.uniform(0, W)
            ang = rng.uniform(0, TAU)
            rx_, ry_ = rng.uniform(3.4, 5.6), rng.uniform(1.8, 2.8)
            pts = []
            for k in range(8):
                aa = k / 8 * TAU
                pts.append((x + math.cos(aa) * rx_ * math.cos(ang) - math.sin(aa) * ry_ * math.sin(ang),
                            y + math.cos(aa) * rx_ * math.sin(ang) + math.sin(aa) * ry_ * math.cos(ang)))
            wd.poly(pts, fill=leaf)
        # clover clusters + flowers
        for _ in range(24):
            x, y = rng.uniform(0, W), rng.uniform(0, W)
            for k in range(3):
                ox = rng.uniform(-5, 5); oy = rng.uniform(-5, 5)
                wd.ellipse(x + ox, y + oy, rng.uniform(2.0, 3.4), rng.uniform(2.0, 3.4),
                           fill=(74, 128, 56, 200) if kind == "park_day" else (26, 48, 40, 220))
        if kind == "park_day":
            for _ in range(8):
                x, y = rng.uniform(0, W), rng.uniform(0, W)
                pet = rng.choice([(238, 226, 130), (238, 238, 244), (232, 150, 190)])
                for k in range(5):
                    aa = k / 5 * TAU
                    wd.ellipse(x + math.cos(aa) * 3.2, y + math.sin(aa) * 3.2, 1.8, 1.8,
                               fill=pet + (235,))
                wd.ellipse(x, y, 1.6, 1.6, fill=(240, 190, 60, 255))
        else:
            # fireflies
            for _ in range(10):
                x, y = rng.uniform(0, W), rng.uniform(0, W)
                wd.ellipse(x, y, 3.4, 3.4, fill=(220, 255, 140, 40))
                wd.ellipse(x, y, 1.5, 1.5, fill=(235, 255, 170, 200))
    g = wd.done()
    img = img.convert("RGBA")
    img.alpha_composite(g.resize((W, W), Image.LANCZOS))
    return finish(img, W, W)

def build_grounds():
    for kind in ["desert_day", "desert_night", "park_day", "park_night"]:
        save(ground_tile(kind), f"ground/{kind}.png", 512, 512)
    print("grounds done")

# ================================================================ PROPS
def prop_canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

def bake_shadow(layers, W, H, cx, cy, rx):
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(sh)
    dd.ellipse([(cx - rx) * SS, (cy - rx * 0.32) * SS, (cx + rx) * SS, (cy + rx * 0.32) * SS],
               fill=(12, 10, 14, 90))
    sh = sh.filter(ImageFilter.GaussianBlur(3 * SS))
    layers.append(arr(sh))

def p_rock(W, H):
    layers = []
    bake_shadow(layers, W, H, 0.5, 0.86, 0.4)
    rng = random.Random(seed_of("rock"))
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    dd.ellipse([W * 0.08, H * 0.38, W * 0.62, H * 0.88], fill=255)
    dd.ellipse([W * 0.4, H * 0.3, W * 0.92, H * 0.84], fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8), "L")
                      .filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255.0
    layers.append(shade(mask, (138, 132, 124), band=5 * SS))
    layers.append(rim_light(mask, (240, 236, 226), 0.4))
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    for _ in range(5):
        x0 = rng.uniform(0.2, 0.75) * W; y0 = rng.uniform(0.5, 0.8) * H
        dd.line([(x0, y0), (x0 + rng.uniform(-14, 14) * SS, y0 - rng.uniform(6, 18) * SS)],
                fill=(96, 90, 82, 180), width=2 * SS)
    layers.append(arr(d))
    all_a = np.zeros((H, W), np.float32)
    for L in layers:
        all_a = np.maximum(all_a, L[:, :, 3] / 255.0)
    layers.append(outline_layer(all_a, (30, 26, 24, 255), 2 * SS))
    return flatten(layers, (H, W))

def p_skull(W, H):
    layers = []
    bake_shadow(layers, W, H, 0.5, 0.84, 0.34)
    rng = random.Random(seed_of("skull"))
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    dd.rounded_rectangle([W * 0.2, H * 0.34, W * 0.8, H * 0.8], radius=int(W * 0.16), fill=255)
    dd.ellipse([W * 0.3, H * 0.18, W * 0.7, H * 0.62], fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8), "L")
                      .filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255.0
    layers.append(shade(mask, (226, 216, 192), band=4 * SS))
    layers.append(rim_light(mask, (255, 252, 240), 0.45))
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the horns
    dd.arc([W * 0.02, H * 0.14, W * 0.4, H * 0.52], 80, 220, fill=(210, 196, 168, 255), width=5 * SS)
    dd.arc([W * 0.6, H * 0.14, W * 0.98, H * 0.52], 320, 100, fill=(210, 196, 168, 255), width=5 * SS)
    # the eyes + nose
    dd.ellipse([W * 0.32, H * 0.42, W * 0.44, H * 0.56], fill=(40, 30, 28, 255))
    dd.ellipse([W * 0.56, H * 0.42, W * 0.68, H * 0.56], fill=(40, 30, 28, 255))
    dd.polygon([(W * 0.46, H * 0.6), (W * 0.54, H * 0.6), (W * 0.5, H * 0.68)],
               fill=(40, 30, 28, 255))
    # the teeth
    for i in range(4):
        tx = W * (0.36 + 0.08 * i)
        dd.line([(tx, H * 0.78), (tx, H * 0.88)], fill=(150, 138, 118, 255), width=2 * SS)
    layers.append(arr(d))
    all_a = np.zeros((H, W), np.float32)
    for L in layers:
        all_a = np.maximum(all_a, L[:, :, 3] / 255.0)
    layers.append(outline_layer(all_a, (52, 42, 36, 255), 2 * SS))
    return flatten(layers, (H, W))

def p_crate(W, H):
    layers = []
    bake_shadow(layers, W, H, 0.5, 0.85, 0.4)
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    dd.rounded_rectangle([W * 0.08, H * 0.12, W * 0.92, H * 0.88], radius=int(W * 0.06), fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    layers.append(shade(mask, (168, 122, 66), band=5 * SS))
    layers.append(rim_light(mask, (232, 190, 130), 0.4))
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    dd.rounded_rectangle([W * 0.08, H * 0.12, W * 0.92, H * 0.88], radius=int(W * 0.06),
                         outline=(96, 64, 30, 255), width=3 * SS)
    dd.line([(W * 0.1, H * 0.14), (W * 0.9, H * 0.86)], fill=(128, 88, 44, 255), width=5 * SS)
    dd.line([(W * 0.9, H * 0.14), (W * 0.1, H * 0.86)], fill=(128, 88, 44, 255), width=5 * SS)
    for yy in (0.36, 0.62):
        dd.line([(W * 0.1, H * yy), (W * 0.9, H * yy)], fill=(120, 82, 40, 255), width=2 * SS)
    layers.append(arr(d))
    all_a = np.zeros((H, W), np.float32)
    for L in layers:
        all_a = np.maximum(all_a, L[:, :, 3] / 255.0)
    layers.append(outline_layer(all_a, (44, 30, 16, 255), 2 * SS))
    return flatten(layers, (H, W))

def p_barrel(W, H):
    layers = []
    bake_shadow(layers, W, H, 0.5, 0.88, 0.36)
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    dd.rounded_rectangle([W * 0.18, H * 0.1, W * 0.82, H * 0.9], radius=int(W * 0.18), fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    layers.append(shade(mask, (94, 116, 128), band=5 * SS))
    layers.append(rim_light(mask, (170, 200, 214), 0.4))
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    for yy in (0.28, 0.5, 0.72):
        dd.line([(W * 0.2, H * yy), (W * 0.8, H * yy)], fill=(52, 66, 76, 255), width=4 * SS)
    # the rust
    rng = random.Random(seed_of("rust"))
    for _ in range(6):
        x0 = rng.uniform(0.24, 0.72) * W; y0 = rng.uniform(0.2, 0.8) * H
        dd.ellipse([x0, y0, x0 + rng.uniform(3, 8) * SS, y0 + rng.uniform(3, 7) * SS],
                   fill=(140, 84, 44, 150))
    # the hazard glyph
    dd.ellipse([W * 0.4, H * 0.4, W * 0.6, H * 0.6], fill=(220, 170, 40, 220))
    dd.polygon([(W * 0.5, H * 0.44), (W * 0.56, H * 0.56), (W * 0.44, H * 0.56)],
               fill=(40, 34, 30, 255))
    layers.append(arr(d))
    all_a = np.zeros((H, W), np.float32)
    for L in layers:
        all_a = np.maximum(all_a, L[:, :, 3] / 255.0)
    layers.append(outline_layer(all_a, (24, 30, 34, 255), 2 * SS))
    return flatten(layers, (H, W))

def p_tree(W, H):
    layers = []
    bake_shadow(layers, W, H, 0.5, 0.9, 0.34)
    rng = random.Random(seed_of("tree"))
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the gnarled trunk
    dd.polygon([(W * 0.42, H * 0.95), (W * 0.46, H * 0.5), (W * 0.4, H * 0.3),
                (W * 0.48, H * 0.34), (W * 0.52, H * 0.12), (W * 0.58, H * 0.36),
                (W * 0.62, H * 0.3), (W * 0.56, H * 0.52), (W * 0.6, H * 0.95)],
               fill=(96, 72, 52, 255))
    # the branches
    for (x0, y0, x1, y1, wd_) in [(0.48, 0.34, 0.24, 0.16, 4), (0.52, 0.3, 0.76, 0.2, 4),
                                  (0.5, 0.22, 0.36, 0.04, 3), (0.53, 0.18, 0.68, 0.06, 3)]:
        dd.line([(W * x0, H * y0), (W * x1, H * y1)], fill=(88, 64, 46, 255), width=wd_ * SS)
    # a few stubborn dead leaves
    for _ in range(7):
        x0 = rng.uniform(0.2, 0.8) * W; y0 = rng.uniform(0.04, 0.3) * H
        dd.ellipse([x0 - 3 * SS, y0 - 2 * SS, x0 + 3 * SS, y0 + 2 * SS],
                   fill=(150, 116, 48, 220))
    layers.append(arr(d))
    all_a = np.zeros((H, W), np.float32)
    for L in layers:
        all_a = np.maximum(all_a, L[:, :, 3] / 255.0)
    layers.append(outline_layer(all_a, (36, 26, 18, 255), 2 * SS))
    return flatten(layers, (H, W))

def p_bench(W, H):
    layers = []
    bake_shadow(layers, W, H, 0.5, 0.85, 0.42)
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    wood = (148, 104, 62, 255); wood_d = (110, 76, 44, 255)
    # the legs
    dd.rectangle([W * 0.16, H * 0.55, W * 0.22, H * 0.88], fill=wood_d)
    dd.rectangle([W * 0.78, H * 0.55, W * 0.84, H * 0.88], fill=wood_d)
    # the seat slats
    for i in range(3):
        yy = H * (0.42 + 0.08 * i)
        dd.rounded_rectangle([W * 0.08, yy, W * 0.92, yy + H * 0.07], radius=3 * SS, fill=wood)
    # the backrest
    for i in range(2):
        yy = H * (0.14 + 0.14 * i)
        dd.rounded_rectangle([W * 0.08, yy, W * 0.92, yy + H * 0.09], radius=3 * SS, fill=wood)
    dd.line([(W * 0.08, H * 0.32), (W * 0.92, H * 0.32)], fill=wood_d, width=3 * SS)
    layers.append(arr(d))
    all_a = np.zeros((H, W), np.float32)
    for L in layers:
        all_a = np.maximum(all_a, L[:, :, 3] / 255.0)
    layers.append(outline_layer(all_a, (40, 28, 16, 255), 2 * SS))
    return flatten(layers, (H, W))

def p_fence(W, H):
    layers = []
    bake_shadow(layers, W, H, 0.5, 0.86, 0.44)
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    wood = (158, 120, 74, 255); wood_d = (118, 86, 52, 255)
    # the pickets
    for i in range(5):
        x0 = W * (0.06 + 0.2 * i)
        dd.polygon([(x0, H * 0.9), (x0, H * 0.28), (x0 + W * 0.05, H * 0.16),
                    (x0 + W * 0.1, H * 0.28), (x0 + W * 0.1, H * 0.9)], fill=wood)
        dd.line([(x0 + W * 0.05, H * 0.16), (x0 + W * 0.05, H * 0.9)], fill=wood_d, width=2 * SS)
    # the rails
    for yy in (0.42, 0.68):
        dd.rectangle([W * 0.04, H * yy, W * 0.96, H * (yy + 0.06)], fill=wood_d)
    layers.append(arr(d))
    all_a = np.zeros((H, W), np.float32)
    for L in layers:
        all_a = np.maximum(all_a, L[:, :, 3] / 255.0)
    layers.append(outline_layer(all_a, (44, 32, 18, 255), 2 * SS))
    return flatten(layers, (H, W))

def p_shrub(W, H):
    layers = []
    bake_shadow(layers, W, H, 0.5, 0.85, 0.36)
    rng = random.Random(seed_of("shrub"))
    m = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(m)
    for _ in range(6):
        x0 = rng.uniform(0.24, 0.76) * W; y0 = rng.uniform(0.34, 0.62) * H
        r = rng.uniform(0.12, 0.2) * W
        dd.ellipse([x0 - r, y0 - r, x0 + r, y0 + r], fill=255)
    mask = np.asarray(m).astype(np.float32) / 255.0
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8), "L")
                      .filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255.0
    layers.append(shade(mask, (110, 128, 62), band=4 * SS))
    layers.append(rim_light(mask, (190, 208, 120), 0.4))
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    # the dead twigs
    for _ in range(5):
        x0 = rng.uniform(0.3, 0.7) * W; y0 = rng.uniform(0.4, 0.6) * H
        dd.line([(x0, y0), (x0 + rng.uniform(-16, 16) * SS, y0 - rng.uniform(8, 20) * SS)],
                fill=(86, 74, 40, 255), width=2 * SS)
    layers.append(arr(d))
    all_a = np.zeros((H, W), np.float32)
    for L in layers:
        all_a = np.maximum(all_a, L[:, :, 3] / 255.0)
    layers.append(outline_layer(all_a, (34, 38, 20, 255), 2 * SS))
    return flatten(layers, (H, W))

def p_ferris(W, H):
    layers = []
    d = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(d)
    col = (60, 58, 74, 255); col2 = (84, 80, 100, 255)
    cx, cy, R = W * 0.5, H * 0.46, W * 0.4
    dd.ellipse([cx - R, cy - R, cx + R, cy + R], outline=col, width=6 * SS)
    dd.ellipse([cx - R * 0.66, cy - R * 0.66, cx + R * 0.66, cy + R * 0.66], outline=col, width=3 * SS)
    for i in range(8):
        a = i / 8 * TAU
        dd.line([(cx, cy), (cx + math.cos(a) * R, cy + math.sin(a) * R)], fill=col, width=3 * SS)
        px, py = cx + math.cos(a) * R, cy + math.sin(a) * R
        dd.rounded_rectangle([px - W * 0.05, py, px + W * 0.05, py + H * 0.09],
                             radius=3 * SS, fill=col2)
    dd.polygon([(cx - W * 0.05, H * 0.97), (cx + W * 0.05, H * 0.97), (cx + W * 0.015, cy),
                (cx - W * 0.015, cy)], fill=col)
    layers.append(arr(d))
    return flatten(layers, (H, W))

def build_props():
    P("rock", 72, 60, p_rock)
    P("skull", 44, 40, p_skull)
    P("crate", 52, 52, p_crate)
    P("barrel", 40, 56, p_barrel)
    P("tree", 76, 92, p_tree)
    P("bench", 72, 36, p_bench)
    P("fence", 84, 44, p_fence)
    P("shrub", 48, 36, p_shrub)
    P("ferris", 220, 200, p_ferris)
    print("props done")

def P(name, w, h, fn):
    save(fn(w * SS, h * SS), f"props/{name}.png", w, h)

# ================================================================ GUNS
# every gun points RIGHT; 48x22; 3-tone metal + a per-weapon accent
def gun_metal(d, x0, y0, x1, y1, base=(120, 126, 140)):
    """a metal block with a top light edge and a bottom dark edge"""
    d.rounded_rectangle([x0, y0, x1, y1], radius=2 * SS, fill=C(base) + (255,))
    d.line([(x0 + 2 * SS, y0 + 1 * SS), (x1 - 2 * SS, y0 + 1 * SS)],
           fill=C((base[0] + 60, base[1] + 62, base[2] + 66)) + (255,), width=1 * SS)
    d.line([(x0 + 2 * SS, y1 - 1 * SS), (x1 - 2 * SS, y1 - 1 * SS)],
           fill=C((base[0] * 0.55, base[1] * 0.55, base[2] * 0.6)) + (255,), width=1 * SS)

def gun_common(W, H, accent, body_fn):
    img = canvas(48, 22)
    d = ImageDraw.Draw(img)
    body_fn(d, W, H, accent)
    return finish_outline_gun(img, W, H)

def finish_outline_gun(img, W, H):
    # a subtle dark outline around the opaque body
    m = np.asarray(img)[:, :, 3].astype(np.float32) / 255.0
    ol = outline_layer(m, (18, 16, 20, 255), 1 * SS)
    out = np.zeros((H, W, 4), np.float32)
    ia = np.asarray(img).astype(np.float32)
    a = ia[:, :, 3:4] / 255.0
    out[:, :, :3] = ia[:, :, :3] * a + ol[:, :, :3] * (ol[:, :, 3:4] / 255.0) * (1 - a)
    out[:, :, 3] = np.clip(ia[:, :, 3] + ol[:, :, 3] * (1 - a[:, :, 0]), 0, 255)
    return finish(img_from(out), W // SS, H // SS)

def gun_shape(kind, accent):
    def draw(d, W, H, acc):
        mid = H * 0.5
        if kind == "smg":
            gun_metal(d, W * 0.18, H * 0.32, W * 0.62, H * 0.6)
            gun_metal(d, W * 0.62, H * 0.4, W * 0.88, H * 0.52, base=(90, 94, 104))
            d.rounded_rectangle([W * 0.3, H * 0.6, W * 0.4, H * 0.92], radius=2 * SS, fill=(70, 60, 52, 255))
            d.rounded_rectangle([W * 0.44, H * 0.6, W * 0.52, H * 0.86], radius=2 * SS, fill=(60, 62, 70, 255))
            d.rectangle([W * 0.68, H * 0.34, W * 0.74, H * 0.58], fill=C(acc) + (255,))
        elif kind == "shotgun":
            gun_metal(d, W * 0.1, H * 0.34, W * 0.9, H * 0.48, base=(110, 92, 70))
            gun_metal(d, W * 0.34, H * 0.5, W * 0.72, H * 0.64, base=(86, 72, 56))
            d.rounded_rectangle([W * 0.06, H * 0.36, W * 0.2, H * 0.66], radius=3 * SS, fill=(120, 82, 48, 255))
            d.rectangle([W * 0.86, H * 0.38, W * 0.94, H * 0.44], fill=C(acc) + (255,))
        elif kind == "rifle":
            gun_metal(d, W * 0.06, H * 0.42, W * 0.94, H * 0.54, base=(96, 100, 110))
            gun_metal(d, W * 0.3, H * 0.28, W * 0.56, H * 0.4, base=(70, 74, 82))
            d.ellipse([W * 0.36, H * 0.24, W * 0.5, H * 0.4], fill=C(acc) + (255,))
            d.rounded_rectangle([W * 0.18, H * 0.54, W * 0.3, H * 0.88], radius=2 * SS, fill=(96, 66, 40, 255))
            d.rounded_rectangle([W * 0.62, H * 0.54, W * 0.76, H * 0.7], radius=2 * SS, fill=(70, 60, 50, 255))
        elif kind == "laser":
            gun_metal(d, W * 0.14, H * 0.36, W * 0.7, H * 0.62, base=(88, 96, 120))
            for i in range(3):
                x0 = W * (0.72 + 0.06 * i)
                d.arc([x0, H * 0.3, x0 + W * 0.12, H * 0.68], -80, 80, fill=C(acc) + (255,), width=2 * SS)
            d.ellipse([W * 0.88, H * 0.4, W * 0.98, H * 0.58], fill=C(acc) + (255,))
            d.ellipse([W * 0.91, H * 0.44, W * 0.95, H * 0.54], fill=(255, 255, 255, 220))
        elif kind == "cannon":
            gun_metal(d, W * 0.12, H * 0.24, W * 0.78, H * 0.74, base=(104, 92, 84))
            gun_metal(d, W * 0.78, H * 0.3, W * 0.94, H * 0.68, base=(76, 68, 62))
            d.ellipse([W * 0.86, H * 0.38, W * 0.96, H * 0.6], fill=(30, 26, 24, 255))
            d.rectangle([W * 0.34, H * 0.2, W * 0.42, H * 0.28], fill=C(acc) + (255,))
            d.rounded_rectangle([W * 0.16, H * 0.74, W * 0.3, H * 0.94], radius=2 * SS, fill=(70, 60, 52, 255))
        elif kind == "frost":
            gun_metal(d, W * 0.14, H * 0.4, W * 0.66, H * 0.62, base=(92, 108, 128))
            for i in range(3):
                x0 = W * (0.66 + 0.09 * i)
                d.polygon([(x0, mid - (9 - i * 2) * SS), (x0 + W * 0.08, mid),
                           (x0, mid + (9 - i * 2) * SS)], fill=C(acc) + (255,))
            d.rounded_rectangle([W * 0.18, H * 0.62, W * 0.32, H * 0.9], radius=2 * SS, fill=(70, 62, 52, 255))
        elif kind == "flame":
            d.ellipse([W * 0.12, H * 0.22, W * 0.48, H * 0.8], fill=(196, 70, 44, 255))
            gun_metal(d, W * 0.44, H * 0.36, W * 0.9, H * 0.6, base=(110, 104, 100))
            d.ellipse([W * 0.88, H * 0.38, W * 0.98, H * 0.58], fill=C(acc) + (255,))
            d.line([(W * 0.2, H * 0.22), (W * 0.3, H * 0.08)], fill=(90, 90, 96, 255), width=2 * SS)
        elif kind == "rail":
            gun_metal(d, W * 0.1, H * 0.3, W * 0.6, H * 0.44, base=(96, 102, 118))
            gun_metal(d, W * 0.1, H * 0.56, W * 0.6, H * 0.7, base=(96, 102, 118))
            gun_metal(d, W * 0.1, H * 0.42, W * 0.86, H * 0.58, base=(70, 74, 88))
            d.rectangle([W * 0.6, H * 0.46, W * 0.9, H * 0.54], fill=C(acc) + (255,))
            d.rectangle([W * 0.66, H * 0.48, W * 0.86, H * 0.52], fill=(255, 255, 255, 200))
        elif kind == "boomerang":
            d.arc([W * 0.08, H * 0.08, W * 0.92, H * 0.95], 110, 250, fill=C(acc) + (255,), width=5 * SS)
            d.arc([W * 0.14, H * 0.16, W * 0.86, H * 0.87], 130, 230, fill=(255, 244, 214, 180), width=2 * SS)
        elif kind == "minigun":
            gun_metal(d, W * 0.08, H * 0.3, W * 0.34, H * 0.7, base=(88, 92, 102))
            for i in range(3):
                yy = H * (0.34 + 0.13 * i)
                gun_metal(d, W * 0.34, yy, W * 0.92, yy + H * 0.09, base=(110, 114, 124))
            d.ellipse([W * 0.16, H * 0.36, W * 0.3, H * 0.64], fill=C(acc) + (255,))
        elif kind == "fryer":
            d.ellipse([W * 0.3, H * 0.14, W * 0.94, H * 0.86], fill=(120, 108, 96, 255))
            d.ellipse([W * 0.42, H * 0.3, W * 0.82, H * 0.7], fill=C(acc) + (255,))
            d.ellipse([W * 0.52, H * 0.4, W * 0.72, H * 0.6], fill=(255, 230, 150, 230))
            gun_metal(d, W * 0.06, H * 0.4, W * 0.34, H * 0.6, base=(96, 88, 80))
        elif kind == "gravity":
            gun_metal(d, W * 0.12, H * 0.38, W * 0.52, H * 0.62, base=(92, 88, 112))
            d.ellipse([W * 0.5, H * 0.12, W * 0.94, H * 0.88], outline=C(acc) + (255,), width=4 * SS)
            d.ellipse([W * 0.6, H * 0.26, W * 0.84, H * 0.74], outline=(255, 255, 255, 170), width=2 * SS)
    return draw

GUN_ACCENTS = {
    "smg": (250, 204, 60), "shotgun": (226, 148, 66), "rifle": (150, 158, 170),
    "laser": (80, 220, 255), "cannon": (240, 120, 60), "frost": (120, 210, 255),
    "flame": (255, 140, 60), "rail": (170, 200, 255), "boomerang": (240, 200, 90),
    "minigun": (200, 160, 120), "fryer": (255, 190, 70), "gravity": (190, 120, 255),
}

def build_guns():
    for wid, acc in GUN_ACCENTS.items():
        img = canvas(48, 22)
        d = ImageDraw.Draw(img)
        gun_shape(wid, acc)(d, 48 * SS, 22 * SS, acc)
        save(finish_outline_gun(img, 48 * SS, 22 * SS), f"weapons/gun_{wid}.png", 48, 22)
        # the icon: a black rounded plate + the gun + the accent ring
        ic = canvas(56, 56)
        dd = ImageDraw.Draw(ic)
        dd.rounded_rectangle([2 * SS, 2 * SS, 54 * SS, 54 * SS], radius=10 * SS, fill=(16, 16, 20, 255),
                             outline=C(acc) + (255,), width=2 * SS)
        gun_shape(wid, acc)(dd, 56 * SS, 56 * SS, acc)
        save(finish(ic, 56, 56), f"weapons/icon_{wid}.png", 56, 56)
    print("guns done")

# ================================================================ BULLETS
def build_bullets():
    # bolt: a yellow energy dart
    img = canvas(18, 12)
    d = ImageDraw.Draw(img)
    d.polygon([(1 * SS, 6 * SS), (12 * SS, 2 * SS), (17 * SS, 6 * SS), (12 * SS, 10 * SS)],
              fill=(255, 226, 90, 255))
    d.polygon([(4 * SS, 6 * SS), (12 * SS, 4 * SS), (15 * SS, 6 * SS), (12 * SS, 8 * SS)],
              fill=(255, 250, 210, 255))
    save(finish(img, 18, 12), "bullets/bolt.png", 18, 12)
    # pellet: a hot tan ball
    img = canvas(12, 12)
    d = ImageDraw.Draw(img)
    d.ellipse([1 * SS, 1 * SS, 11 * SS, 11 * SS], fill=(226, 172, 96, 255))
    d.ellipse([3 * SS, 2.6 * SS, 7 * SS, 6.4 * SS], fill=(255, 226, 170, 255))
    save(finish(img, 12, 12), "bullets/pellet.png", 12, 12)
    # slug: a brass slug
    img = canvas(20, 10)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1 * SS, 2.6 * SS, 15 * SS, 7.4 * SS], radius=3 * SS, fill=(196, 158, 84, 255))
    d.ellipse([13 * SS, 1.6 * SS, 19 * SS, 8.4 * SS], fill=(226, 190, 110, 255))
    save(finish(img, 20, 10), "bullets/slug.png", 20, 10)
    # lance: a cyan beam segment
    img = canvas(22, 8)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 2.6 * SS, 22 * SS, 5.4 * SS], radius=2 * SS, fill=(120, 236, 255, 255))
    d.rounded_rectangle([0, 3.6 * SS, 22 * SS, 4.4 * SS], radius=1 * SS, fill=(255, 255, 255, 240))
    save(finish(img, 22, 8), "bullets/lance.png", 22, 8)
    # bomb: a black sphere + fuse
    img = canvas(16, 16)
    d = ImageDraw.Draw(img)
    d.ellipse([1 * SS, 4 * SS, 13 * SS, 16 * SS], fill=(44, 40, 48, 255))
    d.ellipse([3 * SS, 6 * SS, 7 * SS, 10 * SS], fill=(96, 92, 104, 255))
    d.line([(9 * SS, 5 * SS), (13 * SS, 1 * SS)], fill=(150, 120, 80, 255), width=2 * SS)
    d.ellipse([12 * SS, 0, 16 * SS, 4 * SS], fill=(255, 190, 60, 255))
    save(finish(img, 16, 16), "bullets/bomb.png", 16, 16)
    # shard: an ice crystal
    img = canvas(14, 14)
    d = ImageDraw.Draw(img)
    d.polygon([(7 * SS, 0), (12 * SS, 5 * SS), (7 * SS, 14 * SS), (2 * SS, 5 * SS)],
              fill=(150, 220, 255, 255))
    d.polygon([(7 * SS, 1.5 * SS), (9.5 * SS, 5 * SS), (7 * SS, 11 * SS), (4.5 * SS, 5 * SS)],
              fill=(220, 245, 255, 255))
    save(finish(img, 14, 14), "bullets/shard.png", 14, 14)
    # rail: the white-blue lance
    img = canvas(26, 8)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 2 * SS, 26 * SS, 6 * SS], radius=2 * SS, fill=(180, 208, 255, 255))
    d.rounded_rectangle([0, 3.4 * SS, 26 * SS, 4.6 * SS], radius=1 * SS, fill=(255, 255, 255, 250))
    save(finish(img, 26, 8), "bullets/rail.png", 26, 8)
    # orb: the void sphere
    img = canvas(18, 18)
    d = ImageDraw.Draw(img)
    d.ellipse([1 * SS, 1 * SS, 17 * SS, 17 * SS], fill=(120, 60, 190, 255))
    d.ellipse([3 * SS, 3 * SS, 15 * SS, 15 * SS], outline=(220, 170, 255, 220), width=2 * SS)
    d.ellipse([5 * SS, 5 * SS, 10 * SS, 10 * SS], fill=(235, 210, 255, 220))
    save(finish(img, 18, 18), "bullets/orb.png", 18, 18)
    # boomerang: the curved blade
    img = canvas(20, 20)
    d = ImageDraw.Draw(img)
    d.arc([2 * SS, 2 * SS, 18 * SS, 18 * SS], 200, 80, fill=(240, 200, 90, 255), width=4 * SS)
    d.arc([4 * SS, 4 * SS, 16 * SS, 16 * SS], 210, 70, fill=(255, 244, 210, 220), width=2 * SS)
    save(finish(img, 20, 20), "bullets/boomerang.png", 20, 20)
    # tracer: a small yellow dash
    img = canvas(12, 5)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 1 * SS, 12 * SS, 4 * SS], radius=1 * SS, fill=(255, 232, 120, 255))
    save(finish(img, 12, 5), "bullets/tracer.png", 12, 5)
    print("bullets done")

# ================================================================ PICKUPS
def build_pickups():
    # THE COSMIC COIN: a fat gold coin with a POTATO embossed in the middle
    # (the owner: "a yellow thing with something in the middle" - and it must
    # NOT look like the box's gogacoin)
    S = 44
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cx = cy = S * SS * 0.5
    R = S * SS * 0.46
    # the rim (dark gold) + the face (gold) + the inner ring
    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=(196, 142, 32, 255))
    r2 = R * 0.84
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=(248, 196, 60, 255))
    d.arc([cx - R * 0.94, cy - R * 0.94, cx + R * 0.94, cy + R * 0.94], 0, 360,
          fill=(255, 232, 140, 255), width=2 * SS)
    # the embossed potato (a lumpy oval, darker gold + a light edge)
    pr = R * 0.46
    pts = []
    for i in range(14):
        a = i / 14 * TAU
        lump = 1.0 + (0.09 if i % 3 == 0 else -0.05)
        pts.append((cx + math.cos(a) * pr * lump * 1.12, cy + math.sin(a) * pr * lump * 0.86))
    d.polygon(pts, fill=(214, 158, 40, 255))
    d.line(pts + [pts[0]], fill=(255, 232, 150, 255), width=1 * SS)
    # the potato's dimple eyes
    for (ex, ey) in [(-0.35, -0.25), (0.3, 0.1)]:
        ex_, ey_ = cx + ex * pr, cy + ey * pr
        d.ellipse([ex_ - 1.4 * SS, ey_ - 1.4 * SS, ex_ + 1.4 * SS, ey_ + 1.4 * SS],
                  fill=(180, 126, 26, 255))
    # the glint
    d.ellipse([cx - R * 0.62, cy - R * 0.78, cx - R * 0.2, cy - R * 0.44],
              fill=(255, 246, 200, 170))
    save(finish(img, S, S), "pickups/coin.png", S, S)
    # the XP gem: a cyan crystal
    S = 22
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    cxx, cyy = S * SS * 0.5, S * SS * 0.52
    d.polygon([(cxx, 0.5 * SS), (S * SS * 0.86, cyy), (cxx, S * SS * 0.96), (S * SS * 0.14, cyy)],
              fill=(80, 210, 255, 255))
    d.polygon([(cxx, 2 * SS), (S * SS * 0.62, cyy), (cxx, S * SS * 0.86), (S * SS * 0.3, cyy)],
              fill=(190, 240, 255, 255))
    save(finish(img, S, S), "pickups/xp.png", S, S)
    # the heart
    S = 22
    img = canvas(S, S)
    d = ImageDraw.Draw(img)
    w_ = S * SS
    d.ellipse([1 * SS, 2 * SS, w_ * 0.52, w_ * 0.55], fill=(232, 60, 80, 255))
    d.ellipse([w_ * 0.48, 2 * SS, w_ - 1 * SS, w_ * 0.55], fill=(232, 60, 80, 255))
    d.polygon([(1.6 * SS, w_ * 0.4), (w_ - 1.6 * SS, w_ * 0.4), (w_ * 0.5, w_ * 0.95)],
              fill=(232, 60, 80, 255))
    d.ellipse([w_ * 0.2, w_ * 0.16, w_ * 0.34, w_ * 0.3], fill=(255, 170, 180, 220))
    save(finish(img, S, S), "pickups/heart.png", S, S)
    print("pickups done")

# ================================================================ THE ZIP
def wire_zip_parts():
    """the owner's uploaded Twin_Stick_Shooter_Template.zip: the fireball
    becomes the spitter's spit + the boom burst; the crystals join the
    desert-night props."""
    import shutil
    def first_png(name):
        p = os.path.join(ZIP, name)
        for root, _, fs in os.walk(p):
            for f in sorted(fs):
                if f.endswith(".png") and "layers" not in root:
                    return os.path.join(root, f)
        return None
    spit = first_png("spr_enemy_fireball")
    if spit:
        im = Image.open(spit).convert("RGBA")
        im.save(os.path.join(OUT, "bullets", "spit.png"))
        print("zip: spit <- spr_enemy_fireball", im.size)
    for i in (1, 2, 3):
        src = first_png(f"spr_obstacle_{i}")
        if src:
            im = Image.open(src).convert("RGBA")
            im.save(os.path.join(OUT, "props", f"crystal_{i}.png"))
            print(f"zip: crystal_{i} <- spr_obstacle_{i}", im.size)
    print("zip parts done")

# ================================================================ MAIN
def contact_sheet():
    files = []
    for root, _, fs in os.walk(OUT):
        for f in sorted(fs):
            if f.endswith(".png"):
                files.append(os.path.join(root, f))
    files.sort()
    CELL = 96
    COLS = 10
    rows = (len(files) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * CELL, rows * (CELL + 12)), (88, 88, 98))
    dd = ImageDraw.Draw(sheet)
    for i, p in enumerate(files):
        try:
            im = Image.open(p).convert("RGBA")
            s = min((CELL - 6) / im.width, (CELL - 6) / im.height, 1.0)
            im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))))
            x = (i % COLS) * CELL
            y = (i // COLS) * (CELL + 12)
            sheet.paste(im, (x + (CELL - im.width) // 2, y + (CELL - im.height) // 2), im)
            dd.text((x + 2, y + CELL), os.path.basename(p)[:18], fill=(255, 255, 0))
        except Exception as e:
            print("sheet err", p, e)
    out = "/home/z/my-project/asset_trials/cs_p1_contact.png"
    sheet.save(out)
    print("sheet:", out)

def main():
    build_heroes()
    build_enemies()
    build_grounds()
    build_props()
    build_guns()
    build_bullets()
    build_pickups()
    wire_zip_parts()
    contact_sheet()
    print("ALL ART DONE")

if __name__ == "__main__":
    main()
