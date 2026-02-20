---@diagnostic disable: undefined-global
-- modules/legit/anti_aim.lua
-- Implements Anti-Aim (Spinbot/Jitter) logic.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

local AntiAim = {}

function AntiAim.Update(dt)
    if not Config.AntiAim.Enabled then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local rootPart = LocalPlayer.Character.HumanoidRootPart
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    
    -- Yaw Manipulation
    if Config.AntiAim.Type == "Spin" then
        rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(Config.AntiAim.SpinSpeed), 0)
    elseif Config.AntiAim.Type == "Jitter" then
        rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(math.random(-Config.AntiAim.YawOffset, Config.AntiAim.YawOffset)), 0)
    elseif Config.AntiAim.Type == "Backward" then
        rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, math.rad(180), 0)
    end
    
    -- Pitch Manipulation (Visual Only mostly, unless using specific exploit hooks)
    -- For standard R15/R6, we can try to manipulate Waist/Neck Motor6D C0/C1
    if Config.AntiAim.Pitch ~= "None" then
        local torso = LocalPlayer.Character:FindFirstChild("UpperTorso") or LocalPlayer.Character:FindFirstChild("Torso")
        if torso then
            local waist = torso:FindFirstChild("Waist") or torso:FindFirstChild("Motor6D") -- Adjust based on rig
             if waist then
                if Config.AntiAim.Pitch == "Down" then
                    waist.C0 = waist.C0 * CFrame.Angles(math.rad(-90), 0, 0)
                elseif Config.AntiAim.Pitch == "Up" then
                    waist.C0 = waist.C0 * CFrame.Angles(math.rad(90), 0, 0)
                elseif Config.AntiAim.Pitch == "Jitter" then
                     waist.C0 = waist.C0 * CFrame.Angles(math.rad(math.random(-45, 45)), 0, 0)
                end
             end
        end
    end
end

return AntiAim
