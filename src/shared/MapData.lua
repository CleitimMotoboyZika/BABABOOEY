-- MapBuilder: Creates all 4 game areas with low-poly pixelated aesthetic
-- Called by the .rbxlx generator to produce workspace geometry

-- This module defines the map layout data used by the RBXLX generator
-- Areas: Desert Track, Aquarium Room, Monkey Arena, Betting Room

local MapData = {}

-- ============================================================
-- DESERT RACE TRACK (Camel Racing)
-- Large open desert with a circular track, sand dunes, cacti
-- ============================================================
MapData.DesertTrack = {
	Name = "DesertRaceTrack",
	Position = {0, 0, 0},
	Parts = {
		-- Ground (sandy desert floor)
		{Name = "DesertFloor", Size = {400, 2, 400}, Position = {0, -1, 0}, 
		 Color = {210, 180, 120}, Material = "Sand", Anchored = true},
		
		-- Race Track (darker sand path, oval)
		{Name = "TrackStraight1", Size = {200, 0.5, 30}, Position = {0, 0.5, -80},
		 Color = {180, 150, 90}, Material = "Sand", Anchored = true},
		{Name = "TrackStraight2", Size = {200, 0.5, 30}, Position = {0, 0.5, 80},
		 Color = {180, 150, 90}, Material = "Sand", Anchored = true},
		{Name = "TrackCurve1", Size = {30, 0.5, 190}, Position = {110, 0.5, 0},
		 Color = {180, 150, 90}, Material = "Sand", Anchored = true},
		{Name = "TrackCurve2", Size = {30, 0.5, 190}, Position = {-110, 0.5, 0},
		 Color = {180, 150, 90}, Material = "Sand", Anchored = true},
		
		-- Track fences
		{Name = "FenceOuter1", Size = {220, 4, 2}, Position = {0, 2, -97},
		 Color = {120, 80, 40}, Material = "Wood", Anchored = true},
		{Name = "FenceOuter2", Size = {220, 4, 2}, Position = {0, 2, 97},
		 Color = {120, 80, 40}, Material = "Wood", Anchored = true},
		{Name = "FenceInner1", Size = {180, 3, 2}, Position = {0, 1.5, -63},
		 Color = {120, 80, 40}, Material = "Wood", Anchored = true},
		{Name = "FenceInner2", Size = {180, 3, 2}, Position = {0, 1.5, 63},
		 Color = {120, 80, 40}, Material = "Wood", Anchored = true},
		
		-- Start/Finish line
		{Name = "StartLine", Size = {2, 0.6, 34}, Position = {-90, 0.5, -80},
		 Color = {255, 255, 255}, Material = "SmoothPlastic", Anchored = true},
		
		-- Sand dunes (decorative)
		{Name = "Dune1", Size = {40, 8, 30}, Position = {-150, 4, -150},
		 Color = {220, 190, 130}, Material = "Sand", Anchored = true, Shape = "Ball"},
		{Name = "Dune2", Size = {50, 10, 40}, Position = {150, 5, -130},
		 Color = {215, 185, 125}, Material = "Sand", Anchored = true, Shape = "Ball"},
		{Name = "Dune3", Size = {35, 7, 25}, Position = {170, 3.5, 140},
		 Color = {225, 195, 135}, Material = "Sand", Anchored = true, Shape = "Ball"},
		{Name = "Dune4", Size = {60, 12, 45}, Position = {-160, 6, 120},
		 Color = {210, 180, 120}, Material = "Sand", Anchored = true, Shape = "Ball"},
		
		-- Cacti (tall thin green parts)
		{Name = "Cactus1Stem", Size = {3, 15, 3}, Position = {-140, 7.5, -100},
		 Color = {60, 120, 40}, Material = "SmoothPlastic", Anchored = true},
		{Name = "Cactus1Arm1", Size = {2, 8, 2}, Position = {-137, 10, -100},
		 Color = {60, 120, 40}, Material = "SmoothPlastic", Anchored = true},
		{Name = "Cactus2Stem", Size = {3, 12, 3}, Position = {140, 6, 110},
		 Color = {55, 115, 35}, Material = "SmoothPlastic", Anchored = true},
		
		-- Spectator stands
		{Name = "StandBase", Size = {60, 4, 15}, Position = {0, 2, -115},
		 Color = {100, 80, 60}, Material = "Wood", Anchored = true},
		{Name = "StandRiser", Size = {60, 8, 10}, Position = {0, 6, -125},
		 Color = {90, 70, 50}, Material = "Wood", Anchored = true},
		{Name = "StandTop", Size = {60, 12, 8}, Position = {0, 10, -133},
		 Color = {80, 60, 40}, Material = "Wood", Anchored = true},
		
		-- Scoreboard
		{Name = "Scoreboard", Size = {20, 12, 2}, Position = {0, 12, -145},
		 Color = {30, 30, 30}, Material = "SmoothPlastic", Anchored = true},
		
		-- Sun shade
		{Name = "SunShade", Size = {30, 1, 20}, Position = {0, 16, -125},
		 Color = {200, 50, 50}, Material = "Fabric", Anchored = true},
	},
}

