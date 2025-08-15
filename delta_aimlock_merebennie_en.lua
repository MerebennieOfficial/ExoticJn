
-- Delta Aimlock — Merebennie Edition (English) — Optimized for Delta Mobile Executor
-- All UI is pure white; text is white with thin black outline; indicator-only main button.
-- Adaptive prediction (velocity + ping + FPS), smart target switching, LOS visibility filter,
-- settings fixed to prevent click-through, watermark top-left, FPS counter and FPS booster included.

-- ======= SERVICE BINDINGS =======
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService     = game:GetService("SoundService")
local Stats            = game:GetService("Stats")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")

-- ======= LOCAL STATE =======
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.05); LocalPlayer = Players.LocalPlayer end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera    = Workspace.CurrentCamera

-- ======= SAFE CONSTRUCTORS =======
local function safeNew(className)
    local ok, obj = pcall(function() return Instance.new(className) end)
    if ok then return obj end
    return nil
end

local function safeParent(obj, parent)
    if obj then
        local ok = pcall(function() obj.Parent = parent end)
        if ok then return true end
    end
    return false
end

local function try(func, ...)
    local ok, res = pcall(func, ...)
    if ok then return res end
    return nil
end

local function newSound(id)
    local snd = safeNew("Sound")
    if not snd then return nil end
    snd.SoundId = id
    snd.Volume  = 1
    safeParent(snd, SoundService)
    return snd
end

-- ======= CONFIG =======
local CFG = {
    AIM_RADIUS = 500,
    LOCK_PART  = "Head",
    AIM_MODE   = "Smooth",      -- "Smooth" | "Snap"
    SMOOTHING  = 0.35,          -- 0..1

    USE_CAM_HEIGHT = true,
    CAM_HEIGHT     = 2,
    SCREEN_TILT    = -5,        -- degrees

    SWITCH_SENSITIVITY_YAW   = 0.006,
    SWITCH_SENSITIVITY_PITCH = 0.020,
    SWITCH_COOLDOWN          = 0.08,  -- seconds
    TARGET_PRIORITY          = "Screen", -- "Angle" | "Screen" | "Distance"

    SHOW_FOV      = true,
    FOV_PIXELS    = 120,
    FOV_THICKNESS = 3,
    FOV_COLOR     = Color3.fromRGB(255,255,255),

    CLICK_SOUND_ID = "rbxassetid://6042053626",

    USE_PREDICTION      = true,
    BULLET_SPEED        = 1400,     -- studs/sec
    NET_COMPENSATION    = 1.0,
    FPS_COMPENSATION    = 1.0,
    VELOCITY_WEIGHT     = 1.0,
    MAX_LEAD_SECONDS    = 0.35,

    REQUIRE_VISIBLE = true,      -- line-of-sight filter
    VIS_STICKY_TIME = 0.12,      -- seconds

    USE_FRIEND_FILTER = true,

    ESP_ENABLED         = false,
    ESP_ALWAYS_ON_TOP   = true,
    ESP_SHOW_NAME       = true,
    ESP_FILL            = Color3.fromRGB(255, 0, 0),
    ESP_OUTLINE         = Color3.fromRGB(0, 0, 0),

    -- FPS Counter
    SHOW_FPS_COUNTER  = true,
    FPS_SMOOTH_FACTOR = 0.9,

    -- FPS Booster (local client-side optimizations)
    BOOSTER_DEFAULT = false,
    BOOSTER_PARTICLE_RATE_SCALE = 0.1,  -- scale particle rate
    BOOSTER_DISABLE_POSTFX      = true, -- disable DOF/Bloom/Blur/SunRays/CC
    BOOSTER_DISABLE_SHADOWS     = true,
    BOOSTER_SET_MATERIAL        = false, -- if true, set BasePart.Material to SmoothPlastic (restored when disabled)
}

-- ======= RUNTIME VARS =======
local aiming                 = false
local targetPart             = nil
local targetHRP              = nil
local lastYaw, lastPitch     = nil, nil
local lastSwitchTick         = 0
local avgDelta               = 1/60
local lastSeenVisibleAt      = 0

-- ======= SOUNDS =======
local clickSound = newSound(CFG.CLICK_SOUND_ID)

