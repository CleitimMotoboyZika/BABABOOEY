#!/usr/bin/env python3
"""
generate_rbxlx.py - Arena Selvagem .rbxlx Generator
Generates a complete Roblox Studio place file (.rbxlx) from the Lua source files.
Includes all 4 map areas, scripts, RemoteEvents, and 3D geometry.

Usage: python3 generate_rbxlx.py
Output: ArenaSelvagem.rbxlx (ready to open in Roblox Studio)
"""

import os
import sys
from xml.sax.saxutils import escape

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(SCRIPT_DIR, "src")

def read_lua(path):
    """Read a Lua file and return its escaped content."""
    full = os.path.join(SRC_DIR, path)
    with open(full, "r", encoding="utf-8") as f:
        return escape(f.read())

# ─── Reference ID counter ───
_ref_id = [0]
def next_ref():
    _ref_id[0] += 1
    return f"RBX{_ref_id[0]:08X}"

# ─────────────────────────────────────────────
# XML building helpers
# ─────────────────────────────────────────────
def prop_string(name, val):
    return f'<string name="{name}">{escape(str(val))}</string>'

def prop_token(name, val):
    return f'<token name="{name}">{val}</token>'

def prop_bool(name, val):
    return f'<bool name="{name}">{"true" if val else "false"}</bool>'

def prop_int(name, val):
    return f'<int name="{name}">{val}</int>'

def prop_float(name, val):
    return f'<float name="{name}">{val}</float>'

def prop_double(name, val):
    return f'<double name="{name}">{val}</double>'

def prop_vector3(name, x, y, z):
    return f'''<Vector3 name="{name}">
<X>{x}</X><Y>{y}</Y><Z>{z}</Z>
</Vector3>'''

def prop_color3(name, r, g, b):
    return f'''<Color3 name="{name}">
<R>{r}</R><G>{g}</G><B>{b}</B>
</Color3>'''

def prop_color3uint8(name, r, g, b):
    return f'<Color3uint8 name="{name}">{(r << 16) | (g << 8) | b}</Color3uint8>'

def prop_cframe(name, x, y, z, r00=1, r01=0, r02=0, r10=0, r11=1, r12=0, r20=0, r21=0, r22=1):
    return f'''<CoordinateFrame name="{name}">
<X>{x}</X><Y>{y}</Y><Z>{z}</Z>
<R00>{r00}</R00><R01>{r01}</R01><R02>{r02}</R02>
<R10>{r10}</R10><R11>{r11}</R11><R12>{r12}</R12>
<R20>{r20}</R20><R21>{r21}</R21><R22>{r22}</R22>
</CoordinateFrame>'''

def prop_udim2(name, sx, ox, sy, oy):
    return f'''<UDim2 name="{name}">
<XS>{sx}</XS><XO>{ox}</XO><YS>{sy}</YS><YO>{oy}</YO>
</UDim2>'''

def prop_enum(name, val):
    return f'<token name="{name}">{val}</token>'

def prop_brickcolor(name, val):
    return f'<int name="BrickColor">{val}</int>'

# ─────────────────────────────────────────────
# Instance builders
# ─────────────────────────────────────────────

def make_part(name, x, y, z, sx, sy, sz, color_r, color_g, color_b,
              material=256, anchored=True, cancollide=True, transparency=0,
              shape=1, extra_children="", extra_props=""):
    ref = next_ref()
    return f'''<Item class="Part" referent="{ref}">
<Properties>
{prop_string("Name", name)}
{prop_cframe("CFrame", x, y, z)}
{prop_vector3("size", sx, sy, sz)}
{prop_color3("Color3", color_r/255, color_g/255, color_b/255)}
{prop_color3uint8("Color3uint8", color_r, color_g, color_b)}
{prop_token("Material", material)}
{prop_bool("Anchored", anchored)}
{prop_bool("CanCollide", cancollide)}
{prop_float("Transparency", transparency)}
{prop_token("shape", shape)}
{extra_props}
</Properties>
{extra_children}
</Item>'''

def make_spawn_location(name, x, y, z, sx=8, sy=1, sz=8):
    ref = next_ref()
    return f'''<Item class="SpawnLocation" referent="{ref}">
<Properties>
{prop_string("Name", name)}
{prop_cframe("CFrame", x, y, z)}
{prop_vector3("size", sx, sy, sz)}
{prop_color3("Color3", 0.39, 0.58, 0.93)}
{prop_bool("Anchored", True)}
{prop_token("Material", 256)}
{prop_float("Duration", 0)}
</Properties>
</Item>'''

def make_folder(name, children=""):
    ref = next_ref()
    return f'''<Item class="Folder" referent="{ref}">
<Properties>
{prop_string("Name", name)}
</Properties>
{children}
</Item>'''

def make_remote_event(name):
    ref = next_ref()
    return f'''<Item class="RemoteEvent" referent="{ref}">
<Properties>
{prop_string("Name", name)}
</Properties>
</Item>'''

def make_remote_function(name):
    ref = next_ref()
    return f'''<Item class="RemoteFunction" referent="{ref}">
<Properties>
{prop_string("Name", name)}
</Properties>
</Item>'''

def make_script(name, source, class_name="Script", disabled=False, run_context=0):
    ref = next_ref()
    return f'''<Item class="{class_name}" referent="{ref}">
<Properties>
{prop_string("Name", name)}
<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>
{prop_bool("Disabled", disabled)}
{prop_token("RunContext", run_context)}
</Properties>
</Item>'''

def make_module_script(name, source):
    ref = next_ref()
    return f'''<Item class="ModuleScript" referent="{ref}">
<Properties>
{prop_string("Name", name)}
<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>
</Properties>
</Item>'''

