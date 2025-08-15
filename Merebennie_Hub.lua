
-- Delta Aimlock - Modified per user request
-- Based on uploaded file. (original referenced) fileciteturn0file0

-- Services
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService     = game:GetService("SoundService")

-- Wait for player and PlayerGui
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

-- CONFIG (colors/fonts/behavior)
local CFG = {
    AIM_RADIUS = 500,
    LOCK_PART = "Head",
    AIM_MODE = "Smooth",
    SMOOTHING = 0.35,
    USE_CAM_HEIGHT = true,
    CAM_HEIGHT = 2,
    SCREEN_TILT = -5,
    SWITCH_SENSITIVITY_YAW = 0.006,
    SWITCH_SENSITIVITY_PITCH = 0.02,
    -- SWITCH_COOLDOWN removed from logic (user requested removal)
    TARGET_PRIORITY = "Angle",
    USE_FRIEND_FILTER = true,
    SHOW_FOV = true,
    FOV_PIXELS = 120,
    FOV_THICKNESS = 3,
    FOV_COLOR = Color3.fromRGB(120, 200, 255),

    -- sound changed to user's asset (Button-Click)
    TOGGLE_SOUND_ID = "rbxassetid://6042053626",
    USE_PREDICTION = false,
    BULLET_SPEED = 1400,
    PREDICT_MULT = 1.0,

    -- ESP defaults
    ESP_ENABLED = false,
    ESP_ALWAYS_ON_TOP = true,
    ESP_SHOW_NAME = true,
    ESP_FILL = Color3.fromRGB(255, 80, 80),
    ESP_OUTLINE = Color3.fromRGB(0,0,0),

    UI_BG = Color3.fromRGB(18,18,22),
    UI_ACCENT = Color3.fromRGB(40,160,220),
    UI_BTN = Color3.fromRGB(33, 37, 43),
    UI_BTN_TEXT = Color3.new(1,1,1),
}

-- STATE
local aiming = false
local targetPart = nil
local targetHRP = nil
local lastYaw, lastPitch = nil, nil

local toggleSound = newSound(CFG.TOGGLE_SOUND_ID)

-- GUI BUILD
local gui = safeNew("ScreenGui")
if not gui then return end
gui.Name = "DeltaAim_UI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = PlayerGui end)

LocalPlayer.CharacterAdded:Connect(function()
    if not gui.Parent then pcall(function() gui.Parent = PlayerGui end) end
end)

-- Watermark (top-left, pixelated font)
local watermark = Instance.new("TextLabel")
watermark.Name = "Watermark"
watermark.Parent = gui
watermark.AnchorPoint = Vector2.new(0, 0)
watermark.Position = UDim2.new(0, 6, 0, 6) -- top-left
watermark.Size = UDim2.new(0, 200, 0, 18)
watermark.BackgroundTransparency = 1
watermark.Text = "Made by Merebennie"
-- Pixelated font
watermark.Font = Enum.Font.Pixel
watermark.TextSize = 14
watermark.TextColor3 = Color3.new(1, 1, 1)
watermark.TextTransparency = 0
watermark.TextStrokeColor3 = Color3.new(0, 0, 0)
watermark.TextStrokeTransparency = 0.3
watermark.ZIndex = 200

-- FPS Counter (top-right)
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Name = "FPSCounter"
fpsLabel.Parent = gui
fpsLabel.AnchorPoint = Vector2.new(1, 0)
fpsLabel.Position = UDim2.new(1, -8, 0, 6)
fpsLabel.Size = UDim2.new(0, 100, 0, 18)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 14
fpsLabel.TextColor3 = Color3.new(1,1,1)
fpsLabel.Text = "FPS: ..."
fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
fpsLabel.ZIndex = 200

