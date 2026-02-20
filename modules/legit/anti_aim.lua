---@diagnostic disable: undefined-global
-- modules/legit/anti_aim.lua
-- Implements Anti-Aim (Spinbot/Jitter) logic.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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
                    -- Reset C0 to default first if needed, but keeping track of original is hard without caching
                    -- For now, just apply relative, but be careful of accumulation
                    -- Actually, C0 manipulation in Update loop without reset will cause crazy spinning
                    -- We should probably NOT do this in Update unless we reset it first
                    -- OR, we only set it once.
                    
                    -- Simple fix: Don't multiply C0 recursively.
                    -- But we don't know the original C0.
                    -- Let's skip Pitch for now or make it safer.
                    
                    -- Safer approach: Set TargetAngle for Motor6D if supported? No.
                end
            end
    end
end

return AntiAim
