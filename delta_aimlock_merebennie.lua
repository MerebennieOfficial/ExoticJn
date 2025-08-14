
-- Delta Aimlock (Improved) - For Delta Mobile Executor
-- Made by Merebennie
-- Cleaned & optimized: White UI / Black text, pixel watermark, improved aimbot, Camera FOV slider

-- Services
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService     = game:GetService("SoundService")

-- Player & Camera
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.05); LocalPlayer = Players.LocalPlayer end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- Safe constructors
local function safeNew(class)
    local ok, inst = pcall(function() return Instance.new(class) end)
    if ok then return inst end
    return nil
end

local function newSound(id)
    local ok, s = pcall(function()
        local snd = Instance.new("Sound")
        snd.SoundId = id
        snd.Volume = 1
        snd.Parent = SoundService
        return snd
    end)
    return ok and s or nil
end

-- Configuration
local CFG = {
    AIM_RADIUS = 500,
    LOCK_PART = "Head",
    AIM_MODE = "Smooth",           -- "Smooth" or "Snap"
    SMOOTHING = 8.0,
    USE_CAM_HEIGHT = true,
    CAM_HEIGHT = 2,
    SCREEN_TILT = -5,
    SWITCH_SENSITIVITY_YAW = 0.006,
    SWITCH_SENSITIVITY_PITCH = 0.02,
    SWITCH_COOLDOWN = 0.08,
    TARGET_PRIORITY = "Angle",     -- "Angle", "Screen", "Distance"
    USE_FRIEND_FILTER = true,
    SHOW_FOV = true,
    FOV_PIXELS = 120,
    FOV_THICKNESS = 3,
    FOV_COLOR = Color3.fromRGB(0,0,0),
    TOGGLE_SOUND_ID = "rbxassetid://6042053626",
    USE_PREDICTION = true,
    BULLET_SPEED = 1400,
    PREDICT_MULT = 1.0,
    ESP_ENABLED = false,
    SWITCH_MODE = "ByLook",
    IGNORE_AIR_SWITCH = true,
    CAMERA_FOV = 70, -- default camera FOV
}

local aiming = false
local targetPart = nil
local targetHRP = nil
local lastYaw, lastPitch = nil, nil
local lastSwitchTick = 0
local lastRenderTick = tick()

local toggleSound = newSound(CFG.TOGGLE_SOUND_ID)

-- GUI
local gui = safeNew("ScreenGui")
if not gui then return end
gui.Name = "DeltaAim_UI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = PlayerGui end)

local watermark = Instance.new("TextLabel")
watermark.Name = "Watermark"
watermark.Parent = gui
watermark.AnchorPoint = Vector2.new(0, 0)
watermark.Position = UDim2.new(0, 8, 0, 6)
watermark.Size = UDim2.new(0, 180, 0, 18)
watermark.BackgroundTransparency = 1
watermark.Text = "Made by Merebennie"
watermark.Font = Enum.Font.Arcade
watermark.TextSize = 14
watermark.TextColor3 = Color3.fromRGB(0, 0, 0)
watermark.TextStrokeColor3 = Color3.new(1,1,1)
watermark.TextStrokeTransparency = 0.6
watermark.ZIndex = 100
watermark.BackgroundColor3 = Color3.new(1,1,1)
watermark.BackgroundTransparency = 1

LocalPlayer.CharacterAdded:Connect(function()
    if not gui.Parent then pcall(function() gui.Parent = PlayerGui end) end
end)

-- Main frame
local mainFrame = safeNew("Frame"); mainFrame.Parent = gui
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0,320,0,120)
mainFrame.Position = UDim2.new(0.5,-160,0.12,0)
mainFrame.AnchorPoint = Vector2.new(0.5,0)
mainFrame.Active = true; mainFrame.Draggable = true
mainFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
local cornerMain = Instance.new("UICorner", mainFrame); cornerMain.CornerRadius = UDim.new(0,12)
local strokeMain = Instance.new("UIStroke", mainFrame); strokeMain.Color = Color3.fromRGB(220,220,220); strokeMain.Thickness = 1