-- Main small box (70x70) with only the indicator
local mainFrame = safeNew("Frame"); mainFrame.Parent = gui
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0,70,0,70)
mainFrame.Position = UDim2.new(0,12,1,-120) -- bottom-left practical spot for mobile
mainFrame.AnchorPoint = Vector2.new(0,0)
mainFrame.Active = true; mainFrame.Draggable = true
mainFrame.BackgroundColor3 = CFG.UI_BG
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke", mainFrame).Color = CFG.UI_ACCENT

-- Indicator (centered)
local statusDot = safeNew("Frame"); statusDot.Parent = mainFrame
statusDot.Size = UDim2.new(0,40,0,40)
statusDot.AnchorPoint = Vector2.new(0.5,0.5)
statusDot.Position = UDim2.new(0.5,0.5,0.5,0)
statusDot.BackgroundColor3 = Color3.fromRGB(150,0,0)
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1,0)
statusDot.ZIndex = 150

-- A small label below indicator to show "AIM" (optional)
local mainLabel = safeNew("TextLabel"); mainLabel.Parent = mainFrame
mainLabel.Size = UDim2.new(1,0,0,14); mainLabel.Position = UDim2.new(0,0,1,-16)
mainLabel.BackgroundTransparency = 1
mainLabel.Font = Enum.Font.GothamBold
mainLabel.TextSize = 12
mainLabel.TextColor3 = Color3.new(1,1,1)
mainLabel.Text = "AIM"
mainLabel.TextTransparency = 0
mainLabel.ZIndex = 150

-- Settings button (separate small gear near main)
local settingsBtn = safeNew("TextButton"); settingsBtn.Parent = gui
settingsBtn.Size = UDim2.new(0,28,0,28)
settingsBtn.Position = UDim2.new(0,94,1,-120) -- a bit right of mainFrame
settingsBtn.AnchorPoint = Vector2.new(0,0)
settingsBtn.Text = "⚙"
settingsBtn.Font = Enum.Font.GothamBold; settingsBtn.TextSize = 18
settingsBtn.TextColor3 = CFG.UI_BTN_TEXT
settingsBtn.BackgroundColor3 = CFG.UI_BTN
Instance.new("UICorner", settingsBtn).CornerRadius = UDim.new(1,0)
Instance.new("UIStroke", settingsBtn).Color = CFG.UI_ACCENT
settingsBtn.ZIndex = 160

-- Settings panel (MOVABLE)
local settingsFrame = safeNew("Frame"); settingsFrame.Parent = gui
settingsFrame.Size = UDim2.new(0,0,0,0); settingsFrame.Position = UDim2.new(0.5,-140,0.12,108)
settingsFrame.AnchorPoint = Vector2.new(0.5,0); settingsFrame.BackgroundColor3 = CFG.UI_BG
settingsFrame.Visible = false; settingsFrame.Active = true; settingsFrame.Draggable = true
Instance.new("UICorner", settingsFrame).CornerRadius = UDim.new(0,12)
Instance.new("UIStroke", settingsFrame).Color = CFG.UI_ACCENT
local padding = Instance.new("UIPadding", settingsFrame); padding.PaddingTop = UDim.new(0,8); padding.PaddingLeft = UDim.new(0,8); padding.PaddingRight = UDim.new(0,8)
local layout = Instance.new("UIListLayout", settingsFrame); layout.Padding = UDim.new(0,8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.VerticalAlignment = Enum.VerticalAlignment.Top

-- Utilities: animated button factory (with scale press animation)
local function animatePress(btn)
    if not btn or not btn:IsA("GuiObject") then return end
    btn.MouseButton1Down:Connect(function()
        pcall(function() TweenService:Create(btn, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset * 0.96, btn.Size.Y.Scale, btn.Size.Y.Offset * 0.96)}):Play() end)
    end)
    btn.MouseButton1Up:Connect(function()
        pcall(function() TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset / 0.96, btn.Size.Y.Scale, btn.Size.Y.Offset / 0.96)}):Play() end)
    end)
end

