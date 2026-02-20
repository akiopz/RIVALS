---@diagnostic disable: deprecated
---@diagnostic disable: undefined-global
-- modules/legit/silent_aim.lua
-- Implements silent aim functionality by hooking __index and __namecall.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = Common.GetSafeService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local SilentAim = {}

-- Cache valid target to avoid re-calculating every frame/hook call
local CurrentTarget = nil
local CurrentTargetPart = nil
local CurrentTargetCFrame = nil

-- Update function to be called every frame
function SilentAim.Update(dt)
    -- Lazy Load Hook: If enabled but not hooked, install hooks now
    if Config.SilentAim.Enabled and not getgenv().Rivals_SilentAim_Hooked then
        SilentAim.Init()
    end

    if not Config.SilentAim.Enabled then
        CurrentTarget = nil
        CurrentTargetPart = nil
        CurrentTargetCFrame = nil
        return
    end

    local function targetCheck(player, part)
        -- [Bypass] Trap Check
        if Common.IsTrap(player) then return false end

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
    
    -- [Bypass] Directional Sanity Check
    -- Ensure target is actually on screen to prevent "shooting backward"
    if not onScreen then
        CurrentTarget = nil
        CurrentTargetPart = nil
        CurrentTargetCFrame = nil
        return
    end
    
    local mousePos = Common.GetSafeService("UserInputService"):GetMouseLocation()
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
        if math.random() * 100 > Config.SilentAim.HitChance then return nil, nil, nil end
        
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

-- Export GetTarget (Internal use only, no global export)
-- getgenv().Rivals_GetTarget = SilentAim.GetTarget (REMOVED FOR SAFETY)

function SilentAim.Init()
    -- Only install hook if Silent Aim is ENABLED
    if not Config.SilentAim.Enabled then return end

    -- Prevent multiple hooks stacking on re-execution
    if getgenv().Rivals_SilentAim_Hooked then return end
    getgenv().Rivals_SilentAim_Hooked = true

    local mt = getrawmetatable(game)
    if setreadonly then setreadonly(mt, false) end
    
    local oldIndex
    local oldNamecall
    
    local function getAngle(v1, v2)
        return math.acos(math.clamp(v1.Unit:Dot(v2.Unit), -1, 1))
    end

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
             local target, targetPart, targetCFrame = SilentAim.GetTarget()
             
             if target and targetPart then
                 if k == "Hit" then
                     return targetCFrame or targetPart.CFrame
                 elseif k == "Target" then
                     return targetPart
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
                local target, targetPart = SilentAim.GetTarget()
                if target and targetPart then
                    local origin = args[1]
                    local direction = args[2]
                    
                    -- Check args validity
                    if origin and direction then
                        local newDirection = (targetPart.Position - origin)
                        
                        -- [Safety] Max Angle Check (Limit to 15 degrees to prevent rage-like snaps)
                        -- This prevents "shooting backwards" which triggers anti-cheat
                        local angle = getAngle(direction, newDirection)
                        if angle < math.rad(Config.SilentAim.FieldOfView or 15) then
                             args[2] = newDirection.Unit * direction.Magnitude
                             return oldNamecall(self, unpack(args))
                        end
                    end
                end
            end
            
            if method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
                 local target, targetPart = SilentAim.GetTarget()
                 if target and targetPart then
                     local ray = args[1]
                     if ray then
                         local origin = ray.Origin
                         local direction = ray.Direction
                         local newDirection = (targetPart.Position - origin)
                         
                         -- [Safety] Max Angle Check
                         local angle = getAngle(direction, newDirection)
                         if angle < math.rad(Config.SilentAim.FieldOfView or 15) then
                             local newRay = Ray.new(origin, newDirection.Unit * 5000)
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
        local success, err = pcall(function()
            oldIndex = hookmetamethod(game, "__index", newIndex)
            oldNamecall = hookmetamethod(game, "__namecall", newNamecall)
        end)
        if not success then
             warn("SilentAim Hook Failed: " .. tostring(err))
             -- Fallback or disable
             return
        end
    else
        -- Fallback for older executors
        warn("Executor does not support hookmetamethod")
    end
        oldIndex = mt.__index
        oldNamecall = mt.__namecall
        mt.__index = newIndex
        mt.__namecall = newNamecall
    end
    
    if setreadonly then setreadonly(mt, true) end
end

return SilentAim