def make_point_light(name, x, y, z, brightness=1, color_r=255, color_g=255, color_b=255, range_val=16):
    ref_part = next_ref()
    ref_light = next_ref()
    return f'''<Item class="Part" referent="{ref_part}">
<Properties>
{prop_string("Name", name)}
{prop_cframe("CFrame", x, y, z)}
{prop_vector3("size", 1, 1, 1)}
{prop_float("Transparency", 1)}
{prop_bool("Anchored", True)}
{prop_bool("CanCollide", False)}
</Properties>
<Item class="PointLight" referent="{ref_light}">
<Properties>
{prop_string("Name", "Light")}
{prop_float("Brightness", brightness)}
{prop_color3("Color", color_r/255, color_g/255, color_b/255)}
{prop_float("Range", range_val)}
</Properties>
</Item>
</Item>'''

def make_spot_light(name, x, y, z, brightness=2, color_r=255, color_g=200, color_b=100, range_val=30, angle=120):
    ref_part = next_ref()
    ref_light = next_ref()
    return f'''<Item class="Part" referent="{ref_part}">
<Properties>
{prop_string("Name", name)}
{prop_cframe("CFrame", x, y, z)}
{prop_vector3("size", 1, 1, 1)}
{prop_float("Transparency", 1)}
{prop_bool("Anchored", True)}
{prop_bool("CanCollide", False)}
</Properties>
<Item class="SpotLight" referent="{ref_light}">
<Properties>
{prop_string("Name", "SpotLight")}
{prop_float("Brightness", brightness)}
{prop_color3("Color", color_r/255, color_g/255, color_b/255)}
{prop_float("Range", range_val)}
{prop_float("Angle", angle)}
</Properties>
</Item>
</Item>'''

def make_surface_gui_sign(name, x, y, z, sx, sy, sz, text, text_color_r=255, text_color_g=255, text_color_b=255, bg_r=40, bg_g=40, bg_b=40):
    ref_part = next_ref()
    ref_gui = next_ref()
    ref_frame = next_ref()
    ref_label = next_ref()
    return f'''<Item class="Part" referent="{ref_part}">
<Properties>
{prop_string("Name", name)}
{prop_cframe("CFrame", x, y, z)}
{prop_vector3("size", sx, sy, sz)}
{prop_color3("Color3", bg_r/255, bg_g/255, bg_b/255)}
{prop_bool("Anchored", True)}
{prop_token("Material", 256)}
</Properties>
<Item class="SurfaceGui" referent="{ref_gui}">
<Properties>
{prop_string("Name", "SurfaceGui")}
{prop_token("Face", 5)}
</Properties>
<Item class="TextLabel" referent="{ref_label}">
<Properties>
{prop_string("Name", "Label")}
{prop_udim2("Size", 1, 0, 1, 0)}
{prop_string("Text", text)}
{prop_color3("TextColor3", text_color_r/255, text_color_g/255, text_color_b/255)}
{prop_color3("BackgroundColor3", bg_r/255, bg_g/255, bg_b/255)}
{prop_int("TextSize", 48)}
{prop_token("Font", 8)}
{prop_float("BackgroundTransparency", 0.3)}
</Properties>
</Item>
</Item>
</Item>'''


# ═══════════════════════════════════════════════
# MAP BUILDERS - 4 Areas
# ═══════════════════════════════════════════════

def build_desert_racetrack():
    """Área 1: Pista de corrida de camelos no deserto"""
    parts = []

    # Ground - desert sand
    parts.append(make_part("DesertGround", 0, -1, 0, 500, 2, 300,
                           218, 183, 133, material=880))  # Sand material

    # Race track oval - inner and outer walls
    # Straight sections
    parts.append(make_part("TrackSurface", 0, 0.1, 0, 350, 0.5, 80,
                           194, 160, 110, material=880))

    # Track borders - outer
    parts.append(make_part("OuterFenceLeft", 0, 2, -42, 350, 5, 2,
                           139, 90, 43, material=256))
    parts.append(make_part("OuterFenceRight", 0, 2, 42, 350, 5, 2,
                           139, 90, 43, material=256))
    parts.append(make_part("OuterFenceBack", -176, 2, 0, 2, 5, 86,
                           139, 90, 43, material=256))
    parts.append(make_part("OuterFenceFront", 176, 2, 0, 2, 5, 86,
                           139, 90, 43, material=256))

    # Track borders - inner
    parts.append(make_part("InnerFenceLeft", 0, 2, -18, 280, 4, 1.5,
                           160, 120, 60, material=256))
    parts.append(make_part("InnerFenceRight", 0, 2, 18, 280, 4, 1.5,
                           160, 120, 60, material=256))

    # Starting line
    parts.append(make_part("StartLine", 150, 0.15, 0, 2, 0.3, 80,
                           255, 255, 255, material=256))

    # Finish line
    parts.append(make_part("FinishLine", -150, 0.15, 0, 2, 0.3, 80,
                           200, 0, 0, material=256))

    # Starting gate arch
    parts.append(make_part("StartGateLeft", 150, 6, -35, 4, 12, 4,
                           120, 80, 40, material=256))
    parts.append(make_part("StartGateRight", 150, 6, 35, 4, 12, 4,
                           120, 80, 40, material=256))
    parts.append(make_part("StartGateTop", 150, 12, 0, 4, 2, 74,
                           120, 80, 40, material=256))

    # Sign: "PISTA DO DESERTO"
    parts.append(make_surface_gui_sign("DesertSign", 150, 14, 0, 30, 5, 1,
                                       "🐫 PISTA DO DESERTO 🐫",
                                       255, 215, 0, 80, 50, 20))

    # Spectator stands
    for i in range(5):
        xoff = -120 + i * 60
        parts.append(make_part(f"Stand_{i}", xoff, 2, -55, 50, 4, 15,
                               160, 130, 90, material=256))
        parts.append(make_part(f"StandBack_{i}", xoff, 5, -62, 50, 10, 2,
                               140, 110, 70, material=256))

    # Palm trees (simplified as cylinders + spheres)
    palm_positions = [(-180, 0, -80), (-100, 0, -80), (0, 0, -80), (100, 0, -80), (180, 0, -80),
                      (-180, 0, 80), (-100, 0, 80), (0, 0, 80), (100, 0, 80), (180, 0, 80)]
    for idx, (px, py, pz) in enumerate(palm_positions):
        parts.append(make_part(f"PalmTrunk_{idx}", px, 8, pz, 3, 16, 3,
                               101, 67, 33, material=256, shape=2))  # Cylinder
        parts.append(make_part(f"PalmLeaves_{idx}", px, 17, pz, 12, 4, 12,
                               34, 139, 34, material=256, shape=0))  # Ball

    # Desert dunes (large terrain)
    parts.append(make_part("Dune1", -200, 8, -120, 80, 16, 60,
                           210, 180, 130, material=880, shape=0))
    parts.append(make_part("Dune2", 200, 6, 120, 60, 12, 50,
                           215, 185, 135, material=880, shape=0))
    parts.append(make_part("Dune3", 0, 5, 130, 100, 10, 40,
                           220, 190, 140, material=880, shape=0))

    # Lights
    parts.append(make_spot_light("TrackLight1", -100, 25, 0, 3, 255, 230, 180, 50))
    parts.append(make_spot_light("TrackLight2", 0, 25, 0, 3, 255, 230, 180, 50))
    parts.append(make_spot_light("TrackLight3", 100, 25, 0, 3, 255, 230, 180, 50))

    # Lane markers for 6 racers
    for lane in range(6):
        z_pos = -25 + lane * 10
        parts.append(make_part(f"LaneMarker_{lane}", 150, 0.2, z_pos, 0.5, 0.2, 60,
                               255, 255, 255, material=256, transparency=0.5))

    # Spawn point for this area
    parts.append(make_spawn_location("DesertSpawn", 160, 1, -50))

    return make_folder("PistaDoDeserto", "\n".join(parts))


