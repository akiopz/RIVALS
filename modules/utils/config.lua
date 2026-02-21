---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field
---@diagnostic disable: inject-field
-- Config Singleton Pattern
if getgenv().Rivals_Config_Instance then
    return getgenv().Rivals_Config_Instance
end

local Config = {
    Main = {
        Enabled = true, -- Default ON for usability
    },
    Aimbot = {
        Enabled = true, -- Default ON
        Mode = "Legit", -- "Legit" or "Rage"
        AimMethod = "Camera", -- Changed to Camera for better smoothness
        TeamCheck = true,
        TargetPart = "Head", -- Default, will be overridden if NearestPart is on
        Sensitivity = 1, -- 0 = Rage, 1 = Legit
        Smoothing = 5, -- Smoother by default (Higher = Slower/Smoother)
        FOV = 180, -- Increased default
        ShowFOV = true,
        NearestPart = true, -- Auto select nearest part to cursor
        Prediction = 0.165, -- Prediction factor (velocity * time)
        DynamicPrediction = true, -- [New] Auto-adjust prediction based on distance
        Shake = 0, -- Human-like shake intensity
        ReactionTime = 0, -- ms delay before aiming
        MissChance = 0, -- % chance to miss intentionally
        WallCheck = true, -- Check if target is visible
        KnockedCheck = true, -- [New] Ignore knocked players
        Key = Enum.UserInputType.MouseButton2, -- Right Click to Aim
        StickyAim = true, -- Keep locking the same target
        StickyStrength = 0.8, -- (0-1) 1 = Instant Lock when close, 0 = No extra stickiness
        VisibilityCheckInterval = 0.1, -- [New] Throttle visibility checks to prevent lag (seconds)
        AimLock = false, -- [New] Keep aiming at target even if outside FOV (within AimLockStrength)
        AimLockStrength = 0.5, -- [New] How much to "stick" to the target (0-1, 1 = full lock)
        RCS = false, -- [New] Recoil Control System
        RCSStrength = 0.8, -- [New] How much to compensate for recoil (0-1, 1 = full compensation)
        AutoFire = false, -- [New] Automatically fire when target is locked
        TargetPriority = "Closest" -- [New] "Closest", "LowestHealth", "HighestDamage"
    },
    SilentAim = {
        Enabled = false,
        HitChance = 100,
        HeadshotChance = 100,
        FieldOfView = 50,
        VisibleCheck = false
    },
    HitboxExpander = { -- Was MagicBullet
        Enabled = false,
        Size = 10, -- Hitbox Size
        Transparency = 0.5 -- Hitbox Transparency
    },
    AntiAim = {
        Enabled = false,
        Type = "Spin", -- Spin, Jitter, Backward
        Pitch = "None", -- None, Down, Up, Custom
        PitchAngle = -90,
        YawOffset = 0,
        SpinSpeed = 20,
        HeadOffset = 0 -- Vertical offset for head
    },
    RageBot = {
        FastLock = false,
        RapidFire = false,
        WallBang = false -- Shoot through walls
    },
    TriggerBot = {
        Enabled = false,
        Delay = 0.05,
        VisibilityCheck = true
    },
    ESP = {
        Enabled = true, -- Default ON
        TeamCheck = true,
        Boxes = true,
        Tracers = false,
        Names = true,
        Health = true,
        Skeleton = false, -- Skeleton ESP
        Color = Color3.fromRGB(255, 0, 0),
        Rainbow = false
    },
    SpectatorList = {
        Enabled = false,
        AntiSpectate = false, -- Enable Anti-Spectate
        Mode = "Crash" -- "Lag", "Crash"
    },
    AntiDetection = { -- [New] Auto Legit System
        Enabled = false, -- Default OFF for safety
        DynamicLegit = true, -- Auto adjust smoothing/FOV if spectated
        RandomizeAim = true, -- Add random offset to bone
        Humanize = true, -- Add human-like delays/misses
        AntiBan = false, -- [New] Block Kicks/Bans/Reports (Risky if detected)
        StaffDetection = false, -- [New] Alert if staff joins
        AntiLogger = false, -- [New] Block error logging
        InjectionBypass = true -- [New] Advanced injection protection (Keep ON for stability)
    },
    Backtrack = {
        Enabled = false,
        TimeLimit = 0.5, -- 500ms (Max)
        ShowGhosts = true,
        Color = Color3.fromRGB(0, 255, 255)
    },
    Resolver = { -- [New] Anti-Spinbot/Anti-AA
        Enabled = false,
        SpinThreshold = 15, -- Angular Velocity threshold
        ForcePart = "HumanoidRootPart" -- Part to lock when spinning
    },
    TPS = {
        Enabled = false,
        Distance = 10
    },
    Crosshair = {
        Enabled = false,
        Size = 10,
        Color = Color3.fromRGB(0, 255, 0)
    },
    BulletTracers = {
        Enabled = false,
        MagicCurve = false, -- Magic Bullet Visual Curve
        Color = Color3.fromRGB(255, 255, 255),
        Duration = 0.5,
        Rainbow = false
    },
    KillEffect = {
        Enabled = false,
        SoundId = "rbxassetid://6965860761" -- Example hit sound
    },
    Speed = {
        Enabled = false,
        Speed = 16
    },
    Fly = {
        Enabled = false,
        Speed = 50
    },
    InfiniteJump = {
        Enabled = false
    },
    BunnyHop = {
        Enabled = false,
        Boost = 0 -- 0 to 100 extra speed
    },
    NoClip = {
        Enabled = false
    },
    Fullbright = {
        Enabled = false
    },
    World = {
        Crosshair = false,
        SkyColor = {
            Enabled = false,
            Color = Color3.fromRGB(135, 206, 235), -- Default Sky Blue
            Time = 12 -- Time of day (0-24)
        }
    },
    Spectate = {
        Enabled = false,
        Target = nil
    },
    FakeLag = {
        Enabled = false,
        Limit = 6, -- Choke factor (1-14)
        Dynamic = true -- Randomize choke to look more natural
    },
    GUI = {
        Key = Enum.KeyCode.Insert, -- Menu Toggle Key
    },
    UI = {
        BackgroundImage = "rbxassetid://6675147490", -- Default Anime Background (Replace with your ID)
        BackgroundTransparency = 0.5
    }
}

getgenv().Config = Config
getgenv().Rivals_Config_Instance = Config
return Config
