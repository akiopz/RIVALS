---@diagnostic disable: undefined-global
-- modules/visuals/esp.lua
-- Implements ESP (Extra Sensory Perception) visuals using BillboardGui and Highlight (Safer than Drawing API).

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
if not Config then 
    warn("ESP Module: Failed to load Config") 
    return {} 
end
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = Common.GetSafeService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = Common.GetSafeService("CoreGui")
local RunService = Common.GetSafeService("RunService") -- Added RunService

local ESP = {}

-- Store active visuals
local PlayerVisuals = {} -- {player = {highlight = Instance, billboard = Instance}}
local lastUpdate = 0
local updateInterval = 0.1 -- Update every 100ms (10 FPS) instead of every frame (60 FPS)

-- Helper to get safe parent
local function getSafeParent()
    if gethui then return gethui() end
    local success, coreGui = pcall(function() return Common.GetSafeService("CoreGui") end)
    if success and coreGui then
        return coreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- Helper to create Highlight
local function CreateHighlight(player)
    if not player.Character then return nil end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = tostring(math.random(100000, 999999)) -- [Bypass] Name Spoofing
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.FillColor = Config.ESP.Color
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = player.Character
    
    local success, parent = pcall(getSafeParent)
    if success and parent then
        highlight.Parent = parent
    else
        highlight.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    return highlight
end

-- Helper to create BillboardGui
local function CreateBillboard(player)
    if not player.Character or not player.Character:FindFirstChild("Head") then return nil end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = tostring(math.random(100000, 999999)) -- [Bypass] Name Spoofing
    billboard.Adornee = player.Character:FindFirstChild("Head")
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    
    local success, parent = pcall(getSafeParent)
    if success and parent then
        billboard.Parent = parent
    else
        billboard.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard
    
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "DistanceLabel"
    distanceLabel.Size = UDim2.new(1, 0, 0, 15)
    distanceLabel.Position = UDim2.new(0, 0, 0, 20)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = "0m"
    distanceLabel.TextColor3 = Color3.new(1, 1, 1)
    distanceLabel.TextStrokeTransparency = 0
    distanceLabel.TextSize = 12
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.Parent = billboard

    local healthBarBg = Instance.new("Frame")
    healthBarBg.Name = "HealthBarBg"
    healthBarBg.Size = UDim2.new(0, 4, 0, 40)
    healthBarBg.Position = UDim2.new(0, -10, 0, 0)
    healthBarBg.BackgroundColor3 = Color3.new(0, 0, 0)
    healthBarBg.BorderSizePixel = 0
    healthBarBg.Parent = billboard
    
    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Size = UDim2.new(1, -2, 1, -2)
    healthBar.Position = UDim2.new(0, 1, 0, 1)
    healthBar.BackgroundColor3 = Color3.new(0, 1, 0)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = healthBarBg

    return billboard
end

local function getPlayerColor(player)
    if Config.ESP.Rainbow then
        return Color3.fromHSV(tick() % 5 / 5, 1, 1)
    elseif Config.ESP.TeamCheck and player.Team == LocalPlayer.Team then
        return Color3.fromRGB(0, 255, 0)
    else
        return Config.ESP.Color
    end
end