def build_aquarium_room():
    """Área 2: Sala de aquários com mesa de corrida de lagostins"""
    parts = []
    ox, oz = 500, 0  # Offset from origin

    # Room floor
    parts.append(make_part("AquariumFloor", ox, -1, oz, 150, 2, 150,
                           20, 40, 60, material=256))

    # Room walls
    parts.append(make_part("WallNorth", ox, 12, oz - 76, 150, 26, 2,
                           15, 35, 55, material=256))
    parts.append(make_part("WallSouth", ox, 12, oz + 76, 150, 26, 2,
                           15, 35, 55, material=256))
    parts.append(make_part("WallEast", ox + 76, 12, oz, 2, 26, 150,
                           15, 35, 55, material=256))
    parts.append(make_part("WallWest", ox - 76, 12, oz, 2, 26, 150,
                           15, 35, 55, material=256))

    # Ceiling
    parts.append(make_part("AquariumCeiling", ox, 25, oz, 150, 1, 150,
                           10, 25, 45, material=256))

    # Large aquarium tanks on walls (glass = transparent neon)
    tank_positions = [
        (ox - 74, 10, oz - 40, 3, 16, 30),
        (ox - 74, 10, oz + 20, 3, 16, 30),
        (ox + 74, 10, oz - 40, 3, 16, 30),
        (ox + 74, 10, oz + 20, 3, 16, 30),
        (ox - 30, 10, oz - 74, 30, 16, 3),
        (ox + 30, 10, oz - 74, 30, 16, 3),
    ]
    for idx, (tx, ty, tz, tsx, tsy, tsz) in enumerate(tank_positions):
        parts.append(make_part(f"AquariumTank_{idx}", tx, ty, tz, tsx, tsy, tsz,
                               30, 120, 200, material=288, transparency=0.6))  # Glass
        # Water inside
        parts.append(make_part(f"TankWater_{idx}", tx, ty - 1, tz,
                               tsx - 1, tsy - 3, tsz - 1,
                               20, 80, 160, material=256, transparency=0.4,
                               cancollide=False))

    # Central lobster racing table
    parts.append(make_part("RacingTable", ox, 4, oz, 60, 1, 30,
                           60, 40, 30, material=256))  # Wooden table

    # Table legs
    for lx, lz in [(-28, -13), (28, -13), (-28, 13), (28, 13)]:
        parts.append(make_part(f"TableLeg_{lx}_{lz}", ox + lx, 2, oz + lz, 3, 4, 3,
                               50, 35, 25, material=256))

    # Racing lanes on table (water channels)
    for lane in range(6):
        z_off = -12 + lane * 5
        parts.append(make_part(f"WaterLane_{lane}", ox, 4.6, oz + z_off, 55, 0.3, 3,
                               30, 100, 180, material=256, transparency=0.3))
        # Lane dividers
        parts.append(make_part(f"LaneDivider_{lane}", ox, 4.8, oz + z_off + 2.5, 55, 0.5, 0.3,
                               80, 80, 80, material=256))

    # Start/finish markers on table
    parts.append(make_part("TableStartLine", ox + 26, 4.8, oz, 0.5, 0.3, 30,
                           0, 255, 0, material=288))
    parts.append(make_part("TableFinishLine", ox - 26, 4.8, oz, 0.5, 0.3, 30,
                           255, 0, 0, material=288))

    # Sign
    parts.append(make_surface_gui_sign("AquariumSign", ox, 22, oz - 74, 40, 6, 1,
                                       "🦞 CORRIDA DE LAGOSTINS 🦞",
                                       100, 200, 255, 10, 30, 50))

    # Bubble decorations (spheres)
    import random
    random.seed(42)
    for i in range(20):
        bx = ox + random.randint(-60, 60)
        by = random.randint(5, 22)
        bz = oz + random.randint(-60, 60)
        bs = random.uniform(0.5, 2)
        parts.append(make_part(f"Bubble_{i}", bx, by, bz, bs, bs, bs,
                               100, 180, 255, material=288, transparency=0.7,
                               cancollide=False, shape=0))

    # Viewing chairs around table
    for i in range(8):
        import math
        angle = i * (2 * math.pi / 8)
        cx = ox + math.cos(angle) * 22
        cz = oz + math.sin(angle) * 22
        parts.append(make_part(f"Chair_{i}", cx, 2.5, cz, 3, 5, 3,
                               70, 50, 35, material=256))

    # Blue ambient lighting
    parts.append(make_point_light("AquaLight1", ox - 30, 20, oz - 30, 1.5, 50, 100, 255, 25))
    parts.append(make_point_light("AquaLight2", ox + 30, 20, oz - 30, 1.5, 50, 100, 255, 25))
    parts.append(make_point_light("AquaLight3", ox - 30, 20, oz + 30, 1.5, 50, 100, 255, 25))
    parts.append(make_point_light("AquaLight4", ox + 30, 20, oz + 30, 1.5, 50, 100, 255, 25))

    # Spawn
    parts.append(make_spawn_location("AquariumSpawn", ox + 60, 1, oz + 60))

    return make_folder("SalaDosAquarios", "\n".join(parts))