local title = safeNew("TextLabel"); title.Parent = mainFrame
title.Size = UDim2.new(1,-24,0,28); title.Position = UDim2.new(0,12,0,8)
title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold; title.TextSize = 18
title.TextColor3 = Color3.new(0,0,0); title.Text = "Merebennie Aim Controller"; title.TextXAlignment = Enum.TextXAlignment.Left

local settingsBtn = safeNew("TextButton"); settingsBtn.Parent = mainFrame
settingsBtn.Size = UDim2.new(0,32,0,28); settingsBtn.Position = UDim2.new(1,-12,0,8); settingsBtn.AnchorPoint = Vector2.new(1,0)
settingsBtn.Text = "⚙"; settingsBtn.Font = Enum.Font.GothamBold; settingsBtn.TextSize = 16
settingsBtn.TextColor3 = Color3.new(0,0,0)
settingsBtn.BackgroundColor3 = Color3.fromRGB(247,247,247)
Instance.new("UICorner", settingsBtn).CornerRadius = UDim.new(1,0)
Instance.new("UIStroke", settingsBtn).Color = Color3.fromRGB(220,220,220)

local toggleBtn = safeNew("TextButton"); toggleBtn.Parent = mainFrame
toggleBtn.Size = UDim2.new(0.62,0,0,40); toggleBtn.Position = UDim2.new(0.04,0,0.5,0)
toggleBtn.AnchorPoint = Vector2.new(0,0.5)
toggleBtn.Font = Enum.Font.GothamBold; toggleBtn.TextSize = 16
toggleBtn.Text = "AIMBOT: OFF"; toggleBtn.BackgroundColor3 = Color3.fromRGB(245,245,245)
toggleBtn.TextColor3 = Color3.new(0,0,0)
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke", toggleBtn).Color = Color3.fromRGB(220,220,220)

local statusDot = safeNew("Frame"); statusDot.Parent = mainFrame
statusDot.Size = UDim2.new(0,18,0,18); statusDot.Position = UDim2.new(0.72,12,0.5, -9)
statusDot.BackgroundColor3 = Color3.fromRGB(150,0,0); Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1,0)

-- Settings panel
local settingsFrame = safeNew("Frame"); settingsFrame.Parent = gui
settingsFrame.Size = UDim2.new(0,0,0,0); settingsFrame.Position = UDim2.new(0.5,-180,0.12,140)
settingsFrame.AnchorPoint = Vector2.new(0.5,0); settingsFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
settingsFrame.Visible = false; settingsFrame.Active = true; settingsFrame.Draggable = true
Instance.new("UICorner", settingsFrame).CornerRadius = UDim.new(0,12)
Instance.new("UIStroke", settingsFrame).Color = Color3.fromRGB(210,210,210)
local padding = Instance.new("UIPadding", settingsFrame); padding.PaddingTop = UDim.new(0,12); padding.PaddingLeft = UDim.new(0,12); padding.PaddingRight = UDim.new(0,12)
local layout = Instance.new("UIListLayout", settingsFrame); layout.Padding = UDim.new(0,8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.VerticalAlignment = Enum.VerticalAlignment.Top

-- Factories
local function rowButton(text)
    local b = safeNew("TextButton")
    b.Size = UDim2.new(1,0,0,34)
    b.Font = Enum.Font.Gotham; b.TextSize = 14
    b.Text = text; b.TextColor3 = Color3.new(0,0,0)
    b.BackgroundColor3 = Color3.fromRGB(250,250,250)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", b); stroke.Color = Color3.fromRGB(220,220,220)
    return b
end

local function rowSlider(label, min, max, step, default, callback)
    local frameRow = safeNew("Frame"); frameRow.Parent = settingsFrame; frameRow.Size = UDim2.new(1,0,0,40); frameRow.BackgroundTransparency = 1
    local lbl = safeNew("TextLabel"); lbl.Parent = frameRow; lbl.Size = UDim2.new(0.6,0,1,0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextColor3 = Color3.new(0,0,0)
    local minus = safeNew("TextButton"); minus.Parent = frameRow; minus.Size = UDim2.new(0,36,0,28); minus.Position = UDim2.new(0.62,8,0.5,-14); minus.Text = "-"; minus.Font = Enum.Font.GothamBold; minus.TextSize = 18; minus.BackgroundColor3 = Color3.fromRGB(245,245,245)
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0,6)
    local plus = safeNew("TextButton"); plus.Parent = frameRow; plus.Size = UDim2.new(0,36,0,28); plus.Position = UDim2.new(0.81,8,0.5,-14); plus.Text = "+"; plus.Font = Enum.Font.GothamBold; plus.TextSize = 18; plus.BackgroundColor3 = Color3.fromRGB(245,245,245)
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0,6)
    local value = default
    local function upd(v)
        value = math.clamp(v, min, max)
        lbl.Text = label .. ": " .. tostring(math.floor(value))
        pcall(callback, value)
    end
    minus.MouseButton1Click:Connect(function() upd(value - step) end)
    plus.MouseButton1Click:Connect(function() upd(value + step) end)
    upd(default)
    return frameRow, lbl
