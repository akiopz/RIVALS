---@diagnostic disable: undefined-global
-- modules/visuals/world.lua
-- Handles world-related visuals like crosshairs, bullet tracers, etc.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")

local Camera = workspace.CurrentCamera

local Drawing = Drawing or getgenv().Drawing -- Ensure Drawing library is available

local World = {}

-- Drawing objects
local CrosshairDrawing = nil

function World.Update(dt)
    if not Config.Enabled then
        if CrosshairDrawing then CrosshairDrawing.Visible = false end
        return
    end

    -- Crosshair
    if Config.World.Crosshair then
        if not CrosshairDrawing then
            CrosshairDrawing = Drawing.new("Circle")
            CrosshairDrawing.Radius = 5
            CrosshairDrawing.Thickness = 1
            CrosshairDrawing.Filled = false
            CrosshairDrawing.Color = Color3.fromRGB(255, 255, 255)
            CrosshairDrawing.ZIndex = 999
            table.insert(getgenv().Rivals_Cleanup_Functions, function()
                if CrosshairDrawing then pcall(function() CrosshairDrawing:Remove() end) end
            end)
        end
        CrosshairDrawing.Visible = true
        CrosshairDrawing.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        if CrosshairDrawing then CrosshairDrawing.Visible = false end
    end

    -- Bullet Tracer (TODO: Implement this if needed)
end

function World.Init()
    -- Any initialization logic for World visuals if needed
end

return World
