"""Regenerate Haven's original valley and building sprites with Pillow."""

from math import cos, pi, sin
from pathlib import Path
from random import Random

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "world"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 320, 304


def oak(d, x, y, scale=1, shade=0):
    palette = [
        ("#3c4836", "#566245", "#78825a", "#a0a678"),
        ("#2d382c", "#434e37", "#606c48", "#848b59"),
        ("#333d30", "#4e5a40", "#69764f", "#879163"),
    ][shade]

    def poly(points, color):
        d.polygon([(x+round(px*scale), y+round(py*scale)) for px, py in points], fill=color)

    poly([(-6,1),(-3,-1),(8,-1),(11,2),(5,3),(-4,3)], "#576147")
    poly([(-1,2),(-1,-5),(2,-6),(2,1)], "#686047")
    poly([(-6,-3),(-7,-8),(-4,-12),(-3,-16),(1,-18),(5,-15),(6,-11),
          (8,-8),(6,-3),(2,-1),(-2,-1)], palette[0])
    poly([(-5,-5),(-5,-8),(-2,-12),(-2,-15),(1,-17),(4,-14),(5,-10),
          (6,-8),(4,-4),(-1,-3)], palette[1])
    poly([(-4,-8),(-2,-10),(-1,-14),(1,-16),(3,-14),(3,-10),(1,-8),
          (0,-6),(-3,-6)], palette[2])
    poly([(-1,-11),(0,-15),(2,-14),(2,-12)], palette[3])


