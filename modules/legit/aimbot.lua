---@diagnostic disable: undefined-global
-- modules/legit/aimbot.lua
-- Implements a basic aimbot functionality.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Aimbot = {}

-- Cache target to avoid re-calculating every frame
local CurrentTarget = nil
local CurrentTargetPart = nil

function Aimbot.Update(dt)
    local success, err = pcall(function()
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
            target, targetPart = Common.GetBestTarget(targetCheck)
        end

        if not target or not targetPart then
            CurrentTarget = nil
            CurrentTargetPart = nil
            return
        end

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
        local direction = (targetPosition - Camera.CFrame.Position).Unit

        -- Calculate new CFrame for the camera
        local newCFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + direction)

        -- Apply smoothing
        if Config.Aimbot.Smoothing > 0 then
            Camera.CFrame = Camera.CFrame:Lerp(newCFrame, 1 / Config.Aimbot.Smoothing)
        else
            Camera.CFrame = newCFrame
        end
    end)

    if not success then
        warn("[Aimbot] Error in Update: " .. tostring(err))
    end
end

function Aimbot.Init()
    -- Any initialization logic for Aimbot if needed
end

return Aimbot
