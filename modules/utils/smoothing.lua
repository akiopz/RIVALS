---@diagnostic disable: undefined-global
-- modules/utils/smoothing.lua
-- Implements advanced smoothing techniques for aimbot.

local Smoothing = {}

--- Applies exponential smoothing to a delta value.
-- @param currentDelta number The current difference between target and current position.
-- @param smoothFactor number The smoothing factor (higher means more smoothing).
-- @return number The smoothed delta value.
function Smoothing.Exponential(currentDelta, smoothFactor)
    if smoothFactor <= 1 then return currentDelta end -- No smoothing or instant
    return currentDelta / smoothFactor
end

--- Applies a humanized smoothing effect.
-- This function aims to make the movement less robotic by introducing slight variations.
-- @param currentDelta number The current difference between target and current position.
-- @param smoothFactor number The base smoothing factor.
-- @param humanizationStrength number How much humanization to apply (e.g., 0.1 for 10% variation).
-- @return number The humanized and smoothed delta value.
function Smoothing.Humanized(currentDelta, smoothFactor, humanizationStrength)
    local smoothedDelta = Smoothing.Exponential(currentDelta, smoothFactor)
    
    -- Add a small random offset to simulate human imperfection
    local jitter = (math.random() - 0.5) * humanizationStrength
    return smoothedDelta + jitter
end

--- Applies Bezier curve smoothing (conceptual, actual implementation might vary based on input type).
-- For mouse movement, this would typically involve calculating intermediate points
-- along a Bezier curve between the current mouse position and the target position.
-- For simplicity, this example will use a linear interpolation with a Bezier-like acceleration/deceleration.
-- @param startPos Vector2 The starting mouse position.
-- @param endPos Vector2 The target mouse position.
-- @param progress number A value between 0 and 1 representing the progress along the curve.
-- @param controlPointOffset Vector2 An offset for the control point to shape the curve.
-- @return Vector2 The smoothed position.
function Smoothing.Bezier(startPos, endPos, progress, controlPointOffset)
    -- Simple quadratic Bezier for demonstration
    local controlPoint = (startPos + endPos) / 2 + (controlPointOffset or Vector2.new(0,0))
    
    local p1 = startPos * (1 - progress) + controlPoint * progress
    local p2 = controlPoint * (1 - progress) + endPos * progress
    
    return p1 * (1 - progress) + p2 * progress
end

--- Calculates a smoothed alpha value for CFrame.Lerp, with optional humanization.
-- @param baseAlpha number The base alpha value (e.g., 1 / Config.Aimbot.Smoothing).
-- @param humanizationStrength number How much humanization to apply (e.g., 0.1 for 10% variation).
-- @return number The smoothed and humanized alpha value, clamped between 0.01 and 1.
function Smoothing.GetLerpAlpha(baseAlpha, humanizationStrength)
    local alpha = baseAlpha
    if humanizationStrength and humanizationStrength > 0 then
        local jitter = (math.random() - 0.5) * humanizationStrength
        alpha = alpha + jitter
    end
    return math.clamp(alpha, 0.01, 1)
end

return Smoothing