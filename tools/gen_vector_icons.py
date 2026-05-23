#!/usr/bin/env python3
"""Fetch lucide SVGs and emit a compact Lua VectorIcons table for MatchaUI.

Lucide icons live on a 24x24 grid, stroke-based. We convert every shape to:
  - polylines (flat {x1,y1,x2,y2,...} in 0..24 space)  -> drawn as Line segments
  - circles   ({cx,cy,r})                              -> drawn as outline rings
Curves (path beziers/arcs, ellipses) are flattened to polylines.
Output: each icon = { p={poly,...}, c={circle,...} }  (omitted keys when empty)
"""
import urllib.request, xml.etree.ElementTree as ET, re, sys
from svgpathtools import parse_path

ICONS = "activity,arrow-right,bell,bomb,bookmark,bot,box,bug,calendar,camera,car,check,check-check,chevron-down,chevron-left,chevron-right,chevron-up,circle,circle-alert,circle-check,circle-help,circle-x,clipboard,clock,code,cog,coins,compass,copy,cpu,crosshair,crown,database,dollar-sign,download,droplet,external-link,eye,eye-off,file,filter,fingerprint,flag,flame,folder,folder-open,gamepad-2,gauge,gem,ghost,gift,globe,grid-2x2,hammer,hard-drive,headphones,heart,home,house,image,info,key,keyboard,layers,layout-dashboard,link,list,lock,log-out,mail,map,map-pin,menu,message-square,mic,minus,monitor,moon,mouse,mouse-pointer-2,move,music,navigation,package,palette,pause,pause-circle,pencil,plane,play,play-circle,plus,plus-circle,power,refresh-cw,rocket,rotate-cw,save,scan,search,send,server,settings,settings-2,shield,shield-check,shopping-cart,skull,sliders-horizontal,smartphone,sparkles,square,star,sun,sword,swords,tag,target,terminal,timer,toggle-left,toggle-right,trash-2,triangle-alert,unlock,upload,user,user-plus,users,video,volume-2,volume-x,wand-sparkles,wifi,wrench,x,zap".split(",")

BASE = "https://unpkg.com/lucide-static@latest/icons/{}.svg"
BEZ_SEG = 6   # samples per bezier/arc segment (excluding start point)

def fnum(v):
    s = f"{v:.1f}".rstrip("0").rstrip(".")
    return s if s else "0"

def strip_ns(tag):
    return tag.split("}")[-1]

def flatten_path(d):
    """parse_path -> list of polylines (each a list of (x,y))."""
    path = parse_path(d)
    polys, cur = [], []
    last_end = None
    for seg in path:
        s = (seg.start.real, seg.start.imag)
        e = (seg.end.real, seg.end.imag)
        # new subpath if there's a gap (Move) between segments
        if last_end is None or abs(complex(*s) - complex(*last_end)) > 1e-4:
            if len(cur) >= 2:
                polys.append(cur)
            cur = [s]
        segname = seg.__class__.__name__
        if segname == "Line":
            cur.append(e)
        else:  # CubicBezier, QuadraticBezier, Arc
            for i in range(1, BEZ_SEG + 1):
                p = seg.point(i / BEZ_SEG)
                cur.append((p.real, p.imag))
        last_end = e
    if len(cur) >= 2:
        polys.append(cur)
    return polys

def rect_poly(x, y, w, h):
    return [[(x, y), (x + w, y), (x + w, y + h), (x, y + h), (x, y)]]

def points_poly(s, close):
    nums = [float(n) for n in re.findall(r"-?[\d.]+", s)]
    pts = list(zip(nums[0::2], nums[1::2]))
    if close and pts:
        pts.append(pts[0])
    return [pts] if len(pts) >= 2 else []

def ellipse_poly(cx, cy, rx, ry, n=24):
    import math
    pts = [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n + 1)]
    return [pts]

def parse_svg(svg):
    root = ET.fromstring(svg)
    polys, circles = [], []
    for el in root.iter():
        tag = strip_ns(el.tag)
        a = el.attrib
        try:
            if tag == "path":
                polys += flatten_path(a["d"])
            elif tag == "line":
                polys.append([(float(a["x1"]), float(a["y1"])), (float(a["x2"]), float(a["y2"]))])
            elif tag == "polyline":
                polys += points_poly(a.get("points", ""), False)
            elif tag == "polygon":
                polys += points_poly(a.get("points", ""), True)
            elif tag == "rect":
                polys += rect_poly(float(a["x"]), float(a["y"]), float(a["width"]), float(a["height"]))
            elif tag == "circle":
                circles.append((float(a["cx"]), float(a["cy"]), float(a["r"])))
            elif tag == "ellipse":
                rx, ry = float(a["rx"]), float(a["ry"])
                if abs(rx - ry) < 0.01:
                    circles.append((float(a["cx"]), float(a["cy"]), rx))
                else:
                    polys += ellipse_poly(float(a["cx"]), float(a["cy"]), rx, ry)
        except (KeyError, ValueError):
            continue
    return polys, circles

def lua_icon(polys, circles):
    parts = []
    if polys:
        ps = []
        for pl in polys:
            flat = []
            for (x, y) in pl:
                flat.append(fnum(x)); flat.append(fnum(y))
            ps.append("{" + ",".join(flat) + "}")
        parts.append("p={" + ",".join(ps) + "}")
    if circles:
        cs = ["{" + ",".join(fnum(v) for v in c) + "}" for c in circles]
        parts.append("c={" + ",".join(cs) + "}")
    return "{" + ",".join(parts) + "}"

def main():
    out = {}
    for i, name in enumerate(ICONS):
        try:
            svg = urllib.request.urlopen(BASE.format(name), timeout=20).read().decode()
            polys, circles = parse_svg(svg)
            out[name] = lua_icon(polys, circles)
            print(f"[{i+1}/{len(ICONS)}] {name}: {len(polys)} polys, {len(circles)} circles", file=sys.stderr)
        except Exception as e:
            print(f"FAIL {name}: {e}", file=sys.stderr)
    lines = ["-- Auto-generated lucide vector icons (24x24 space). Do not edit by hand.",
             "-- p = polylines (flat x,y pairs), c = circles (cx,cy,r).",
             "return {"]
    for name in sorted(out):
        key = name if re.match(r"^[A-Za-z_]\w*$", name) else f'["{name}"]'
        # names with dashes are not valid lua identifiers -> bracket form
        if "-" in name:
            key = f'["{name}"]'
        lines.append(f'  {key}={out[name]},')
    lines.append("}")
    blob = "\n".join(lines)
    open("vector_icons.lua", "w", encoding="utf-8").write(blob)
    print(f"\nWROTE vector_icons.lua  ({len(blob)} bytes, {len(out)} icons)", file=sys.stderr)

if __name__ == "__main__":
    main()
