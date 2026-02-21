---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field
-- modules/legit/aimbot.lua
-- Implements a basic aimbot functionality.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")
local Prediction = getgenv().RivalsLoad("modules/utils/prediction.lua")
local Smoothing = getgenv().RivalsLoad("modules/utils/smoothing.lua")
local InputSimulation = getgenv().RivalsLoad("modules/utils/input_simulation.lua")

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
    local target = CurrentTarget
    local targetPart = CurrentTargetPart

    -- 1. Check if we have a cached target that is still valid
    local isCachedTargetValid = false
    if target and targetPart then
        -- Rage Mode: Skip FOV/Vis checks, just stick to target
        if Config.Aimbot.Mode == "Rage" then
            isCachedTargetValid = true
        else
            -- Legit Mode: Check FOV and Visibility
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                local fovDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                
                local fov = Config.Aimbot.FOV or 180
                local effectiveFov = fov
                -- If AimLock is enabled, expand the FOV for existing targets
                if Config.Aimbot.AimLock then
                    effectiveFov = fov + (fov * Config.Aimbot.AimLockStrength) -- Expand FOV based on AimLockStrength
                end

                if fovDistance <= effectiveFov then
                     -- Only check visibility if WallCheck is ON
                     if not Config.Aimbot.WallCheck or Common.IsVisible(target, targetPart) then
                        isCachedTargetValid = true
                     end
                end
            end
        end
    end
    
    if not isCachedTargetValid then
        target = nil
        targetPart = nil
    end

    -- 2. If cached target is invalid/lost, scan for new one
    if not target then
        -- [Optimization] Throttle scanning to avoid lag
        if tick() - lastScanTime < scanInterval then
            return -- Wait for next scan interval
        end
        lastScanTime = tick()

        -- Use Common.GetBestTarget which now has frame caching!
        target, targetPart = Common.Targeting.GetBestTarget()
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

    -- Apply prediction using the new Prediction module
    if Config.Aimbot.Prediction > 0 and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        targetPosition = Prediction.PredictPosition(
            target,
            target.Character.HumanoidRootPart,
            dt,
            Config.Aimbot.Prediction,
            Config.Aimbot.DynamicPrediction,
            Camera
        )
    end

    -- [NEW] Apply RCS offset to targetPosition
    if Config.Aimbot.RCS and isAiming then
        -- A simple RCS: apply a downward vertical offset to the target position
        -- This is a simplified model. More advanced RCS might consider weapon recoil patterns.
        -- The multiplier 0.5 is arbitrary and can be tuned.
        targetPosition = targetPosition + Vector3.new(0, -Config.Aimbot.RCSStrength * 0.5, 0)
    end

    -- Calculate direction to target
    local diff = targetPosition - Camera.CFrame.Position
    if diff.Magnitude < 0.1 then return end -- Avoid NaN
    local direction = diff.Unit

    -- [NEW] AutoFire
    if Config.Aimbot.AutoFire and isAiming then
        InputSimulation.SimulateKeyPress(Enum.UserInputType.MouseButton1)
    end

    -- Aim Method: Camera vs Mouse
    if Config.Aimbot.AimMethod == "Mouse" then
        local targetScreenPos, onScreen = Camera:WorldToViewportPoint(targetPosition)
        if onScreen then
            local mouseLocation = UserInputService:GetMouseLocation()
            local deltaX = targetScreenPos.X - mouseLocation.X
            local deltaY = targetScreenPos.Y - mouseLocation.Y
            
            -- Apply Smoothing
            local smoothFactor = Config.Aimbot.Smoothing or 5
            if Config.Aimbot.Mode == "Rage" then smoothFactor = 1 end -- Instant lock

            if smoothFactor > 1 then
                -- Use humanized smoothing for mouse movement
                deltaX = Smoothing.Humanized(deltaX, smoothFactor, Config.Aimbot.HumanizationStrength or 0.1)
                deltaY = Smoothing.Humanized(deltaY, smoothFactor, Config.Aimbot.HumanizationStrength or 0.1)
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
            InputSimulation.MoveMouseRelative(deltaX, deltaY)
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
        if Config.Aimbot.AimLock and Config.Aimbot.Smoothing == 1 then
            maxDegreesPerFrame = 360 -- Effectively remove the limit for instant lock
        end
        local currentLook = Camera.CFrame.LookVector
        local targetLook = direction
        local dot = math.clamp(currentLook:Dot(targetLook), -1, 1)
        local angle = math.acos(dot)
        local maxAngle = math.rad(maxDegreesPerFrame)
        
        if angle > maxAngle then
            local fraction = maxAngle / angle
            newCFrame = Camera.CFrame:Lerp(newCFrame, fraction)
        end

        if Config.Aimbot.Smoothing > 0 and Config.Aimbot.Mode ~= "Rage" then
            local baseSmoothFactor = (1 / Config.Aimbot.Smoothing)
            local smoothFactor = Smoothing.GetLerpAlpha(baseSmoothFactor, Config.Aimbot.HumanizationStrength or 0.1)
            
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
