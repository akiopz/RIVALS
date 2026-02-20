---@diagnostic disable: undefined-global
-- modules/visuals/esp.lua
-- Implements ESP (Extra Sensory Perception) visuals for players.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Drawing = Drawing or getgenv().Drawing -- Ensure Drawing library is available

local ESP = {}

-- Store active drawings to clean up
local PlayerDrawings = {} -- {player = {box = Drawing.new("Square"), name = Drawing.new("Text"), ...}}

-- Function to get player color based on team and config
local function getPlayerColor(player)
    if Config.ESP.Rainbow then
        return Color3.fromHSV(tick() % 10 / 10, 1, 1)
    elseif Config.ESP.TeamCheck and player.Team == LocalPlayer.Team then
        return Color3.fromRGB(0, 255, 0) -- Green for teammates
    else
        return Config.ESP.Color
    end
end

function ESP.Update(player)
    if not Config.ESP.Enabled or not player or player == LocalPlayer or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
        -- Clean up drawings if player is invalid or ESP is disabled
        if PlayerDrawings[player] then
            for _, drawObj in pairs(PlayerDrawings[player]) do
                pcall(function() drawObj:Remove() end)
            end
            PlayerDrawings[player] = nil
        end
        return
    end

    local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    local head = player.Character:FindFirstChild("Head")
    if not head then return end

    local screenPosHead, onScreenHead = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) -- Slightly above head
    local screenPosRoot, onScreenRoot = Camera:WorldToViewportPoint(humanoidRootPart.Position - Vector3.new(0, 0.5, 0)) -- Slightly below root

    if not onScreenHead and not onScreenRoot then
        -- Clean up drawings if player is off screen
        if PlayerDrawings[player] then
            for _, drawObj in pairs(PlayerDrawings[player]) do
                pcall(function() drawObj:Remove() end)
            end
            PlayerDrawings[player] = nil
        end
        return
    end

    local color = getPlayerColor(player)

    -- Initialize drawing objects if they don't exist
    if not PlayerDrawings[player] then
        PlayerDrawings[player] = {
            box = Drawing.new("Square"),
            name = Drawing.new("Text"),
            healthBar = Drawing.new("Square"),
            tracer = Drawing.new("Line"),
            skeleton = {} -- Table for skeleton lines
        }
        -- Register cleanup for this player's drawings
        table.insert(getgenv().Rivals_Cleanup_Functions, function()
            if PlayerDrawings[player] then
                for _, drawObj in pairs(PlayerDrawings[player]) do
                    if type(drawObj) == "table" then -- Skeleton lines
                        for _, line in pairs(drawObj) do pcall(function() line:Remove() end) end
                    else
                        pcall(function() drawObj:Remove() end)
                    end
                end
                PlayerDrawings[player] = nil
            end
        end)
    end

    local drawings = PlayerDrawings[player]

    -- Calculate box size and position
    local height = math.abs(screenPosHead.Y - screenPosRoot.Y)
    local width = height / 2
    local x = screenPosRoot.X - width / 2
    local y = screenPosHead.Y

    -- Box ESP
    if Config.ESP.Boxes then
        drawings.box.Visible = true
        drawings.box.Color = color
        drawings.box.Thickness = 1
        drawings.box.Filled = false
        drawings.box.Position = Vector2.new(x, y)
        drawings.box.Size = Vector2.new(width, height)
    else
        drawings.box.Visible = false
    end

    -- Name ESP
    if Config.ESP.Names then
        drawings.name.Visible = true
        drawings.name.Color = color
        drawings.name.Text = player.Name
        drawings.name.Size = 12
        drawings.name.Center = true
        drawings.name.Position = Vector2.new(screenPosHead.X, screenPosHead.Y - 15)
    else
        drawings.name.Visible = false
    end

    -- Health Bar ESP
    if Config.ESP.HealthBars then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid then
            local healthRatio = humanoid.Health / humanoid.MaxHealth
            local healthBarHeight = height * healthRatio
            local healthBarY = y + (height - healthBarHeight)

            drawings.healthBar.Visible = true
            drawings.healthBar.Color = Color3.fromRGB(255 * (1 - healthRatio), 255 * healthRatio, 0) -- Green to Red
            drawings.healthBar.Thickness = 1
            drawings.healthBar.Filled = true
            drawings.healthBar.Position = Vector2.new(x - 5, y) -- Left of the box
            drawings.healthBar.Size = Vector2.new(3, height)
        else
            drawings.healthBar.Visible = false
        end
    else
        drawings.healthBar.Visible = false
    end

    -- Tracer ESP
    if Config.ESP.Tracers then
        drawings.tracer.Visible = true
        drawings.tracer.Color = color
        drawings.tracer.Thickness = 1
        drawings.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y) -- Bottom center of screen
        drawings.tracer.To = Vector2.new(screenPosRoot.X, screenPosRoot.Y)
    else
        drawings.tracer.Visible = false
    end

    -- Skeleton ESP
    if Config.ESP.Skeletons then
        local skeletonParts = {
            {"Head", "Neck"}, {"Neck", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "RightShoulder"}, {"RightShoulder", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
            {"UpperTorso", "LeftShoulder"}, {"LeftShoulder", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
            {"LowerTorso", "RightHip"}, {"RightHip", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
            {"LowerTorso", "LeftHip"}, {"LeftHip", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
        }

        for i, connection in ipairs(skeletonParts) do
            local part1 = player.Character:FindFirstChild(connection[1])
            local part2 = player.Character:FindFirstChild(connection[2])

            if part1 and part2 then
                local screenPos1, onScreen1 = Camera:WorldToViewportPoint(part1.Position)
                local screenPos2, onScreen2 = Camera:WorldToViewportPoint(part2.Position)

                if onScreen1 and onScreen2 then
                    if not drawings.skeleton[i] then
                        drawings.skeleton[i] = Drawing.new("Line")
                        table.insert(getgenv().Rivals_Cleanup_Functions, function()
                            if drawings.skeleton[i] then pcall(function() drawings.skeleton[i]:Remove() end) end
                        end)
                    end
                    drawings.skeleton[i].Visible = true
                    drawings.skeleton[i].Color = color
                    drawings.skeleton[i].Thickness = 1
                    drawings.skeleton[i].From = Vector2.new(screenPos1.X, screenPos1.Y)
                    drawings.skeleton[i].To = Vector2.new(screenPos2.X, screenPos2.Y)
                else
                    if drawings.skeleton[i] then drawings.skeleton[i].Visible = false end
                end
            else
                if drawings.skeleton[i] then drawings.skeleton[i].Visible = false end
            end
        end
    else
        -- Hide all skeleton lines
        for _, line in pairs(drawings.skeleton) do
            pcall(function() line.Visible = false end)
        end
    end
end

function ESP.Init()
    -- Any initialization logic for ESP if needed
end

return ESP
