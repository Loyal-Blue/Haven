"""Regenerate the Android and iOS launcher icons from Haven's original design."""

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
icon = Image.new("RGB", (256, 256), "#292d2c")
d = ImageDraw.Draw(icon)
d.rounded_rectangle((34, 34, 221, 221), radius=46, fill="#e6eae7")
d.ellipse((63, 171, 195, 193), fill="#ccd4cf")
d.polygon([(120, 171), (121, 119), (134, 119), (134, 179), (121, 179)], fill="#5d6862")
d.polygon([(128, 58), (159, 102), (148, 102), (174, 134), (158, 134),
           (184, 165), (73, 165), (99, 134), (83, 134), (108, 102), (97, 102)],
          fill="#3c4641")
d.polygon([(128, 63), (128, 161), (80, 161), (102, 133), (88, 131),
           (113, 100), (102, 100)], fill="#687970")
d.polygon([(128, 68), (123, 102), (111, 102), (122, 89), (114, 89)], fill="#a8b8ae")

res = ROOT / "android" / "app" / "src" / "main" / "res"
for density, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    icon.resize((size, size), Image.Resampling.LANCZOS).save(res / f"mipmap-{density}" / "ic_launcher.png")

catalog = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
for entry in json.loads((catalog / "Contents.json").read_text())["images"]:
    size = round(float(entry["size"].split("x")[0]) * int(entry["scale"][0]))
    icon.resize((size, size), Image.Resampling.LANCZOS).save(catalog / entry["filename"])