def build_monkey_ring():
    """Área 3: Ringue improvisado para rinha de macacos"""
    parts = []
    ox, oz = -300, 0

    # Ground - concrete floor
    parts.append(make_part("RingFloor", ox, -1, oz, 120, 2, 120,
                           100, 100, 100, material=256))

    # Elevated ring platform
    parts.append(make_part("RingPlatform", ox, 1, oz, 40, 2, 40,
                           180, 160, 140, material=256))

    # Ring mat
    parts.append(make_part("RingMat", ox, 2.1, oz, 36, 0.3, 36,
                           200, 50, 50, material=256))

    # Ring corner posts
    corners = [(-18, 0, -18), (18, 0, -18), (-18, 0, 18), (18, 0, 18)]
    for idx, (cx, cy, cz) in enumerate(corners):
        parts.append(make_part(f"RingPost_{idx}", ox + cx, 5, oz + cz, 2, 8, 2,
                               180, 180, 180, material=256, shape=2))
        # Colored top
        color = [(255, 0, 0), (0, 0, 255), (255, 0, 0), (0, 0, 255)][idx]
        parts.append(make_part(f"PostTop_{idx}", ox + cx, 9.5, oz + cz, 3, 1, 3,
                               *color, material=256))

    # Ring ropes (3 levels)
    rope_y = [4, 6, 8]
    for ry_idx, ry in enumerate(rope_y):
        # 4 sides of the ring
        parts.append(make_part(f"RopeN_{ry_idx}", ox, ry, oz - 18, 36, 0.5, 0.5,
                               255, 255, 200, material=256, shape=2))
        parts.append(make_part(f"RopeS_{ry_idx}", ox, ry, oz + 18, 36, 0.5, 0.5,
                               255, 255, 200, material=256, shape=2))
        parts.append(make_part(f"RopeE_{ry_idx}", ox + 18, ry, oz, 0.5, 0.5, 36,
                               255, 255, 200, material=256, shape=2))
        parts.append(make_part(f"RopeW_{ry_idx}", ox - 18, ry, oz, 0.5, 0.5, 36,
                               255, 255, 200, material=256, shape=2))

    # Spectator bleachers (tiered seating)
    for side in range(4):
        import math
        angle = side * (math.pi / 2)
        for tier in range(3):
            dist = 35 + tier * 8
            height = 2 + tier * 3
            sx_val = 40 if side % 2 == 0 else 8
            sz_val = 8 if side % 2 == 0 else 40
            bx = ox + math.cos(angle) * dist
            bz = oz + math.sin(angle) * dist
            parts.append(make_part(f"Bleacher_{side}_{tier}", bx, height, bz,
                                   sx_val, 1.5, sz_val,
                                   120, 120, 130, material=256))

    # Overhead lights (harsh industrial)
    parts.append(make_spot_light("RingLight1", ox - 10, 20, oz - 10, 4, 255, 255, 220, 30, 90))
    parts.append(make_spot_light("RingLight2", ox + 10, 20, oz - 10, 4, 255, 255, 220, 30, 90))
    parts.append(make_spot_light("RingLight3", ox - 10, 20, oz + 10, 4, 255, 255, 220, 30, 90))
    parts.append(make_spot_light("RingLight4", ox + 10, 20, oz + 10, 4, 255, 255, 220, 30, 90))

    # Sign
    parts.append(make_surface_gui_sign("RingSign", ox, 15, oz - 22, 25, 5, 1,
                                       "🐵 RINGUE DOS PRIMATAS 🐵",
                                       255, 100, 100, 50, 20, 20))

    # Improvised elements (barrels, crates)
    barrel_pos = [(-40, 3, -30), (-45, 3, 30), (40, 3, -35), (42, 3, 28)]
    for idx, (bx, by, bz) in enumerate(barrel_pos):
        parts.append(make_part(f"Barrel_{idx}", ox + bx, by, oz + bz, 5, 6, 5,
                               139, 90, 43, material=256, shape=2))

    crate_pos = [(-35, 2, -20), (38, 2, 20), (-30, 2, 35)]
    for idx, (cx, cy, cz) in enumerate(crate_pos):
        parts.append(make_part(f"Crate_{idx}", ox + cx, cy, oz + cz, 6, 6, 6,
                               160, 130, 80, material=256))

    # Scoreboard
    parts.append(make_surface_gui_sign("Scoreboard", ox + 22, 12, oz, 1, 8, 12,
                                       "PLACAR\n---\nLutador 1\nvs\nLutador 2",
                                       255, 255, 255, 20, 20, 30))

    # Spawn
    parts.append(make_spawn_location("RingSpawn", ox - 50, 1, oz - 40))

    return make_folder("RinguePrimatas", "\n".join(parts))


