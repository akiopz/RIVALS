---@diagnostic disable: undefined-global
---@diagnostic disable: inject-field
---@diagnostic disable: undefined-field
---@diagnostic disable: lowercase-global
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Config = getgenv().RivalsLoad("modules/utils/config.lua")

local Common = {}

-- [Universal] Polyfill getgenv
if not getgenv then
    getgenv = function() return _G end
end

-- [Universal] Device Detection
Common.IsMobile = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").MouseEnabled
Common.IsXbox = game:GetService("GuiService"):IsTenFootInterface()

Common.DebugMode = false

function Common.Log(...)
    if Common.DebugMode then
        print("[Rivals V5]", ...)
    end
end

-- [Bypass] Safe Service Access
function Common.GetSafeService(serviceName)
    local service = game:GetService(serviceName)
    if cloneref then
        return cloneref(service)
    end
    return service
end

-- [Bypass] Error Suppression
function Common.SafeCall(func, ...)
    local success, result = xpcall(func, function(err)
        -- Suppress error, do not print to console to avoid detection
        if Common.DebugMode then
            warn("[SafeCall Error]", err)
        end
        return err
    end, ...)
    return success, result
end

-- [Bypass] GUI Protection
function Common.ProtectGui(gui)
    -- Try syn.protect_gui first (Synapse X / ScriptWare)
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
        gui.Parent = Common.GetSafeService("CoreGui")
        return
    end
    
    -- Try gethui (Universal)
    if gethui then
        local success, parent = pcall(gethui)
        if success and parent then
            gui.Parent = parent
            return
        end
    end
    
    -- Try other protectors
    if PROT_GUI then
        pcall(PROT_GUI, gui)
    end
    
    -- Fallback: CoreGui or PlayerGui
    local success, core = pcall(function() return Common.GetSafeService("CoreGui") end)
    if success and core then
        gui.Parent = core
    else
        local players = Common.GetSafeService("Players")
        local localPlayer = players.LocalPlayer
        if localPlayer then
            gui.Parent = localPlayer:WaitForChild("PlayerGui", 5)
        end
    end
end

Common.CurrentTarget = nil
Common.CurrentPart = nil
Common.LastTargetUpdateTime = 0
Common.CachedTarget = nil
Common.CachedPart = nil
Common.ValidEnemies = {}
Common.LastEnemyUpdateTime = 0

Common.Targeting = {}
Common.cachedVisibility = {}

-- [Targeting Module]
-- This module handles target acquisition, filtering, and selection.
-- It replaces the old Common.GetBestTarget logic with a more modular approach.

-- [Optimization] Update Valid Enemies List (Every 100ms)
function Common.Targeting.UpdateValidEnemies()
    if tick() - Common.LastEnemyUpdateTime > 0.1 then
        Common.ValidEnemies = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                local hum = player.Character:FindFirstChild("Humanoid")
                if root and hum and hum.Health > 0 then
                    local isEnemy = true
                    if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team and player.Team ~= nil then
                        isEnemy = false
                    end
                    
                    if isEnemy and Config.Aimbot.KnockedCheck and Common.IsKnocked(player) then
                        isEnemy = false
                    end
                    
                    if isEnemy and Common.IsTrap(player) then
                        isEnemy = false
                    end
                    
                    if isEnemy then
                        table.insert(Common.ValidEnemies, player)
                    end
                end
            end
        end
        Common.LastEnemyUpdateTime = tick()
    end
end