def rock(d, x, y, size=4):
    d.polygon([(x-size,y),(x-size+2,y-size//2-1),(x+1,y-size//2-2),
               (x+size,y-1),(x+size-1,y+2),(x,y+3)], fill="#707567")
    d.polygon([(x-size+1,y),(x-size+3,y-size//2-1),(x+1,y-size//2-2),
               (x+size-1,y-1),(x+1,y+1)], fill="#bcc0aa")
    d.point((x,y-size//2-1), fill="#d7d8bd")


def anchor(x, y):
    return 155 + 14*(x-5) - 14*(y-4), 165 + 5*(x-5) + 16*(y-4)


def terrain(variant="center"):
    seeds = {"center": 430, "meadows": 769, "pinewood": 412, "highlands": 903}
    rng = Random(seeds[variant])
    img = Image.new("RGB", (W,H), "#424b37")
    d = ImageDraw.Draw(img)
    outline = [(0,224),(13,204),(32,183),(47,166),(68,148),(89,140),(101,127),
               (112,104),(128,98),(141,79),(165,59),(178,43),(206,28),(221,9),
               (250,0),(320,0),(320,108),(305,127),(287,141),(270,149),(258,175),
               (229,195),(215,221),(192,238),(179,254),(150,264),(148,280),(118,304),(0,304)]
    d.polygon(outline, fill="#899464")
    d.polygon([(0,250),(30,223),(60,202),(79,179),(113,155),(136,137),(153,115),(180,102),
               (189,77),(224,63),(266,27),(320,8),(320,92),(291,112),(260,142),
               (254,159),(226,181),(208,213),(186,226),(165,237),(143,258),(124,272),
               (97,294),(0,304)], fill="#a7ad74")
    d.polygon([(0,4),(80,0),(143,11),(177,0),(214,0),(186,37),(155,56),(130,69),(103,76),
               (92,105),(71,125),(42,145),(0,152)], fill="#535d43")
    d.polygon([(320,141),(282,161),(267,184),(236,210),(212,239),(196,251),(164,269),
               (142,294),(130,304),(320,304)], fill="#515943")

    fields = [
        ([(258,20),(289,11),(311,19),(304,39),(283,47),(271,50)],"#b6b475"),
        ([(249,43),(269,35),(275,49),(268,63),(249,71),(238,60)],"#d3b96f"),
        ([(275,57),(300,48),(319,52),(310,73),(293,84),(273,82)],"#d9c477"),
        ([(231,77),(245,64),(266,66),(264,82),(245,91),(230,87)],"#b8b777"),
        ([(263,86),(292,87),(290,98),(278,109),(254,111),(246,102)],"#d5bf72"),
        ([(217,100),(234,91),(246,97),(244,112),(219,122),(207,116)],"#bdba76"),
        ([(244,113),(269,110),(282,112),(266,130),(248,135),(235,131)],"#e0c879"),
        ([(246,138),(265,131),(277,134),(265,148),(247,155),(236,153)],"#cbbb74"),
        ([(209,150),(226,142),(238,151),(237,162),(213,175),(204,166)],"#d1be72"),
        ([(227,177),(247,170),(251,181),(230,191),(213,195),(212,187)],"#dec778"),
        ([(192,193),(216,185),(215,198),(200,215),(181,220),(173,212)],"#d5be71"),
        ([(168,218),(195,216),(194,227),(180,237),(155,239),(152,231)],"#b7b476"),
        ([(139,235),(155,234),(154,247),(139,263),(113,262),(113,252)],"#d6c172"),
        ([(80,233),(104,223),(113,229),(103,252),(84,266),(69,253)],"#c7b573"),
        ([(26,260),(48,246),(66,250),(60,265),(44,275),(23,273)],"#d1bb70"),
        ([(3,279),(32,274),(47,280),(46,292),(24,299),(2,298)],"#aaa666"),
        ([(50,285),(69,269),(91,266),(94,278),(82,289),(55,300)],"#d4be73"),
        ([(66,168),(89,155),(104,160),(98,175),(80,187),(61,183)],"#bdbb75"),
        ([(98,139),(120,127),(131,132),(134,143),(117,153),(106,151)],"#b8b771"),
        ([(70,201),(95,191),(102,198),(95,213),(76,222),(66,214)],"#d6c376"),
    ]
    for index, (points, color) in enumerate(fields):
        if variant == "pinewood" and index % 3 != 1:
            continue
        if variant == "meadows":
            color = ("#c2ca84", "#aab66c", "#d5c87c")[index % 3]
        if variant == "highlands":
            color = ("#b6b78e", "#c6be9a", "#b1b284")[index % 3]
        d.polygon(points, fill=color, outline="#939869")
        xmin,xmax=min(x for x,_ in points),max(x for x,_ in points)
        ymin,ymax=min(y for _,y in points),max(y for _,y in points)
        rgb=tuple(bytes.fromhex(color[1:]))
        for y in range(ymin+2,ymax,3):
            for x in range(xmin,xmax):
                if img.getpixel((x,y))==rgb and rng.random()<.75:
                    d.point((x,y),fill=tuple(max(0,v-rng.choice([5,8,12])) for v in rgb))

    def ridge(crest, height):
        faces = [(x + int(height*.43), y + height) for x,y in crest]
        d.polygon([*crest,*reversed(faces)], fill="#777d71")
        shades = ["#c7cab6","#a6ad9d","#dde0c9","#92998b","#bec2ae"]
        for i in range(len(crest)-1):
            (x,y),(nx,ny)=crest[i:i+2]
            a,b=faces[i:i+2]
            p=(x+(nx-x)//2+height//5,(y+ny)//2+height//2)
            d.polygon([(x,y),(nx,ny),p,b,a], fill=shades[i%len(shades)])
            d.polygon([(nx,ny),p,(p[0]+3,p[1]+height//3),b], fill="#7b8376")
            d.line([(x,y),(nx,ny)], fill="#cdd0b8", width=2)
            d.line([a,b], fill="#5c6656",width=2)
            for _ in range(5):
                qx=rng.randint(min(x,nx),max(x,nx))
                qy=max(y,ny)+rng.randint(1,max(2,height//2))
                if 0<=qx<W and 0<=qy<H and img.getpixel((qx,qy))==tuple(bytes.fromhex(shades[i%len(shades)][1:])):
                    d.line([(qx,qy),(qx+2,qy+2)], fill="#a8ad9b")

    upper_height = {"center": 28, "meadows": 19, "pinewood": 25, "highlands": 34}
    lower_height = {"center": 26, "meadows": 18, "pinewood": 23, "highlands": 32}
    ridge([(0,130),(17,120),(25,103),(46,109),(65,96),(78,75),(96,77),(115,57),
           (148,58),(160,48),(169,36),(190,29)], upper_height[variant])
    ridge([(117,282),(141,276),(155,259),(173,255),(189,230),(210,226),(225,204),
           (250,194),(258,173),(276,175),(290,153),(319,151)], lower_height[variant])
    ridge([(224,297),(254,280),(266,259),(287,263),(297,229),(320,224)], 13)
    ridge([(0,43),(21,34),(36,41),(52,20),(80,18),(105,7)], 15)

    main=[(0,284),(25,261),(50,246),(76,236),(92,220),(111,206),(127,198),
          (142,180),(155,165),(170,146),(187,132),(198,116),(213,100),
          (227,80),(233,62),(246,43),(265,32),(287,21),(319,10)]
    branch=[(87,147),(104,144),(119,148),(129,153),(145,161),(155,165),
            (174,170),(190,176),(210,182),(223,192)]
    side=[(111,206),(98,205),(83,209),(65,217)]
    for path, width in [(main,9),(branch,6),(side,5)]:
        d.line(path, fill="#92946a", width=width, joint="curve")
        d.line(path, fill="#c7b894", width=width-3, joint="curve")
    surface={(137,148,100),(167,173,116),(83,93,67),(66,75,55),(81,89,67)}
    for _ in range(3200):
        x,y=rng.randrange(W),rng.randrange(H)
        pixel=img.getpixel((x,y))
        if pixel in surface:
            tint=rng.choice([-10,-6,7,10])
            d.line([(x,y),(x+rng.randrange(3),y)],fill=tuple(c+tint for c in pixel))
        elif pixel==(199,184,148) and rng.random()<.19:
            d.point((x,y),fill="#d5c69c")

    # The spruce bands use the negative space around the paths and legal plots.
    valid = {1:[1,2,3,6,7,8,9],2:[2,3,6,7,8,9],3:[2,3,4,6,7,8,9],
             5:[1,2,3,4,6,7,9],6:[2,3,4,6,7]}
    pads=[anchor(x,y) for y,xs in valid.items() for x in xs]
    grove = []
    for _ in range(640 if variant == "pinewood" else 450):
        x,y=rng.randrange(W),rng.randrange(8,H+4)
        if any((x-px)**2+(y-py)**2<11**2 for px,py in pads):
            continue
        pixel=img.getpixel((x,min(y,H-1)))
        if pixel in {(66,75,55),(83,93,67),(81,89,67)}:
            grove.append((x,y,rng.uniform(.6,1.28),rng.choice([1,1,2])))
        elif pixel in {(137,148,100),(167,173,116)} and rng.random()<.2:
            grove.append((x,y,rng.uniform(.43,.72),rng.choice([0,2])))
    for x,y,s,shade in sorted(grove,key=lambda item:item[1]):
        oak(d,x,y,s,shade)
    for x,y in [(56,171),(67,156),(134,115),(174,83),(187,90),(246,71),
                (278,134),(252,163),(224,201),(103,233),(79,239),(202,219)]:
        rock(d,x,y,rng.randint(2,5))
    for x,y in [(39,256),(103,224),(132,198),(159,186),(181,149),(209,123),(231,91)]:
        d.line([(x-3,y+2),(x+5,y-1)],fill="#918b69",width=1)
        for dx in (-3,1,5):
            d.line([(x+dx,y+2-dx//3),(x+dx,y-2-dx//3)], fill="#d0c6a4")

    for t in range(4):
        for i in range(8):
            angle=(i/8)*2*pi
            qx,qy=16+round(cos(angle)*(2+t)),239+round(sin(angle)*(1+t))
            d.point((qx,qy),fill="#a6a779")
    if variant == "meadows":
        pool = [(19,230),(25,219),(37,214),(49,218),(54,225),(47,230),(37,231),(28,238)]
        d.polygon(pool, fill="#628075", outline="#98a584")
        for x, y in [(28,226), (36,219), (43,226), (47,222), (26,231)]:
            d.line((x, y, x+4, y), fill="#879f89")
        for x, y in [(22,234), (48,229), (36,217)]:
            rock(d, x, y, 2)
    elif variant == "highlands":
        for x, y, size in [(13,19,5), (38,31,6), (118,17,7), (285,247,7), (305,267,6)]:
            rock(d, x, y, size)

    filename = "terrain.png" if variant == "center" else f"terrain-{variant}.png"
    img.save(OUT/filename,optimize=True)


def tree(d, x, y, palette=0, scale=1):
    oak(d,x,y,scale,palette)


def sprite(name):
    img = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(img)
    if name in ["cottage", "workshop"]:
        workshop = name == "workshop"
        shadow = "#697452"
        roof = "#a45f44" if workshop else "#775244"
        light = "#c47c52" if workshop else "#a16b54"
        red_dark = "#754d39" if workshop else "#773f39"
        d.polygon([(3,25),(8,21),(23,21),(30,25),(26,29),(8,29)], shadow)
        d.rectangle((6,15,24,25), fill="#e1ddc8")
        d.polygon([(23,14),(27,15),(27,24),(23,26)], "#ab9c87")
        d.line((6,25,23,25), fill="#8d775c")
        d.rectangle((19,6,22,13), fill="#74584b")
        d.rectangle((18,5,23,6), fill="#9f7c65")
        d.polygon([(3,16),(12,6),(19,6),(27,14),(27,16)], red_dark)
        d.polygon([(4,14),(12,6),(20,6),(25,13),(26,15),(4,15)], roof)
        for line in [(7,12,21),(9,10,22),(11,8,24),(13,6,25)]:
            y,x1,x2=line
            d.line((x1,y,x2,y),fill=light)
            for x in range(x1+2,x2,4):
                d.point((x,y+1), fill=red_dark)
        d.rectangle((9,18,13,22), fill="#665c51")
        d.rectangle((10,19,12,21), fill="#b3c9ad")
        d.point((11,20), fill="#e5ead0")
        d.rectangle((17,19,21,25), fill="#795547")
        d.rectangle((18,20,20,25), fill="#a77b54")
        d.point((20,23), fill="#e2b975")
        d.line((16,26,22,26), fill="#ccba86")
        if workshop:
            d.rectangle((9,17,14,22), fill="#665c51")
            d.rectangle((10,18,13,21), fill="#dfb66b")
            d.line((8,22,15,22), fill="#ab6950")
        else:
            d.point((5,24), fill="#ead39a")
            d.point((4,23), fill="#efbba0")
            d.point((5,22), fill="#537d49")
    elif name == "orchard":
        tree(d,11,25,1,.68)
        tree(d,22,24,0,.66)
        for x,y in [(7,19),(12,16),(15,20),(18,19),(23,15),(24,20)]:
            d.point((x,y), fill="#eab478")
            d.point((x+1,y), fill="#dc815e")
    elif name == "garden":
        d.rectangle((4,13,27,26), fill="#795b42")
        for x in range(6,26,4):
            d.line((x,14,x,25),fill="#a57955",width=2)
            for y in range(16,25,4):
                d.line((x-1,y,x+1,y),fill="#5b8648")
                d.point((x,y-1),fill="#96b759")
                d.point((x,y+1),fill="#d6b56a")
        d.line((3,12,27,12),fill="#b49a6d")
        for x in (3,9,15,21,27):
            d.line((x,11,x,14),fill="#dfc28c")
    elif name == "well":
        d.ellipse((6,19,25,28), fill="#687b54")
        d.ellipse((9,17,23,26), fill="#a29c82")
        d.ellipse((10,17,22,23), fill="#d5c8a3")
        d.ellipse((12,18,20,22), fill="#487f75")
        d.line((11,11,11,23),fill="#7f6048")
        d.line((21,11,21,22),fill="#7f6048")
        d.polygon([(7,14),(13,7),(20,7),(25,14),(24,16),(7,16)], fill="#8e5644")
        d.line((10,12,23,12), fill="#c68d61")
        d.line((12,10,21,10), fill="#c68d61")
        d.line((16,16,16,21), fill="#c9ad7d")
    img.save(OUT / f"{name}.png", optimize=True)


if __name__ == "__main__":
    for district in ("center", "meadows", "pinewood", "highlands"):
        terrain(district)
    for building in ("cottage", "garden", "orchard", "well", "workshop"):
        sprite(building)