def build_betting_room():
    """Área 4: Sala vintage de apostas estilo corrida de cavalos"""
    parts = []
    ox, oz = 0, -300

    # Floor - vintage dark wood
    parts.append(make_part("BettingFloor", ox, -1, oz, 200, 2, 200,
                           80, 50, 30, material=256))

    # Walls - vintage wallpaper feel
    parts.append(make_part("BWallN", ox, 10, oz - 101, 200, 22, 2,
                           70, 45, 30, material=256))
    parts.append(make_part("BWallS", ox, 10, oz + 101, 200, 22, 2,
                           70, 45, 30, material=256))
    parts.append(make_part("BWallE", ox + 101, 10, oz, 2, 22, 200,
                           70, 45, 30, material=256))
    parts.append(make_part("BWallW", ox - 101, 10, oz, 2, 22, 200,
                           70, 45, 30, material=256))

    # Ceiling - ornate
    parts.append(make_part("BettingCeiling", ox, 21, oz, 200, 1, 200,
                           60, 40, 25, material=256))

    # Wainscoting (lower wall trim) - darker wood panels
    for wall_data in [
        (ox, 3, oz - 99, 198, 6, 1),
        (ox, 3, oz + 99, 198, 6, 1),
        (ox + 99, 3, oz, 1, 6, 198),
        (ox - 99, 3, oz, 1, 6, 198),
    ]:
        parts.append(make_part("Wainscot", *wall_data,
                               50, 30, 18, material=256))

    # Crown molding
    for wall_data in [
        (ox, 19, oz - 100, 200, 2, 1),
        (ox, 19, oz + 100, 200, 2, 1),
        (ox + 100, 19, oz, 1, 2, 200),
        (ox - 100, 19, oz, 1, 2, 200),
    ]:
        parts.append(make_part("CrownMold", *wall_data,
                               100, 70, 40, material=256))

    # Vintage betting counter (long mahogany bar)
    parts.append(make_part("BettingCounter", ox, 4, oz + 60, 80, 4, 6,
                           90, 50, 25, material=256))
    parts.append(make_part("CounterTop", ox, 6.1, oz + 60, 82, 0.5, 7,
                           120, 80, 40, material=256))

    # Cashier windows on counter
    for i in range(4):
        cw_x = ox - 30 + i * 20
        parts.append(make_part(f"CashierWindow_{i}", cw_x, 8, oz + 60, 8, 5, 1,
                               180, 160, 120, material=256))
        parts.append(make_surface_gui_sign(f"CashierSign_{i}", cw_x, 11, oz + 59, 6, 2, 0.5,
                                           f"GUICHÊ {i+1}",
                                           255, 215, 0, 60, 30, 15))

    # Large race display boards on north wall
    for i in range(3):
        bx = ox - 50 + i * 50
        parts.append(make_part(f"DisplayBoard_{i}", bx, 12, oz - 98, 35, 10, 1,
                               20, 30, 20, material=256))
        labels = [
            "🐫 CORRIDA DE CAMELOS\n━━━━━━━━━━━━━\nPróxima corrida em breve...",
            "🐵 RINHA DE MACACOS\n━━━━━━━━━━━━━\nPróxima luta em breve...",
            "🦞 CORRIDA DE LAGOSTINS\n━━━━━━━━━━━━━\nPróxima corrida em breve..."
        ]
        parts.append(make_surface_gui_sign(f"BoardDisplay_{i}", bx, 12, oz - 97, 33, 8, 0.5,
                                           labels[i],
                                           100, 255, 100, 10, 20, 10))

    # Odds board
    parts.append(make_surface_gui_sign("OddsBoard", ox + 90, 12, oz, 0.5, 10, 25,
                                       "📊 TABELA DE ODDS 📊\n━━━━━━━━━━━━\nCamelo 1.8x\nMacaco 2.5x\nLagostim 2.0x\n━━━━━━━━━━━━\nAposta Mín: 10\nAposta Máx: 10,000",
                                       255, 215, 0, 30, 20, 10))

    # Vintage seating - rows of chairs
    for row in range(4):
        for col in range(8):
            cx = ox - 56 + col * 16
            cz = oz - 20 + row * 20
            # Chair seat
            parts.append(make_part(f"ChairSeat_{row}_{col}", cx, 2, cz, 4, 0.5, 4,
                                   120, 30, 30, material=256))
            # Chair back
            parts.append(make_part(f"ChairBack_{row}_{col}", cx, 4, cz - 2, 4, 4, 0.5,
                                   120, 30, 30, material=256))
            # Chair legs
            for lx, lz in [(-1.5, -1.5), (1.5, -1.5), (-1.5, 1.5), (1.5, 1.5)]:
                parts.append(make_part(f"ChairLeg_{row}_{col}_{lx}_{lz}",
                                       cx + lx, 1, cz + lz, 0.5, 2, 0.5,
                                       80, 60, 30, material=256))

    # Vintage chandeliers
    chandelier_pos = [(ox - 40, 18, oz - 40), (ox + 40, 18, oz - 40),
                      (ox - 40, 18, oz + 20), (ox + 40, 18, oz + 20)]
    for idx, (chx, chy, chz) in enumerate(chandelier_pos):
        # Chain
        parts.append(make_part(f"Chain_{idx}", chx, 19.5, chz, 0.3, 3, 0.3,
                               180, 150, 80, material=256))
        # Body
        parts.append(make_part(f"ChandBody_{idx}", chx, chy, chz, 8, 2, 8,
                               180, 150, 80, material=256, shape=2))
        # Warm light
        parts.append(make_point_light(f"ChandLight_{idx}", chx, chy - 1, chz,
                                      2, 255, 200, 100, 30))

    # Vintage decorations - framed pictures on walls
    pic_positions = [
        (ox - 70, 12, oz + 99, 10, 8, 0.5),
        (ox - 30, 12, oz + 99, 10, 8, 0.5),
        (ox + 30, 12, oz + 99, 10, 8, 0.5),
        (ox + 70, 12, oz + 99, 10, 8, 0.5),
    ]
    pic_labels = ["🐎 CAMPEÃO 1952", "🏆 DERBY CLÁSSICO", "🐎 CORRIDA REAL", "🎖 HALL DA FAMA"]
    for idx, ((px, py, pz, psx, psy, psz), label) in enumerate(zip(pic_positions, pic_labels)):
        # Frame
        parts.append(make_part(f"PicFrame_{idx}", px, py, pz, psx + 2, psy + 2, psz + 0.5,
                               100, 70, 35, material=256))
        parts.append(make_surface_gui_sign(f"PicLabel_{idx}", px, py, pz + 0.4, psx, psy, 0.3,
                                           label, 200, 180, 140, 40, 30, 20))

    # Potted plants in corners
    plant_pos = [(ox - 90, 0, oz - 90), (ox + 90, 0, oz - 90),
                 (ox - 90, 0, oz + 90), (ox + 90, 0, oz + 90)]
    for idx, (ppx, ppy, ppz) in enumerate(plant_pos):
        # Pot
        parts.append(make_part(f"Pot_{idx}", ppx, 2, ppz, 5, 4, 5,
                               120, 80, 50, material=256, shape=2))
        # Plant
        parts.append(make_part(f"Plant_{idx}", ppx, 6, ppz, 6, 6, 6,
                               30, 120, 30, material=256, shape=0))

    # Carpet
    parts.append(make_part("VintageCarpet", ox, 0.05, oz - 10, 120, 0.1, 80,
                           120, 20, 30, material=256))
    # Carpet border
    parts.append(make_part("CarpetBorder", ox, 0.06, oz - 10, 124, 0.08, 84,
                           160, 130, 50, material=256, transparency=0.5))

    # Sign above entrance
    parts.append(make_surface_gui_sign("BettingSign", ox, 18, oz + 99, 50, 5, 1,
                                       "🎰 SALA DE APOSTAS VINTAGE 🎰",
                                       255, 215, 0, 60, 30, 15))

    # Vintage clock on wall
    parts.append(make_part("Clock", ox, 16, oz - 98, 6, 6, 1,
                           40, 30, 20, material=256, shape=2))
    parts.append(make_surface_gui_sign("ClockFace", ox, 16, oz - 97.5, 5, 5, 0.3,
                                       "🕐", 255, 255, 255, 50, 40, 30))

    # Spawn
    parts.append(make_spawn_location("BettingSpawn", ox, 1, oz + 80))

    return make_folder("SalaDeApostas", "\n".join(parts))


