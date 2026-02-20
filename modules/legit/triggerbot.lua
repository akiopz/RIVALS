---@diagnostic disable: undefined-global
-- modules/legit/triggerbot.lua
-- TriggerBot implementation with auto-shoot delay and visibility check.

local Config = getgenv().RivalsLoad("modules/utils/config.lua")
local Common = getgenv().RivalsLoad("modules/utils/common.lua")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local TriggerBot = {}

function TriggerBot.Update(dt)
    if not Config.TriggerBot.Enabled then return end

    local mouseLocation = game:GetService("UserInputService"):GetMouseLocation()
    local ray = Camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)

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

                -- Shoot
                mouse1press()
                task.wait(Config.TriggerBot.Delay)
                mouse1release()
            end
        end
    end
end

return TriggerBot
