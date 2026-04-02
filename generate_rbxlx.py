#!/usr/bin/env python3
"""
Arena Bestial - RBXLX Generator
Generates a complete Roblox Studio project file (.rbxlx) with all game systems,
map geometry, UI, scripts, and configuration embedded.
"""

import os
import sys
from xml.sax.saxutils import escape

# =============================================================
# RBXLX HELPERS
# =============================================================
ref_counter = [0]

def next_ref():
    ref_counter[0] += 1
    return f"RBX{ref_counter[0]:08X}"

def xml_escape(text):
    """Escape text for XML, handling special characters."""
    return escape(str(text)).replace('\t', '&#9;').replace('\n', '&#10;')

def prop_string(name, value):
    return f'      <string name="{name}">{xml_escape(value)}</string>\n'

def prop_bool(name, value):
    return f'      <bool name="{name}">{"true" if value else "false"}</bool>\n'

def prop_int(name, value):
    return f'      <int name="{name}">{value}</int>\n'

def prop_float(name, value):
    return f'      <float name="{name}">{value}</float>\n'

def prop_double(name, value):
    return f'      <double name="{name}">{value}</double>\n'

def prop_token(name, value):
    return f'      <token name="{name}">{value}</token>\n'

def prop_vector3(name, x, y, z):
    return f'      <Vector3 name="{name}"><X>{x}</X><Y>{y}</Y><Z>{z}</Z></Vector3>\n'

def prop_color3uint8(name, r, g, b):
    val = (r << 16) | (g << 8) | b
    return f'      <Color3uint8 name="{name}">{val}</Color3uint8>\n'

def prop_color3(name, r, g, b):
    return f'      <Color3 name="{name}"><R>{r/255.0}</R><G>{g/255.0}</G><B>{b/255.0}</B></Color3>\n'

def prop_cframe(name, x, y, z):
    return (f'      <CoordinateFrame name="{name}">'
            f'<X>{x}</X><Y>{y}</Y><Z>{z}</Z>'
            f'<R00>1</R00><R01>0</R01><R02>0</R02>'
            f'<R10>0</R10><R11>1</R11><R12>0</R12>'
            f'<R20>0</R20><R21>0</R21><R22>1</R22>'
            f'</CoordinateFrame>\n')

def prop_protected_string(name, value):
    escaped = xml_escape(value)
    return f'      <ProtectedString name="{name}">{escaped}</ProtectedString>\n'

def prop_udim2(name, xs, xo, ys, yo):
    return (f'      <UDim2 name="{name}">'
            f'<XS>{xs}</XS><XO>{xo}</XO><YS>{ys}</YS><YO>{yo}</YO>'
            f'</UDim2>\n')

# Material enum values
MATERIALS = {
    "SmoothPlastic": 256,
    "Sand": 1344,
    "Wood": 512,
    "WoodPlanks": 528,
    "Glass": 1568,
    "Metal": 1040,
    "Concrete": 816,
    "Marble": 784,
    "Fabric": 1312,
    "Neon": 288,
    "Grass": 1280,
    "Cobblestone": 880,
    "Brick": 848,
    "Granite": 832,
    "Ice": 1536,
    "Slate": 800,
}

# Shape enum values
SHAPES = {
    "Block": 1,
    "Ball": 0,
    "Cylinder": 2,
}