local function rowButton(text)
    local b = safeNew("TextButton")
    b.Size = UDim2.new(1,0,0,30)
    b.Font = Enum.Font.Gotham; b.TextSize = 14
    b.Text = text; b.TextColor3 = CFG.UI_BTN_TEXT
    b.BackgroundColor3 = CFG.UI_BTN
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", b).Color = CFG.UI_ACCENT
    animatePress(b)
    return b
end

-- slider factory with english labels
local function rowSlider(label, min, max, step, default, callback)
    local frameRow = safeNew("Frame"); frameRow.Parent = settingsFrame; frameRow.Size = UDim2.new(1,0,0,28); frameRow.BackgroundTransparency = 1
    local lbl = safeNew("TextLabel"); lbl.Parent = frameRow; lbl.Size = UDim2.new(0.62,0,1,0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextColor3 = Color3.new(1,1,1)
    local minus = rowButton("-"); minus.Parent = frameRow; minus.Size = UDim2.new(0,26,1,0); minus.Position = UDim2.new(0.66,4,0,0)
    local plus = rowButton("+"); plus.Parent = frameRow; plus.Size = UDim2.new(0,26,1,0); plus.Position = UDim2.new(0.86,4,0,0)
    local value = default
    local function upd(v)
        value = math.clamp(v, min, max)
        lbl.Text = label .. ": " .. string.format("%.2f", value)
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

-- FOV frame
local fovFrame = safeNew("Frame"); fovFrame.Parent = gui
fovFrame.Name = "FOVFrame"; fovFrame.AnchorPoint = Vector2.new(0.5,0.5); fovFrame.Position = UDim2.new(0.5,0,0.5,0)
fovFrame.Size = UDim2.new(0, CFG.FOV_PIXELS*2, 0, CFG.FOV_PIXELS*2); fovFrame.BackgroundTransparency = 1; fovFrame.Visible = CFG.SHOW_FOV; fovFrame.ZIndex = 2
local inner = safeNew("Frame"); inner.Parent = fovFrame; inner.Size = UDim2.new(1,0,1,0); inner.BackgroundTransparency = 1
Instance.new("UICorner", inner).CornerRadius = UDim.new(1,0)
local innerStroke = Instance.new("UIStroke", inner); innerStroke.Thickness = CFG.FOV_THICKNESS; innerStroke.Color = CFG.FOV_COLOR; innerStroke.Transparency = 0.5; innerStroke.LineJoinMode = Enum.LineJoinMode.Round

-- Quick movable small aim toggle (in case user likes it)
local quickBtn = safeNew("TextButton"); quickBtn.Parent = gui
quickBtn.AnchorPoint = Vector2.new(0,1); quickBtn.Position = UDim2.new(0,12,1,-80)
quickBtn.Size = UDim2.new(0,52,0,52); quickBtn.Text = "AIM"; quickBtn.Font = Enum.Font.GothamBold; quickBtn.TextSize = 16
quickBtn.TextColor3 = Color3.new(1,1,1); quickBtn.BackgroundColor3 = CFG.UI_BTN
quickBtn.Active = true; quickBtn.Draggable = true; quickBtn.ZIndex = 50
Instance.new("UICorner", quickBtn).CornerRadius = UDim.new(1,0)
Instance.new("UIStroke", quickBtn).Color = CFG.UI_ACCENT
animatePress(quickBtn)

-- SETTINGS ROWS (English labels and options)
rowSlider("Aim Smoothing (0..1)", 0, 1, 0.01, CFG.SMOOTHING, function(v) CFG.SMOOTHING = v end)
rowDropdown("Aim Mode", { {label="Smooth", value="Smooth"}, {label="Snap", value="Snap"} }, CFG.AIM_MODE, function(v) CFG.AIM_MODE = v end)
rowToggle("Use Prediction", CFG.USE_PREDICTION, function(v) CFG.USE_PREDICTION = v end)
rowSlider("Bullet Speed (for prediction)", 200, 5000, 50, CFG.BULLET_SPEED, function(v) CFG.BULLET_SPEED = v end)
rowSlider("Prediction Multiplier", 0, 3, 0.01, CFG.PREDICT_MULT, function(v) CFG.PREDICT_MULT = v end)
rowDropdown("Target Priority", { {label="Angle", value="Angle"}, {label="Screen", value="Screen"}, {label="Distance", value="Distance"} }, CFG.TARGET_PRIORITY, function(v) CFG.TARGET_PRIORITY = v end)

rowSlider("Screen Tilt (deg)", -15, 15, 1, CFG.SCREEN_TILT, function(v) CFG.SCREEN_TILT = v end)
rowSlider("Switch Sensitivity (yaw)", 0.001, 0.02, 0.001, CFG.SWITCH_SENSITIVITY_YAW, function(v) CFG.SWITCH_SENSITIVITY_YAW = v end)
rowSlider("Switch Sensitivity (pitch)", 0.005, 0.12, 0.005, CFG.SWITCH_SENSITIVITY_PITCH, function(v) CFG.SWITCH_SENSITIVITY_PITCH = v end)

rowSlider("FOV Size (px)", 20, 400, 5, CFG.FOV_PIXELS, function(v) CFG.FOV_PIXELS = v; if fovFrame then fovFrame.Size = UDim2.new(0, v*2, 0, v*2) end end)
rowToggle("Show FOV Ring", CFG.SHOW_FOV, function(v) CFG.SHOW_FOV = v; if fovFrame then fovFrame.Visible = v end end)
rowToggle("Friend Filter", CFG.USE_FRIEND_FILTER, function(v) CFG.USE_FRIEND_FILTER = v end)

-- ESP Row
rowToggle("Enable ESP", CFG.ESP_ENABLED, function(v)
    CFG.ESP_ENABLED = v
    if v then
        for _,plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer then spawn(function() if plr.Character then createESPForPlayer(plr) end end) end end
    else
        for _,plr in ipairs(Players:GetPlayers()) do removeESPForPlayer(plr) end
    end
end)
rowToggle("ESP Always On Top", CFG.ESP_ALWAYS_ON_TOP, function(v)
    CFG.ESP_ALWAYS_ON_TOP = v
    for _,plr in ipairs(Players:GetPlayers()) do
        local data = _ESP and _ESP[plr]
        if data and data.highlight then
            pcall(function()
                data.highlight.DepthMode = v and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            end)
        end
    end
end)
rowToggle("Show Names (ESP)", CFG.ESP_SHOW_NAME, function(v)
    CFG.ESP_SHOW_NAME = v
    for _,plr in ipairs(Players:GetPlayers()) do
        local data = _ESP and _ESP[plr]
        if data then
            if data.billboard then data.billboard.Enabled = CFG.ESP_SHOW_NAME end
        end
    end
end)

-- Spawn management (Set spawn / Teleport to spawn / Reset)
local savedSpawns = {}

local setSpawnBtn = rowButton("Set Spawn (record current position)")
setSpawnBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local pos = char.HumanoidRootPart.Position
        table.insert(savedSpawns, pos)
        setSpawnBtn.Text = "Set Spawn (saved: " .. tostring(#savedSpawns) .. ")"
        if toggleSound then pcall(function() toggleSound:Play() end) end
    end
end)
setSpawnBtn.Parent = settingsFrame

local teleportSpawnBtn = rowButton("Teleport To Last Spawn")
teleportSpawnBtn.MouseButton1Click:Connect(function()
    if #savedSpawns == 0 then
        teleportSpawnBtn.Text = "Teleport To Last Spawn (none)"
        return
    end
    local last = savedSpawns[#savedSpawns]
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            char:SetPrimaryPartCFrame(CFrame.new(last + Vector3.new(0,2,0)))
        end)
        if toggleSound then pcall(function() toggleSound:Play() end) end
    end
end)
teleportSpawnBtn.Parent = settingsFrame

local resetSpawnsBtn = rowButton("Reset All Set Spawns")
resetSpawnsBtn.MouseButton1Click:Connect(function()
    savedSpawns = {}
    setSpawnBtn.Text = "Set Spawn (record current position)"
    if toggleSound then pcall(function() toggleSound:Play() end) end
end)
resetSpawnsBtn.Parent = settingsFrame

-- helper to compute settings height
local function computeSettingsHeight()
    for i=1,6 do task.wait(0.01) end
    local ok, size = pcall(function() return layout.AbsoluteContentSize.Y + 16 end)
    return (ok and size) or 120
end

settingsBtn.MouseButton1Click:Connect(function()
    pcall(function() if toggleSound then toggleSound:Play() end end)
    if settingsFrame.Visible then
        TweenService:Create(settingsFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
        task.delay(0.18, function() settingsFrame.Visible = false end)
    else
        settingsFrame.Visible = true
        local h = computeSettingsHeight()
        TweenService:Create(settingsFrame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0,300,0,h)}):Play()
    end
end)