def build_connectors():
    """Caminhos que conectam as 4 áreas"""
    parts = []

    # Path: Betting Room (0,-300) -> Desert Track (0,0)
    parts.append(make_part("PathBetting2Desert", 0, -0.5, -150, 15, 1, 300,
                           150, 140, 120, material=256))

    # Path: Desert Track (0,0) -> Aquarium (500,0)
    parts.append(make_part("PathDesert2Aquarium", 250, -0.5, 0, 500, 1, 15,
                           150, 140, 120, material=256))

    # Path: Desert Track (0,0) -> Monkey Ring (-300,0)
    parts.append(make_part("PathDesert2Ring", -150, -0.5, 0, 300, 1, 15,
                           150, 140, 120, material=256))

    # Path signs
    signs = [
        (30, 5, -80, "→ Pista do Deserto"),
        (-30, 5, -80, "← Ringue dos Primatas"),
        (250, 5, -10, "→ Sala dos Aquários"),
        (0, 5, -230, "↓ Sala de Apostas"),
    ]
    for idx, (sx, sy, sz, text) in enumerate(signs):
        parts.append(make_surface_gui_sign(f"PathSign_{idx}", sx, sy, sz, 15, 3, 0.5,
                                           text, 255, 255, 255, 60, 60, 60))

    # Path lighting
    for i in range(10):
        parts.append(make_point_light(f"PathLight_{i}", -150 + i * 80, 8, -150, 0.8, 255, 220, 180, 20))

    return make_folder("Conectores", "\n".join(parts))


def build_remote_events():
    """Create all RemoteEvents and RemoteFunctions needed by the game"""
    children = []

    # Events folder
    event_children = []

    # Fight Events
    fight_events = ["FightAnnounced", "FightStarted", "FightTurnUpdate", "FightEnded",
                    "FightBetConfirmed", "FightBetResults", "FightPlaceBet"]
    fight_folder = make_folder("FightEvents",
        "\n".join(make_remote_event(e) for e in fight_events))
    event_children.append(fight_folder)

    # Race Events
    race_events = ["RaceAnnounced", "RaceStarted", "RaceTick", "RaceEnded",
                   "RaceBettingOpen", "RaceBettingClosed", "RacePlaceBet", "RaceBetResults"]
    race_folder = make_folder("RaceEvents",
        "\n".join(make_remote_event(e) for e in race_events))
    event_children.append(race_folder)

    # Evolution Events
    evo_events = ["TrainRequest", "TrainResult", "FeedRequest", "FeedResult",
                  "EvolveRequest", "Evolution", "StatsRequest", "StatsResponse", "LevelUp"]
    evo_folder = make_folder("EvolutionEvents",
        "\n".join(make_remote_event(e) for e in evo_events))
    event_children.append(evo_folder)

    # Inventory Events
    inv_events = ["BuyItem", "SellItem", "EquipItem", "UnequipItem", "UseItem",
                  "InventoryUpdated", "EquipUpdated", "ShopError"]
    inv_folder = make_folder("InventoryEvents",
        "\n".join(make_remote_event(e) for e in inv_events))
    event_children.append(inv_folder)

    # Inventory Functions
    inv_funcs = ["GetInventory", "GetEquippedItems", "GetShopItems"]
    inv_func_folder = make_folder("InventoryFunctions",
        "\n".join(make_remote_function(f) for f in inv_funcs))
    event_children.append(inv_func_folder)

    # Trade Events
    trade_events = ["TradeRequest", "TradeAccepted", "TradeDeclined",
                    "TradeAddItem", "TradeRemoveItem", "TradeSetCoins",
                    "TradeConfirmUpdate", "TradeCompleted", "TradeCancelled", "TradeError"]
    trade_folder = make_folder("TradeEvents",
        "\n".join(make_remote_event(e) for e in trade_events))
    event_children.append(trade_folder)

    # General Events
    general_events = ["UpdateCoins", "PlaceBet", "Notification"]
    for e in general_events:
        event_children.append(make_remote_event(e))

    events_folder = make_folder("Events", "\n".join(event_children))
    children.append(events_folder)

    # Modules folder (for shared modules)
    children.append(make_folder("Modules"))

    # Assets folder
    children.append(make_folder("Assets"))

    return "\n".join(children)