function Common.Targeting.GetPotentialTargets(customVisibilityCheck)
    Common.Targeting.UpdateValidEnemies() -- Ensure valid enemies list is up-to-date

    if not Camera or not Camera.Parent then Camera = Workspace.CurrentCamera end
    local mousePos = UserInputService:GetMouseLocation()
    
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
    
    if not Config.Aimbot.Enabled and not Config.SilentAim.Enabled and not Config.RageBot.FastLock and not isAiming then return {} end
    
    local fov = Config.Aimbot.FOV
    if Config.SilentAim.Enabled then 
        fov = math.max(Config.SilentAim.FieldOfView or 180, Config.Aimbot.FOV or 180) 
    end
    if Config.RageBot.FastLock then fov = math.huge end
    
    if isAiming then
        fov = math.huge -- Lock anywhere if key is held
    end
    
    local potentialTargets = {}
    local targets = Common.ValidEnemies
    if #targets == 0 then return {} end

    for _, player in ipairs(targets) do
        if player and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChild("Humanoid")
            if root and hum and hum.Health > 0 then
                 local distanceToPlayer = (root.Position - Camera.CFrame.Position).Magnitude
                 if distanceToPlayer < 5000 or Config.RageBot.FastLock then -- Advanced filtering can go here
                    local validTarget = true
                    
                    if Config.Aimbot.KnockedCheck and Common.IsKnocked(player) then
                        validTarget = false
                    end
                    
                    if validTarget then
                        local part = nil
                        if Config.Aimbot.NearestPart then
                             part = Common.GetNearestPart(player)
                        else
                            local primaryPartName = Config.Aimbot.TargetPart
                            local fallbackOrder = Config.Aimbot.TargetPartFallbackOrder or {}
                            
                            part = player.Character:FindFirstChild(primaryPartName)
                            
                            local isPartVisibleFunc = function(p, targetPart)
                                if customVisibilityCheck then
                                    return customVisibilityCheck(p, targetPart)
                                else
                                    return Common.IsVisible(p, targetPart)
                                end
                            end

                            if not part or not isPartVisibleFunc(player, part) then
                                for _, fallbackPartName in ipairs(fallbackOrder) do
                                    if fallbackPartName ~= primaryPartName then
                                        local fallbackPart = player.Character:FindFirstChild(fallbackPartName)
                                        if fallbackPart and isPartVisibleFunc(player, fallbackPart) then
                                            part = fallbackPart
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        
                        if part then
                            part = Common.GetResolvedPart(player, part)
                            
                            local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local distToMouse = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                                if distToMouse < fov then
                                    local isVisible = false
                                    if customVisibilityCheck then
                                        isVisible = customVisibilityCheck(player, part)
                                    else
                                        isVisible = Common.IsVisible(player, part)
                                    end

                                    if isVisible then
                                        table.insert(potentialTargets, {
                                            player = player,
                                            part = part,
                                            distToMouse = distToMouse,
                                            health = hum.Health,
                                            distanceToPlayer = distanceToPlayer
                                        })
                                    end
                                end
                            end
                        end
                    end
                 end
            end
        end
    end
    return potentialTargets
end

function Common.Targeting.GetBestTarget(customVisibilityCheck)
    -- [Optimization] Return cached result if called multiple times in same frame
    if Common.LastTargetUpdateTime == tick() and not customVisibilityCheck then
        return Common.CachedTarget, Common.CachedPart
    end

    local bestTarget = nil
    local bestPart = nil

    local potentialTargets = Common.Targeting.GetPotentialTargets(customVisibilityCheck)
    
    -- [Sticky Aim Check]
    local player = Common.CurrentTarget
    local part = Common.CurrentPart
    local mousePos = UserInputService:GetMouseLocation()
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

    local fov = Config.Aimbot.FOV
    if Config.SilentAim.Enabled then 
        fov = math.max(Config.SilentAim.FieldOfView or 180, Config.Aimbot.FOV or 180) 
    end
    if Config.RageBot.FastLock then fov = math.huge end
    
    if isAiming then
        fov = math.huge -- Lock anywhere if key is held
    end

    if player and part and (Config.Aimbot.StickyAim or isAiming) then
        if player.Parent and player.Character and part.Parent == player.Character then
             local valid = true
             if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team and player.Team ~= nil then valid = false end
             if Config.Aimbot.KnockedCheck and Common.IsKnocked(player) then valid = false end
             
             if valid then
                 local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                 if onScreen then
                     local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                     if dist < (fov * 1.2) then
                         if Common.IsVisible(player, part) then
                             -- Check if the sticky target is still in the potential targets list
                             for _, targetData in ipairs(potentialTargets) do
                                 if targetData.player == player then
                                     Common.CurrentTarget = player
                                     Common.CurrentPart = part
                                     if not customVisibilityCheck then
                                         Common.LastTargetUpdateTime = tick()
                                         Common.CachedTarget = player
                                         Common.CachedPart = part
                                     end
                                     return player, part
                                 end
                             end
                         end
                     end
                 end
             end
        end
    end

    -- Sort potential targets based on priority
    if #potentialTargets > 0 then
        local priority = Config.Aimbot.TargetPriority
        if priority == "Closest" then
            table.sort(potentialTargets, function(a, b) return a.distanceToPlayer < b.distanceToPlayer end)
        elseif priority == "LowestHealth" then
            table.sort(potentialTargets, function(a, b) return a.health < b.health end)
        else -- Default to Closest if priority is not recognized
            table.sort(potentialTargets, function(a, b) return a.distanceToPlayer < b.distanceToPlayer end)
        end

        bestTarget = potentialTargets[1].player
        bestPart = potentialTargets[1].part
    end
    
    -- Cache result
    Common.CurrentTarget = bestTarget
    Common.CurrentPart = bestPart
    
    if not customVisibilityCheck then
        Common.LastTargetUpdateTime = tick()
        Common.CachedTarget = bestTarget
        Common.CachedPart = bestPart
    end
    
    return bestTarget, bestPart