-- UI update
local function updateUI()
    mainLabel.Text = aiming and "AIM (ON)" or "AIM (OFF)"
    statusDot.BackgroundColor3 = aiming and Color3.fromRGB(0,200,0) or Color3.fromRGB(150,0,0)
end
updateUI()

-- toggle behavior (via mainFrame or quick button)
local function toggleAiming()
    aiming = not aiming; targetPart = nil; targetHRP = nil
    pcall(function() if toggleSound then toggleSound:Play() end end)
    updateUI()
end

mainFrame.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        toggleAiming()
    end
end)

toggleBtn = nil -- original toggle removed (main indicator used)
quickBtn.MouseButton1Click:Connect(toggleAiming)

UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Enum.KeyCode.V then
        toggleAiming()
    end
end)

-- ===== ESP IMPLEMENTATION =====
_ESP = {}

function createESPForPlayer(player)
    if not player or player == LocalPlayer then return end
    if _ESP[player] then return end

    local data = {}
    _ESP[player] = data

    local function buildForCharacter(char)
        if not char then return end
        if data.highlight then pcall(function() data.highlight:Destroy() end); data.highlight = nil end
        if data.billboard then pcall(function() data.billboard:Destroy() end); data.billboard = nil end

        local ok, highlight = pcall(function()
            local h = Instance.new("Highlight")
            h.FillColor = CFG.ESP_FILL
            h.OutlineColor = CFG.ESP_OUTLINE
            h.Adornee = char
            h.Parent = workspace
            h.Enabled = CFG.ESP_ENABLED
            h.DepthMode = CFG.ESP_ALWAYS_ON_TOP and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            return h
        end)
        if ok and highlight then data.highlight = highlight end

        local head = char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
        if head then
            local ok2, billboard = pcall(function()
                local bg = Instance.new("BillboardGui")
                bg.Name = "ESPName"
                bg.Adornee = head
                bg.Size = UDim2.new(0,140,0,36)
                bg.StudsOffset = Vector3.new(0, 1.6, 0)
                bg.AlwaysOnTop = true
                bg.Parent = char
                local txt = Instance.new("TextLabel", bg)
                txt.Size = UDim2.new(1,0,1,0)
                txt.BackgroundTransparency = 1
                txt.Text = player.Name
                txt.TextColor3 = Color3.new(1,1,1)
                txt.Font = Enum.Font.GothamBold
                txt.TextScaled = true
                txt.ZIndex = 10
                txt.TextStrokeColor3 = Color3.new(0,0,0)
                txt.TextStrokeTransparency = 0.2
                local outline = Instance.new("Frame", bg)
                outline.AnchorPoint = Vector2.new(0.5, 0.5)
                outline.Size = UDim2.new(1.02, 0, 1.02, 0)
                outline.Position = UDim2.new(0.5, 0, 0.5, 0)
                outline.BackgroundTransparency = 0.95
                outline.BackgroundColor3 = Color3.new(0,0,0)
                outline.ZIndex = 9
                return bg
            end)
            if ok2 and billboard then data.billboard = billboard; data.billboard.Enabled = CFG.ESP_SHOW_NAME end
        end
    end

    data.charConn = player.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        buildForCharacter(char)
    end)

    if player.Character then buildForCharacter(player.Character) end

    data.remove = function()
        pcall(function()
            if data.highlight then data.highlight:Destroy() end
            if data.billboard then data.billboard:Destroy() end
            if data.charConn then data.charConn:Disconnect() end
        end)
        _ESP[player] = nil
    end