def build_lighting():
    """Configure Lighting service"""
    ref = next_ref()
    return f'''<Item class="Lighting" referent="{ref}">
<Properties>
{prop_string("Name", "Lighting")}
{prop_float("Brightness", 1)}
{prop_float("ClockTime", 14)}
{prop_float("GeographicLatitude", 0)}
{prop_color3("Ambient", 0.3, 0.3, 0.35)}
{prop_color3("OutdoorAmbient", 0.4, 0.38, 0.35)}
{prop_color3("ColorShift_Bottom", 0, 0, 0)}
{prop_color3("ColorShift_Top", 0, 0, 0)}
{prop_float("EnvironmentDiffuseScale", 1)}
{prop_float("EnvironmentSpecularScale", 1)}
{prop_float("ExposureCompensation", 0)}
{prop_float("FogEnd", 10000)}
{prop_float("FogStart", 0)}
{prop_color3("FogColor", 0.75, 0.75, 0.75)}
{prop_string("Technology", "ShadowMap")}
</Properties>
<Item class="Atmosphere" referent="{next_ref()}">
<Properties>
{prop_string("Name", "Atmosphere")}
{prop_float("Density", 0.3)}
{prop_float("Offset", 0.25)}
{prop_color3("Color", 0.9, 0.85, 0.7)}
{prop_color3("Decay", 0.9, 0.85, 0.7)}
{prop_float("Glare", 0)}
{prop_float("Haze", 1)}
</Properties>
</Item>
<Item class="Sky" referent="{next_ref()}">
<Properties>
{prop_string("Name", "Sky")}
{prop_bool("CelestialBodiesShown", True)}
{prop_float("StarCount", 3000)}
{prop_float("SunAngularSize", 21)}
{prop_float("MoonAngularSize", 11)}
</Properties>
</Item>
</Item>'''


def build_starter_gui():
    """StarterGui configuration"""
    ref = next_ref()
    return f'''<Item class="StarterGui" referent="{ref}">
<Properties>
{prop_string("Name", "StarterGui")}
{prop_bool("ResetPlayerGuiOnSpawn", False)}
{prop_token("ScreenOrientation", 0)}
</Properties>
</Item>'''


def build_starter_player():
    """StarterPlayer configuration"""
    ref = next_ref()
    return f'''<Item class="StarterPlayer" referent="{ref}">
<Properties>
{prop_string("Name", "StarterPlayer")}
</Properties>
<Item class="StarterPlayerScripts" referent="{next_ref()}">
<Properties>
{prop_string("Name", "StarterPlayerScripts")}
</Properties>
{make_script("ClientMain", read_lua_raw("Client/ClientMain.lua"), "LocalScript")}
</Item>
<Item class="StarterCharacterScripts" referent="{next_ref()}">
<Properties>
{prop_string("Name", "StarterCharacterScripts")}
</Properties>
</Item>
</Item>'''


def read_lua_raw(path):
    """Read raw Lua content (unescaped for CDATA)"""
    full = os.path.join(SRC_DIR, path)
    with open(full, "r", encoding="utf-8") as f:
        content = f.read()
    # Escape CDATA end sequence if present
    return content.replace("]]>", "]]]]><![CDATA[>")


def build_server_script_service():
    """ServerScriptService with all server scripts"""
    ref = next_ref()

    # Read all server scripts
    main_server = read_lua_raw("Server/MainServer.lua")
    data_store = read_lua_raw("Server/DataStoreManager.lua")
    fight_system = read_lua_raw("Server/FightSystem.lua")
    race_system = read_lua_raw("Server/RaceSystem.lua")
    trade_system = read_lua_raw("Server/TradeSystem.lua")
    evolution_system = read_lua_raw("Server/EvolutionSystem.lua")
    inventory_system = read_lua_raw("Server/InventorySystem.lua")

    return f'''<Item class="ServerScriptService" referent="{ref}">
<Properties>
{prop_string("Name", "ServerScriptService")}
</Properties>
{make_script("MainServer", main_server)}
{make_module_script("DataStoreManager", data_store)}
{make_module_script("FightSystem", fight_system)}
{make_module_script("RaceSystem", race_system)}
{make_module_script("TradeSystem", trade_system)}
{make_module_script("EvolutionSystem", evolution_system)}
{make_module_script("InventorySystem", inventory_system)}
</Item>'''


def build_replicated_storage():
    """ReplicatedStorage with shared modules and remote events"""
    ref = next_ref()
    game_config = read_lua_raw("Shared/GameConfig.lua")

    return f'''<Item class="ReplicatedStorage" referent="{ref}">
<Properties>
{prop_string("Name", "ReplicatedStorage")}
</Properties>
{make_module_script("GameConfig", game_config)}
{build_remote_events()}
</Item>'''


