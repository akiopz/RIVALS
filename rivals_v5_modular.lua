---@diagnostic disable: param-type-mismatch
---@diagnostic disable: unused-local
---@diagnostic disable: deprecated
---@diagnostic disable: undefined-global
-- Rivals V5 Modular Script
-- Main entry point for the modular exploit.
-- This script loads all other modules and manages their lifecycle.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Global table to store module instances
local Modules = {}

-- Global table to store active connections for cleanup
if not getgenv().Rivals_Connections then getgenv().Rivals_Connections = {} end

-- Global table to store custom cleanup functions for modules
if not getgenv().Rivals_Cleanup_Functions then getgenv().Rivals_Cleanup_Functions = {} end

-- Function to load modules (placeholder for now, will be replaced by HTTP loading)
local function RivalsLoad(path)
    local content
    local success

    -- Try loading from local file first
    if isfile and isfile(path) then
        success, content = pcall(readfile, path)
    end

    -- If local file not found or failed, try GitHub
    if not success or not content then
        if getgenv().GITHUB_RAW_URL then
            local moduleUrl = getgenv().GITHUB_RAW_URL .. path
            success, content = pcall(function()
                return game:HttpGet(moduleUrl, true)
            end)
        else
            warn("[RivalsLoad] GITHUB_RAW_URL not set and local file not found: " .. path)
            return nil
        end
    end

    if not success or not content then
        warn("[RivalsLoad] Failed to load module " .. path .. ": " .. tostring(content))
        return nil
    end

    local loadSuccess, module = pcall(loadstring(content))
    if not loadSuccess then
        warn("[RivalsLoad] Error executing module " .. path .. ": " .. tostring(module))
        return nil
    end
    return module
end

getgenv().RivalsLoad = RivalsLoad -- Export for modules to use

-- Configuration (will be loaded from modules/utils/config.lua)
local Config

-- Main script initialization
local function Init()
    task.wait(2) -- Wait for game to load
    -- Clear previous connections and run cleanup functions on re-injection
    if getgenv().Rivals_Connections then
        for _, conn in pairs(getgenv().Rivals_Connections) do
            if conn and conn.Disconnect then
                pcall(function() conn:Disconnect() end)
            end
        end
    end
    getgenv().Rivals_Connections = {}

    if getgenv().Rivals_Cleanup_Functions then
        for _, cleanup in pairs(getgenv().Rivals_Cleanup_Functions) do
            pcall(cleanup)
        end
    end
    getgenv().Rivals_Cleanup_Functions = {}

    -- Load Config first
    local success, err = pcall(function()
        Config = RivalsLoad("modules/utils/config.lua")
        if Config and Config.Init then Config.Init() end
    end)
    if not success then warn("Failed to load/init Config: " .. tostring(err)) end

    -- Load other modules
    local modulePaths = {
        "modules/utils/common.lua",
        "modules/legit/aimbot.lua",
        "modules/legit/silent_aim.lua",
        "modules/visuals/esp.lua",
        "modules/visuals/world.lua",
        "modules/ui/gui.lua",
        -- Add other modules here as they are created
    }

    for _, path in ipairs(modulePaths) do
        local moduleName = path:match("modules/(.+).lua")
        if moduleName then
            moduleName = moduleName:gsub("/", "_")
            local moduleSuccess, moduleErr = pcall(function()
                Modules[moduleName] = RivalsLoad(path)
                if Modules[moduleName] and Modules[moduleName].Init then
                    Modules[moduleName].Init()
                end
            end)
            if not moduleSuccess then warn("Failed to load/init module " .. path .. ": " .. tostring(moduleErr)) end
        end
    end

    -- Main loops
    RunService.Heartbeat:Connect(function(dt)
        pcall(function()
            if Config and Config.Main and Config.Main.Enabled then
                -- Update Aimbot
                if Modules.legit_aimbot and Modules.legit_aimbot.Update then
                    Modules.legit_aimbot.Update(dt)
                end
                -- Update SilentAim
                if Modules.legit_silent_aim and Modules.legit_silent_aim.Update then
                    Modules.legit_silent_aim.Update(dt)
                end
                -- Update World visuals (e.g., crosshair)
                if Modules.visuals_world and Modules.visuals_world.Update then
                    Modules.visuals_world.Update(dt)
                end
            end
        end)
    end)

    RunService.RenderStepped:Connect(function(dt)
        pcall(function()
            if Config and Config.Main and Config.Main.Enabled then
                -- Update ESP
                if Modules.visuals_esp and Modules.visuals_esp.Update then
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                            Modules.visuals_esp.Update(player)
                        end
                    end
                end
                -- Update GUI
                if Modules.ui_gui and Modules.ui_gui.Update then
                    Modules.ui_gui.Update(dt)
                end
            end
        end)
    end)

    print("[Rivals V5] Script Loaded Successfully!")
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Rivals V5",
            Text = "腳本加載成功！",
            Duration = 3,
            Icon = "rbxassetid://6675147490" -- User's Shark Icon
        })
    end)
end

-- Run initialization
pcall(Init)