-- ============================================================
-- AQUARIUM ROOM (Lobster Racing)
-- Indoor room with aquarium walls, blue lighting, racing table
-- ============================================================
MapData.AquariumRoom = {
	Name = "AquariumRoom",
	Position = {500, 0, 0},
	Parts = {
		-- Floor
		{Name = "AquaFloor", Size = {100, 2, 100}, Position = {500, -1, 0},
		 Color = {30, 50, 70}, Material = "Marble", Anchored = true},
		
		-- Walls (glass-like aquarium theme)
		{Name = "WallNorth", Size = {100, 30, 3}, Position = {500, 14, -50},
		 Color = {40, 80, 120}, Material = "Glass", Anchored = true, Transparency = 0.3},
		{Name = "WallSouth", Size = {100, 30, 3}, Position = {500, 14, 50},
		 Color = {40, 80, 120}, Material = "Glass", Anchored = true, Transparency = 0.3},
		{Name = "WallEast", Size = {3, 30, 100}, Position = {550, 14, 0},
		 Color = {40, 80, 120}, Material = "Glass", Anchored = true, Transparency = 0.3},
		{Name = "WallWest", Size = {3, 30, 100}, Position = {450, 14, 0},
		 Color = {40, 80, 120}, Material = "Glass", Anchored = true, Transparency = 0.3},
		
		-- Ceiling
		{Name = "AquaCeiling", Size = {100, 2, 100}, Position = {500, 30, 0},
		 Color = {20, 40, 60}, Material = "SmoothPlastic", Anchored = true},
		
		-- Racing Table (center)
		{Name = "RacingTableTop", Size = {60, 2, 20}, Position = {500, 5, 0},
		 Color = {20, 60, 40}, Material = "SmoothPlastic", Anchored = true},
		{Name = "TableLeg1", Size = {3, 5, 3}, Position = {475, 2.5, -7},
		 Color = {60, 50, 40}, Material = "Wood", Anchored = true},
		{Name = "TableLeg2", Size = {3, 5, 3}, Position = {475, 2.5, 7},
		 Color = {60, 50, 40}, Material = "Wood", Anchored = true},
		{Name = "TableLeg3", Size = {3, 5, 3}, Position = {525, 2.5, -7},
		 Color = {60, 50, 40}, Material = "Wood", Anchored = true},
		{Name = "TableLeg4", Size = {3, 5, 3}, Position = {525, 2.5, 7},
		 Color = {60, 50, 40}, Material = "Wood", Anchored = true},
		
		-- Racing lanes (on table)
		{Name = "Lane1", Size = {55, 0.3, 2}, Position = {500, 6.2, -6},
		 Color = {100, 200, 220}, Material = "Neon", Anchored = true},
		{Name = "Lane2", Size = {55, 0.3, 2}, Position = {500, 6.2, -3},
		 Color = {100, 220, 200}, Material = "Neon", Anchored = true},
		{Name = "Lane3", Size = {55, 0.3, 2}, Position = {500, 6.2, 0},
		 Color = {100, 200, 220}, Material = "Neon", Anchored = true},
		{Name = "Lane4", Size = {55, 0.3, 2}, Position = {500, 6.2, 3},
		 Color = {100, 220, 200}, Material = "Neon", Anchored = true},
		{Name = "Lane5", Size = {55, 0.3, 2}, Position = {500, 6.2, 6},
		 Color = {100, 200, 220}, Material = "Neon", Anchored = true},
		
		-- Aquarium decorations (coral, seaweed blocks)
		{Name = "Coral1", Size = {4, 6, 4}, Position = {510, 3, -35},
		 Color = {255, 100, 80}, Material = "SmoothPlastic", Anchored = true},
		{Name = "Coral2", Size = {3, 8, 3}, Position = {490, 4, -38},
		 Color = {255, 150, 200}, Material = "SmoothPlastic", Anchored = true},
		{Name = "Coral3", Size = {5, 5, 5}, Position = {515, 2.5, 35},
		 Color = {200, 80, 255}, Material = "SmoothPlastic", Anchored = true},
		{Name = "Seaweed1", Size = {2, 12, 2}, Position = {485, 6, 40},
		 Color = {30, 150, 60}, Material = "Grass", Anchored = true},
		{Name = "Seaweed2", Size = {2, 10, 2}, Position = {520, 5, -40},
		 Color = {40, 160, 70}, Material = "Grass", Anchored = true},
		
		-- Fish tank decorations (treasure chest)
		{Name = "TreasureChest", Size = {4, 3, 3}, Position = {480, 1.5, 30},
		 Color = {120, 80, 30}, Material = "Wood", Anchored = true},
		
		-- Benches around table
		{Name = "Bench1", Size = {30, 3, 5}, Position = {500, 1.5, -18},
		 Color = {80, 60, 40}, Material = "Wood", Anchored = true},
		{Name = "Bench2", Size = {30, 3, 5}, Position = {500, 1.5, 18},
		 Color = {80, 60, 40}, Material = "Wood", Anchored = true},
	},
}