-- ======= GUI ROOT =======
local gui = safeNew("ScreenGui")
if not gui then return end
gui.Name = "DeltaAim_UI_EN"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
safeParent(gui, PlayerGui)

LocalPlayer.CharacterAdded:Connect(function()
    if not gui.Parent then safeParent(gui, PlayerGui) end
end)

-- ======= UI HELPERS =======
local function applyTextStyle(lbl, size, isBold)
    if not lbl then return end
    lbl.BackgroundTransparency = 1
    lbl.Font = isBold and Enum.Font.GothamBold or Enum.Font.Gotham
    lbl.TextSize = size
    lbl.TextColor3 = Color3.new(1,1,1) -- white
    lbl.TextStrokeColor3 = Color3.new(0,0,0)
    lbl.TextStrokeTransparency = 0.15
end

local function strokeify(obj)
    if not obj then return nil end
    local st = safeNew("UIStroke")
    if not st then return nil end
    st.Color = Color3.fromRGB(0,0,0)
    st.Thickness = 1
    safeParent(st, obj)
    return st
end

local function cornerify(obj, radius)
    if not obj then return nil end
    local c = safeNew("UICorner")
    if not c then return nil end
    c.CornerRadius = UDim.new(0, radius or 8)
    safeParent(c, obj)
    return c
end

local function makeRowButton(text)
    local b = safeNew("TextButton")
    b.Size = UDim2.new(1,0,0,30)
    b.AutoButtonColor = true
    applyTextStyle(b, 14, false)
    b.Text = text
    b.BackgroundColor3 = Color3.new(1,1,1)
    cornerify(b, 6)
    strokeify(b)
    return b
end

local function invisibleWhenHiddenGuard(frame)
    if not frame then return end
    frame.Visible = false
    frame.Active  = false
end

local function visibleInteractive(frame)
    if not frame then return end
    frame.Visible = true
    frame.Active  = true
end

-- ======= WATERMARK =======
local watermark = safeNew("TextLabel")
watermark.Name = "Watermark"
watermark.AnchorPoint = Vector2.new(0, 0)
watermark.Position = UDim2.new(0, 6, 0, 6)
watermark.Size = UDim2.new(0, 240, 0, 20)
watermark.BackgroundTransparency = 1
watermark.Text = "Made by Merebennie"
watermark.Font = Enum.Font.Arcade
watermark.TextSize = 16
watermark.TextColor3 = Color3.new(1, 1, 1)
watermark.TextStrokeColor3 = Color3.fromRGB(0,0,0)
watermark.TextStrokeTransparency = 0.15
watermark.ZIndex = 100
safeParent(watermark, gui)