end

local function rowToggle(label, default, callback)
    local v = default
    local btn = rowButton(label .. ": " .. (v and "ON" or "OFF"))
    btn.MouseButton1Click:Connect(function()
        v = not v
        btn.Text = label .. ": " .. (v and "ON" or "OFF")
        pcall(callback, v)
    end)
    btn.Parent = settingsFrame
    return btn
end

local function rowDropdown(label, opts, defaultValue, callback)
    local idx = 1
    for i,o in ipairs(opts) do if o.value == defaultValue then idx = i break end end
    local b = rowButton(label .. ": " .. opts[idx].label)
    b.MouseButton1Click:Connect(function()
        idx = idx % #opts + 1
        b.Text = label .. ": " .. opts[idx].label
        pcall(callback, opts[idx].value)
    end)
    b.Parent = settingsFrame
    return b
end

-- FOV visual
local fovFrame = safeNew("Frame"); fovFrame.Parent = gui
fovFrame.Name = "FOVFrame"; fovFrame.AnchorPoint = Vector2.new(0.5,0.5); fovFrame.Position = UDim2.new(0.5,0,0.5,0)
fovFrame.Size = UDim2.new(0, CFG.FOV_PIXELS*2, 0, CFG.FOV_PIXELS*2); fovFrame.BackgroundTransparency = 1; fovFrame.Visible = CFG.SHOW_FOV; fovFrame.ZIndex = 2
local inner = safeNew("Frame"); inner.Parent = fovFrame; inner.Size = UDim2.new(1,0,1,0); inner.BackgroundTransparency = 1
Instance.new("UICorner", inner).CornerRadius = UDim.new(1,0)
local innerStroke = Instance.new("UIStroke", inner); innerStroke.Thickness = CFG.FOV_THICKNESS; innerStroke.Color = CFG.FOV_COLOR; innerStroke.Transparency = 0.55; innerStroke.LineJoinMode = Enum.LineJoinMode.Round

-- Quick button
local quickBtn = safeNew("TextButton"); quickBtn.Parent = gui
quickBtn.AnchorPoint = Vector2.new(0,1); quickBtn.Position = UDim2.new(0,12,1,-90)
quickBtn.Size = UDim2.new(0,56,0,56); quickBtn.Text = "AIM"; quickBtn.Font = Enum.Font.GothamBold; quickBtn.TextSize = 16
quickBtn.TextColor3 = Color3.new(0,0,0); quickBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
quickBtn.Active = true; quickBtn.Draggable = true; quickBtn.ZIndex = 50
Instance.new("UICorner", quickBtn).CornerRadius = UDim.new(1,0)
Instance.new("UIStroke", quickBtn).Color = Color3.fromRGB(220,220,220)