-- ============================================================
-- MONKEY ARENA (Fight Ring)
-- Gritty improvised fighting ring with ropes, lights, crowd area
-- ============================================================
MapData.MonkeyArena = {
	Name = "MonkeyArena",
	Position = {0, 0, 500},
	Parts = {
		-- Arena floor
		{Name = "ArenaFloor", Size = {120, 2, 120}, Position = {0, -1, 500},
		 Color = {50, 45, 40}, Material = "Concrete", Anchored = true},
		
		-- Ring platform (raised)
		{Name = "RingPlatform", Size = {30, 3, 30}, Position = {0, 1.5, 500},
		 Color = {80, 30, 30}, Material = "SmoothPlastic", Anchored = true},
		
		-- Ring mat
		{Name = "RingMat", Size = {28, 0.5, 28}, Position = {0, 3.2, 500},
		 Color = {150, 150, 150}, Material = "Fabric", Anchored = true},
		
		-- Ring posts (corners)
		{Name = "RingPost1", Size = {2, 8, 2}, Position = {-13, 6, 487},
		 Color = {180, 180, 180}, Material = "Metal", Anchored = true},
		{Name = "RingPost2", Size = {2, 8, 2}, Position = {13, 6, 487},
		 Color = {180, 180, 180}, Material = "Metal", Anchored = true},
		{Name = "RingPost3", Size = {2, 8, 2}, Position = {-13, 6, 513},
		 Color = {180, 180, 180}, Material = "Metal", Anchored = true},
		{Name = "RingPost4", Size = {2, 8, 2}, Position = {13, 6, 513},
		 Color = {180, 180, 180}, Material = "Metal", Anchored = true},
		
		-- Ring ropes
		{Name = "RopeN1", Size = {26, 0.5, 0.5}, Position = {0, 6, 487},
		 Color = {200, 50, 50}, Material = "Fabric", Anchored = true},
		{Name = "RopeN2", Size = {26, 0.5, 0.5}, Position = {0, 8, 487},
		 Color = {200, 50, 50}, Material = "Fabric", Anchored = true},
		{Name = "RopeS1", Size = {26, 0.5, 0.5}, Position = {0, 6, 513},
		 Color = {200, 50, 50}, Material = "Fabric", Anchored = true},
		{Name = "RopeS2", Size = {26, 0.5, 0.5}, Position = {0, 8, 513},
		 Color = {200, 50, 50}, Material = "Fabric", Anchored = true},
		{Name = "RopeE1", Size = {0.5, 0.5, 26}, Position = {13, 6, 500},
		 Color = {200, 50, 50}, Material = "Fabric", Anchored = true},
		{Name = "RopeE2", Size = {0.5, 0.5, 26}, Position = {13, 8, 500},
		 Color = {200, 50, 50}, Material = "Fabric", Anchored = true},
		{Name = "RopeW1", Size = {0.5, 0.5, 26}, Position = {-13, 6, 500},
		 Color = {200, 50, 50}, Material = "Fabric", Anchored = true},
		{Name = "RopeW2", Size = {0.5, 0.5, 26}, Position = {-13, 8, 500},
		 Color = {200, 50, 50}, Material = "Fabric", Anchored = true},
		
		-- Crowd bleachers
		{Name = "BleacherN", Size = {50, 6, 10}, Position = {0, 3, 465},
		 Color = {60, 55, 50}, Material = "Concrete", Anchored = true},
		{Name = "BleacherS", Size = {50, 6, 10}, Position = {0, 3, 535},
		 Color = {60, 55, 50}, Material = "Concrete", Anchored = true},
		{Name = "BleacherE", Size = {10, 6, 50}, Position = {40, 3, 500},
		 Color = {60, 55, 50}, Material = "Concrete", Anchored = true},
		{Name = "BleacherW", Size = {10, 6, 50}, Position = {-40, 3, 500},
		 Color = {60, 55, 50}, Material = "Concrete", Anchored = true},
		
		-- Overhead lights
		{Name = "LightBar", Size = {40, 2, 2}, Position = {0, 18, 500},
		 Color = {40, 40, 40}, Material = "Metal", Anchored = true},
		{Name = "SpotLight1", Size = {3, 1, 3}, Position = {-10, 17, 500},
		 Color = {255, 255, 200}, Material = "Neon", Anchored = true},
		{Name = "SpotLight2", Size = {3, 1, 3}, Position = {10, 17, 500},
		 Color = {255, 255, 200}, Material = "Neon", Anchored = true},
		
		-- Barrel decorations
		{Name = "Barrel1", Size = {4, 5, 4}, Position = {-30, 2.5, 480},
		 Color = {100, 70, 40}, Material = "Wood", Anchored = true, Shape = "Cylinder"},
		{Name = "Barrel2", Size = {4, 5, 4}, Position = {-32, 2.5, 520},
		 Color = {100, 70, 40}, Material = "Wood", Anchored = true, Shape = "Cylinder"},
		{Name = "Barrel3", Size = {4, 5, 4}, Position = {30, 2.5, 520},
		 Color = {90, 65, 35}, Material = "Wood", Anchored = true, Shape = "Cylinder"},
	},
}

