---@diagnostic disable: undefined-global
-- modules/utils/prediction.lua
-- Implements advanced prediction techniques for aimbot.

local Prediction = {}

-- Kalman Filter state for each target
local kalmanFilters = {}

-- Helper function to create a new Kalman filter instance
local function createKalmanFilter()
    -- A simplified 1D Kalman filter for position (x, y, z)
    -- State: [position, velocity]
    -- P: Error covariance matrix
    -- Q: Process noise covariance
    -- R: Measurement noise covariance
    -- K: Kalman gain

    local filter = {
        -- State vector [x, vx, y, vy, z, vz]
        x = Vector3.new(0, 0, 0),
        v = Vector3.new(0, 0, 0),

        -- Covariance matrix (simplified as scalar for each dimension)
        P_pos = 1, -- Position uncertainty
        P_vel = 1, -- Velocity uncertainty

        -- Process noise (how much the system changes between updates)
        Q_pos = 0.01,
        Q_vel = 0.1,

        -- Measurement noise (how noisy our observations are)
        R_pos = 0.1,
    }
    return filter
end

-- Update Kalman filter with new measurement
local function updateKalmanFilter(filter, measurement, dt)
    -- Predict
    filter.x = filter.x + filter.v * dt
    filter.P_pos = filter.P_pos + filter.Q_pos
    filter.P_vel = filter.P_vel + filter.Q_vel

    -- Update
    local K_pos = filter.P_pos / (filter.P_pos + filter.R_pos)
    local K_vel = filter.P_vel / (filter.P_vel + filter.R_pos) -- Simplified, usually velocity has its own R

    filter.x = filter.x + (measurement - filter.x) * K_pos
    filter.v = (measurement - filter.x) / dt -- Re-estimate velocity based on corrected position
    
    filter.P_pos = filter.P_pos * (1 - K_pos)
    filter.P_vel = filter.P_vel * (1 - K_vel)
end

--- Predicts the target's future position using enhanced linear prediction, Kalman filter, and humanized jitter.
-- @param target Player object
-- @param targetPart BasePart (e.g., HumanoidRootPart)
-- @param dt Delta time since last update
-- @param predictionFactor Configured prediction factor
-- @param dynamicPredictionEnabled Whether dynamic prediction is enabled
-- @param Camera Camera object
-- @return Vector3 Predicted target position
function Prediction.PredictPosition(target, targetPart, dt, predictionFactor, dynamicPredictionEnabled, Camera)
    local targetPosition = targetPart.Position
    local targetId = target.Name -- Using player name as a unique ID for caching filters

    -- Initialize Kalman filter for this target if it doesn't exist
    if not kalmanFilters[targetId] then
        kalmanFilters[targetId] = createKalmanFilter()
        kalmanFilters[targetId].x = targetPosition -- Initialize with current position
    end

    local filter = kalmanFilters[targetId]

    -- Update Kalman filter with current measurement
    updateKalmanFilter(filter, targetPosition, dt)

    -- Enhanced Linear Prediction (using Kalman-filtered velocity)
    local predictedPosition = filter.x + filter.v * predictionFactor

    -- Dynamic Prediction Adjustment (if enabled)
    if dynamicPredictionEnabled then
        local distance = (targetPosition - Camera.CFrame.Position).Magnitude
        -- Adjust prediction factor based on distance. This is a simple linear scaling.
        -- You might want to fine-tune this formula based on game physics.
        predictionFactor = predictionFactor * (1 + (distance / 100)) -- Example: +1% prediction per 1 unit distance
        predictionFactor = math.clamp(predictionFactor, 0, 0.5) -- Clamp to reasonable values
    end

    -- Apply humanized jitter
    local jitterStrength = 0.05 -- Configurable jitter strength
    predictedPosition = predictedPosition + Vector3.new(
        (math.random() - 0.5) * jitterStrength,
        (math.random() - 0.5) * jitterStrength,
        (math.random() - 0.5) * jitterStrength
    )

    return predictedPosition
end

return Prediction