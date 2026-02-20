---@diagnostic disable: undefined-global
-- modules/legit/triggerbot.lua
-- TriggerBot implementation with auto-shoot delay and visibility check.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = Common.GetSafeService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInputService = Common.GetSafeService("UserInputService")
local vim = Common.GetSafeService("VirtualInputManager")

local TriggerBot = {}

function TriggerBot.Update(dt)
    if not Config.TriggerBot.Enabled then return end

    local mouseLocation = UserInputService:GetMouseLocation()
    local ray = Camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
    
    -- Use cached RaycastParams for performance
    if not Common.RaycastParams then
        Common.RaycastParams = RaycastParams.new()
        Common.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
        Common.RaycastParams.IgnoreWater = true
    end
    
    local filter = {Camera}
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    Common.RaycastParams.FilterDescendantsInstances = filter

    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, Common.RaycastParams)

    if result and result.Instance then
        local hitPart = result.Instance
        local hitModel = hitPart:FindFirstAncestorOfClass("Model")
        
        if hitModel then
            local player = Players:GetPlayerFromCharacter(hitModel)
            
            if player and player ~= LocalPlayer then
                if Config.TriggerBot.TeamCheck and player.Team == LocalPlayer.Team then
                    return
                end
                
                -- Check visibility if enabled
                if Config.TriggerBot.VisibilityCheck then
                     if not Common.IsVisible(player, hitPart) then
                         return
                     end
                end

                -- Shoot (Spawn task to avoid yielding main loop)
                task.spawn(function()
                    if mouse1press and mouse1release then
                        mouse1press()
                        task.wait(Config.TriggerBot.Delay)
                        mouse1release()
                    elseif vim then
                        vim:SendMouseButtonEvent(mouseLocation.X, mouseLocation.Y, 0, true, game, 1)
                        task.wait(Config.TriggerBot.Delay)
                        vim:SendMouseButtonEvent(mouseLocation.X, mouseLocation.Y, 0, false, game, 1)
                    end
                end)
            end
        end
    end
end

return TriggerBot