-- ============================================================
-- BETTING ROOM (Vintage Horse Racing Betting Parlor)
-- Dark wood, green felt, chalkboards, old TVs, cigar smoke feel
-- ============================================================
MapData.BettingRoom = {
	Name = "BettingRoom",
	Position = {500, 0, 500},
	Parts = {
		-- Floor (dark wood)
		{Name = "BettingFloor", Size = {100, 2, 100}, Position = {500, -1, 500},
		 Color = {60, 40, 25}, Material = "WoodPlanks", Anchored = true},
		
		-- Walls
		{Name = "BWallN", Size = {100, 25, 3}, Position = {500, 11.5, 450},
		 Color = {70, 50, 30}, Material = "Wood", Anchored = true},
		{Name = "BWallS", Size = {100, 25, 3}, Position = {500, 11.5, 550},
		 Color = {70, 50, 30}, Material = "Wood", Anchored = true},
		{Name = "BWallE", Size = {3, 25, 100}, Position = {550, 11.5, 500},
		 Color = {70, 50, 30}, Material = "Wood", Anchored = true},
		{Name = "BWallW", Size = {3, 25, 100}, Position = {450, 11.5, 500},
		 Color = {70, 50, 30}, Material = "Wood", Anchored = true},
		
		-- Ceiling
		{Name = "BettingCeiling", Size = {100, 2, 100}, Position = {500, 25, 500},
		 Color = {50, 35, 20}, Material = "Wood", Anchored = true},
		
		-- Betting counter (long bar)
		{Name = "BettingCounter", Size = {60, 5, 6}, Position = {500, 2.5, 465},
		 Color = {80, 55, 30}, Material = "Wood", Anchored = true},
		{Name = "CounterTop", Size = {62, 1, 7}, Position = {500, 5.2, 465},
		 Color = {40, 100, 50}, Material = "SmoothPlastic", Anchored = true},
		
		-- Chalkboards (odds display)
		{Name = "Chalkboard1", Size = {20, 12, 1}, Position = {490, 14, 451.5},
		 Color = {30, 40, 30}, Material = "SmoothPlastic", Anchored = true},
		{Name = "Chalkboard2", Size = {20, 12, 1}, Position = {515, 14, 451.5},
		 Color = {30, 40, 30}, Material = "SmoothPlastic", Anchored = true},
		{Name = "ChalkboardFrame1", Size = {22, 14, 1.5}, Position = {490, 14, 451},
		 Color = {80, 60, 35}, Material = "Wood", Anchored = true},
		{Name = "ChalkboardFrame2", Size = {22, 14, 1.5}, Position = {515, 14, 451},
		 Color = {80, 60, 35}, Material = "Wood", Anchored = true},
		
		-- Tables (round pub tables)
		{Name = "Table1Top", Size = {8, 1, 8}, Position = {480, 4, 490},
		 Color = {70, 50, 30}, Material = "Wood", Anchored = true, Shape = "Cylinder"},
		{Name = "Table1Leg", Size = {3, 4, 3}, Position = {480, 2, 490},
		 Color = {60, 40, 25}, Material = "Wood", Anchored = true},
		{Name = "Table2Top", Size = {8, 1, 8}, Position = {520, 4, 490},
		 Color = {70, 50, 30}, Material = "Wood", Anchored = true, Shape = "Cylinder"},
		{Name = "Table2Leg", Size = {3, 4, 3}, Position = {520, 2, 490},
		 Color = {60, 40, 25}, Material = "Wood", Anchored = true},
		{Name = "Table3Top", Size = {8, 1, 8}, Position = {500, 4, 510},
		 Color = {70, 50, 30}, Material = "Wood", Anchored = true, Shape = "Cylinder"},
		{Name = "Table3Leg", Size = {3, 4, 3}, Position = {500, 2, 510},
		 Color = {60, 40, 25}, Material = "Wood", Anchored = true},
		
		-- Bar stools
		{Name = "Stool1", Size = {3, 4, 3}, Position = {480, 2, 470},
		 Color = {90, 30, 30}, Material = "Fabric", Anchored = true, Shape = "Cylinder"},
		{Name = "Stool2", Size = {3, 4, 3}, Position = {490, 2, 470},
		 Color = {90, 30, 30}, Material = "Fabric", Anchored = true, Shape = "Cylinder"},
		{Name = "Stool3", Size = {3, 4, 3}, Position = {500, 2, 470},
		 Color = {90, 30, 30}, Material = "Fabric", Anchored = true, Shape = "Cylinder"},
		{Name = "Stool4", Size = {3, 4, 3}, Position = {510, 2, 470},
		 Color = {90, 30, 30}, Material = "Fabric", Anchored = true, Shape = "Cylinder"},
		{Name = "Stool5", Size = {3, 4, 3}, Position = {520, 2, 470},
		 Color = {90, 30, 30}, Material = "Fabric", Anchored = true, Shape = "Cylinder"},
		
		-- Old CRT TVs (showing races)
		{Name = "TV1Body", Size = {10, 8, 8}, Position = {470, 10, 452},
		 Color = {50, 50, 55}, Material = "SmoothPlastic", Anchored = true},
		{Name = "TV1Screen", Size = {8, 6, 0.5}, Position = {470, 10, 456.5},
		 Color = {100, 150, 200}, Material = "Neon", Anchored = true},
		{Name = "TV2Body", Size = {10, 8, 8}, Position = {530, 10, 452},
		 Color = {50, 50, 55}, Material = "SmoothPlastic", Anchored = true},
		{Name = "TV2Screen", Size = {8, 6, 0.5}, Position = {530, 10, 456.5},
		 Color = {100, 150, 200}, Material = "Neon", Anchored = true},
		
		-- Hanging lamps (warm light)
		{Name = "Lamp1Chain", Size = {1, 6, 1}, Position = {485, 22, 490},
		 Color = {100, 80, 50}, Material = "Metal", Anchored = true},
		{Name = "Lamp1Shade", Size = {6, 3, 6}, Position = {485, 18.5, 490},
		 Color = {180, 130, 50}, Material = "Fabric", Anchored = true, Shape = "Cylinder"},
		{Name = "Lamp2Chain", Size = {1, 6, 1}, Position = {515, 22, 510},
		 Color = {100, 80, 50}, Material = "Metal", Anchored = true},
		{Name = "Lamp2Shade", Size = {6, 3, 6}, Position = {515, 18.5, 510},
		 Color = {180, 130, 50}, Material = "Fabric", Anchored = true, Shape = "Cylinder"},
		
		-- Horse racing posters/frames on walls
		{Name = "Poster1", Size = {8, 10, 0.5}, Position = {460, 12, 549.5},
		 Color = {180, 150, 100}, Material = "SmoothPlastic", Anchored = true},
		{Name = "Poster2", Size = {8, 10, 0.5}, Position = {480, 12, 549.5},
		 Color = {160, 140, 90}, Material = "SmoothPlastic", Anchored = true},
		{Name = "Poster3", Size = {8, 10, 0.5}, Position = {520, 12, 549.5},
		 Color = {170, 145, 95}, Material = "SmoothPlastic", Anchored = true},
		{Name = "Poster4", Size = {8, 10, 0.5}, Position = {540, 12, 549.5},
		 Color = {165, 135, 85}, Material = "SmoothPlastic", Anchored = true},
		
		-- Cash register
		{Name = "CashRegister", Size = {4, 4, 4}, Position = {500, 7, 464},
		 Color = {120, 100, 60}, Material = "Metal", Anchored = true},
		
		-- Floor carpet (green)
		{Name = "Carpet", Size = {80, 0.5, 60}, Position = {500, 0.5, 500},
		 Color = {30, 80, 40}, Material = "Fabric", Anchored = true},
	},
}