end

-- [Bypass] Bezier Curve Utilities for Aimbot
function Common.BezierQuad(t, p0, p1, p2)
    return (1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2
end

function Common.BezierCubic(t, p0, p1, p2, p3)
    return (1 - t)^3 * p0 + 3 * (1 - t)^2 * t * p1 + 3 * (1 - t) * t^2 * p2 + t^3 * p3
end

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

-- [Bypass] Trap/Bot Detection
function Common.IsTrap(player)
    if not player then return true end
    
    -- 1. Bot ID Check (Negative IDs are often bots/test dummies)
    if player.UserId < 0 then return true end
    
    -- 2. Character Validity
    if not player.Character then return true end
    local char = player.Character
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    
    if not root or not hum then return true end
    
    -- 3. Health Sanity Check (Traps often have 0 or infinite health)
    if hum.MaxHealth <= 0 or hum.MaxHealth == math.huge then return true end
    
    -- 4. Invisibility Check (Traps are often invisible)
    -- Check Head transparency instead of RootPart (RootPart is always transparent)
    local head = char:FindFirstChild("Head")
    if head and head.Transparency >= 1 then return true end
    
    return false
end

function Common.IsVisible(target, part)
    if not Camera or not Camera.Parent then Camera = Workspace.CurrentCamera end
    if not Camera then return false end
    if not part then return false end

    -- WallBang Check
    if Config.RageBot.WallBang then return true end

    local isWallCheckEnabled = false
    if Config.SilentAim.Enabled then
        isWallCheckEnabled = Config.SilentAim.VisibleCheck
    else
        isWallCheckEnabled = Config.Aimbot.WallCheck
    end

    -- If wall check is disabled, always return true
    if not isWallCheckEnabled then return true end

    local origin = Camera.CFrame.Position
    local direction = part.Position - origin
    local distance = direction.Magnitude

    -- Re-use RaycastParams for performance
    if not Common.RaycastParams then
        Common.RaycastParams = RaycastParams.new()
        Common.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
        Common.RaycastParams.IgnoreWater = true
    end
    
    local filter = {Camera}
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    Common.RaycastParams.FilterDescendantsInstances = filter
    
    local result
    local success = pcall(function()
        result = Workspace:Raycast(origin, direction.Unit * (distance - 0.1), Common.RaycastParams)
    end)
    
    local isCurrentlyVisible = false
    if success and result and result.Instance and result.Instance:IsDescendantOf(target.Character) then
        isCurrentlyVisible = true
    end

    -- Forgiveness mechanism
    local forgivenessDuration = Config.Aimbot.AimLockForgivenessDuration or 0
    local targetId = target.Name -- Using player name as a unique ID for caching

    if isCurrentlyVisible then
        Common.cachedVisibility[targetId] = tick()
        return true
    else
        -- Check if target was recently visible within the forgiveness duration
        local lastVisibleTime = Common.cachedVisibility[targetId]
        if lastVisibleTime and (tick() - lastVisibleTime <= forgivenessDuration) then
            return true
        end
    end

    return false
end

function Common.GetNearestPart(player)
    if not Camera or not Camera.Parent then Camera = Workspace.CurrentCamera end
    if not Camera then return nil end

    local bestPart = nil
    local shortestDist = math.huge
    local mousePos = UserInputService:GetMouseLocation()
    
    if player and player.Character then
        -- Optimization: Check if player is generally in front of camera first
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        
        -- [Bypass] Trap Check
        if Common.IsTrap(player) then return nil end

        local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
        if not onScreen then return nil end -- Skip if root is not on screen

        -- Optimization: Check Head/Torso first. If close, stick to it.
        local priorityParts = {"Head", "HumanoidRootPart"}
        local allParts = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
        local partsToCheck = allParts

        -- If player is very far, just use Head or Torso to save performance
        local distToRoot = (root.Position - Camera.CFrame.Position).Magnitude
        
        -- [Optimization] Ultra Long Distance: Just return Head
        if distToRoot > 1000 then
             return player.Character:FindFirstChild("Head") or root
        end

        if distToRoot > 300 then
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



return Common