def build_workspace():
    """Workspace with all map geometry"""
    ref = next_ref()

    # Build all 4 areas + connectors
    desert = build_desert_racetrack()
    aquarium = build_aquarium_room()
    ring = build_monkey_ring()
    betting = build_betting_room()
    connectors = build_connectors()

    # Main spawn
    main_spawn = make_spawn_location("MainSpawn", 0, 1, -100)

    # Baseplate
    baseplate = make_part("Baseplate", 0, -10, -100, 1200, 1, 1200,
                          91, 154, 76, material=880, transparency=0)

    return f'''<Item class="Workspace" referent="{ref}">
<Properties>
{prop_string("Name", "Workspace")}
</Properties>
<Item class="Camera" referent="{next_ref()}">
<Properties>
{prop_string("Name", "Camera")}
{prop_cframe("CFrame", 0, 30, -100)}
</Properties>
</Item>
{baseplate}
{main_spawn}
{desert}
{aquarium}
{ring}
{betting}
{connectors}
<Item class="Terrain" referent="{next_ref()}">
<Properties>
{prop_string("Name", "Terrain")}
</Properties>
</Item>
</Item>'''


def generate_rbxlx():
    """Generate the complete .rbxlx file"""

    workspace = build_workspace()
    lighting = build_lighting()
    server_scripts = build_server_script_service()
    replicated_storage = build_replicated_storage()
    starter_gui = build_starter_gui()
    starter_player = build_starter_player()

    # Additional services
    ref_players = next_ref()
    ref_server_storage = next_ref()
    ref_replicated_first = next_ref()
    ref_sound_service = next_ref()
    ref_chat = next_ref()
    ref_teams = next_ref()

    other_services = f'''
<Item class="Players" referent="{ref_players}">
<Properties>
{prop_string("Name", "Players")}
</Properties>
</Item>
<Item class="ServerStorage" referent="{ref_server_storage}">
<Properties>
{prop_string("Name", "ServerStorage")}
</Properties>
</Item>
<Item class="ReplicatedFirst" referent="{ref_replicated_first}">
<Properties>
{prop_string("Name", "ReplicatedFirst")}
</Properties>
</Item>
<Item class="SoundService" referent="{ref_sound_service}">
<Properties>
{prop_string("Name", "SoundService")}
</Properties>
</Item>
<Item class="Chat" referent="{ref_chat}">
<Properties>
{prop_string("Name", "Chat")}
</Properties>
</Item>
<Item class="Teams" referent="{ref_teams}">
<Properties>
{prop_string("Name", "Teams")}
</Properties>
</Item>'''

    rbxlx = f'''<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
<External>null</External>
<External>nil</External>
{workspace}
{lighting}
{server_scripts}
{replicated_storage}
{starter_gui}
{starter_player}
{other_services}
</roblox>'''

    return rbxlx


def main():
    print("=" * 50)
    print("  Arena Selvagem - .rbxlx Generator")
    print("=" * 50)

    output_path = os.path.join(SCRIPT_DIR, "ArenaSelvagem.rbxlx")

    print("\n[1/6] Loading Lua source files...")
    print(f"  Source directory: {SRC_DIR}")

    # Verify all source files exist
    required_files = [
        "Server/MainServer.lua",
        "Server/DataStoreManager.lua",
        "Server/FightSystem.lua",
        "Server/RaceSystem.lua",
        "Server/TradeSystem.lua",
        "Server/EvolutionSystem.lua",
        "Server/InventorySystem.lua",
        "Client/ClientMain.lua",
        "Shared/GameConfig.lua",
    ]
    for f in required_files:
        full = os.path.join(SRC_DIR, f)
        if not os.path.exists(full):
            print(f"  ERROR: Missing file: {f}")
            sys.exit(1)
        size = os.path.getsize(full)
        print(f"  ✓ {f} ({size} bytes)")

    print("\n[2/6] Building Workspace (4 map areas + connectors)...")
    print("  ✓ Pista do Deserto (Camel Race Track)")
    print("  ✓ Sala dos Aquários (Lobster Racing Room)")
    print("  ✓ Ringue dos Primatas (Monkey Fight Ring)")
    print("  ✓ Sala de Apostas Vintage (Betting Room)")
    print("  ✓ Conectores (Pathways)")

    print("\n[3/6] Building ServerScriptService...")
    print("  ✓ MainServer.lua (entry point + AutoFix)")
    print("  ✓ DataStoreManager.lua (persistence)")
    print("  ✓ FightSystem.lua (AI combat)")
    print("  ✓ RaceSystem.lua (AI racing)")
    print("  ✓ TradeSystem.lua (P2P trading)")
    print("  ✓ EvolutionSystem.lua (leveling & evolution)")
    print("  ✓ InventorySystem.lua (items & equipment)")

    print("\n[4/6] Building ReplicatedStorage...")
    print("  ✓ GameConfig.lua (shared configuration)")
    print("  ✓ RemoteEvents (40+ events)")
    print("  ✓ RemoteFunctions (3 functions)")

    print("\n[5/6] Building StarterPlayer...")
    print("  ✓ ClientMain.lua (UI & spectator)")

    print("\n[6/6] Generating .rbxlx file...")
    rbxlx_content = generate_rbxlx()

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(rbxlx_content)

    file_size = os.path.getsize(output_path)
    print(f"\n  ✓ Written: {output_path}")
    print(f"  ✓ File size: {file_size:,} bytes ({file_size/1024:.1f} KB)")

    print("\n" + "=" * 50)
    print("  BUILD COMPLETE!")
    print("=" * 50)
    print(f"\n  Output: {output_path}")
    print("  Open this file directly in Roblox Studio.")
    print("  No additional setup required!")
    print("\n  Game Features:")
    print("  • 🐫 AI-controlled Camel Racing (Desert Track)")
    print("  • 🦞 AI-controlled Lobster Racing (Aquarium)")
    print("  • 🐵 AI-controlled Monkey Fighting (Ring)")
    print("  • 🎰 Vintage Betting Room")
    print("  • 📦 Inventory & Equipment System")
    print("  • 🔄 P2P Trading System")
    print("  • 📈 Incremental Evolution (100 levels)")
    print("  • 💾 DataStore Persistence")
    print("  • 🛡️ Server-side Anti-exploit")
    print("  • 🔧 AutoFix Bug Recovery")
    print()

if __name__ == "__main__":
    main()
