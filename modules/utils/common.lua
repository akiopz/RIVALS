---@diagnostic disable: undefined-global
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Config = getgenv().RivalsLoad("modules/utils/config.lua")

local Common = {}

Common.CurrentTarget = nil
Common.CurrentPart = nil

function Common.IsKnocked(player)
    if not player or not player.Character then return false end
    local char = player.Character
    
    -- 1. Attribute Check
    if char:GetAttribute("Knocked") == true or char:GetAttribute("Downed") == true or char:GetAttribute("Reviving") == true then
        return true
    end
    
    -- 2. Child Object Check
    if char:FindFirstChild("Knocked") or char:FindFirstChild("Downed") or char:FindFirstChild("Reviving") then
        return true
    end
    
    -- 3. Humanoid State Check (PlatformStand is common for knocked players)
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        if hum.Health <= 0 then return true end -- Dead check
        if hum.PlatformStand then return true end
        if hum:GetState() == Enum.HumanoidStateType.Physics then return true end
    end
    
    return false
end

function Common.IsVisible(target, part)
    -- WallBang Check
    if Config.RageBot.WallBang then return true end

    -- Check visibility based on active mode
    if Config.SilentAim.Enabled then
        if not Config.SilentAim.VisibleCheck then return true end
    else
        if not Config.Aimbot.WallCheck then return true end
    end
    
    local origin = Camera.CFrame.Position
    local direction = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    params.IgnoreWater = true
    
    local result
    local success = pcall(function()
        result = Workspace:Raycast(origin, direction.Unit * (direction.Magnitude - 0.1), params)
    end)
    
    if not success then return false end -- Assume not visible on error
    
    if result and result.Instance and not result.Instance:IsDescendantOf(target.Character) then
        return false
    end
    return true
end

function Common.GetNearestPart(player)
    local bestPart = nil
    local shortestDist = math.huge
    local mousePos = UserInputService:GetMouseLocation()
    
    if player and player.Character then
        -- Optimization: Check Head/Torso first. If close, stick to it.
        local priorityParts = {"Head", "HumanoidRootPart"}
        local allParts = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
        local partsToCheck = allParts

        -- If player is very far, just use Head or Torso to save performance
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if root and (root.Position - Camera.CFrame.Position).Magnitude > 300 then
             partsToCheck = priorityParts
        end
        
        for _, partName in ipairs(partsToCheck) do
            local part = player.Character:FindFirstChild(partName)
            if part then
                local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        bestPart = part
                    end
                end
            end
        end
    end
    return bestPart
end

function Common.GetResolvedPart(player, part)
    if not Config.Resolver.Enabled then return part end
    if not player or not player.Character then return part end
    
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        -- Anti-Spinbot Resolver
        local angVel = hrp.AssemblyAngularVelocity
        if angVel.Magnitude > Config.Resolver.SpinThreshold then
             return player.Character:FindFirstChild(Config.Resolver.ForcePart) or part
        end

        -- Anti-Air / Jumping Resolver
        local vel = hrp.Velocity
        if math.abs(vel.Y) > 5 then
            return player.Character:FindFirstChild("UpperTorso") or player.Character:FindFirstChild("HumanoidRootPart") or part
        end
    end
    return part
end

function Common.GetBestTarget(customVisibilityCheck)
    local mousePos = UserInputService:GetMouseLocation()
    
    -- Check if Aim Key is held to enable "Anywhere" locking
    local isAiming = false
    if Config.Aimbot.Key then
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
    
    if not Config.Aimbot.Enabled and not Config.SilentAim.Enabled and not Config.RageBot.FastLock and not isAiming then return nil, nil end
    
    local fov = Config.Aimbot.FOV
    if Config.SilentAim.Enabled then fov = Config.SilentAim.FieldOfView end
    if Config.RageBot.FastLock then fov = math.huge end
    
    if isAiming then
        fov = math.huge -- Lock anywhere if key is held
    end
    
    -- [Sticky Aim Check]
    local player = Common.CurrentTarget
    local part = Common.CurrentPart

    -- If key is held, force Sticky Aim logic regardless of config
    if player and part and (Config.Aimbot.StickyAim or isAiming) then
        if player.Parent and player.Character and part.Parent == player.Character then
             local valid = true
             if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team and player.Team ~= nil then valid = false end
             if Config.Aimbot.KnockedCheck and Common.IsKnocked(player) then valid = false end
             
             if valid then
                 local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                 if onScreen then
                     local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                     -- If aiming, fov is huge, so this will always pass
                     if dist < (fov * 1.2) then
                         if Common.IsVisible(player, part) then
                             return player, part
                         end
                     end
                 end
             end
        end
    end
    
    local bestTarget = nil
    local bestPart = nil
    local shortestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            -- Distance Check Optimization: Skip players > 5000 studs (unless Rage FastLock)
            -- Use RootPart for fast distance check
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                 local dist = (root.Position - Camera.CFrame.Position).Magnitude
                 if dist < 5000 or Config.RageBot.FastLock then
                    local validTarget = true
                    
                    if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team and player.Team ~= nil then
                        validTarget = false
                    end
                    
                    if validTarget and Config.Aimbot.KnockedCheck and Common.IsKnocked(player) then
                        validTarget = false
                    end
                    
                    if validTarget then
                        local part = nil
                        if Config.Aimbot.NearestPart then
                             part = Common.GetNearestPart(player)
                        else
                             part = player.Character:FindFirstChild(Config.Aimbot.TargetPart)
                             if not part and Config.Aimbot.TargetPart == "UpperTorso" then part = player.Character:FindFirstChild("Torso") end -- R6 Fallback
                             if not part then part = player.Character:FindFirstChild("Head") end -- Ultimate Fallback
                        end
                        
                        if part then
                            part = Common.GetResolvedPart(player, part)
                            
                            local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local distToMouse = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                                if distToMouse < fov then
                                    if distToMouse < shortestDist then
                                        -- Visibility Check (Most expensive, do last)
                                        local isVisible = false
                                        if customVisibilityCheck then
                                            isVisible = customVisibilityCheck(player, part)
                                        else
                                            isVisible = Common.IsVisible(player, part)
                                        end

                                        if isVisible then
                                            shortestDist = distToMouse
                                            bestTarget = player
                                            bestPart = part
                                        end
                                    end
                                end
                            end
                        end
                    end
                 end
            end
        end
    end
    
    -- Cache result
    Common.CurrentTarget = bestTarget
    Common.CurrentPart = bestPart
    
    return bestTarget, bestPart
end

return Common