-- ======= MAIN FRAME =======
local mainFrame = safeNew("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 280, 0, 110)
mainFrame.Position = UDim2.new(0.5, -140, 0.12, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.BackgroundColor3 = Color3.new(1,1,1) -- white
cornerify(mainFrame, 12)
strokeify(mainFrame)
safeParent(mainFrame, gui)

local title = safeNew("TextLabel")
title.Size = UDim2.new(1, -40, 0, 28)
title.Position = UDim2.new(0, 8, 0, 0)
applyTextStyle(title, 18, true)
title.Text = "Aimlock Controller"
title.TextXAlignment = Enum.TextXAlignment.Left
safeParent(title, mainFrame)

local settingsBtn = safeNew("TextButton")
settingsBtn.Size = UDim2.new(0, 28, 0, 28)
settingsBtn.Position = UDim2.new(1, -8, 0, 4)
settingsBtn.AnchorPoint = Vector2.new(1,0)
settingsBtn.Text = "⚙"
applyTextStyle(settingsBtn, 18, true)
settingsBtn.BackgroundColor3 = Color3.new(1,1,1)
cornerify(settingsBtn, 14)
strokeify(settingsBtn)
safeParent(settingsBtn, mainFrame)

-- Indicator-only container
local indicatorBack = safeNew("Frame")
indicatorBack.Size = UDim2.new(0.85, 0, 0, 38)
indicatorBack.Position = UDim2.new(0.05, 0, 0.52, 0)
indicatorBack.BackgroundColor3 = Color3.new(1,1,1)
cornerify(indicatorBack, 8)
strokeify(indicatorBack)
safeParent(indicatorBack, mainFrame)

local statusDot = safeNew("Frame")
statusDot.Size = UDim2.new(0, 18, 0, 18)
statusDot.Position = UDim2.new(0.84, 0, 0.55, 0)
statusDot.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
cornerify(statusDot, 50)
strokeify(statusDot)
safeParent(statusDot, mainFrame)

-- ======= SETTINGS PANEL =======
local settingsFrame = safeNew("Frame")
settingsFrame.Size = UDim2.new(0, 0, 0, 0)
settingsFrame.Position = UDim2.new(0.5, -150, 0.12, 120)
settingsFrame.AnchorPoint = Vector2.new(0.5,0)
settingsFrame.BackgroundColor3 = Color3.new(1,1,1)
settingsFrame.Draggable = true
cornerify(settingsFrame, 12)
strokeify(settingsFrame)
safeParent(settingsFrame, gui)
invisibleWhenHiddenGuard(settingsFrame)

local sPadding = safeNew("UIPadding")
sPadding.PaddingTop = UDim.new(0, 8)
sPadding.PaddingLeft = UDim.new(0, 8)
sPadding.PaddingRight = UDim.new(0, 8)
safeParent(sPadding, settingsFrame)

local sLayout = safeNew("UIListLayout")
sLayout.Padding = UDim.new(0, 8)
sLayout.SortOrder = Enum.SortOrder.LayoutOrder
sLayout.VerticalAlignment = Enum.VerticalAlignment.Top
safeParent(sLayout, settingsFrame)

-- ======= QUICK AIM BUTTON (circle Aimbot) =======
local quickBtn = safeNew("TextButton")
quickBtn.AnchorPoint = Vector2.new(0,1)
quickBtn.Position = UDim2.new(0, 12, 1, -80)
quickBtn.Size = UDim2.new(0, 52, 0, 52)
quickBtn.Text = "AIM"
applyTextStyle(quickBtn, 16, true)
quickBtn.BackgroundColor3 = Color3.new(1,1,1)
quickBtn.Active = true
quickBtn.Draggable = true
quickBtn.ZIndex = 50
cornerify(quickBtn, 26)
strokeify(quickBtn)
safeParent(quickBtn, gui)

-- ======= FOV RING =======
local fovFrame = safeNew("Frame")
fovFrame.Name = "FOVFrame"
fovFrame.AnchorPoint = Vector2.new(0.5,0.5)
fovFrame.Position = UDim2.new(0.5,0,0.5,0)
fovFrame.Size = UDim2.new(0, CFG.FOV_PIXELS*2, 0, CFG.FOV_PIXELS*2)
fovFrame.BackgroundTransparency = 1
fovFrame.Visible = CFG.SHOW_FOV
fovFrame.ZIndex = 2
safeParent(fovFrame, gui)

local fovInner = safeNew("Frame")
fovInner.Size = UDim2.new(1,0,1,0)
fovInner.BackgroundTransparency = 1
cornerify(fovInner, CFG.FOV_PIXELS) -- full round
safeParent(fovInner, fovFrame)

local fovStroke = safeNew("UIStroke")
fovStroke.Thickness = CFG.FOV_THICKNESS
fovStroke.Color     = CFG.FOV_COLOR
fovStroke.Transparency = 0.5
fovStroke.LineJoinMode = Enum.LineJoinMode.Round
safeParent(fovStroke, fovInner)

-- ======= FPS COUNTER =======
local fpsLabel = safeNew("TextLabel")
fpsLabel.Size = UDim2.new(0, 120, 0, 20)
fpsLabel.AnchorPoint = Vector2.new(1,0)
fpsLabel.Position = UDim2.new(1, -10, 0, 6)
applyTextStyle(fpsLabel, 14, true)
fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
fpsLabel.Text = "FPS: 60.0"
safeParent(fpsLabel, gui)

-- ======= SETTINGS ROW BUILDERS =======
local function addSlider(label, min, max, step, default, onChange)
    local row = safeNew("Frame")
    row.Size = UDim2.new(1,0,0,28)
    row.BackgroundTransparency = 1
    safeParent(row, settingsFrame)

    local txt = safeNew("TextLabel")
    txt.Size = UDim2.new(0.62,0,1,0)
    applyTextStyle(txt, 14, false)
    txt.TextXAlignment = Enum.TextXAlignment.Left
    safeParent(txt, row)

    local minus = makeRowButton("-")
    minus.Size = UDim2.new(0,26,1,0)
    minus.Position = UDim2.new(0.66,4,0,0)
    safeParent(minus, row)

    local plus = makeRowButton("+")
    plus.Size  = UDim2.new(0,26,1,0)
    plus.Position = UDim2.new(0.86,4,0,0)
    safeParent(plus, row)

    local value = default
    local function update(v)
        value = math.clamp(v, min, max)
        txt.Text = label .. ": " .. string.format("%.2f", value)
        if onChange then try(onChange, value) end
    end

    minus.MouseButton1Click:Connect(function()
        if not settingsFrame.Visible then return end
        update(value - step)
        if clickSound then clickSound:Play() end
    end)

    plus.MouseButton1Click:Connect(function()
        if not settingsFrame.Visible then return end
        update(value + step)
        if clickSound then clickSound:Play() end
    end)

    update(default)
    return row
end

local function addToggle(label, default, onChange)
    local v = default
    local btn = makeRowButton(label .. ": " .. (v and "ON" or "OFF"))
    btn.MouseButton1Click:Connect(function()
        if not settingsFrame.Visible then return end
        v = not v
        btn.Text = label .. ": " .. (v and "ON" or "OFF")
        if onChange then try(onChange, v) end
        if clickSound then clickSound:Play() end
    end)
    safeParent(btn, settingsFrame)
    return btn
end

local function addDropdown(label, options, defaultValue, onChange)
    local idx = 1
    for i, o in ipairs(options) do
        if o.value == defaultValue then idx = i break end
    end
    local btn = makeRowButton(label .. ": " .. options[idx].label)
    btn.MouseButton1Click:Connect(function()
        if not settingsFrame.Visible then return end
        idx = (idx % #options) + 1
        btn.Text = label .. ": " .. options[idx].label
        if onChange then try(onChange, options[idx].value) end
        if clickSound then clickSound:Play() end
    end)
    safeParent(btn, settingsFrame)
    return btn
end

-- ======= SETTINGS CONTENT =======
addSlider("Aim Smoothing (0..1)", 0, 1, 0.05, CFG.SMOOTHING, function(v) CFG.SMOOTHING = v end)
addDropdown("Aim Mode", {
    {label="Smooth", value="Smooth"},
    {label="Snap",   value="Snap"},
}, CFG.AIM_MODE, function(v) CFG.AIM_MODE = v end)

addToggle("Use Prediction", CFG.USE_PREDICTION, function(v) CFG.USE_PREDICTION = v end)
addSlider("Bullet Speed", 200, 5000, 50, CFG.BULLET_SPEED, function(v) CFG.BULLET_SPEED = v end)
addSlider("Ping Compensation", 0, 2, 0.05, CFG.NET_COMPENSATION, function(v) CFG.NET_COMPENSATION = v end)
addSlider("FPS Compensation", 0, 2, 0.05, CFG.FPS_COMPENSATION, function(v) CFG.FPS_COMPENSATION = v end)
addSlider("Velocity Weight", 0, 2, 0.05, CFG.VELOCITY_WEIGHT, function(v) CFG.VELOCITY_WEIGHT = v end)
addSlider("Max Lead (s)", 0.05, 0.6, 0.01, CFG.MAX_LEAD_SECONDS, function(v) CFG.MAX_LEAD_SECONDS = v end)

addDropdown("Target Priority", {
    {label="By Angle",    value="Angle"},
    {label="By Screen",   value="Screen"},
    {label="By Distance", value="Distance"},
}, CFG.TARGET_PRIORITY, function(v) CFG.TARGET_PRIORITY = v end)

addDropdown("Switch Mode", {
    {label="By Look", value="ByLook"},
    {label="Closest", value="Closest"},
}, "ByLook", function(v) CFG.SWITCH_MODE = v end)

addSlider("Screen Tilt (°)", -15, 15, 1, CFG.SCREEN_TILT, function(v) CFG.SCREEN_TILT = v end)
addSlider("Switch Sensitivity (yaw)", 0.001, 0.02, 0.001, CFG.SWITCH_SENSITIVITY_YAW, function(v) CFG.SWITCH_SENSITIVITY_YAW = v end)
addSlider("Switch Sensitivity (pitch)", 0.005, 0.12, 0.005, CFG.SWITCH_SENSITIVITY_PITCH, function(v) CFG.SWITCH_SENSITIVITY_PITCH = v end)
addSlider("Switch Cooldown (s)", 0.02, 0.5, 0.01, CFG.SWITCH_COOLDOWN, function(v) CFG.SWITCH_COOLDOWN = math.max(0.02, v) end)
addSlider("FOV Size (px)", 20, 400, 5, CFG.FOV_PIXELS, function(v)
    CFG.FOV_PIXELS = v
    if fovFrame then
        fovFrame.Size = UDim2.new(0, v*2, 0, v*2)
        cornerify(fovInner, v)
    end
end)
addToggle("Show FOV Ring", CFG.SHOW_FOV, function(v)
    CFG.SHOW_FOV = v
    if fovFrame then fovFrame.Visible = v end
end)
addToggle("Friend Filter", CFG.USE_FRIEND_FILTER, function(v) CFG.USE_FRIEND_FILTER = v end)
addToggle("Require Visible (LOS)", CFG.REQUIRE_VISIBLE, function(v) CFG.REQUIRE_VISIBLE = v end)

addToggle("Show FPS Counter", CFG.SHOW_FPS_COUNTER, function(v) CFG.SHOW_FPS_COUNTER = v end)

-- FPS Booster toggle row
addToggle("FPS Booster", CFG.BOOSTER_DEFAULT, function(v)
    FPSBooster:setEnabled(v)
end)

-- ======= SETTINGS OPEN/CLOSE =======
local function computeSettingsHeight()
    for _=1,6 do task.wait(0.01) end
    local ok, size = pcall(function() return sLayout.AbsoluteContentSize.Y + 16 end)
    if ok then return size end
    return 180
end

settingsBtn.MouseButton1Click:Connect(function()
    if clickSound then clickSound:Play() end
    if settingsFrame.Visible then
        settingsFrame.Active = false
        TweenService:Create(settingsFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
        task.delay(0.18, function() settingsFrame.Visible = false end)
    else
        settingsFrame.Visible = true
        settingsFrame.Active  = true
        local h = computeSettingsHeight()
        TweenService:Create(settingsFrame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0,320,0,h)}):Play()
    end
end)

-- ======= INDICATOR STATUS =======
local function updateIndicator()
    statusDot.BackgroundColor3 = aiming and Color3.fromRGB(0,200,0) or Color3.fromRGB(150,0,0)
end
updateIndicator()

-- ======= QUICK TOGGLE & KEYBIND =======
local function toggleAim()
    aiming = not aiming
    targetPart = nil
    targetHRP  = nil
    if clickSound then clickSound:Play() end
    updateIndicator()
end

quickBtn.MouseButton1Click:Connect(function() toggleAim() end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.V then
        toggleAim()
    end
end)

-- ======= ESP SUPPORT (Optional) =======
local _ESP = {}

local function createESPForPlayer(player)
    if not player or player == LocalPlayer or _ESP[player] then return end
    local data = {}
    _ESP[player] = data

    local function buildForCharacter(char)
        if not char then return end
        if data.highlight then try(function() data.highlight:Destroy() end) end
        if data.billboard then try(function() data.billboard:Destroy() end) end
        data.highlight = nil
        data.billboard = nil

        local highlight = safeNew("Highlight")
        if highlight then
            highlight.FillColor   = CFG.ESP_FILL
            highlight.OutlineColor= CFG.ESP_OUTLINE
            highlight.Adornee     = char
            highlight.Enabled     = CFG.ESP_ENABLED
            highlight.DepthMode   = CFG.ESP_ALWAYS_ON_TOP and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            safeParent(highlight, Workspace)
            data.highlight = highlight
        end

        local head = char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
        if head then
            local bg = safeNew("BillboardGui")
            if bg then
                bg.Name = "ESPName"
                bg.Adornee = head
                bg.Size = UDim2.new(0,140,0,36)
                bg.StudsOffset = Vector3.new(0, 1.6, 0)
                bg.AlwaysOnTop = true
                safeParent(bg, char)
                local txt = safeNew("TextLabel")
                if txt then
                    txt.Size = UDim2.new(1,0,1,0)
                    applyTextStyle(txt, 14, true)
                    txt.TextScaled = true
                    txt.Text = player.Name
                    safeParent(txt, bg)
                end
                data.billboard = bg
                if data.billboard then data.billboard.Enabled = CFG.ESP_SHOW_NAME end
            end
        end
    end

    data.charConn = player.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        buildForCharacter(char)
    end)

    if player.Character then buildForCharacter(player.Character) end

    data.remove = function()
        if data.highlight then try(function() data.highlight:Destroy() end) end
        if data.billboard then try(function() data.billboard:Destroy() end) end
        if data.charConn then try(function() data.charConn:Disconnect() end) end
        _ESP[player] = nil
    end
end

local function removeESPForPlayer(player)
    local data = _ESP[player]
    if not data then return end
    if data.highlight then try(function() data.highlight:Destroy() end) end
    if data.billboard then try(function() data.billboard:Destroy() end) end
    if data.charConn then try(function() data.charConn:Disconnect() end) end
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

-- ======= HELPERS =======
local function isRealPlayer(plr)
    if not plr or plr == LocalPlayer then return false end
    if CFG.USE_FRIEND_FILTER and try(function() return LocalPlayer:IsFriendsWith(plr.UserId) end) then return false end
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildWhichIsA("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return Players:FindFirstChild(plr.Name) ~= nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLineOfSight(fromPos, toPos, ignore)
    rayParams.FilterDescendantsInstances = ignore
    local result = Workspace:Raycast(fromPos, (toPos - fromPos), rayParams)
    if not result then return true end
    return false
end

-- Ping in seconds
local function getPingSeconds()
    local ms = 0
    local provider = Stats and Stats.Network and Stats.Network:FindFirstChild("ServerStatsItem")
    if provider and provider:FindFirstChild("Data Ping") then
        local item = provider["Data Ping"]
        if item and item.GetValue then
            local v = try(function() return item:GetValue() end)
            if type(v) == "number" then ms = v end
        end
    end
    return math.max(0, ms) / 1000
end

local function computeLeadPosition(part, hrp)
    if not CFG.USE_PREDICTION or not hrp or not part then
        return part and part.Position or nil
    end
    local camPos   = Camera.CFrame.Position
    local targetPos = part.Position
    local dist     = (targetPos - camPos).Magnitude

    local vel = Vector3.zero
    if hrp and hrp:IsA("BasePart") then
        vel = hrp.Velocity
    end

    local baseTime = (CFG.BULLET_SPEED > 0) and (dist / CFG.BULLET_SPEED) or 0
    local pingSec  = getPingSeconds() * CFG.NET_COMPENSATION
    local frameSec = math.clamp(avgDelta, 0, 1) * CFG.FPS_COMPENSATION
    local leadTime = math.clamp(baseTime + pingSec + frameSec, 0, CFG.MAX_LEAD_SECONDS)
    local lead     = vel * leadTime * CFG.VELOCITY_WEIGHT
    return targetPos + lead
end

local function inFOVScreen(pos)
    local scr, onScreen = Camera:WorldToViewportPoint(pos)
    if not onScreen then return false end
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local d = (Vector2.new(scr.X, scr.Y) - center).Magnitude
    return d <= CFG.FOV_PIXELS
end

local function pickBest(ignoreFOV)
    local bestPart, bestHRP, bestScore = nil, nil, math.huge
    local camCF   = Camera.CFrame
    local camPos  = camCF.Position
    local camLook = camCF.LookVector
    local ignoreList = {LocalPlayer.Character, Camera}

    for _, plr in ipairs(Players:GetPlayers()) do
        if isRealPlayer(plr) then
            local ch  = plr.Character
            local prt = ch and (ch:FindFirstChild(CFG.LOCK_PART) or ch:FindFirstChild("HumanoidRootPart"))
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if prt and hrp then
                local worldDist = (prt.Position - camPos).Magnitude
                if worldDist <= CFG.AIM_RADIUS then
                    local predicted = computeLeadPosition(prt, hrp) or prt.Position
                    if not CFG.REQUIRE_VISIBLE or hasLineOfSight(camPos, predicted, ignoreList) then
                        local score
                        if CFG.TARGET_PRIORITY == "Angle" then
                            local dirUnit = (predicted - camPos).Unit
                            local dot = camLook:Dot(dirUnit)
                            score = -dot + worldDist/10000
                        elseif CFG.TARGET_PRIORITY == "Distance" then
                            score = worldDist
                        else
                            local scr, onScreen = Camera:WorldToViewportPoint(predicted)
                            if (not onScreen or (not ignoreFOV and not inFOVScreen(predicted))) then
                                score = 1e9
                            else
                                local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                                local d = (Vector2.new(scr.X, scr.Y) - center).Magnitude
                                score = d + worldDist/1000
                            end
                        end
                        if score < bestScore then
                            bestScore = score
                            bestPart  = prt
                            bestHRP   = hrp
                        end
                    end
                end
            end
        end
    end

    targetPart = bestPart
    targetHRP  = bestHRP
    return targetPart
end

local function aimAt(pos)
    local origin = Camera.CFrame.Position
    if CFG.USE_CAM_HEIGHT then origin = origin + Vector3.new(0, CFG.CAM_HEIGHT, 0) end
    local desired = CFrame.new(origin, pos) * CFrame.Angles(math.rad(CFG.SCREEN_TILT), 0, 0)
    if CFG.AIM_MODE == "Snap" or CFG.SMOOTHING <= 0 then
        try(function() Camera.CFrame = desired end)
    else
        local cur   = Camera.CFrame
        local alpha = math.clamp(CFG.SMOOTHING, 0, 1)
        local nextCF = cur:Lerp(desired, alpha)
        try(function() Camera.CFrame = nextCF end)
    end
end

-- ======= FPS BOOSTER =======
local FPSBooster = {}
FPSBooster.enabled = false
FPSBooster.original = {
    postfx = {},
    particles = {},
    trails = {},
    beams = {},
    shadows = nil,
    materials = {},
}

function FPSBooster:scanAndCache()
    self.original.postfx = {}
    self.original.particles = {}
    self.original.trails = {}
    self.original.beams = {}
    self.original.materials = {}

    for _, inst in ipairs(Lighting:GetChildren()) do
        if inst:IsA("DepthOfFieldEffect") or inst:IsA("BloomEffect") or inst:IsA("BlurEffect") or inst:IsA("SunRaysEffect") or inst:IsA("ColorCorrectionEffect") then
            table.insert(self.original.postfx, {obj=inst, enabled=inst.Enabled})
        end
    end

    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ParticleEmitter") then
            table.insert(self.original.particles, {obj=d, rate=d.Rate})
        elseif d:IsA("Trail") then
            table.insert(self.original.trails, {obj=d, enabled=d.Enabled})
        elseif d:IsA("Beam") then
            table.insert(self.original.beams, {obj=d, enabled=d.Enabled})
        elseif CFG.BOOSTER_SET_MATERIAL and d:IsA("BasePart") then
            table.insert(self.original.materials, {obj=d, material=d.Material})
        end
    end

    self.original.shadows = Lighting.GlobalShadows
end

function FPSBooster:apply()
    if self.enabled then return end
    self:scanAndCache()

    if CFG.BOOSTER_DISABLE_POSTFX then
        for _, rec in ipairs(self.original.postfx) do
            local o = rec.obj
            if o and o.Enabled ~= false then
                o.Enabled = false
            end
        end
    end

    for _, rec in ipairs(self.original.particles) do
        local o = rec.obj
        if o and o.Rate > 0 then
            o.Rate = math.max(0, math.floor(o.Rate * CFG.BOOSTER_PARTICLE_RATE_SCALE))
        end
    end

    for _, rec in ipairs(self.original.trails) do
        local o = rec.obj
        if o and o.Enabled ~= false then
            o.Enabled = false
        end
    end

    for _, rec in ipairs(self.original.beams) do
        local o = rec.obj
        if o and o.Enabled ~= false then
            o.Enabled = false
        end
    end

    if CFG.BOOSTER_DISABLE_SHADOWS then
        Lighting.GlobalShadows = false
    end

    if CFG.BOOSTER_SET_MATERIAL then
        for _, rec in ipairs(self.original.materials) do
            local o = rec.obj
            if o then
                o.Material = Enum.Material.SmoothPlastic
            end
        end
    end

    self.enabled = true
end

function FPSBooster:restore()
    if not self.enabled then return end

    for _, rec in ipairs(self.original.postfx) do
        local o = rec.obj
        if o then o.Enabled = rec.enabled end
    end

    for _, rec in ipairs(self.original.particles) do
        local o = rec.obj
        if o then o.Rate = rec.rate end
    end

    for _, rec in ipairs(self.original.trails) do
        local o = rec.obj
        if o then o.Enabled = rec.enabled end
    end

    for _, rec in ipairs(self.original.beams) do
        local o = rec.obj
        if o then o.Enabled = rec.enabled end
    end

    if CFG.BOOSTER_DISABLE_SHADOWS and self.original.shadows ~= nil then
        Lighting.GlobalShadows = self.original.shadows
    end

    if CFG.BOOSTER_SET_MATERIAL then
        for _, rec in ipairs(self.original.materials) do
            local o = rec.obj
            if o then o.Material = rec.material end
        end
    end

    self.enabled = false
end

function FPSBooster:setEnabled(v)
    if v then
        self:apply()
    else
        self:restore()
    end
end

-- ======= RENDER LOOP =======
RunService.RenderStepped:Connect(function(dt)
    -- FPS counter smoothing
    avgDelta = CFG.FPS_SMOOTH_FACTOR * avgDelta + (1 - CFG.FPS_SMOOTH_FACTOR) * dt
    if CFG.SHOW_FPS_COUNTER and fpsLabel then
        local fps = (avgDelta > 0) and (1/avgDelta) or 0
        fpsLabel.Text = string.format("FPS: %.1f", fps)
        fpsLabel.Visible = true
    else
        fpsLabel.Visible = false
    end

    -- Keep FOV centered and styled
    if fovFrame then
        fovFrame.Position = UDim2.new(0.5,0,0.5,0)
        fovFrame.Size = UDim2.new(0, CFG.FOV_PIXELS*2, 0, CFG.FOV_PIXELS*2)
        if fovStroke then
            fovStroke.Thickness = CFG.FOV_THICKNESS
            fovStroke.Color     = CFG.FOV_COLOR
        end
    end

    -- Camera movement-based switching
    local look  = Camera.CFrame.LookVector
    local yaw   = math.atan2(look.X, look.Z)
    local pitch = math.asin(-look.Y)
    local now   = tick()

    if lastYaw ~= nil then
        local dy = math.abs(yaw - lastYaw); if dy > math.pi then dy = math.abs(dy - 2*math.pi) end
        local dp = math.abs(pitch - lastPitch)
        if (dy >= CFG.SWITCH_SENSITIVITY_YAW or dp >= CFG.SWITCH_SENSITIVITY_PITCH) and (now - lastSwitchTick) >= CFG.SWITCH_COOLDOWN then
            pickBest(true)
            lastSwitchTick = now
        end
    end

    lastYaw = yaw
    lastPitch = pitch

    -- Aim logic
    if aiming then
        local keep = false
        if targetPart and targetHRP then
            local camPos = Camera.CFrame.Position
            local within = (targetPart.Position - camPos).Magnitude <= CFG.AIM_RADIUS
            if within then
                if not CFG.REQUIRE_VISIBLE then
                    keep = true
                else
                    local predicted = computeLeadPosition(targetPart, targetHRP) or targetPart.Position
                    local seen = hasLineOfSight(camPos, predicted, {LocalPlayer.Character, Camera})
                    if seen then
                        keep = true
                        lastSeenVisibleAt = now
                    else
                        keep = (now - lastSeenVisibleAt) <= CFG.VIS_STICKY_TIME
                    end
                end
            end
        end

        if not keep then
            pickBest(false)
        end

        if targetPart and targetHRP then
            local aimPos = computeLeadPosition(targetPart, targetHRP) or targetPart.Position
            aimAt(aimPos)
        end
    end
end)

-- ======= GUI RESILIENCE =======
task.spawn(function()
    while task.wait(2) do
        if not gui.Parent then safeParent(gui, PlayerGui) end
    end
end)

-- ======= AUTO-INIT BOOSTER IF DEFAULT =======
FPSBooster:setEnabled(CFG.BOOSTER_DEFAULT)

-- ======= PRINT READY =======
print("[DeltaAim] Merebennie EN build loaded (Delta Mobile ready).")