-- ============================================================
-- CONNECTING PATHS BETWEEN AREAS
-- ============================================================
MapData.Paths = {
	-- Path from Desert to Aquarium
	{Name = "PathDesertAqua", Size = {120, 1, 15}, Position = {250, 0, 0},
	 Color = {140, 130, 110}, Material = "Cobblestone", Anchored = true},
	
	-- Path from Desert to Arena
	{Name = "PathDesertArena", Size = {15, 1, 120}, Position = {0, 0, 250},
	 Color = {140, 130, 110}, Material = "Cobblestone", Anchored = true},
	
	-- Path from Aquarium to Betting
	{Name = "PathAquaBetting", Size = {15, 1, 120}, Position = {500, 0, 250},
	 Color = {140, 130, 110}, Material = "Cobblestone", Anchored = true},
	
	-- Path from Arena to Betting
	{Name = "PathArenaBetting", Size = {120, 1, 15}, Position = {250, 0, 500},
	 Color = {140, 130, 110}, Material = "Cobblestone", Anchored = true},
	
	-- Central hub
	{Name = "CentralHub", Size = {30, 1, 30}, Position = {250, 0.5, 250},
	 Color = {120, 110, 100}, Material = "Cobblestone", Anchored = true},
}

-- ============================================================
-- SPAWN LOCATION
-- ============================================================
MapData.SpawnLocation = {
	Name = "SpawnLocation",
	Position = {250, 3, 250},
	Size = {20, 1, 20},
	Color = {100, 100, 110},
}

return MapData