-- Settings rows
rowSlider("Aim Smooth (higher=faster)", 1, 30, 1, CFG.SMOOTHING, function(v) CFG.SMOOTHING = v end)
rowDropdown("Aim Mode", { {label="Smooth", value="Smooth"}, {label="Snap", value="Snap"} }, CFG.AIM_MODE, function(v) CFG.AIM_MODE = v end)
rowToggle("Use Prediction", CFG.USE_PREDICTION, function(v) CFG.USE_PREDICTION = v end)
rowSlider("Bullet Speed (prediction)", 200, 5000, 50, CFG.BULLET_SPEED, function(v) CFG.BULLET_SPEED = v end)
rowSlider("Prediction Mult", 0, 3, 0.1, CFG.PREDICT_MULT, function(v) CFG.PREDICT_MULT = v end)
rowDropdown("Target Priority", { {label="Angle", value="Angle"}, {label="Screen", value="Screen"}, {label="Distance", value="Distance"} }, CFG.TARGET_PRIORITY, function(v) CFG.TARGET_PRIORITY = v end)
rowDropdown("Switch Mode", { {label="ByLook", value="ByLook"}, {label="Closest", value="Closest"} }, CFG.SWITCH_MODE, function(v) CFG.SWITCH_MODE = v end)
rowSlider("Switch Sensitivity (yaw)", 0.001, 0.02, 0.001, CFG.SWITCH_SENSITIVITY_YAW, function(v) CFG.SWITCH_SENSITIVITY_YAW = v end)
rowSlider("Switch Sensitivity (pitch)", 0.005, 0.12, 0.005, CFG.SWITCH_SENSITIVITY_PITCH, function(v) CFG.SWITCH_SENSITIVITY_PITCH = v end)
rowSlider("Switch Cooldown (s)", 0.02, 0.5, 0.01, CFG.SWITCH_COOLDOWN, function(v) CFG.SWITCH_COOLDOWN = math.max(0.02, v) end)
rowSlider("FOV Ring Size (px)", 20, 400, 5, CFG.FOV_PIXELS, function(v) CFG.FOV_PIXELS = v; if fovFrame then fovFrame.Size = UDim2.new(0, v*2, 0, v*2) end end)
rowToggle("Show FOV Ring", CFG.SHOW_FOV, function(v) CFG.SHOW_FOV = v; if fovFrame then fovFrame.Visible = v end end)
rowToggle("Friend Filter", CFG.USE_FRIEND_FILTER, function(v) CFG.USE_FRIEND_FILTER = v end)

-- Camera FOV slider (new feature)
rowSlider("Camera FOV", 50, 120, 1, CFG.CAMERA_FOV, function(v)
    CFG.CAMERA_FOV = v
    pcall(function() Camera.FieldOfView = math.clamp(v, 50, 120) end)
end)

-- Toggle behavior
local function updateUI()
    toggleBtn.Text = aiming and "AIMBOT: ON" or "AIMBOT: OFF"
    statusDot.BackgroundColor3 = aiming and Color3.fromRGB(0,200,0) or Color3.fromRGB(150,0,0)
end
updateUI()

settingsBtn.MouseButton1Click:Connect(function()
    pcall(function() if toggleSound then toggleSound:Play() end end)
    if settingsFrame.Visible then
        TweenService:Create(settingsFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
        task.delay(0.18, function() settingsFrame.Visible = false end)
    else
        settingsFrame.Visible = true
        local h = layout.AbsoluteContentSize.Y + 20
        settingsFrame.Size = UDim2.new(0,0,0,0)
        TweenService:Create(settingsFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0,360,0,h)}):Play()
    end
end)

toggleBtn.MouseButton1Click:Connect(function()
    aiming = not aiming; targetPart = nil; targetHRP = nil
    pcall(function() if toggleSound then toggleSound:Play() end end)
    updateUI()
end)
quickBtn.MouseButton1Click:Connect(function()
    aiming = not aiming; targetPart = nil; targetHRP = nil
    pcall(function() if toggleSound then toggleSound:Play() end end)
    local t1 = TweenService:Create(quickBtn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,46,0,46)})
    local t2 = TweenService:Create(quickBtn, TweenInfo.new(0.12, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {Size = UDim2.new(0,56,0,56)})
    t1:Play(); task.wait(0.09); t2:Play()
    updateUI()
end)

UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Enum.KeyCode.V then
        aiming = not aiming; targetPart = nil; targetHRP = nil
        pcall(function() if toggleSound then toggleSound:Play() end end)
        updateUI()
    end
end)

-- ESP (minimal)
local _ESP = {}
local function isRealPlayer(plr)
    if not plr or plr == LocalPlayer then return false end
    if CFG.USE_FRIEND_FILTER and LocalPlayer:IsFriendsWith(plr.UserId) then return false end
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildWhichIsA("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return true
end

local function createESPForPlayer(player)
    if not player or player == LocalPlayer then return end
    if _ESP[player] then return end
    local data = {}
    _ESP[player] = data
    local function buildForCharacter(char)
        if not char then return end
        if data.highlight then pcall(function() data.highlight:Destroy() end) end
        local ok, highlight = pcall(function()
            local h = Instance.new("Highlight")
            h.FillColor = Color3.fromRGB(255,0,0)
            h.OutlineColor = Color3.fromRGB(0,0,0)
            h.Adornee = char
            h.Parent = workspace
            h.Enabled = CFG.ESP_ENABLED
            return h
        end)
        if ok and highlight then data.highlight = highlight end
    end
    data.charConn = player.CharacterAdded:Connect(buildForCharacter)
    if player.Character then buildForCharacter(player.Character) end
    data.remove = function()
        pcall(function()
            if data.highlight then data.highlight:Destroy() end
            if data.charConn then data.charConn:Disconnect() end
        end)
        _ESP[player] = nil
    end
end

Players.PlayerAdded:Connect(function(plr)
    if CFG.ESP_ENABLED and plr ~= LocalPlayer then
        task.wait(0.12)
        createESPForPlayer(plr)
    end
end)
Players.PlayerRemoving:Connect(function(plr) if _ESP[plr] and _ESP[plr].remove then _ESP[plr].remove() end end)

-- Targeting helpers
local function isAirborne(hrp)
    if not hrp then return false end
    local vy = hrp.Velocity and hrp.Velocity.Y or 0
    return math.abs(vy) > 12
end

local function predictPos(part, hrp)
    if not CFG.USE_PREDICTION or not hrp then return part.Position end
    local vel = Vector3.new(0,0,0)
    pcall(function() if hrp and hrp:IsA("BasePart") then vel = hrp.Velocity end end)
    local dist = (part.Position - Camera.CFrame.Position).Magnitude
    if CFG.BULLET_SPEED <= 0 then return part.Position end
    local t = dist / CFG.BULLET_SPEED
    t = math.clamp(t, 0, 2)
    return part.Position + vel * t * CFG.PREDICT_MULT
end

local function screenDistanceToCenter(point)
    local viewCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    return (Vector2.new(point.X, point.Y) - viewCenter).Magnitude
end

local function pickBest(ignoreFOV)
    local bestPart, bestHRP = nil, nil
    local bestScore = math.huge
    local camCF = Camera.CFrame
    local camLook = camCF.LookVector
    for _,plr in ipairs(Players:GetPlayers()) do
        if isRealPlayer(plr) then
            local ch = plr.Character
            local part = ch and (ch:FindFirstChild(CFG.LOCK_PART) or ch:FindFirstChild("HumanoidRootPart"))
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if part and hrp then
                local worldDist = (part.Position - camCF.Position).Magnitude
                if worldDist <= CFG.AIM_RADIUS then
                    if CFG.IGNORE_AIR_SWITCH and isAirborne(hrp) and CFG.SWITCH_MODE == "ByLook" and not (targetPart and targetPart == part) then
                    else
                        local predicted = predictPos(part, hrp)
                        local dir = (predicted - camCF.Position)
                        if dir.Magnitude > 0 then
                            local dirUnit = dir.Unit
                            local dot = camLook:Dot(dirUnit)
                            local score
                            if CFG.TARGET_PRIORITY == "Angle" then
                                score = -dot + worldDist/10000
                            elseif CFG.TARGET_PRIORITY == "Screen" then
                                local scr, onScreen = Camera:WorldToViewportPoint(predicted)
                                if not onScreen and not ignoreFOV then
                                    score = 1e9
                                else
                                    local d = screenDistanceToCenter(scr)
                                    score = d + worldDist/1000
                                end
                            else
                                score = worldDist
                            end
                            if score < bestScore then bestScore = score; bestPart = part; bestHRP = hrp end
                        end
                    end
                end
            end
        end
    end
    targetPart = bestPart
    targetHRP = bestHRP
    return targetPart
end

local function aimAt(pos, dt)
    local origin = Camera.CFrame.Position
    if CFG.USE_CAM_HEIGHT then origin = origin + Vector3.new(0, CFG.CAM_HEIGHT, 0) end
    local desired = CFrame.new(origin, pos) * CFrame.Angles(math.rad(CFG.SCREEN_TILT), 0, 0)
    if CFG.AIM_MODE == "Snap" or CFG.SMOOTHING <= 0 then
        pcall(function() Camera.CFrame = desired end)
    else
        local alpha = 1 - math.exp(-CFG.SMOOTHING * math.clamp(dt, 0, 0.06) * 60)
        local cur = Camera.CFrame
        local nextCF = cur:Lerp(desired, alpha)
        pcall(function() Camera.CFrame = nextCF end)
    end
end

-- Render loop
RunService.RenderStepped:Connect(function()
    local now = tick()
    local dt = math.max(0.0001, now - lastRenderTick)
    lastRenderTick = now

    if fovFrame then
        pcall(function()
            fovFrame.Position = UDim2.new(0.5,0,0.5,0)
            fovFrame.Size = UDim2.new(0, CFG.FOV_PIXELS*2, 0, CFG.FOV_PIXELS*2)
            innerStroke.Thickness = CFG.FOV_THICKNESS
            innerStroke.Color = CFG.FOV_COLOR
        end)
    end

    local look = Camera.CFrame.LookVector
    local yaw = math.atan2(look.X, look.Z)
    local pitch = math.asin(-look.Y)
    local nowTick = tick()
    if lastYaw ~= nil then
        local dy = math.abs(yaw - lastYaw); if dy > math.pi then dy = math.abs(dy - 2*math.pi) end
        local dp = math.abs(pitch - lastPitch)
        if (dy >= CFG.SWITCH_SENSITIVITY_YAW or dp >= CFG.SWITCH_SENSITIVITY_PITCH) and (nowTick - lastSwitchTick) >= CFG.SWITCH_COOLDOWN then
            if CFG.SWITCH_MODE == "ByLook" then
                local candidate = pickBest(false)
                if candidate then
                    local predicted = predictPos(candidate, targetHRP)
                    local scr, onScreen = Camera:WorldToViewportPoint(predicted)
                    if onScreen and screenDistanceToCenter(scr) <= CFG.FOV_PIXELS then
                        targetPart = candidate
                        lastSwitchTick = nowTick
                    end
                end
            else
                pickBest(true)
                lastSwitchTick = nowTick
            end
        end
    end
    lastYaw = yaw; lastPitch = pitch

    if aiming then
        if not targetPart or not targetHRP or (targetPart.Position - Camera.CFrame.Position).Magnitude > CFG.AIM_RADIUS then
            pickBest(false)
        end
        if targetPart and targetHRP then
            local targetPos = predictPos(targetPart, targetHRP)
            aimAt(targetPos, dt)
        end
    end
end)

-- Keep GUI parented
spawn(function()
    while task.wait(2) do
        if not gui.Parent then pcall(function() gui.Parent = PlayerGui end) end
    end
end)

-- Apply initial camera FOV
pcall(function() Camera.FieldOfView = math.clamp(CFG.CAMERA_FOV or 70, 50, 120) end)

-- End
