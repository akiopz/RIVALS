---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field
-- modules/visuals/world.lua
-- Handles world-related visuals like crosshairs using ScreenGui (Safer than Drawing API).

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
if not Config then 
    warn("World Module: Failed to load Config") 
    return {} 
end
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local CoreGui = Common.GetSafeService("CoreGui")
local Players = Common.GetSafeService("Players")
local LocalPlayer = Players.LocalPlayer

local World = {}

local screenGui
local crosshairFrame

function World.Init()
    -- Create ScreenGui with Randomized Name
    local screenGuiName = tostring(math.random(1000000, 9999999))
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = screenGuiName
    screenGui.ResetOnSpawn = false
    
    -- Apply Protection
    Common.ProtectGui(screenGui)

    -- Create Crosshair (Circle)
    crosshairFrame = Instance.new("Frame")
    crosshairFrame.Name = "Crosshair"
    crosshairFrame.Size = UDim2.new(0, 8, 0, 8)
    crosshairFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    crosshairFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    crosshairFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    crosshairFrame.BackgroundTransparency = 0.5
    crosshairFrame.BorderSizePixel = 0
    crosshairFrame.Visible = false
    crosshairFrame.Parent = screenGui
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0) -- Make it round
    uiCorner.Parent = crosshairFrame
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Thickness = 1
    uiStroke.Color = Color3.new(0, 0, 0)
    uiStroke.Parent = crosshairFrame

    -- Cleanup
    table.insert(getgenv().Rivals_Cleanup_Functions, function()
        if screenGui then pcall(function() screenGui:Destroy() end) end
    end)
end

function World.Update(dt)
    if not Config.Main.Enabled then
        if crosshairFrame then crosshairFrame.Visible = false end
        return
    end

    if Config.World.Crosshair then
        if crosshairFrame then
            crosshairFrame.Visible = true
            crosshairFrame.BackgroundColor3 = Config.World.SkyColor.Color or Color3.new(1, 1, 1) -- Use some color
            -- Actually let's just use white for now or add a specific config
            crosshairFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Green default
        end
    else
        if crosshairFrame then crosshairFrame.Visible = false end
    end
end

return World
