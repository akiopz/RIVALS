---@diagnostic disable: param-type-mismatch
---@diagnostic disable: unused-local
---@diagnostic disable: deprecated
---@diagnostic disable: undefined-global
---@diagnostic disable: inject-field
---@diagnostic disable: undefined-field
-- Rivals V5 Modular Script
-- Main entry point for the modular exploit.
-- This script loads all other modules and manages their lifecycle.

-- print("----------------------------------------------------------------")
-- print("[Rivals V5] STARTING LOCAL EXECUTION - VERSION: ScreenGui Rewrite")
-- print("----------------------------------------------------------------")

local function GetSafeService(service_name)
    local service = game:GetService(service_name)
    if cloneref then
        return cloneref(service)
    end
    return service
end

local Players = GetSafeService("Players")
local RunService = GetSafeService("RunService")
local UserInputService = GetSafeService("UserInputService")
local StarterGui = GetSafeService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- [Bypass] Anti-Tamper / Environment Cleanup
if getgenv().RivalsLoad then
    -- Clean up previous environment if exists to prevent detection
    getgenv().RivalsLoad = nil
end

-- Global table to store module instances
local Modules = {}

-- Global cache for loaded modules to prevent redundant requests
if not getgenv().Rivals_ModuleCache then getgenv().Rivals_ModuleCache = {} end

-- Global table to store active connections for cleanup
if not getgenv().Rivals_Connections then getgenv().Rivals_Connections = {} end

-- Global table to store custom cleanup functions for modules
if not getgenv().Rivals_Cleanup_Functions then getgenv().Rivals_Cleanup_Functions = {} end

-- Function to load modules (placeholder for now, will be replaced by HTTP loading)
local function RivalsLoad(path)
    -- [Cache Check] Return cached module if already loaded
    if getgenv().Rivals_ModuleCache[path] then
        return getgenv().Rivals_ModuleCache[path]
    end

    local content
    local success
    
    -- print("[RivalsLoad] Attempting to load: " .. path)

    -- Try loading from local file first
    if isfile and isfile(path) then
        success, content = pcall(readfile, path)
        if success then
            -- print("[RivalsLoad] Loaded LOCAL file: " .. path)
        else
            -- Suppress warning unless debug mode
            -- warn("[RivalsLoad] Failed to read LOCAL file: " .. path)
        end
    else
        -- Suppress warning unless debug mode
        -- warn("[RivalsLoad] File not found locally: " .. path)
    end

    -- If local file not found or failed, try GitHub
    if not success or not content then
        if getgenv().GITHUB_RAW_URL then
            -- print("[RivalsLoad] Attempting GitHub load for: " .. path)
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

    local chunk, syntaxErr = loadstring(content)
    if not chunk then
        warn("[RivalsLoad] Syntax error in " .. path .. ": " .. tostring(syntaxErr))
        return nil
    end

    local loadSuccess, module = pcall(chunk)
    if not loadSuccess then
        warn("[RivalsLoad] Error executing module " .. path .. ": " .. tostring(module))
        return nil
    end
    
    -- [Cache Save] Store loaded module in cache
    getgenv().Rivals_ModuleCache[path] = module
    
    return module
end

getgenv().RivalsLoad = RivalsLoad -- Export for modules to use

-- Configuration (will be loaded from modules/utils/config.lua)
local Config

