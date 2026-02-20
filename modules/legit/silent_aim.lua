---@diagnostic disable: deprecated
---@diagnostic disable: undefined-global
-- modules/legit/silent_aim.lua
-- Implements silent aim functionality by hooking __index and __namecall.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local SilentAim = {}

-- Cache valid target to avoid re-calculating every frame/hook call
local CurrentTarget = nil
local CurrentTargetPart = nil
local CurrentTargetCFrame = nil

-- Update function to be called every frame
function SilentAim.Update()
    if not Config.SilentAim.Enabled then
        CurrentTarget = nil
        CurrentTargetPart = nil
        CurrentTargetCFrame = nil
        return
    end

    local function targetCheck(player, part)
        -- If Visible Check is disabled, everything is valid
        if not Config.SilentAim.VisibleCheck then return true end
        
        -- Check standard visibility
        if Common.IsVisible(player, part) then return true end
        
        -- TODO: Add Backtrack check here if implemented
        
        return false
    end

    local target, targetPart = Common.GetBestTarget(targetCheck)
    if not target or not targetPart then
        CurrentTarget = nil
        CurrentTargetPart = nil
        CurrentTargetCFrame = nil
        return
    end

    -- FOV Check (Silent Aim usually doesn't have FOV, but for consistency with Aimbot)
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    local mousePos = game:GetService("UserInputService"):GetMouseLocation()
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

    if dist > Config.Aimbot.FieldOfView then -- Using Aimbot FOV for now
        CurrentTarget = nil
        CurrentTargetPart = nil
        CurrentTargetCFrame = nil
        return
    end

    -- TODO: Add more advanced visibility/raycast checks here if needed

    CurrentTarget = target
    CurrentTargetPart = targetPart
    CurrentTargetCFrame = targetPart.CFrame
end

function SilentAim.GetTarget()
    -- Simply return cached target
    -- Apply RNG here
    if CurrentTarget and CurrentTargetPart then
        if math.random(0, 100) > Config.SilentAim.HitChance then return nil, nil, nil end
        
        -- Headshot Chance override
        local finalPart = CurrentTargetPart
        local finalCFrame = CurrentTargetCFrame
        
        if math.random(0, 100) <= (Config.SilentAim.HeadshotChance or 100) then
            if CurrentTarget.Character then
                local head = CurrentTarget.Character:FindFirstChild("Head")
                if head then 
                    finalPart = head 
                    finalCFrame = head.CFrame
                end
            end
        end
        
        return CurrentTarget, finalPart, finalCFrame
    end
    return nil, nil, nil
end

-- Export GetTarget to global environment for hook re-use
getgenv().Rivals_GetTarget = SilentAim.GetTarget

function SilentAim.Init()
    -- Prevent multiple hooks stacking on re-execution
    if getgenv().Rivals_SilentAim_Hooked then return end
    getgenv().Rivals_SilentAim_Hooked = true

    local mt = getrawmetatable(game)
    if setreadonly then setreadonly(mt, false) end
    
    local oldIndex
    local oldNamecall
    
    local newIndex = newcclosure(function(self, k)
        -- FAST PATH: Only interfere if key is interesting
        if k ~= "Hit" and k ~= "Target" then
            return oldIndex(self, k)
        end

        -- Safety Checks
        if not Config.SilentAim.Enabled or checkcaller() then
            return oldIndex(self, k)
        end
        
        -- Type Checking (Safe)
        if typeof(self) == "Instance" and (self:IsA("Mouse") or self:IsA("PlayerMouse")) then
             local getTarget = getgenv().Rivals_GetTarget
             if getTarget then
                 local target, targetPart, targetCFrame = getTarget()
                 
                 if target and targetPart then
                     if k == "Hit" then
                         return targetCFrame or targetPart.CFrame
                     elseif k == "Target" then
                         return targetPart
                     end
                 end
             end
        end
        
        return oldIndex(self, k)
    end)
    
    local newNamecall = newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        
        if Config.SilentAim.Enabled and not checkcaller() then
            if method == "Raycast" and self == workspace then
                local getTarget = getgenv().Rivals_GetTarget
                if getTarget then
                    local target, targetPart = getTarget()
                    if target and targetPart then
                        local origin = args[1]
                        -- Check args validity
                        if origin and args[2] then
                            local direction = (targetPart.Position - origin).Unit * (args[2].Magnitude)
                            args[2] = direction
                            return oldNamecall(self, unpack(args))
                        end
                    end
                end
            end
            
            if method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
                 local getTarget = getgenv().Rivals_GetTarget
                 if getTarget then
                     local target, targetPart = getTarget()
                     if target and targetPart then
                         local ray = args[1]
                         if ray then
                             local newRay = Ray.new(ray.Origin, (targetPart.Position - ray.Origin).Unit * 5000)
                             args[1] = newRay
                             return oldNamecall(self, unpack(args))
                         end
                     end
                 end
            end
        end
        
        return oldNamecall(self, unpack(args))
    end)
    
    if hookmetamethod then
        oldIndex = hookmetamethod(game, "__index", newIndex)
        oldNamecall = hookmetamethod(game, "__namecall", newNamecall)
    else
        -- Fallback for older executors
        oldIndex = mt.__index
        oldNamecall = mt.__namecall
        mt.__index = newIndex
        mt.__namecall = newNamecall
    end
    
    if setreadonly then setreadonly(mt, true) end
end

return SilentAim