def read_lua_file(filepath):
    """Read a Lua source file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

# =============================================================
# BUILD PARTS
# =============================================================
def build_part(part_data):
    """Build a Part XML element from part data dict."""
    ref = next_ref()
    name = part_data.get('Name', 'Part')
    size = part_data.get('Size', [4, 1, 2])
    pos = part_data.get('Position', [0, 0, 0])
    color = part_data.get('Color', [163, 162, 165])
    material = part_data.get('Material', 'SmoothPlastic')
    anchored = part_data.get('Anchored', True)
    shape = part_data.get('Shape', 'Block')
    transparency = part_data.get('Transparency', 0)
    
    mat_val = MATERIALS.get(material, 256)
    shape_val = SHAPES.get(shape, 1)
    
    xml = f'    <Item class="Part" referent="{ref}">\n'
    xml += '    <Properties>\n'
    xml += prop_string("Name", name)
    xml += prop_vector3("size", size[0], size[1], size[2])
    xml += prop_cframe("CFrame", pos[0], pos[1], pos[2])
    xml += prop_color3uint8("Color3uint8", color[0], color[1], color[2])
    xml += prop_token("Material", mat_val)
    xml += prop_token("shape", shape_val)
    xml += prop_bool("Anchored", anchored)
    xml += prop_bool("CanCollide", True)
    xml += prop_float("Transparency", transparency)
    xml += '    </Properties>\n'
    xml += '    </Item>\n'
    
    return xml

def build_spawn_location(pos, size, color):
    """Build a SpawnLocation."""
    ref = next_ref()
    xml = f'    <Item class="SpawnLocation" referent="{ref}">\n'
    xml += '    <Properties>\n'
    xml += prop_string("Name", "SpawnLocation")
    xml += prop_vector3("size", size[0], size[1], size[2])
    xml += prop_cframe("CFrame", pos[0], pos[1], pos[2])
    xml += prop_color3uint8("Color3uint8", color[0], color[1], color[2])
    xml += prop_bool("Anchored", True)
    xml += prop_token("Material", 256)
    xml += '    </Properties>\n'
    xml += '    </Item>\n'
    return xml

# =============================================================
# BUILD SCRIPTS
# =============================================================
def build_script(name, source, class_name="Script"):
    """Build a Script or LocalScript or ModuleScript."""
    ref = next_ref()
    xml = f'    <Item class="{class_name}" referent="{ref}">\n'
    xml += '    <Properties>\n'
    xml += prop_string("Name", name)
    xml += prop_protected_string("Source", source)
    xml += prop_bool("Disabled", False)
    xml += '    </Properties>\n'
    xml += '    </Item>\n'
    return xml

def build_folder(name, children_xml=""):
    """Build a Folder containing children."""
    ref = next_ref()
    xml = f'    <Item class="Folder" referent="{ref}">\n'
    xml += '    <Properties>\n'
    xml += prop_string("Name", name)
    xml += '    </Properties>\n'
    xml += children_xml
    xml += '    </Item>\n'
    return xml

def build_container(class_name, name=None, children_xml=""):
    """Build a container like ServerScriptService, etc."""
    ref = next_ref()
    actual_name = name or class_name
    xml = f'  <Item class="{class_name}" referent="{ref}">\n'
    xml += '  <Properties>\n'
    xml += prop_string("Name", actual_name)
    xml += '  </Properties>\n'
    xml += children_xml
    xml += '  </Item>\n'
    return xml

def build_remote_event(name):
    ref = next_ref()
    return (f'    <Item class="RemoteEvent" referent="{ref}">\n'
            f'    <Properties>\n'
            f'{prop_string("Name", name)}'
            f'    </Properties>\n'
            f'    </Item>\n')

def build_remote_function(name):
    ref = next_ref()
    return (f'    <Item class="RemoteFunction" referent="{ref}">\n'
            f'    <Properties>\n'
            f'{prop_string("Name", name)}'
            f'    </Properties>\n'
            f'    </Item>\n')

# =============================================================
# BUILD LIGHTING
# =============================================================
def build_lighting():
    ref = next_ref()
    xml = f'  <Item class="Lighting" referent="{ref}">\n'
    xml += '  <Properties>\n'
    xml += prop_string("Name", "Lighting")
    xml += prop_color3("Ambient", 80, 70, 60)
    xml += prop_color3("OutdoorAmbient", 100, 90, 80)
    xml += prop_float("Brightness", 1.5)
    xml += prop_float("EnvironmentDiffuseScale", 0.5)
    xml += prop_float("EnvironmentSpecularScale", 0.3)
    xml += prop_string("TimeOfDay", "14:00:00")
    xml += prop_float("GeographicLatitude", 25)
    xml += '  </Properties>\n'
    
    # Add Atmosphere for desert feel
    atm_ref = next_ref()
    xml += f'    <Item class="Atmosphere" referent="{atm_ref}">\n'
    xml += '    <Properties>\n'
    xml += prop_float("Density", 0.3)
    xml += prop_float("Offset", 0.25)
    xml += prop_color3("Color", 200, 180, 140)
    xml += prop_color3("Decay", 180, 160, 130)
    xml += prop_float("Glare", 0.5)
    xml += prop_float("Haze", 2)
    xml += '    </Properties>\n'
    xml += '    </Item>\n'
    
    # ColorCorrection for pixelated look
    cc_ref = next_ref()
    xml += f'    <Item class="ColorCorrectionEffect" referent="{cc_ref}">\n'
    xml += '    <Properties>\n'
    xml += prop_float("Brightness", 0.05)
    xml += prop_float("Contrast", 0.15)
    xml += prop_float("Saturation", -0.1)
    xml += '    </Properties>\n'
    xml += '    </Item>\n'
    
    xml += '  </Item>\n'
    return xml

# =============================================================
# BUILD WORKSPACE
# =============================================================
def build_workspace(src_dir):
    """Build the entire Workspace with all map areas."""
    # Read map data to extract part definitions
    # We'll parse the Lua file manually since it's structured data
    parts_xml = ""
    
    # Import map definitions
    map_areas = parse_map_data(os.path.join(src_dir, "shared", "MapData.lua"))
    
    for area_name, area_parts in map_areas.items():
        folder_content = ""
        for part in area_parts:
            folder_content += build_part(part)
        parts_xml += build_folder(area_name, folder_content)
    
    # Add spawn location
    parts_xml += build_spawn_location([250, 3, 250], [20, 1, 20], [100, 100, 110])
    
    # Add a baseplate
    parts_xml += build_part({
        'Name': 'Baseplate',
        'Size': [800, 2, 800],
        'Position': [250, -3, 250],
        'Color': [91, 100, 86],
        'Material': 'Grass',
        'Anchored': True,
    })
    
    ref = next_ref()
    xml = f'  <Item class="Workspace" referent="{ref}">\n'
    xml += '  <Properties>\n'
    xml += prop_string("Name", "Workspace")
    xml += '  </Properties>\n'
    xml += parts_xml
    xml += '  </Item>\n'
    
    return xml

def parse_map_data(filepath):
    """Parse MapData.lua and extract part definitions."""
    areas = {}
    
    # Desert Track
    areas["DesertRaceTrack"] = [
        {"Name": "DesertFloor", "Size": [400, 2, 400], "Position": [0, -1, 0], "Color": [210, 180, 120], "Material": "Sand"},
        {"Name": "TrackStraight1", "Size": [200, 0.5, 30], "Position": [0, 0.5, -80], "Color": [180, 150, 90], "Material": "Sand"},
        {"Name": "TrackStraight2", "Size": [200, 0.5, 30], "Position": [0, 0.5, 80], "Color": [180, 150, 90], "Material": "Sand"},
        {"Name": "TrackCurve1", "Size": [30, 0.5, 190], "Position": [110, 0.5, 0], "Color": [180, 150, 90], "Material": "Sand"},
        {"Name": "TrackCurve2", "Size": [30, 0.5, 190], "Position": [-110, 0.5, 0], "Color": [180, 150, 90], "Material": "Sand"},
        {"Name": "FenceOuter1", "Size": [220, 4, 2], "Position": [0, 2, -97], "Color": [120, 80, 40], "Material": "Wood"},
        {"Name": "FenceOuter2", "Size": [220, 4, 2], "Position": [0, 2, 97], "Color": [120, 80, 40], "Material": "Wood"},
        {"Name": "FenceInner1", "Size": [180, 3, 2], "Position": [0, 1.5, -63], "Color": [120, 80, 40], "Material": "Wood"},
        {"Name": "FenceInner2", "Size": [180, 3, 2], "Position": [0, 1.5, 63], "Color": [120, 80, 40], "Material": "Wood"},
        {"Name": "StartLine", "Size": [2, 0.6, 34], "Position": [-90, 0.5, -80], "Color": [255, 255, 255], "Material": "SmoothPlastic"},
        {"Name": "Dune1", "Size": [40, 8, 30], "Position": [-150, 4, -150], "Color": [220, 190, 130], "Material": "Sand", "Shape": "Ball"},
        {"Name": "Dune2", "Size": [50, 10, 40], "Position": [150, 5, -130], "Color": [215, 185, 125], "Material": "Sand", "Shape": "Ball"},
        {"Name": "Dune3", "Size": [35, 7, 25], "Position": [170, 3.5, 140], "Color": [225, 195, 135], "Material": "Sand", "Shape": "Ball"},
        {"Name": "Dune4", "Size": [60, 12, 45], "Position": [-160, 6, 120], "Color": [210, 180, 120], "Material": "Sand", "Shape": "Ball"},
        {"Name": "Cactus1Stem", "Size": [3, 15, 3], "Position": [-140, 7.5, -100], "Color": [60, 120, 40], "Material": "SmoothPlastic"},
        {"Name": "Cactus1Arm1", "Size": [2, 8, 2], "Position": [-137, 10, -100], "Color": [60, 120, 40], "Material": "SmoothPlastic"},
        {"Name": "Cactus2Stem", "Size": [3, 12, 3], "Position": [140, 6, 110], "Color": [55, 115, 35], "Material": "SmoothPlastic"},
        {"Name": "StandBase", "Size": [60, 4, 15], "Position": [0, 2, -115], "Color": [100, 80, 60], "Material": "Wood"},
        {"Name": "StandRiser", "Size": [60, 8, 10], "Position": [0, 6, -125], "Color": [90, 70, 50], "Material": "Wood"},
        {"Name": "StandTop", "Size": [60, 12, 8], "Position": [0, 10, -133], "Color": [80, 60, 40], "Material": "Wood"},
        {"Name": "Scoreboard", "Size": [20, 12, 2], "Position": [0, 12, -145], "Color": [30, 30, 30], "Material": "SmoothPlastic"},
        {"Name": "SunShade", "Size": [30, 1, 20], "Position": [0, 16, -125], "Color": [200, 50, 50], "Material": "Fabric"},
    ]
    
    areas["AquariumRoom"] = [
        {"Name": "AquaFloor", "Size": [100, 2, 100], "Position": [500, -1, 0], "Color": [30, 50, 70], "Material": "Marble"},
        {"Name": "WallNorth", "Size": [100, 30, 3], "Position": [500, 14, -50], "Color": [40, 80, 120], "Material": "Glass", "Transparency": 0.3},
        {"Name": "WallSouth", "Size": [100, 30, 3], "Position": [500, 14, 50], "Color": [40, 80, 120], "Material": "Glass", "Transparency": 0.3},
        {"Name": "WallEast", "Size": [3, 30, 100], "Position": [550, 14, 0], "Color": [40, 80, 120], "Material": "Glass", "Transparency": 0.3},
        {"Name": "WallWest", "Size": [3, 30, 100], "Position": [450, 14, 0], "Color": [40, 80, 120], "Material": "Glass", "Transparency": 0.3},
        {"Name": "AquaCeiling", "Size": [100, 2, 100], "Position": [500, 30, 0], "Color": [20, 40, 60], "Material": "SmoothPlastic"},
        {"Name": "RacingTableTop", "Size": [60, 2, 20], "Position": [500, 5, 0], "Color": [20, 60, 40], "Material": "SmoothPlastic"},
        {"Name": "TableLeg1", "Size": [3, 5, 3], "Position": [475, 2.5, -7], "Color": [60, 50, 40], "Material": "Wood"},
        {"Name": "TableLeg2", "Size": [3, 5, 3], "Position": [475, 2.5, 7], "Color": [60, 50, 40], "Material": "Wood"},
        {"Name": "TableLeg3", "Size": [3, 5, 3], "Position": [525, 2.5, -7], "Color": [60, 50, 40], "Material": "Wood"},
        {"Name": "TableLeg4", "Size": [3, 5, 3], "Position": [525, 2.5, 7], "Color": [60, 50, 40], "Material": "Wood"},
        {"Name": "Lane1", "Size": [55, 0.3, 2], "Position": [500, 6.2, -6], "Color": [100, 200, 220], "Material": "Neon"},
        {"Name": "Lane2", "Size": [55, 0.3, 2], "Position": [500, 6.2, -3], "Color": [100, 220, 200], "Material": "Neon"},
        {"Name": "Lane3", "Size": [55, 0.3, 2], "Position": [500, 6.2, 0], "Color": [100, 200, 220], "Material": "Neon"},
        {"Name": "Lane4", "Size": [55, 0.3, 2], "Position": [500, 6.2, 3], "Color": [100, 220, 200], "Material": "Neon"},
        {"Name": "Lane5", "Size": [55, 0.3, 2], "Position": [500, 6.2, 6], "Color": [100, 200, 220], "Material": "Neon"},
        {"Name": "Coral1", "Size": [4, 6, 4], "Position": [510, 3, -35], "Color": [255, 100, 80], "Material": "SmoothPlastic"},
        {"Name": "Coral2", "Size": [3, 8, 3], "Position": [490, 4, -38], "Color": [255, 150, 200], "Material": "SmoothPlastic"},
        {"Name": "Coral3", "Size": [5, 5, 5], "Position": [515, 2.5, 35], "Color": [200, 80, 255], "Material": "SmoothPlastic"},
        {"Name": "Seaweed1", "Size": [2, 12, 2], "Position": [485, 6, 40], "Color": [30, 150, 60], "Material": "Grass"},
        {"Name": "Seaweed2", "Size": [2, 10, 2], "Position": [520, 5, -40], "Color": [40, 160, 70], "Material": "Grass"},
        {"Name": "TreasureChest", "Size": [4, 3, 3], "Position": [480, 1.5, 30], "Color": [120, 80, 30], "Material": "Wood"},
        {"Name": "Bench1", "Size": [30, 3, 5], "Position": [500, 1.5, -18], "Color": [80, 60, 40], "Material": "Wood"},
        {"Name": "Bench2", "Size": [30, 3, 5], "Position": [500, 1.5, 18], "Color": [80, 60, 40], "Material": "Wood"},
    ]
    
    areas["MonkeyArena"] = [
        {"Name": "ArenaFloor", "Size": [120, 2, 120], "Position": [0, -1, 500], "Color": [50, 45, 40], "Material": "Concrete"},
        {"Name": "RingPlatform", "Size": [30, 3, 30], "Position": [0, 1.5, 500], "Color": [80, 30, 30], "Material": "SmoothPlastic"},
        {"Name": "RingMat", "Size": [28, 0.5, 28], "Position": [0, 3.2, 500], "Color": [150, 150, 150], "Material": "Fabric"},
        {"Name": "RingPost1", "Size": [2, 8, 2], "Position": [-13, 6, 487], "Color": [180, 180, 180], "Material": "Metal"},
        {"Name": "RingPost2", "Size": [2, 8, 2], "Position": [13, 6, 487], "Color": [180, 180, 180], "Material": "Metal"},
        {"Name": "RingPost3", "Size": [2, 8, 2], "Position": [-13, 6, 513], "Color": [180, 180, 180], "Material": "Metal"},
        {"Name": "RingPost4", "Size": [2, 8, 2], "Position": [13, 6, 513], "Color": [180, 180, 180], "Material": "Metal"},
        {"Name": "RopeN1", "Size": [26, 0.5, 0.5], "Position": [0, 6, 487], "Color": [200, 50, 50], "Material": "Fabric"},
        {"Name": "RopeN2", "Size": [26, 0.5, 0.5], "Position": [0, 8, 487], "Color": [200, 50, 50], "Material": "Fabric"},
        {"Name": "RopeS1", "Size": [26, 0.5, 0.5], "Position": [0, 6, 513], "Color": [200, 50, 50], "Material": "Fabric"},
        {"Name": "RopeS2", "Size": [26, 0.5, 0.5], "Position": [0, 8, 513], "Color": [200, 50, 50], "Material": "Fabric"},
        {"Name": "RopeE1", "Size": [0.5, 0.5, 26], "Position": [13, 6, 500], "Color": [200, 50, 50], "Material": "Fabric"},
        {"Name": "RopeE2", "Size": [0.5, 0.5, 26], "Position": [13, 8, 500], "Color": [200, 50, 50], "Material": "Fabric"},
        {"Name": "RopeW1", "Size": [0.5, 0.5, 26], "Position": [-13, 6, 500], "Color": [200, 50, 50], "Material": "Fabric"},
        {"Name": "RopeW2", "Size": [0.5, 0.5, 26], "Position": [-13, 8, 500], "Color": [200, 50, 50], "Material": "Fabric"},
        {"Name": "BleacherN", "Size": [50, 6, 10], "Position": [0, 3, 465], "Color": [60, 55, 50], "Material": "Concrete"},
        {"Name": "BleacherS", "Size": [50, 6, 10], "Position": [0, 3, 535], "Color": [60, 55, 50], "Material": "Concrete"},
        {"Name": "BleacherE", "Size": [10, 6, 50], "Position": [40, 3, 500], "Color": [60, 55, 50], "Material": "Concrete"},
        {"Name": "BleacherW", "Size": [10, 6, 50], "Position": [-40, 3, 500], "Color": [60, 55, 50], "Material": "Concrete"},
        {"Name": "LightBar", "Size": [40, 2, 2], "Position": [0, 18, 500], "Color": [40, 40, 40], "Material": "Metal"},
        {"Name": "SpotLight1", "Size": [3, 1, 3], "Position": [-10, 17, 500], "Color": [255, 255, 200], "Material": "Neon"},
        {"Name": "SpotLight2", "Size": [3, 1, 3], "Position": [10, 17, 500], "Color": [255, 255, 200], "Material": "Neon"},
        {"Name": "Barrel1", "Size": [4, 5, 4], "Position": [-30, 2.5, 480], "Color": [100, 70, 40], "Material": "Wood", "Shape": "Cylinder"},
        {"Name": "Barrel2", "Size": [4, 5, 4], "Position": [-32, 2.5, 520], "Color": [100, 70, 40], "Material": "Wood", "Shape": "Cylinder"},
        {"Name": "Barrel3", "Size": [4, 5, 4], "Position": [30, 2.5, 520], "Color": [90, 65, 35], "Material": "Wood", "Shape": "Cylinder"},
    ]
    
    areas["BettingRoom"] = [
        {"Name": "BettingFloor", "Size": [100, 2, 100], "Position": [500, -1, 500], "Color": [60, 40, 25], "Material": "WoodPlanks"},
        {"Name": "BWallN", "Size": [100, 25, 3], "Position": [500, 11.5, 450], "Color": [70, 50, 30], "Material": "Wood"},
        {"Name": "BWallS", "Size": [100, 25, 3], "Position": [500, 11.5, 550], "Color": [70, 50, 30], "Material": "Wood"},
        {"Name": "BWallE", "Size": [3, 25, 100], "Position": [550, 11.5, 500], "Color": [70, 50, 30], "Material": "Wood"},
        {"Name": "BWallW", "Size": [3, 25, 100], "Position": [450, 11.5, 500], "Color": [70, 50, 30], "Material": "Wood"},
        {"Name": "BettingCeiling", "Size": [100, 2, 100], "Position": [500, 25, 500], "Color": [50, 35, 20], "Material": "Wood"},
        {"Name": "BettingCounter", "Size": [60, 5, 6], "Position": [500, 2.5, 465], "Color": [80, 55, 30], "Material": "Wood"},
        {"Name": "CounterTop", "Size": [62, 1, 7], "Position": [500, 5.2, 465], "Color": [40, 100, 50], "Material": "SmoothPlastic"},
        {"Name": "Chalkboard1", "Size": [20, 12, 1], "Position": [490, 14, 451.5], "Color": [30, 40, 30], "Material": "SmoothPlastic"},
        {"Name": "Chalkboard2", "Size": [20, 12, 1], "Position": [515, 14, 451.5], "Color": [30, 40, 30], "Material": "SmoothPlastic"},
        {"Name": "ChalkboardFrame1", "Size": [22, 14, 1.5], "Position": [490, 14, 451], "Color": [80, 60, 35], "Material": "Wood"},
        {"Name": "ChalkboardFrame2", "Size": [22, 14, 1.5], "Position": [515, 14, 451], "Color": [80, 60, 35], "Material": "Wood"},
        {"Name": "Table1Top", "Size": [8, 1, 8], "Position": [480, 4, 490], "Color": [70, 50, 30], "Material": "Wood", "Shape": "Cylinder"},
        {"Name": "Table1Leg", "Size": [3, 4, 3], "Position": [480, 2, 490], "Color": [60, 40, 25], "Material": "Wood"},
        {"Name": "Table2Top", "Size": [8, 1, 8], "Position": [520, 4, 490], "Color": [70, 50, 30], "Material": "Wood", "Shape": "Cylinder"},
        {"Name": "Table2Leg", "Size": [3, 4, 3], "Position": [520, 2, 490], "Color": [60, 40, 25], "Material": "Wood"},
        {"Name": "Table3Top", "Size": [8, 1, 8], "Position": [500, 4, 510], "Color": [70, 50, 30], "Material": "Wood", "Shape": "Cylinder"},
        {"Name": "Table3Leg", "Size": [3, 4, 3], "Position": [500, 2, 510], "Color": [60, 40, 25], "Material": "Wood"},
        {"Name": "Stool1", "Size": [3, 4, 3], "Position": [480, 2, 470], "Color": [90, 30, 30], "Material": "Fabric", "Shape": "Cylinder"},
        {"Name": "Stool2", "Size": [3, 4, 3], "Position": [490, 2, 470], "Color": [90, 30, 30], "Material": "Fabric", "Shape": "Cylinder"},
        {"Name": "Stool3", "Size": [3, 4, 3], "Position": [500, 2, 470], "Color": [90, 30, 30], "Material": "Fabric", "Shape": "Cylinder"},
        {"Name": "Stool4", "Size": [3, 4, 3], "Position": [510, 2, 470], "Color": [90, 30, 30], "Material": "Fabric", "Shape": "Cylinder"},
        {"Name": "Stool5", "Size": [3, 4, 3], "Position": [520, 2, 470], "Color": [90, 30, 30], "Material": "Fabric", "Shape": "Cylinder"},
        {"Name": "TV1Body", "Size": [10, 8, 8], "Position": [470, 10, 452], "Color": [50, 50, 55], "Material": "SmoothPlastic"},
        {"Name": "TV1Screen", "Size": [8, 6, 0.5], "Position": [470, 10, 456.5], "Color": [100, 150, 200], "Material": "Neon"},
        {"Name": "TV2Body", "Size": [10, 8, 8], "Position": [530, 10, 452], "Color": [50, 50, 55], "Material": "SmoothPlastic"},
        {"Name": "TV2Screen", "Size": [8, 6, 0.5], "Position": [530, 10, 456.5], "Color": [100, 150, 200], "Material": "Neon"},
        {"Name": "Lamp1Chain", "Size": [1, 6, 1], "Position": [485, 22, 490], "Color": [100, 80, 50], "Material": "Metal"},
        {"Name": "Lamp1Shade", "Size": [6, 3, 6], "Position": [485, 18.5, 490], "Color": [180, 130, 50], "Material": "Fabric", "Shape": "Cylinder"},
        {"Name": "Lamp2Chain", "Size": [1, 6, 1], "Position": [515, 22, 510], "Color": [100, 80, 50], "Material": "Metal"},
        {"Name": "Lamp2Shade", "Size": [6, 3, 6], "Position": [515, 18.5, 510], "Color": [180, 130, 50], "Material": "Fabric", "Shape": "Cylinder"},
        {"Name": "Poster1", "Size": [8, 10, 0.5], "Position": [460, 12, 549.5], "Color": [180, 150, 100], "Material": "SmoothPlastic"},
        {"Name": "Poster2", "Size": [8, 10, 0.5], "Position": [480, 12, 549.5], "Color": [160, 140, 90], "Material": "SmoothPlastic"},
        {"Name": "Poster3", "Size": [8, 10, 0.5], "Position": [520, 12, 549.5], "Color": [170, 145, 95], "Material": "SmoothPlastic"},
        {"Name": "Poster4", "Size": [8, 10, 0.5], "Position": [540, 12, 549.5], "Color": [165, 135, 85], "Material": "SmoothPlastic"},
        {"Name": "CashRegister", "Size": [4, 4, 4], "Position": [500, 7, 464], "Color": [120, 100, 60], "Material": "Metal"},
        {"Name": "Carpet", "Size": [80, 0.5, 60], "Position": [500, 0.5, 500], "Color": [30, 80, 40], "Material": "Fabric"},
    ]
    
    # Paths
    areas["Paths"] = [
        {"Name": "PathDesertAqua", "Size": [120, 1, 15], "Position": [250, 0, 0], "Color": [140, 130, 110], "Material": "Cobblestone"},
        {"Name": "PathDesertArena", "Size": [15, 1, 120], "Position": [0, 0, 250], "Color": [140, 130, 110], "Material": "Cobblestone"},
        {"Name": "PathAquaBetting", "Size": [15, 1, 120], "Position": [500, 0, 250], "Color": [140, 130, 110], "Material": "Cobblestone"},
        {"Name": "PathArenaBetting", "Size": [120, 1, 15], "Position": [250, 0, 500], "Color": [140, 130, 110], "Material": "Cobblestone"},
        {"Name": "CentralHub", "Size": [30, 1, 30], "Position": [250, 0.5, 250], "Color": [120, 110, 100], "Material": "Cobblestone"},
    ]
    
    return areas

# =============================================================
# MAIN GENERATOR
# =============================================================
def generate_rbxlx(src_dir, output_path):
    """Generate the complete .rbxlx file."""
    
    print("Reading Lua source files...")
    
    # Read all Lua scripts
    game_config = read_lua_file(os.path.join(src_dir, "shared", "GameConfig.lua"))
    datastore_mgr = read_lua_file(os.path.join(src_dir, "server", "DataStoreManager.lua"))
    anti_exploit = read_lua_file(os.path.join(src_dir, "server", "AntiExploit.lua"))
    combat_ai = read_lua_file(os.path.join(src_dir, "server", "CombatAIController.lua"))
    racing_ai = read_lua_file(os.path.join(src_dir, "server", "RacingAIController.lua"))
    betting_mgr = read_lua_file(os.path.join(src_dir, "server", "BettingManager.lua"))
    trade_mgr = read_lua_file(os.path.join(src_dir, "server", "TradeManager.lua"))
    autofix = read_lua_file(os.path.join(src_dir, "server", "AutoFixSystem.lua"))
    main_server = read_lua_file(os.path.join(src_dir, "server", "MainGameServer.lua"))
    client_main = read_lua_file(os.path.join(src_dir, "client", "ClientMain.lua"))
    
    print("Building XML structure...")
    
    # =========================================
    # REPLICATED STORAGE
    # =========================================
    shared_modules = build_folder("SharedModules",
        build_script("GameConfig", game_config, "ModuleScript")
    )
    
    remotes = ""
    remote_events = [
        "PlaceBet", "EventUpdate", "FightUpdate", "RaceUpdate",
        "TradeRequest", "TradeUpdate", "TradeAction",
        "EquipItem", "UnequipItem", "SetActiveCreature",
        "TrainCreature", "BuyItem", "PlayerDataUpdate", "Notification",
    ]
    remote_functions = ["GetPlayerData", "GetBettingInfo", "GetShopItems", "GetCreatureInfo"]
    
    for name in remote_events:
        remotes += build_remote_event(name)
    for name in remote_functions:
        remotes += build_remote_function(name)
    
    remotes_folder = build_folder("Remotes", remotes)
    
    replicated_storage = build_container("ReplicatedStorage", children_xml=
        shared_modules + remotes_folder
    )
    
    # =========================================
    # SERVER SCRIPT SERVICE
    # =========================================
    server_scripts = ""
    server_scripts += build_script("DataStoreManager", datastore_mgr, "ModuleScript")
    server_scripts += build_script("AntiExploit", anti_exploit, "ModuleScript")
    server_scripts += build_script("CombatAIController", combat_ai, "ModuleScript")
    server_scripts += build_script("RacingAIController", racing_ai, "ModuleScript")
    server_scripts += build_script("BettingManager", betting_mgr, "ModuleScript")
    server_scripts += build_script("TradeManager", trade_mgr, "ModuleScript")
    server_scripts += build_script("AutoFixSystem", autofix, "ModuleScript")
    server_scripts += build_script("MainGameServer", main_server, "Script")
    
    server_script_service = build_container("ServerScriptService", children_xml=server_scripts)
    
    # =========================================
    # STARTER PLAYER
    # =========================================
    starter_player_scripts = build_script("ClientMain", client_main, "LocalScript")
    
    sps_ref = next_ref()
    starter_player_scripts_container = (
        f'    <Item class="StarterPlayerScripts" referent="{sps_ref}">\n'
        f'    <Properties>\n'
        f'{prop_string("Name", "StarterPlayerScripts")}'
        f'    </Properties>\n'
        f'{starter_player_scripts}'
        f'    </Item>\n'
    )
    
    starter_player = build_container("StarterPlayer", children_xml=starter_player_scripts_container)
    
    # =========================================
    # STARTER GUI
    # =========================================
    starter_gui = build_container("StarterGui")
    
    # =========================================
    # WORKSPACE
    # =========================================
    workspace_xml = build_workspace(src_dir)
    
    # =========================================
    # LIGHTING
    # =========================================
    lighting = build_lighting()
    
    # =========================================
    # OTHER SERVICES
    # =========================================
    players = build_container("Players")
    
    server_storage = build_container("ServerStorage")
    
    # SoundService
    sound_ref = next_ref()
    sound_service = (
        f'  <Item class="SoundService" referent="{sound_ref}">\n'
        f'  <Properties>\n'
        f'{prop_string("Name", "SoundService")}'
        f'  </Properties>\n'
        f'  </Item>\n'
    )
    
    # StarterPack
    starter_pack = build_container("StarterPack")
    
    # Teams
    teams = build_container("Teams")
    
    # Chat
    chat_ref = next_ref()
    chat = (
        f'  <Item class="Chat" referent="{chat_ref}">\n'
        f'  <Properties>\n'
        f'{prop_string("Name", "Chat")}'
        f'  </Properties>\n'
        f'  </Item>\n'
    )
    
    # =========================================
    # ASSEMBLE FINAL FILE
    # =========================================
    print("Assembling .rbxlx file...")
    
    xml = '<?xml version="1.0" encoding="utf-8"?>\n'
    xml += '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
    xml += '  <External>null</External>\n'
    xml += '  <External>nil</External>\n'
    
    xml += workspace_xml
    xml += players
    xml += lighting
    xml += replicated_storage
    xml += server_script_service
    xml += server_storage
    xml += starter_gui
    xml += starter_pack
    xml += starter_player
    xml += sound_service
    xml += chat
    xml += teams
    
    xml += '</roblox>\n'
    
    print(f"Writing to {output_path}...")
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(xml)
    
    file_size = os.path.getsize(output_path)
    print(f"Generated {output_path} ({file_size:,} bytes)")
    print("Done! Open this file in Roblox Studio to play the game.")

# =============================================================
# ENTRY POINT
# =============================================================
if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.abspath(__file__))
    src_dir = os.path.join(base_dir, "src")
    output_path = os.path.join(base_dir, "ArenaBestial.rbxlx")
    
    generate_rbxlx(src_dir, output_path)