end

function removeESPForPlayer(player)
    local data = _ESP[player]
    if not data then return end
    pcall(function()
        if data.highlight then data.highlight:Destroy() end
        if data.billboard then data.billboard:Destroy() end
        if data.charConn then data.charConn:Disconnect() end
    end)
    _ESP[player] = nil
end

Players.PlayerAdded:Connect(function(plr)
    if CFG.ESP_ENABLED and plr ~= LocalPlayer then
        task.wait(0.12)
        createESPForPlayer(plr)
    end
end)
Players.PlayerRemoving:Connect(function(plr)
    removeESPForPlayer(plr)
end)

if CFG.ESP_ENABLED then
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then createESPForPlayer(plr) end
    end
end

-- ===== TARGETING HELPERS =====
local function isRealPlayer(plr)
    if not plr or plr == LocalPlayer then return false end
    if CFG.USE_FRIEND_FILTER and LocalPlayer:IsFriendsWith(plr.UserId) then return false end
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildWhichIsA("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return Players:FindFirstChild(plr.Name) ~= nil
end

-- Improved prediction: solves intercept time for moving target vs bullet speed
local function predictPos(part, hrp)
    if not part then return part and part.Position end
    if not CFG.USE_PREDICTION or not hrp then return part.Position end

    local origin = Camera.CFrame.Position
    if CFG.USE_CAM_HEIGHT then origin = origin + Vector3.new(0, CFG.CAM_HEIGHT, 0) end

    local targetPos = part.Position
    local r = targetPos - origin
    local v = Vector3.new(0,0,0)
    pcall(function() if hrp and hrp:IsA("BasePart") then v = hrp.Velocity end end)
    local s = math.max(0.0001, CFG.BULLET_SPEED)

    local a = v:Dot(v) - s*s
    local b = 2 * r:Dot(v)
    local c = r:Dot(r)

    local t = nil
    if math.abs(a) < 1e-6 then
        -- linear: b t + c = 0 => t = -c / b
        if math.abs(b) > 1e-6 then
            local tt = -c / b
            if tt > 0 then t = tt end
        end
    else
        local disc = b*b - 4*a*c
        if disc >= 0 then
            local sqrtD = math.sqrt(disc)
            local t1 = (-b + sqrtD) / (2*a)
            local t2 = (-b - sqrtD) / (2*a)
            -- choose smallest positive
            local cand = {}
            if t1 > 0 then table.insert(cand, t1) end
            if t2 > 0 then table.insert(cand, t2) end
            if #cand > 0 then
                t = math.min(unpack(cand))
            end
        end
    end

    if not t then
        -- fallback to simple estimate
        local dist = r.Magnitude
        t = dist / s
    end

    -- apply multiplier and lead
    local lead = v * t * (CFG.PREDICT_MULT or 1)
    return targetPos + lead
end

local function pickBest(ignoreFOV)
    local bestPart, bestHRP = nil, nil
    local bestScore = math.huge
    local camCF = Camera.CFrame
    local camLook = camCF.LookVector
    local viewCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _,plr in ipairs(Players:GetPlayers()) do
        if isRealPlayer(plr) then
            local ch = plr.Character
            local part = ch and (ch:FindFirstChild(CFG.LOCK_PART) or ch:FindFirstChild("HumanoidRootPart"))
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if part and hrp then
                local worldDist = (part.Position - camCF.Position).Magnitude
                if worldDist <= CFG.AIM_RADIUS then
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
                                score = 1e6
                            else
                                local d = (Vector2.new(scr.X, scr.Y) - viewCenter).Magnitude
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

    targetPart = bestPart
    targetHRP = bestHRP
    return targetPart
end

local function selectByLook()
    pickBest(true)
end

local function aimAt(pos)
    if not pos then return end
    local origin = Camera.CFrame.Position
    if CFG.USE_CAM_HEIGHT then origin = origin + Vector3.new(0, CFG.CAM_HEIGHT, 0) end
    local desired = CFrame.new(origin, pos) * CFrame.Angles(math.rad(CFG.SCREEN_TILT), 0, 0)
    if CFG.AIM_MODE == "Snap" or CFG.SMOOTHING <= 0 then
        pcall(function() Camera.CFrame = desired end)
    else
        local cur = Camera.CFrame
        local alpha = math.clamp(CFG.SMOOTHING, 0, 1)
        local nextCF = cur:Lerp(desired, alpha)
        pcall(function() Camera.CFrame = nextCF end)
    end
end

-- Main loop
local lastFrameTime = tick()
local fpsAcc = 0
local fpsCount = 0
local fpsUpdateTimer = 0

RunService.RenderStepped:Connect(function(dt)
    -- keep FOV centered and sized
    if fovFrame then
        pcall(function()
            fovFrame.Position = UDim2.new(0.5,0,0.5,0)
            fovFrame.Size = UDim2.new(0, CFG.FOV_PIXELS*2, 0, CFG.FOV_PIXELS*2)
            innerStroke.Thickness = CFG.FOV_THICKNESS
            innerStroke.Color = CFG.FOV_COLOR
        end)
    end

    -- camera-swiping switching WITHOUT cooldown (user requested removal of cooldown)
    local look = Camera.CFrame.LookVector
    local yaw = math.atan2(look.X, look.Z)
    local pitch = math.asin(-look.Y)
    if lastYaw ~= nil then
        local dy = math.abs(yaw - lastYaw); if dy > math.pi then dy = math.abs(dy - 2*math.pi) end
        local dp = math.abs(pitch - lastPitch)
        if (dy >= CFG.SWITCH_SENSITIVITY_YAW or dp >= CFG.SWITCH_SENSITIVITY_PITCH) then
            -- immediate select by look (no cooldown gating)
            selectByLook()
        end
    end
    lastYaw = yaw; lastPitch = pitch

    if aiming then
        if not targetPart or not targetHRP or (targetPart.Position - Camera.CFrame.Position).Magnitude > CFG.AIM_RADIUS then
            pickBest(false)
        end
        if targetPart and targetHRP then
            local targetPos = predictPos(targetPart, targetHRP)
            aimAt(targetPos)
        end
    end

    -- FPS calculation (smooth average)
    fpsAcc = fpsAcc + (1/dt)
    fpsCount = fpsCount + 1
    fpsUpdateTimer = fpsUpdateTimer + dt
    if fpsUpdateTimer >= 0.5 then
        local avg = math.floor((fpsAcc / math.max(1, fpsCount)) + 0.5)
        fpsLabel.Text = "FPS: " .. tostring(avg)
        fpsAcc = 0; fpsCount = 0; fpsUpdateTimer = 0
    end
end)

-- GUI safety: reparent if removed
spawn(function()
    while task.wait(2) do
        if not gui.Parent then pcall(function() gui.Parent = PlayerGui end) end
    end
end)

print("[DeltaAim] Modified version loaded.")