function ESP.Update(player)
    -- Throttling: Check if enough time has passed since last global update
    -- Note: Since this is called per player in a loop (usually), we should throttle the loop caller or handle it here.
    -- If this function is called inside a loop over all players, we can just return early if time not met.
    -- However, the main loop in rivals_v5_modular.lua calls this per frame for all players.
    -- To optimize properly, we should only process a subset of players per frame or skip frames entirely.
    
    if tick() - lastUpdate < updateInterval then
        return
    end
    
    -- We need to update lastUpdate only once per frame cycle, not per player call.
    -- But since we don't control the loop here easily without static variable...
    -- Let's assume the caller handles the loop.
    -- If the caller calls ESP.Update(player), it expects an update.
    -- But we can optimize by checking distance and updating less frequently for far players.
    
    if not Config.ESP.Enabled or not player or player == LocalPlayer then
        -- Cleanup if disabled
        if PlayerVisuals[player] then
            if PlayerVisuals[player].highlight then pcall(function() PlayerVisuals[player].highlight:Destroy() end) end
            if PlayerVisuals[player].billboard then pcall(function() PlayerVisuals[player].billboard:Destroy() end) end
            PlayerVisuals[player] = nil
        end
        return
    end

    if not player.Character or not player.Character:FindFirstChild("Humanoid") or not player.Character:FindFirstChild("HumanoidRootPart") or player.Character.Humanoid.Health <= 0 then
        -- Hide but don't destroy yet if just respawning, or destroy? Better destroy to be safe.
        if PlayerVisuals[player] then
            if PlayerVisuals[player].highlight then PlayerVisuals[player].highlight.Enabled = false end
            if PlayerVisuals[player].billboard then PlayerVisuals[player].billboard.Enabled = false end
        end
        return
    end

    -- [Bypass] Trap Check
    if Common.IsTrap(player) then
        if PlayerVisuals[player] then
            if PlayerVisuals[player].highlight then PlayerVisuals[player].highlight.Enabled = false end
            if PlayerVisuals[player].billboard then PlayerVisuals[player].billboard.Enabled = false end
        end
        return
    end

    -- Init visuals if missing
    if not PlayerVisuals[player] then
        PlayerVisuals[player] = {}
    end

    local visuals = PlayerVisuals[player]
    local color = getPlayerColor(player)
    
    -- [Bypass] Render Distance Check
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local dist = (root.Position - workspace.CurrentCamera.CFrame.Position).Magnitude
    
    -- Dynamic Throttling based on distance
    -- Close players update every frame (or close to it)
    -- Far players update less frequently
    -- This requires persistent state per player, which we have in PlayerVisuals
    
    if not PlayerVisuals[player] then PlayerVisuals[player] = {lastUpdate = 0} end
    local pVis = PlayerVisuals[player]
    
    local playerUpdateInterval = 0
    if dist < 100 then
        playerUpdateInterval = 0 -- Every frame
    elseif dist < 300 then
        playerUpdateInterval = 0.05 -- 20 FPS
    else
        playerUpdateInterval = 0.1 -- 10 FPS
    end
    
    if tick() - (pVis.lastUpdate or 0) < playerUpdateInterval then
        return
    end
    pVis.lastUpdate = tick()
    
    if dist > 3000 then -- Don't render if > 3000 studs
        if visuals.highlight then visuals.highlight.Enabled = false end
        if visuals.billboard then visuals.billboard.Enabled = false end
        return
    end

    -- [Bypass] Off-Screen Check (Optional: Disable if behind camera)
    local _, onScreen = workspace.CurrentCamera:WorldToViewportPoint(root.Position)
    if not onScreen then
         -- We might want to keep chams (highlight) visible through walls, so only hide billboard?
         -- Or hide both if performance/safety is concern.
         -- For now, let's keep Highlight visible (wallhack) but maybe hide text to reduce clutter?
         -- Actually, hiding completely when off-screen is safer but defeats the purpose of ESP (seeing through walls/behind).
         -- The "Bypass" part is mainly about not spamming updates.
    end

    -- HIGHLIGHT (Box/Chams)
    if Config.ESP.Boxes then
        if not visuals.highlight then
            visuals.highlight = CreateHighlight(player)
            -- Register cleanup
            table.insert(getgenv().Rivals_Cleanup_Functions, function()
                if visuals.highlight then pcall(function() visuals.highlight:Destroy() end) end
            end)
        end
        if visuals.highlight then
            visuals.highlight.Enabled = true
            visuals.highlight.FillColor = color
            visuals.highlight.OutlineColor = Color3.new(1, 1, 1)
            visuals.highlight.Adornee = player.Character
        end
    else
        if visuals.highlight then visuals.highlight.Enabled = false end
    end

    -- NAMES / HEALTH (Billboard)
    if Config.ESP.Names or Config.ESP.Health then
        if not visuals.billboard then
            visuals.billboard = CreateBillboard(player)
            -- Register cleanup
            table.insert(getgenv().Rivals_Cleanup_Functions, function()
                if visuals.billboard then pcall(function() visuals.billboard:Destroy() end) end
            end)
        end

        if visuals.billboard then
            visuals.billboard.Enabled = true
            visuals.billboard.Adornee = player.Character:FindFirstChild("Head")
            
            local nameLabel = visuals.billboard:FindFirstChild("NameLabel")
            local distanceLabel = visuals.billboard:FindFirstChild("DistanceLabel")
            local healthBarBg = visuals.billboard:FindFirstChild("HealthBarBg")
            
            if Config.ESP.Names then
                nameLabel.Visible = true
                nameLabel.Text = player.Name
                nameLabel.TextColor3 = color
                
                local dist = (player.Character.HumanoidRootPart.Position - workspace.CurrentCamera.CFrame.Position).Magnitude
                distanceLabel.Visible = true
                distanceLabel.Text = math.floor(dist) .. "m"
            else
                nameLabel.Visible = false
                distanceLabel.Visible = false
            end
            
            if Config.ESP.Health then
                healthBarBg.Visible = true
                local humanoid = player.Character:FindFirstChild("Humanoid")
                local healthBar = healthBarBg:FindFirstChild("HealthBar")
                if humanoid and healthBar then
                    local ratio = humanoid.Health / humanoid.MaxHealth
                    healthBar.Size = UDim2.new(1, -2, ratio, -2)
                    healthBar.Position = UDim2.new(0, 1, 1 - ratio, 1) -- Fill from bottom
                    healthBar.BackgroundColor3 = Color3.fromRGB(255 * (1 - ratio), 255 * ratio, 0)
                end
            else
                healthBarBg.Visible = false
            end
        end
    else
        if visuals.billboard then visuals.billboard.Enabled = false end
    end
end

function ESP.Init()
    -- Clear old visuals
    for _, v in pairs(PlayerVisuals) do
        if v.highlight then v.highlight:Destroy() end
        if v.billboard then v.billboard:Destroy() end
    end
    PlayerVisuals = {}
end

return ESP
