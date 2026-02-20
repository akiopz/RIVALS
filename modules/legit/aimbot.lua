---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field
-- modules/legit/aimbot.lua
-- Implements a basic aimbot functionality.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = Common.GetSafeService("Players")
local UserInputService = Common.GetSafeService("UserInputService")
local vim = Common.GetSafeService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Aimbot = {}

-- Cache target to avoid re-calculating every frame
local CurrentTarget = nil
local CurrentTargetPart = nil
local lastScanTime = 0
local scanInterval = 0.05 -- Scan for new target every 50ms (20 FPS) instead of every frame

local function isValidTarget(player, part)
    if not player or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
        return false
    end
    if not part or not part:IsA("BasePart") then
        return false
    end
    -- Team check
    if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then
        return false
    end
    return true
end

local function targetCheck(player, part)
    if not isValidTarget(player, part) then return false end

    -- Rage Mode: Ignore WallCheck if enabled
    if Config.Aimbot.Mode == "Rage" then
        return true
    end

    -- Visibility check: If WallCheck is true, target must be visible.
    if Config.Aimbot.WallCheck and not Common.IsVisible(player, part) then
        return false
    end
    return true
end

function Aimbot.Update(dt)
    -- Robustness: Check dependencies
    if not LocalPlayer or not LocalPlayer.Character then return end
    if not Camera or not Camera.Parent then Camera = workspace.CurrentCamera end
    if not Camera then return end

    if not Config.Aimbot.Enabled then
        CurrentTarget = nil
        CurrentTargetPart = nil
        return
    end

    -- Check if aimbot key is pressed
    local isAiming = false
    if Common.IsMobile then
        isAiming = true
    else
        local key = Config.Aimbot.Key
        if typeof(key) == "EnumItem" then
            if key.EnumType == Enum.UserInputType then
                isAiming = UserInputService:IsMouseButtonPressed(key)
            elseif key.EnumType == Enum.KeyCode then
                isAiming = UserInputService:IsKeyDown(key)
            end
        elseif typeof(key) == "string" then
            if key == "MouseButton1" or key == "MB1" then
                isAiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            elseif key == "MouseButton2" or key == "MB2" then
                isAiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            else
                local success, keyCode = pcall(function() return Enum.KeyCode[key] end)
                if success and keyCode then
                    isAiming = UserInputService:IsKeyDown(keyCode)
                end
            end
        end
    end

    if not isAiming then
        CurrentTarget = nil
        CurrentTargetPart = nil
        return
    end

    -- [Optimization] Target Validation & Caching
    local target, targetPart = nil, nil

    -- 1. Check if we have a cached target that is still valid
    if CurrentTarget and CurrentTargetPart and isValidTarget(CurrentTarget, CurrentTargetPart) then
        local valid = false
        
        -- Rage Mode: Skip FOV/Vis checks, just stick to target
        if Config.Aimbot.Mode == "Rage" then
            valid = true
        else
            -- Legit Mode: Check FOV and Visibility
            local screenPos, onScreen = Camera:WorldToViewportPoint(CurrentTargetPart.Position)
            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                local fovDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

                if fovDistance <= Config.Aimbot.FieldOfView then
                     -- Only check visibility if WallCheck is ON
                     if not Config.Aimbot.WallCheck or Common.IsVisible(CurrentTarget, CurrentTargetPart) then
                        valid = true
                     end
                end
            end
        end
        
        if valid then
            target = CurrentTarget
            targetPart = CurrentTargetPart
        end
    end

    -- 2. If cached target is invalid/lost, scan for new one
    if not target then
        if tick() - lastScanTime >= scanInterval then
            target, targetPart = Common.GetBestTarget(targetCheck)
            lastScanTime = tick()
        else
            -- Optimization: Return early if waiting for next scan
            return
        end
    end

    if not target or not targetPart then
        CurrentTarget = nil
        CurrentTargetPart = nil
        return
    end

    -- Update Cache
    CurrentTarget = target
    CurrentTargetPart = targetPart
    
    -- Calculate target position
    local targetPosition = targetPart.Position

    -- Apply prediction
    if Config.Aimbot.Prediction > 0 and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local velocity = target.Character.HumanoidRootPart.Velocity
        targetPosition = targetPosition + (velocity * Config.Aimbot.Prediction)
    end

    -- Calculate direction to target
    local diff = targetPosition - Camera.CFrame.Position
    if diff.Magnitude < 0.1 then return end -- Avoid NaN
    local direction = diff.Unit

    -- Aim Method: Camera vs Mouse
    if Config.Aimbot.AimMethod == "Mouse" then
        local targetScreenPos, onScreen = Camera:WorldToViewportPoint(targetPosition)
        if onScreen then
            local mouseLocation = UserInputService:GetMouseLocation()
            local deltaX = targetScreenPos.X - mouseLocation.X
            local deltaY = targetScreenPos.Y - mouseLocation.Y
            
            -- Apply Smoothing
            local smoothFactor = Config.Aimbot.Smoothing
            if Config.Aimbot.Mode == "Rage" then smoothFactor = 0 end -- Instant lock

            if smoothFactor > 0 then
                deltaX = deltaX / smoothFactor
                deltaY = deltaY / smoothFactor
            end
            
            -- Apply Max Turn Speed (Cap delta)
            local maxDelta = 50 
            if Config.Aimbot.Mode == "Rage" then maxDelta = 9999 end

            if math.abs(deltaX) > maxDelta then 
                if deltaX > 0 then deltaX = maxDelta else deltaX = -maxDelta end
            end
            if math.abs(deltaY) > maxDelta then 
                if deltaY > 0 then deltaY = maxDelta else deltaY = -maxDelta end
            end

            -- Move Mouse
            if mousemoverel then
                mousemoverel(deltaX, deltaY)
            elseif Input and Input.MoveMouse then 
                Input.MoveMouse(deltaX, deltaY)
            elseif vim then 
                 vim:SendMouseMoveEvent(mouseLocation.X + deltaX, mouseLocation.Y + deltaY, 0, game)
            end
        end
    else
        -- Camera Aimbot (CFrame)
        local newCFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + direction)

        -- Rage Mode: Instant Lock
        if Config.Aimbot.Mode == "Rage" then
             Camera.CFrame = newCFrame
             return
        end

        -- Legit Mode: Smooth Lock
        local maxDegreesPerFrame = 10 
        local currentLook = Camera.CFrame.LookVector
        local targetLook = direction
        local dot = math.clamp(currentLook:Dot(targetLook), -1, 1)
        local angle = math.acos(dot)
        local maxAngle = math.rad(maxDegreesPerFrame)
        
        if angle > maxAngle then
            local fraction = maxAngle / angle
            newCFrame = Camera.CFrame:Lerp(newCFrame, fraction)
        end

        if Config.Aimbot.Smoothing > 0 then
            local jitter = (math.random() - 0.5) * 0.1 
            local smoothFactor = (1 / Config.Aimbot.Smoothing) + jitter
            smoothFactor = math.clamp(smoothFactor, 0.01, 1) 
            
            local dist = (targetPosition - Camera.CFrame.Position).Magnitude
            if dist < 20 then
                 smoothFactor = smoothFactor * 1.5 -- Faster at close range
            elseif dist > 100 then
                 smoothFactor = smoothFactor * 0.8 -- Slower/more precise at long range
            end
            
            Camera.CFrame = Camera.CFrame:Lerp(newCFrame, smoothFactor)
        else
            Camera.CFrame = newCFrame
        end
    end
end

function Aimbot.Init()
    -- Any initialization logic for Aimbot if needed
end

return Aimbot
