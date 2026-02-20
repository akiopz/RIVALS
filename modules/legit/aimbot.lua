---@diagnostic disable: undefined-global
-- modules/legit/aimbot.lua
-- Implements a basic aimbot functionality.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local vim = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Aimbot = {}

-- Cache target to avoid re-calculating every frame
local CurrentTarget = nil
local CurrentTargetPart = nil
local lastScanTime = 0
local scanInterval = 0.05 -- Scan for new target every 50ms (20 FPS) instead of every frame

function Aimbot.Update(dt)
    local success, err = pcall(function()
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
        if not UserInputService:IsKeyDown(Config.Aimbot.Key) then
            CurrentTarget = nil
            CurrentTargetPart = nil
            return
        end

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

            -- Visibility check: If WallCheck is false, target must be visible.
            -- If WallCheck is true, visibility is not a strict requirement for initial selection,
            -- but we might still prioritize visible targets.
            if not Config.Aimbot.WallCheck and not Common.IsVisible(player, part) then
                return false
            end
            return true
        end

        local target, targetPart = nil, nil

        -- If we have a current target, try to stick to it
        if CurrentTarget and CurrentTargetPart and isValidTarget(CurrentTarget, CurrentTargetPart) then
            -- Check if current target is still within FOV and meets visibility criteria
            local screenPos, onScreen = Camera:WorldToViewportPoint(CurrentTargetPart.Position)
            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                local fovDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

                if fovDistance <= Config.Aimbot.FieldOfView then
                    if Config.Aimbot.WallCheck or Common.IsVisible(CurrentTarget, CurrentTargetPart) then
                        target = CurrentTarget
                        targetPart = CurrentTargetPart
                    end
                end
            end
        end

        -- If no current target or current target is invalid/out of FOV, find a new one
        if not target then
            if tick() - lastScanTime >= scanInterval then
                target, targetPart = Common.GetBestTarget(targetCheck)
                lastScanTime = tick()
            else
                -- Skip scanning this frame, return early if no target
                return
            end
        end

        if not target or not targetPart then
            CurrentTarget = nil
            CurrentTargetPart = nil
            return
        end

        CurrentTarget = target
        CurrentTargetPart = targetPart
        
        -- Safety: Check Camera validity
        if not Camera or not Camera.Parent then
            Camera = workspace.CurrentCamera
        end

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
            -- Mouse Aimbot (mousemoverel)
            local targetScreenPos, onScreen = Camera:WorldToViewportPoint(targetPosition)
            if onScreen then
                local mouseLocation = UserInputService:GetMouseLocation()
                local deltaX = targetScreenPos.X - mouseLocation.X
                local deltaY = targetScreenPos.Y - mouseLocation.Y
                
                -- Apply Smoothing
                local smoothFactor = Config.Aimbot.Smoothing
                if smoothFactor > 0 then
                    deltaX = deltaX / smoothFactor
                    deltaY = deltaY / smoothFactor
                end
                
                -- Apply Max Turn Speed (Cap delta)
                local maxDelta = 50 -- Max pixels per frame
                if math.abs(deltaX) > maxDelta then deltaX = math.sign(deltaX) * maxDelta end
                if math.abs(deltaY) > maxDelta then deltaY = math.sign(deltaY) * maxDelta end

                -- Move Mouse
                if mousemoverel then
                    mousemoverel(deltaX, deltaY)
                elseif Input and Input.MoveMouse then -- Fluxus/Other
                    Input.MoveMouse(deltaX, deltaY)
                elseif vim then -- VirtualInputManager Fallback
                     vim:SendMouseMoveEvent(mouseLocation.X + deltaX, mouseLocation.Y + deltaY, 0, game)
                end
            end
        else
            -- Camera Aimbot (CFrame)
            -- Calculate new CFrame for the camera
            local newCFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + direction)

            -- [Bypass] Max Turn Speed Cap (Anti-Snap)
        -- Prevents instant 180 degree turns which flag anti-cheats
        local maxDegreesPerFrame = 10 -- Conservative limit (approx 600 degrees/sec at 60fps)
        local currentLook = Camera.CFrame.LookVector
        local targetLook = direction
        local dot = math.clamp(currentLook:Dot(targetLook), -1, 1)
        local angle = math.acos(dot)
        local maxAngle = math.rad(maxDegreesPerFrame)
        
        if angle > maxAngle then
            local fraction = maxAngle / angle
            newCFrame = Camera.CFrame:Lerp(newCFrame, fraction)
        end

        -- Apply smoothing with Humanization (Randomization) and Bezier Curve
        if Config.Aimbot.Smoothing > 0 then
            -- [Bypass] Add slight randomness to smoothing to mimic human hand movement
            local jitter = (math.random() - 0.5) * 0.1 -- +/- 0.05 variation
            local smoothFactor = (1 / Config.Aimbot.Smoothing) + jitter
            smoothFactor = math.clamp(smoothFactor, 0.01, 1) -- Ensure valid range
            
            -- [Bypass] Reaction Time Delay simulation (Skip update if just acquired target)
            -- We would need a timer for this, skipping for now to keep it simple but effective
            
            -- [Bypass] Bezier Curve Movement
            -- Instead of linear Lerp, use a quadratic Bezier curve control point
            -- Control point is slightly off the direct path to create a curve
            local currentPos = Camera.CFrame.Position
            local targetPos = newCFrame.Position
            
            -- Calculate a control point
            local midPoint = (currentPos + targetPos) / 2
            -- Add some offset to midPoint based on distance
            local offset = (targetPos - currentPos).Magnitude * 0.1
            local controlPoint = midPoint + Vector3.new(
                (math.random() - 0.5) * offset,
                (math.random() - 0.5) * offset,
                (math.random() - 0.5) * offset
            )
            
            -- Since CFrame Lerp is rotational too, and Bezier is positional,
            -- we will stick to CFrame:Lerp for rotation but apply position curve if needed.
            -- However, standard Lerp is safer for Camera.
            -- Let's stick to Lerp but with the variable smoothFactor (Humanization) we added.
            -- The Bezier implementation for Camera CFrame is complex and prone to snapping if not done perfectly.
            -- We will enhance the "Humanization" part instead.
            
            -- Enhanced Humanization: Dynamic Smoothing based on distance
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
        end -- Close AimMethod if/else
    end)

    if not success then
        warn("[Aimbot] Error in Update: " .. tostring(err))
    end
end

function Aimbot.Init()
    -- Any initialization logic for Aimbot if needed
end

return Aimbot