-- Main script initialization
    local function Init()
        task.wait(2) -- Wait for game to load
        
        -- [Bypass] Anti-Tamper / Environment Cleanup
        -- Clean up previous environment if exists to prevent detection
        -- Note: We must NOT clear RivalsLoad here because modules use it during initialization!
        -- It will be cleared after all modules are loaded (see line ~188)
        
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
        
        task.wait(0.1)

        -- Load other modules
        local modulePaths = {
            "modules/utils/common.lua",
            "modules/legit/aimbot.lua",
            "modules/legit/triggerbot.lua", -- Added TriggerBot
            "modules/legit/silent_aim.lua",
            "modules/legit/hitbox_expander.lua", -- Added HitboxExpander
            "modules/legit/anti_aim.lua", -- Added AntiAim
            "modules/visuals/esp.lua",
            "modules/visuals/world.lua",
            "modules/ui/gui.lua",
            -- Add other modules here as they are created
        }

        -- Async Loading
        task.spawn(function()
            for _, path in ipairs(modulePaths) do
                local moduleName = path:match("modules/(.+).lua")
                if moduleName then
                    moduleName = moduleName:gsub("/", "_")
                    local moduleSuccess, moduleErr = pcall(function()
                        -- print("[RivalsLoad] Loading " .. path .. "...")
                        Modules[moduleName] = RivalsLoad(path)
                        if Modules[moduleName] and Modules[moduleName].Init then
                            Modules[moduleName].Init()
                        end
                    end)
                    if not moduleSuccess then 
                        warn("Failed to load/init module " .. path .. ": " .. tostring(moduleErr)) 
                    end
                    task.wait(0.2) -- Increased wait to prevent timeout
                end
            end
            
            -- print("[Rivals V5] All Modules Loaded!")
            
            -- Cleanup Loader to prevent detection
            getgenv().RivalsLoad = nil
            
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "Rivals V5",
                    Text = "載入完成!",
                    Duration = 3
                })
            end)
        end)

        -- Main loops
        RunService.Heartbeat:Connect(function(dt)
        if not Modules then return end -- Safety check
        
        -- Safe call wrapper
        local safeCall = pcall
        if Modules["utils_common"] and Modules["utils_common"].SafeCall then
            safeCall = Modules["utils_common"].SafeCall
        end

        safeCall(function()
            -- Debug Print (Throttle)
            if math.random() < 0.01 then
                -- print("[Rivals V5] Main Loop Running...") 
            end

            -- Update Aimbot
            -- Moved to RenderStepped for smoother camera movement
            
            -- Update TriggerBot
            if Modules["legit_triggerbot"] and Modules["legit_triggerbot"].Update then
                Modules["legit_triggerbot"].Update(dt)
            end
            -- Update SilentAim
            if Modules["legit_silent_aim"] and Modules["legit_silent_aim"].Update then
                Modules["legit_silent_aim"].Update(dt)
            end
            -- Update World visuals (e.g., crosshair)
            if Modules["visuals_world"] and Modules["visuals_world"].Update then
                Modules["visuals_world"].Update(dt)
            end
            -- Update Hitbox Expander
            if Modules["legit_hitbox_expander"] and Modules["legit_hitbox_expander"].Update then
                Modules["legit_hitbox_expander"].Update(dt)
            end
                -- Update Anti-Aim
            if Modules["legit_anti_aim"] and Modules["legit_anti_aim"].Update then
                Modules["legit_anti_aim"].Update(dt)
            end
        end)
    end)

    RunService.RenderStepped:Connect(function(dt)
        if not Modules then return end -- Safety check
        
        local safeCall = pcall
        if Modules["utils_common"] and Modules["utils_common"].SafeCall then
            safeCall = Modules["utils_common"].SafeCall
        end
        
        safeCall(function()
            -- Update Aimbot
            if Modules["legit_aimbot"] and Modules["legit_aimbot"].Update then
                Modules["legit_aimbot"].Update(dt)
            end
            
            -- Update ESP
            if Modules["visuals_esp"] and Modules["visuals_esp"].Update then
                    Modules["visuals_esp"].Update() -- Use internal loop
            end
            -- Update GUI
            if Modules["ui_gui"] and Modules["ui_gui"].Update then
                Modules["ui_gui"].Update(dt)
            end
        end)
    end)

    -- print("[Rivals V5] Script Loaded Successfully!")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Rivals V5",
            Text = "已安全注入 (Safe Mode)",
            Duration = 3,
            Icon = "rbxassetid://6675147490"
        })
    end)
end

-- Run initialization
pcall(Init)
