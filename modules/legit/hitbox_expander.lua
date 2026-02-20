---@diagnostic disable: undefined-global
-- modules/legit/hitbox_expander.lua
-- Expands hitboxes of enemies to make them easier to hit.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

local HitboxExpander = {}

local lastUpdate = 0
local updateInterval = 0.5 -- Update only 2 times per second

function HitboxExpander.Update(dt)
    if not Config.HitboxExpander.Enabled then return end
    
    -- Safety: Don't run if we are dead or loading
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    -- Throttling: Check update interval
    if tick() - lastUpdate < updateInterval then return end
    lastUpdate = tick()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            -- Team Check
            local isTeammate = Config.HitboxExpander.TeamCheck and player.Team == LocalPlayer.Team
            
            if not isTeammate then
                local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    rootPart.Size = Vector3.new(Config.HitboxExpander.Size, Config.HitboxExpander.Size, Config.HitboxExpander.Size)
                    rootPart.Transparency = Config.HitboxExpander.Transparency
                    rootPart.CanCollide = false
                end
            end
        end
    end
end

return HitboxExpander
