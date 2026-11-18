-- All tunable numbers live here. Pure data, no Roblox APIs, so the simulation can be tested outside Studio.
local Config = {}

-- Fill these in after publishing the two places. 0 = Studio test mode (run directly, no lobby).
Config.Places = { Lobby = 0, Run = 0 }

Config.MaxPlayers = 4

-- The cage is a line of sections: Bow - Midship - Stern - Airlock
Config.Sections = { "Bow", "Midship", "Stern", "Airlock" }
Config.CrackSections = { "Bow", "Midship", "Stern" }
Config.Adjacent = {
	Bow = { "Midship" },
	Midship = { "Bow", "Stern" },
	Stern = { "Midship", "Airlock" },
	Airlock = { "Stern" },
}

Config.Difficulties = {
	Easy      = { monsterRate = 0.7,  monsterSpeed = 0.8, reaction = 1.4,  battery = 0.8, crack = 0.7, ascent = 1.4, money = 0.75 },
	Normal    = { monsterRate = 1.0,  monsterSpeed = 1.0, reaction = 1.0,  battery = 1.0, crack = 1.0, ascent = 1.8, money = 1.0 },
	Hard      = { monsterRate = 1.35, monsterSpeed = 1.2, reaction = 0.75, battery = 1.2, crack = 1.4, ascent = 2.2, money = 1.6 },
	Nightmare = { monsterRate = 1.7,  monsterSpeed = 1.4, reaction = 0.55, battery = 1.4, crack = 1.8, ascent = 2.8, money = 2.5 },
}
Config.DifficultyOrder = { "Easy", "Normal", "Hard", "Nightmare" }

-- Index = number of living players. Fewer players => less active monsters.
Config.PlayerScale = {
	rate  = { 0.6, 0.75, 0.9, 1.0 },
	speed = { 0.8, 0.9, 0.95, 1.0 },
}

Config.Cage = {
	MaxDepth = 1500,      -- metres
	DescentSpeed = 5,     -- m/s with engine on
	DriftDescent = 1.5,   -- m/s with engine off (gravity)
	AscentSpeed = 5,      -- m/s with engine on
	ArtifactSpeedMult = 0.75,
	CoastTime = 4,        -- seconds of momentum after the engine is killed on the ascent
	SinkSpeed = 1,        -- m/s sinking once momentum is gone
	Hull = 100,
}

Config.Battery = { Max = 300, Base = 0.08, Engine = 0.2, Light = 0.5, SwarmDrain = 0.3, ArtifactMult = 1.15 }
Config.Light = { Cone = 30 } -- half angle, degrees
Config.Cracks = { FirstDelay = 30, Interval = 45, Max = 6, RepairTime = 4 }
Config.Extinguisher = { Sections = { "Bow", "Midship", "Stern" }, Capacity = 100, SprayDrain = 20, RefillRate = 40 }
Config.Outside = { Oxygen = 45, DangerGrace = 2 }

Config.Shark   = { Warning = 6, NearTime = 14, Reaction = 4, Damage = 50, CracksOnHit = 2, AttackCooldown = 5 }
Config.Squid   = { StartDist = 100, CloseSpeed = 3.5, PushSpeed = 12, RetreatDist = 110, Drift = 15,
                   Far = 70, Near = 40, VeryNear = 15 }
Config.Crawler = { MinCrackAge = 15, Warning = 8, KillTime = 25, MoveTime = 10, SprayNeeded = 4, SprayDecay = 0.5 }
Config.Swarm   = { GrowTime = 60, ClearTime = 12 }
Config.Pursuer = { MinSpeedFrac = 0.4, FillRate = 8, DrainRate = 6 }

Config.Director = {
	BaseRate = 0.02, MinGap = 8, MaxConcurrent = 3, MaxConcurrentAscent = 4,
	OverlapChance = 0.25, AscentSpeedMult = 1.25,
	Unlock = { Shark = 100, Squid = 250, Crawler = 150, Swarm = 400 },
	Weights = { Shark = 3, Squid = 3, Crawler = 2, Swarm = 1.5 },
}

Config.Money = { PerMeter = 0.5, SurviveBonus = 250, ArtifactBonus = 250 }
Config.Shop = { EquipSlots = 3 }
Config.Match = { WaitSeconds = 15 }
Config.Run = { JoinWait = 20, EndDelay = 12 }

-- Traits apply crew-wide, each trait id counts once. Effects multiply; `flicker` adds.
Config.Traits = {
	battery_cell    = { name = "Extended Battery", cost = 400, effects = { battery = 1.3, flicker = 1 },
	                    drawback = "Light flickers" },
	wide_beam       = { name = "Wide Beam", cost = 300, effects = { lightCone = 1.4, lightDrain = 1.2 },
	                    drawback = "Light drains 20% more" },
	quick_hands     = { name = "Quick Hands", cost = 250, effects = { repair = 1.5 } },
	muffled_engine  = { name = "Muffled Engine", cost = 350, effects = { sharkReaction = 1.5, thrust = 0.85 },
	                    drawback = "15% less thrust" },
	big_extinguisher = { name = "Big Extinguisher", cost = 200, effects = { extCapacity = 1.6 } },
	rebreather      = { name = "Rebreather", cost = 250, effects = { oxygen = 1.5 } },
}

return Config
