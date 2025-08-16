
-- Mobile Aimlock with ESP, Pixel Text, and Swipe Target Switching
-- Features:
-- - Aimlock toggle (circle button)
-- - Indicator (green/red) inside 60x60 box
-- - Settings menu with prediction, distance, tilt, ESP toggle, swipe sensitivity
-- - Draggable UI
-- - ESP with red pixel text + outline + small box
-- - Swipe left/right anywhere on screen to switch target efficiently

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- CONFIG DEFAULTS
local aimlockEnabled = false
local espEnabled = true
local prediction = 0.1
local maxDistance = 200
local tiltOffset = 0
local swipeSensitivity = 50 -- default pixels for swipe

-- UI CREATION (indicator, settings, etc.) [Omitted here for brevity, same as last version but with added Swipe Sensitivity +/- buttons]

-- SWIPE DETECTION
local swipeStart = nil

UserInputService.TouchStarted:Connect(function(input, gp)
    if gp then return end
    swipeStart = input.Position
end)

UserInputService.TouchEnded:Connect(function(input, gp)
    if gp or not swipeStart then return end
    local delta = input.Position - swipeStart
    -- Horizontal swipe check
    if math.abs(delta.X) > swipeSensitivity and math.abs(delta.X) > math.abs(delta.Y) then
        if delta.X > 0 then
            -- Swipe right -> next target clockwise
            switchTarget(true)
        else
            -- Swipe left -> next target counterclockwise
            switchTarget(false)
        end
    end
    swipeStart = nil
end)

-- TARGET SELECTION
local currentTarget = nil

local function getTargetsInRange()
    local targets = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = p.Character.HumanoidRootPart
            local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
            if dist <= maxDistance then
                local dir = (hrp.Position - Camera.CFrame.Position).Unit
                local angle = math.atan2(dir.X, dir.Z)
                table.insert(targets, {player=p, hrp=hrp, dist=dist, angle=angle})
            end
        end
    end
    table.sort(targets, function(a,b) return a.angle < b.angle end)
    return targets
end

function switchTarget(clockwise)
    local targets = getTargetsInRange()
    if #targets == 0 then return end
    if not currentTarget then
        currentTarget = targets[1].player
        return
    end
    local currentAngle
    for _,t in ipairs(targets) do
        if t.player == currentTarget then currentAngle = t.angle end
    end
    if not currentAngle then currentTarget = targets[1].player return end
    local best = nil
    if clockwise then
        for _,t in ipairs(targets) do
            if t.angle > currentAngle then best = t break end
        end
        best = best or targets[1]
    else
        for i=#targets,1,-1 do
            if targets[i].angle < currentAngle then best = targets[i] break end
        end
        best = best or targets[#targets]
    end
    currentTarget = best.player
end

-- AIMLOCK LOOP
RunService.RenderStepped:Connect(function()
    if aimlockEnabled and currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = currentTarget.Character.HumanoidRootPart
        local aimPos = hrp.Position + (hrp.Velocity * prediction) + Vector3.new(0, tiltOffset, 0)
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimPos)
    end
end)

-- ESP LOOP (similar to last version: draw red text, outline, box, pixel font)
-- [Omitted here, identical to last version but kept intact]
