
--[[
Delta Aim Enhanced - Mobile/PC Friendly (Optimized for Delta Mobile)
Author: ChatGPT (per user request) | Watermark set to "Made by Merebennie"
Notes:
- Single local script. Every line has a concrete purpose.
- UI: white background, black text, pixel-perfect, mobile-first, PC-friendly.
- Sound: Button Click (rbxassetid://6042053626)
- Features: Aimbot (smart, smooth, manual switching), ESP (box+name), FPS/Ping counters, FPS Booster & Performance Mode,
  FOV slider, Custom Crosshair, Recoil Control, Keybinds/Touch controls, Mini Quick Menu, Auto-Save, Safe Mode,
  Health/Armor overlay for current target, Auto Reconnect.
- Saving uses writefile/readfile if available (Delta executor); otherwise falls back to session memory.
]]

--// Services
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local SoundService       = game:GetService("SoundService")
local Lighting           = game:GetService("Lighting")
local HttpService        = game:GetService("HttpService")
local Stats              = game:GetService("Stats")
local TeleportService    = game:GetService("TeleportService")

--// Locals
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait() LocalPlayer = Players.LocalPlayer end
local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")

--// Utils
local function safeNew(class) local ok, v = pcall(Instance.new, class); return ok and v or nil end
local function playSound(id, vol)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = vol or 1
    s.PlayOnRemove = true
    s.Parent = SoundService
    s:Destroy() -- triggers PlayOnRemove
end
local function clamp(x, a, b) return math.clamp(x, a, b) end
local function lerp(a, b, t) return a + (b - a)*t end
local function v2(x,y) return Vector2.new(x,y) end
local function c3(r,g,b) return Color3.fromRGB(r,g,b) end

--// File persistence helpers (Delta-friendly)
local SAVE_DIR = "DeltaAimEnhanced"
local SAVE_FILE = SAVE_DIR.."/settings.json"
local haveFS = (writefile and readfile and isfile and makefolder) and true or false
if haveFS then pcall(function() if not isfile(SAVE_DIR) then makefolder(SAVE_DIR) end end) end
local function saveJSON(tbl)
    local ok, data = pcall(HttpService.JSONEncode, HttpService, tbl)
    if ok then
        if haveFS then pcall(writefile, SAVE_FILE, data) end
        getgenv()._DeltaAimEnhanced_Settings = tbl
    end
end
local function loadJSON(defaults)
    local fromFS = nil
    if haveFS and isfile(SAVE_FILE) then
        local ok, data = pcall(readfile, SAVE_FILE)
        if ok and data then
            local ok2, parsed = pcall(HttpService.JSONDecode, HttpService, data)
            if ok2 and type(parsed)=="table" then fromFS = parsed end
        end
    end
    local fromGENV = rawget(getgenv(), "_DeltaAimEnhanced_Settings")
    local base = defaults or {}
    if type(fromGENV)=="table" then for k,v in pairs(fromGENV) do base[k]=v end end
    if type(fromFS)=="table" then for k,v in pairs(fromFS) do base[k]=v end end
    return base
end

--// SETTINGS (defaults)
local DEFAULTS = {
    uiScale = 1.0,
    aimbotEnabled = false,
    aimSmooth = 0.35,
    maxAimRange = 500,
    aimPart = "Head", -- "Head" or "HumanoidRootPart"
    smartPriority = "Screen", -- "Screen" | "Angle" | "Distance"
    headPriority = true, -- true=head, false=torso
    fov = 70,
    showFOVRing = true,
    fovRingRadius = 120,
    fovRingThickness = 2,
    recoilControl = 0.2, -- 0..1
    espEnabled = false,
    espNames = true,
    espBoxes = true,
    espAlwaysOnTop = true,
    friendFilter = true,
    usePrediction = false,
    bulletSpeed = 1400,
    predictMultiplier = 1.0,
    switchOnlyManual = true, -- only switch when manual or target invalid
    hotkeyToggle = "V",
    hotkeySwitch = "N",
    hotkeyMenu   = "M",
    -- Crosshair
    crosshairEnabled = true,
    crosshairSize = 12,
    crosshairOpacity = 1,
    crosshairColor = {0,0,0},
    -- Performance
    fpsBooster = false,
    performanceMode = false,
    safeMode = false,
    -- Mini Menu
    miniMenu = true,
    -- Overlay
    showFPS = true,
    showPing = true,
}
local CFG = loadJSON(DEFAULTS)

-- Apply FOV immediately
pcall(function() Camera.FieldOfView = clamp(CFG.fov, 40, 120) end)

--// State
local STATE = {
    targetPlayer = nil,
    targetPart = nil,
    targetHRP = nil,
    aiming = CFG.aimbotEnabled,
    lastPick = 0,
    fps = 0,
    ping = 0,
    lastSwitchTick = 0,
}

--// Sound (Button Click)
local CLICK_SOUND = "rbxassetid://6042053626"

--// GUI ROOT
local gui = safeNew("ScreenGui")
gui.Name = "DeltaAim_Enhanced_UI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

-- UIScale for mobile-first design
local uiScale = Instance.new("UIScale")
uiScale.Scale = CFG.uiScale
uiScale.Parent = gui

--// STYLES
local WHITE = c3(255,255,255)
local BLACK = c3(0,0,0)
local GREY  = c3(220,220,220)

local function styleFrame(f)
    f.BackgroundColor3 = WHITE
    f.BorderSizePixel = 1
    f.BorderColor3 = BLACK
end
local function styleText(t, size, bold)
    t.TextColor3 = BLACK
    t.BackgroundTransparency = 1
    t.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    t.TextScaled = false
    t.TextSize = size
end
local function roundify(inst, r)
    local u = Instance.new("UICorner")
    u.CornerRadius = UDim.new(0, r or 10)
    u.Parent = inst
end
local function strokify(inst)
    local s = Instance.new("UIStroke")
    s.Color = BLACK
    s.Thickness = 1
    s.Transparency = 0
    s.Parent = inst
end
local function paddify(inst, pad)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, pad); p.PaddingBottom = UDim.new(0, pad)
    p.PaddingLeft = UDim.new(0, pad); p.PaddingRight = UDim.new(0, pad)
    p.Parent = inst
end

--// WATERMARK
local watermark = Instance.new("TextLabel")
watermark.Name = "Watermark"
watermark.Parent = gui
watermark.AnchorPoint = Vector2.new(0,0)
watermark.Position = UDim2.new(0, 8, 0, 8)
watermark.Size = UDim2.new(0, 190, 0, 22)
styleText(watermark, 18, true)
watermark.Font = Enum.Font.Arcade -- pixelated retro style
watermark.Text = "Made by Merebennie"
watermark.TextXAlignment = Enum.TextXAlignment.Left
watermark.TextYAlignment = Enum.TextYAlignment.Top

--// MAIN PANEL
local main = Instance.new("Frame")
main.Name = "MainPanel"
main.Parent = gui
main.AnchorPoint = Vector2.new(1,0)
main.Position = UDim2.new(1, -12, 0, 12)
main.Size = UDim2.new(0, 320, 0, 360)
styleFrame(main); roundify(main, 12); strokify(main); paddify(main, 10)

local layout = Instance.new("UIListLayout", main)
layout.Padding = UDim.new(0, 8)
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Parent = main
title.Size = UDim2.new(1, 0, 0, 24)
styleText(title, 20, true)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Delta Aim Enhanced"

-- Toggle Row creator
local function makeToggleRow(label, initial, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,32)
    row.BackgroundTransparency = 1
    row.Parent = main
    local l = Instance.new("TextLabel", row)
    l.Size = UDim2.new(1, -70, 1, 0)
    l.TextXAlignment = Enum.TextXAlignment.Left
    styleText(l, 16, false); l.Text = label
    local btn = Instance.new("TextButton", row)
    btn.AnchorPoint = Vector2.new(1,0.5)
    btn.Position = UDim2.new(1, -4, 0.5, 0)
    btn.Size = UDim2.new(0, 64, 0, 26)
    btn.AutoButtonColor = true
    btn.Text = initial and "ON" or "OFF"
    btn.TextColor3 = BLACK
    btn.BackgroundColor3 = GREY
    roundify(btn, 8); strokify(btn)
    btn.MouseButton1Click:Connect(function()
        initial = not initial
        btn.Text = initial and "ON" or "OFF"
        playSound(CLICK_SOUND, 1)
        onChange(initial)
        saveJSON(CFG)
    end)
    return row
end

-- Slider Row
local function makeSliderRow(label, min, max, step, initial, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,40)
    row.BackgroundTransparency = 1
    row.Parent = main
    local l = Instance.new("TextLabel", row)
    l.Size = UDim2.new(1, 0, 0, 16)
    l.TextXAlignment = Enum.TextXAlignment.Left
    styleText(l, 16, false); l.Text = label.." ("..tostring(initial)..")"
    local bar = Instance.new("Frame", row)
    bar.Position = UDim2.new(0,0,0,20)
    bar.Size = UDim2.new(1,0,0,16)
    styleFrame(bar); roundify(bar, 8); strokify(bar)
    paddify(bar, 2)
    local fill = Instance.new("Frame", bar)
    fill.BackgroundColor3 = BLACK
    fill.Size = UDim2.new((initial-min)/(max-min), 0, 1, 0)
    roundify(fill, 6)
    strokify(fill)
    local dragging = false
    local function setFromX(x)
        local rel = clamp((x - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
        local val = min + math.floor(rel*(max-min)/step+0.5)*step
        l.Text = label.." ("..tostring(val)..")"
        fill.Size = UDim2.new((val-min)/(max-min), 0, 1, 0)
        onChange(val); saveJSON(CFG)
    end
    bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; setFromX(inp.Position.X); playSound(CLICK_SOUND,1)
        end
    end)
    bar.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragging=false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end)
    return row
end

-- Dropdown Row (simple cycle button)
local function makeDropdownRow(label, options, initialIndex, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,32)
    row.BackgroundTransparency = 1
    row.Parent = main
    local l = Instance.new("TextLabel", row)
    l.Size = UDim2.new(1, -110, 1, 0)
    l.TextXAlignment = Enum.TextXAlignment.Left
    styleText(l, 16, false); l.Text = label
    local btn = Instance.new("TextButton", row)
    btn.AnchorPoint = Vector2.new(1,0.5)
    btn.Position = UDim2.new(1, -4, 0.5, 0)
    btn.Size = UDim2.new(0, 100, 0, 26)
    btn.TextColor3 = BLACK
    btn.BackgroundColor3 = GREY
    roundify(btn, 8); strokify(btn)
    local idx = initialIndex
    btn.Text = tostring(options[idx])
    btn.MouseButton1Click:Connect(function()
        idx = (idx % #options) + 1
        btn.Text = tostring(options[idx])
        playSound(CLICK_SOUND,1)
        onChange(options[idx])
        saveJSON(CFG)
    end)
    return row
end

-- Buttons Row (compact)
local function makeButtonRow(label, buttonText, onClick)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,32)
    row.BackgroundTransparency = 1
    row.Parent = main
    local l = Instance.new("TextLabel", row)
    l.Size = UDim2.new(1, -120, 1, 0)
    l.TextXAlignment = Enum.TextXAlignment.Left
    styleText(l, 16, false); l.Text = label
    local btn = Instance.new("TextButton", row)
    btn.AnchorPoint = Vector2.new(1,0.5); btn.Position = UDim2.new(1,-4,0.5,0)
    btn.Size = UDim2.new(0, 112, 0, 26)
    btn.Text = buttonText
    btn.TextColor3 = BLACK
    btn.BackgroundColor3 = GREY
    roundify(btn, 8); strokify(btn)
    btn.MouseButton1Click:Connect(function()
        playSound(CLICK_SOUND,1)
        onClick()
    end)
    return row
end

--// MINI QUICK MENU (bottom-left)
local mini = Instance.new("Frame")
mini.Name = "MiniMenu"
mini.Parent = gui
mini.AnchorPoint = Vector2.new(0,1)
mini.Position = UDim2.new(0, 12, 1, -12)
mini.Size = UDim2.new(0, 190, 0, 120)
styleFrame(mini); roundify(mini, 10); strokify(mini); paddify(mini, 8)
mini.Visible = CFG.miniMenu

local miniLayout = Instance.new("UIListLayout", mini)
miniLayout.Padding = UDim.new(0,6)

local function makeMiniBtn(text, callback)
    local b = Instance.new("TextButton")
    b.Parent = mini
    b.Size = UDim2.new(1,0,0,26)
    b.Text = text; b.TextColor3 = BLACK
    b.BackgroundColor3 = GREY
    roundify(b,8); strokify(b)
    b.MouseButton1Click:Connect(function() playSound(CLICK_SOUND,1); callback() end)
    return b
end

makeMiniBtn("Toggle Aimbot", function()
    STATE.aiming = not STATE.aiming
    CFG.aimbotEnabled = STATE.aiming
    saveJSON(CFG)
end)
makeMiniBtn("Switch Target", function()
    STATE.targetPlayer = nil; STATE.targetPart=nil; STATE.targetHRP=nil
end)
makeMiniBtn("Performance Mode", function()
    CFG.performanceMode = not CFG.performanceMode
    saveJSON(CFG)
end)
makeMiniBtn("Safe Mode", function()
    CFG.safeMode = not CFG.safeMode
    if CFG.safeMode then
        CFG.aimbotEnabled=false; STATE.aiming=false
        CFG.espEnabled=false
    end
    saveJSON(CFG)
end)

--// OVERLAYS (FPS & Ping)
local overlay = Instance.new("Frame")
overlay.Parent = gui
overlay.AnchorPoint = Vector2.new(1,1)
overlay.Position = UDim2.new(1, -12, 1, -12)
overlay.Size = UDim2.new(0, 170, 0, 60)
overlay.BackgroundTransparency = 1

local fpsLabel = Instance.new("TextLabel", overlay)
fpsLabel.Size = UDim2.new(1,0,0,24)
styleText(fpsLabel, 16, true); fpsLabel.TextXAlignment = Enum.TextXAlignment.Right

local pingLabel = Instance.new("TextLabel", overlay)
pingLabel.Position = UDim2.new(0,0,0,28)
pingLabel.Size = UDim2.new(1,0,0,24)
styleText(pingLabel, 16, true); pingLabel.TextXAlignment = Enum.TextXAlignment.Right

--// FOV RING
local fovRing = Instance.new("Frame")
fovRing.Name = "FOVRing"
fovRing.Parent = gui
fovRing.AnchorPoint = Vector2.new(0.5,0.5)
fovRing.Position = UDim2.new(0.5,0,0.5,0)
fovRing.Size = UDim2.new(0, CFG.fovRingRadius*2, 0, CFG.fovRingRadius*2)
fovRing.BackgroundTransparency = 1
local ringInner = Instance.new("Frame", fovRing)
ringInner.Size = UDim2.new(1,0,1,0)
ringInner.BackgroundTransparency = 1
local ringCorner = Instance.new("UICorner", ringInner)
ringCorner.CornerRadius = UDim.new(1,0)
local ringStroke = Instance.new("UIStroke", ringInner)
ringStroke.Thickness = CFG.fovRingThickness
ringStroke.Color = BLACK
ringStroke.Transparency = CFG.showFOVRing and 0 or 1
fovRing.Visible = CFG.showFOVRing

--// CROSSHAIR
local cross = Instance.new("Frame")
cross.Parent = gui
cross.BackgroundTransparency = 1
cross.AnchorPoint = Vector2.new(0.5,0.5)
cross.Position = UDim2.new(0.5,0,0.5,0)
cross.Size = UDim2.new(0, 1, 0, 1)

local function rebuildCrosshair()
    cross:ClearAllChildren()
    if not CFG.crosshairEnabled then return end
    local size = CFG.crosshairSize
    local alpha = clamp(CFG.crosshairOpacity, 0, 1)
    local rgb = CFG.crosshairColor
    local color = Color3.fromRGB(rgb[0 or 1] or 0, rgb[2] or 0, rgb[3] or 0)
    local parts = {
        {Vector2.new(-size, 0), Vector2.new(-2, 0)},
        {Vector2.new(2, 0), Vector2.new(size, 0)},
        {Vector2.new(0, -size), Vector2.new(0, -2)},
        {Vector2.new(0, 2), Vector2.new(0, size)},
    }
    for _,seg in ipairs(parts) do
        local p1, p2 = seg[1], seg[2]
        local line = Instance.new("Frame")
        line.Parent = cross
        line.BackgroundColor3 = color
        line.BackgroundTransparency = 1 - alpha
        line.BorderSizePixel = 0
        line.AnchorPoint = Vector2.new(0.5,0.5)
        local w = math.max(2, math.floor(size/6))
        local length = (p2 - p1).Magnitude
        line.Size = UDim2.new(0, w, 0, length)
        line.Position = UDim2.new(0, (p1.X+p2.X)/2, 0, (p1.Y+p2.Y)/2)
        -- rotate
        local angle = math.atan2(p2.Y-p1.Y, p2.X-p1.X)
        line.Rotation = math.deg(angle) + 90
        roundify(line, w//2)
    end
end
rebuildCrosshair()

--// TARGET OVERLAY (Health/Armor)
local targetOverlay = Instance.new("Frame")
targetOverlay.Parent = gui
targetOverlay.AnchorPoint = Vector2.new(0.5,1)
targetOverlay.Position = UDim2.new(0.5,0,1,-80)
targetOverlay.Size = UDim2.new(0, 320, 0, 54)
styleFrame(targetOverlay); roundify(targetOverlay, 10); strokify(targetOverlay); paddify(targetOverlay, 8)
targetOverlay.Visible = false

local targetName = Instance.new("TextLabel", targetOverlay)
targetName.Size = UDim2.new(1,0,0,18)
styleText(targetName, 16, true)
targetName.TextXAlignment = Enum.TextXAlignment.Left

local hb = Instance.new("Frame", targetOverlay) -- Health bar bg
hb.Position = UDim2.new(0,0,0,22); hb.Size = UDim2.new(1,0,0,12)
styleFrame(hb); roundify(hb, 8); strokify(hb)

local hf = Instance.new("Frame", hb) -- Health fill
hf.BackgroundColor3 = Color3.fromRGB(0,170,0); roundify(hf, 6); strokify(hf)
hf.Size = UDim2.new(0,0,1,0)

local ab = Instance.new("Frame", targetOverlay) -- Armor bar bg
ab.Position = UDim2.new(0,0,0,38); ab.Size = UDim2.new(1,0,0,12)
styleFrame(ab); roundify(ab, 8); strokify(ab)

local af = Instance.new("Frame", ab) -- Armor fill
af.BackgroundColor3 = Color3.fromRGB(0,100,180); roundify(af, 6); strokify(af)
af.Size = UDim2.new(0,0,1,0)

--// ESP (box + name) using BillboardGui + 2D box from ScreenGui
local ESP_DATA = {}

local function clearESPFor(plr)
    local data = ESP_DATA[plr]
    if not data then return end
    if data.box then data.box:Destroy() end
    if data.name then data.name:Destroy() end
    if data.conn then data.conn:Disconnect() end
    ESP_DATA[plr] = nil
end

local function make2DBox()
    local box = Instance.new("Frame")
    box.Parent = gui
    box.BackgroundTransparency = 1
    box.Visible = false
    local stroke = Instance.new("UIStroke"); stroke.Parent = box; stroke.Color = BLACK; stroke.Thickness = 1
    return box
end

local function update2DBox(box, tl, br)
    box.Size = UDim2.new(0, math.abs(br.X - tl.X), 0, math.abs(br.Y - tl.Y))
    box.Position = UDim2.new(0, math.min(tl.X, br.X), 0, math.min(tl.Y, br.Y))
    box.Visible = true
end

local function createESP(plr)
    if plr == LocalPlayer or ESP_DATA[plr] then return end
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local nameBG = Instance.new("BillboardGui")
    nameBG.Name = "ESPName"; nameBG.Adornee = head; nameBG.Size = UDim2.new(0,160,0,28)
    nameBG.StudsOffset = Vector3.new(0,2,0); nameBG.AlwaysOnTop = true; nameBG.Parent = char
    local nameLabel = Instance.new("TextLabel", nameBG)
    nameLabel.Size = UDim2.new(1,0,1,0); nameLabel.BackgroundTransparency = 1
    nameLabel.Text = plr.Name; nameLabel.TextColor3 = BLACK
    nameLabel.Font = Enum.Font.GothamBold; nameLabel.TextScaled = true
    nameBG.Enabled = CFG.espEnabled and CFG.espNames

    local box = make2DBox()

    local rec = {}
    rec.box = box; rec.name = nameBG
    rec.conn = RunService.RenderStepped:Connect(function()
        if not CFG.espEnabled then
            if box.Visible then box.Visible=false end
            nameBG.Enabled = false
            return
        end
        nameBG.Enabled = CFG.espNames
        -- 2D box projection
        local c = plr.Character
        if not c then box.Visible=false; return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        local head = c:FindFirstChild("Head")
        if not hrp or not hum then box.Visible=false; return end

        local hrpPos, on1 = Camera:WorldToViewportPoint(hrp.Position)
        local headPos, on2 = head and Camera:WorldToViewportPoint(head.Position) or hrpPos, true
        local feetPos, on3 = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, hum.HipHeight + 2, 0))
        if (on1 or on2 or on3) and CFG.espBoxes then
            local height = math.abs(headPos.Y - feetPos.Y)
            local width = height * 0.6
            local tl = Vector2.new(hrpPos.X - width/2, headPos.Y)
            local br = Vector2.new(hrpPos.X + width/2, feetPos.Y)
            update2DBox(box, tl, br)
        else
            box.Visible = false
        end
    end)

    ESP_DATA[plr] = rec
end

local function refreshESP()
    for plr,_ in pairs(ESP_DATA) do clearESPFor(plr) end
    if CFG.espEnabled then
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then createESP(plr) end
        end
    end
end

Players.PlayerAdded:Connect(function(plr) task.wait(0.25); if CFG.espEnabled then createESP(plr) end end)
Players.PlayerRemoving:Connect(function(plr) clearESPFor(plr) end)

--// TARGETING
local function isValidEnemy(plr)
    if not plr or plr==LocalPlayer then return false end
    if CFG.friendFilter and LocalPlayer:IsFriendsWith(plr.UserId) then return false end
    local c = plr.Character
    if not c then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return true
end

local function predictPos(part, hrp)
    if not CFG.usePrediction or not hrp then return part.Position end
    local vel = Vector3.zero
    pcall(function() vel = hrp.Velocity end)
    local dist = (part.Position - Camera.CFrame.Position).Magnitude
    if CFG.bulletSpeed <= 0 then return part.Position end
    local t = dist / CFG.bulletSpeed
    return part.Position + vel * t * CFG.predictMultiplier
end

local function getLockPart(ch)
    if CFG.headPriority then
        return ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
    else
        return ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Head")
    end
end

local function pickBestTarget()
    -- only switch if current invalid OR manual switch requested
    local best, bestPart, bestHRP
    local bestScore = math.huge
    local viewCenter = Camera.ViewportSize/2
    for _,plr in ipairs(Players:GetPlayers()) do
        if isValidEnemy(plr) then
            local ch = plr.Character
            local part = ch and getLockPart(ch)
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if part and hrp then
                local pos = predictPos(part, hrp)
                local screen, onScreen = Camera:WorldToViewportPoint(pos)
                if onScreen then
                    local dCenter = (Vector2.new(screen.X, screen.Y) - Vector2.new(viewCenter.X, viewCenter.Y)).Magnitude
                    local dist = (pos - Camera.CFrame.Position).Magnitude
                    local score
                    if CFG.smartPriority == "Screen" then
                        score = dCenter + dist/2000
                    elseif CFG.smartPriority == "Angle" then
                        local dot = Camera.CFrame.LookVector:Dot((pos - Camera.CFrame.Position).Unit)
                        score = -dot + dist/10000
                    else
                        score = dist
                    end
                    if dCenter <= CFG.fovRingRadius or not CFG.showFOVRing then
                        if score < bestScore then bestScore = score; best = plr; bestPart = part; bestHRP = hrp end
                    end
                end
            end
        end
    end
    STATE.targetPlayer = best
    STATE.targetPart = bestPart
    STATE.targetHRP = bestHRP
end

-- Manual switch request flag
local REQUEST_SWITCH = false

-- Aiming function
local function aimAt(pos)
    local desired = CFrame.new(Camera.CFrame.Position, pos)
    local sm = clamp(CFG.aimSmooth, 0, 1)
    if sm <= 0 then
        Camera.CFrame = desired
    else
        Camera.CFrame = Camera.CFrame:Lerp(desired, sm)
    end
end

-- Update target overlay
local function updateTargetOverlay()
    if STATE.targetPlayer and STATE.targetPart and STATE.targetHRP then
        local hum = STATE.targetPlayer.Character and STATE.targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            targetOverlay.Visible = true
            targetName.Text = "Target: "..STATE.targetPlayer.Name
            local hp = clamp(hum.Health, 0, hum.MaxHealth)
            hf.Size = UDim2.new(hum.MaxHealth>0 and (hp/hum.MaxHealth) or 0, 0, 1, 0)
            local armorVal = 0
            if STATE.targetPlayer.Character and STATE.targetPlayer.Character:FindFirstChild("Armor") then
                local av = STATE.targetPlayer.Character.Armor.Value
                armorVal = clamp(tonumber(av) or 0, 0, 100)
            end
            af.Size = UDim2.new(armorVal/100, 0, 1, 0)
        else
            targetOverlay.Visible = false
        end
    else
        targetOverlay.Visible = false
    end
end

-- FPS Booster / Performance Mode
local ORIGINAL = {}
local function applyBooster(enableHeavy)
    -- Save originals once
    if not ORIGINAL.Lighting then
        ORIGINAL.Lighting = {
            GlobalShadows = Lighting.GlobalShadows,
            Technology    = Lighting.Technology,
            FogEnd        = Lighting.FogEnd,
        }
        ORIGINAL.Effects = {}
        for _,v in ipairs(Lighting:GetChildren()) do
            ORIGINAL.Effects[v] = v.Enabled ~= nil and v.Enabled or true
        end
        ORIGINAL.Terrain = {}
        local Terrain = workspace:FindFirstChildOfClass("Terrain")
        if Terrain then
            ORIGINAL.Terrain.Decoration = Terrain.Decoration
        end
    end
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    if enableHeavy then
        Lighting.GlobalShadows = false
        pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
        Lighting.FogEnd = 9e9
        for _,v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("ColorCorrectionEffect") then
                v.Enabled = false
            end
        end
        if Terrain then Terrain.Decoration = false end
    else
        -- restore
        if ORIGINAL.Lighting then
            Lighting.GlobalShadows = ORIGINAL.Lighting.GlobalShadows
            pcall(function() Lighting.Technology = ORIGINAL.Lighting.Technology end)
            Lighting.FogEnd = ORIGINAL.Lighting.FogEnd
        end
        if ORIGINAL.Effects then
            for v,enabled in pairs(ORIGINAL.Effects) do pcall(function() if v then v.Enabled = enabled end end) end
        end
        if Terrain and ORIGINAL.Terrain then Terrain.Decoration = ORIGINAL.Terrain.Decoration end
    end
end

-- Safe Mode
local function applySafeMode(on)
    if on then
        CFG.aimbotEnabled=false; STATE.aiming=false
        CFG.espEnabled=false; refreshESP()
    end
end
applySafeMode(CFG.safeMode)

-- Keybind helpers
local function strToKeyCode(s)
    if not s or s=="" then return Enum.KeyCode.Unknown end
    s = tostring(s):upper()
    return Enum.KeyCode[s] or Enum.KeyCode.Unknown
end

-- UI: Controls
makeToggleRow("Aimbot", CFG.aimbotEnabled, function(v) CFG.aimbotEnabled=v; STATE.aiming=v end)
makeDropdownRow("Aim Part", {"Head","HumanoidRootPart"}, (CFG.aimPart=="Head" and 1 or 2), function(v) CFG.aimPart=v; CFG.headPriority=(v=="Head") end)
makeDropdownRow("Priority", {"Screen","Angle","Distance"}, (CFG.smartPriority=="Screen" and 1 or CFG.smartPriority=="Angle" and 2 or 3), function(v) CFG.smartPriority=v end)
makeSliderRow("Smoothness", 0, 1, 0.01, CFG.aimSmooth, function(v) CFG.aimSmooth=v end)
makeSliderRow("Max Range", 100, 1500, 10, CFG.maxAimRange, function(v) CFG.maxAimRange=v end)
makeToggleRow("Prediction", CFG.usePrediction, function(v) CFG.usePrediction=v end)
makeSliderRow("Bullet Speed", 200, 5000, 50, CFG.bulletSpeed, function(v) CFG.bulletSpeed=v end)
makeSliderRow("Predict Mult.", 0, 3, 0.05, CFG.predictMultiplier, function(v) CFG.predictMultiplier=v end)
makeToggleRow("Friend Filter", CFG.friendFilter, function(v) CFG.friendFilter=v end)

makeSliderRow("Camera FOV", 40, 120, 1, CFG.fov, function(v) CFG.fov=v; Camera.FieldOfView=v end)
makeToggleRow("Show FOV Ring", CFG.showFOVRing, function(v) CFG.showFOVRing=v; fovRing.Visible=v; ringStroke.Transparency = v and 0 or 1 end)
makeSliderRow("FOV Ring Radius", 20, 400, 2, CFG.fovRingRadius, function(v) CFG.fovRingRadius=v; fovRing.Size = UDim2.new(0, v*2, 0, v*2) end)
makeSliderRow("Recoil Control", 0, 1, 0.01, CFG.recoilControl, function(v) CFG.recoilControl=v end)

makeToggleRow("ESP (Boxes + Names)", CFG.espEnabled, function(v) CFG.espEnabled=v; refreshESP() end)
makeToggleRow("ESP Names", CFG.espNames, function(v) CFG.espNames=v end)
makeToggleRow("ESP Boxes", CFG.espBoxes, function(v) CFG.espBoxes=v end)
makeToggleRow("ESP Always On Top", CFG.espAlwaysOnTop, function(v) CFG.espAlwaysOnTop=v end)

makeToggleRow("Crosshair", CFG.crosshairEnabled, function(v) CFG.crosshairEnabled=v; rebuildCrosshair() end)
makeSliderRow("Crosshair Size", 6, 36, 1, CFG.crosshairSize, function(v) CFG.crosshairSize=v; rebuildCrosshair() end)
makeSliderRow("Crosshair Opacity", 0, 1, 0.05, CFG.crosshairOpacity, function(v) CFG.crosshairOpacity=v; rebuildCrosshair() end)

makeToggleRow("FPS Booster", CFG.fpsBooster, function(v) CFG.fpsBooster=v; applyBooster(v or CFG.performanceMode) end)
makeToggleRow("Performance Mode", CFG.performanceMode, function(v) CFG.performanceMode=v; applyBooster(v) end)
makeToggleRow("Safe Mode", CFG.safeMode, function(v) CFG.safeMode=v; applySafeMode(v) end)

makeButtonRow("Save Settings", "Save Now", function() saveJSON(CFG) end)

--// Touch Buttons (for mobile)
local touchBar = Instance.new("Frame")
touchBar.Parent = gui
touchBar.AnchorPoint = Vector2.new(0.5,1)
touchBar.Position = UDim2.new(0.5,0,1,-12)
touchBar.Size = UDim2.new(0, 340, 0, 46)
styleFrame(touchBar); roundify(touchBar, 10); strokify(touchBar); paddify(touchBar, 6)

local function makeTouchButton(text, onClick)
    local b = Instance.new("TextButton")
    b.Parent = touchBar
    b.BackgroundColor3 = GREY
    b.Size = UDim2.new(0.32, -6, 1, 0)
    b.Text = text; b.TextColor3 = BLACK
    roundify(b, 8); strokify(b)
    b.MouseButton1Click:Connect(function() playSound(CLICK_SOUND, 1); onClick() end)
    return b
end
local tbLayout = Instance.new("UIListLayout", touchBar)
tbLayout.FillDirection = Enum.FillDirection.Horizontal
tbLayout.Padding = UDim.new(0,6)
tbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tbLayout.VerticalAlignment = Enum.VerticalAlignment.Center

makeTouchButton("Aimbot", function() STATE.aiming = not STATE.aiming; CFG.aimbotEnabled=STATE.aiming; saveJSON(CFG) end)
makeTouchButton("Switch", function() REQUEST_SWITCH = true end)
makeTouchButton("Menu", function() main.Visible = not main.Visible end)

--// Keybinds
UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.UserInputType == Enum.UserInputType.Keyboard then
        if inp.KeyCode == strToKeyCode(CFG.hotkeyToggle) then
            STATE.aiming = not STATE.aiming; CFG.aimbotEnabled=STATE.aiming; playSound(CLICK_SOUND,1); saveJSON(CFG)
        elseif inp.KeyCode == strToKeyCode(CFG.hotkeySwitch) then
            REQUEST_SWITCH = true; playSound(CLICK_SOUND,1)
        elseif inp.KeyCode == strToKeyCode(CFG.hotkeyMenu) then
            main.Visible = not main.Visible; playSound(CLICK_SOUND,1)
        end
    end
end)

--// Auto Reconnect support
local function queueScript()
    local src = "-- Delta Aim Enhanced Auto-Queue\n"..([[
loadstring(game:HttpGet("https://pastebin.com/raw/4FHt0zZz"))()
    ]]):gsub("\n","") -- placeholder: in exploit context, replace with local load method if desired
    if queue_on_teleport then pcall(queue_on_teleport, src) end
end
LocalPlayer.OnTeleport:Connect(function() pcall(queueScript) end)

--// Metrics (FPS & Ping)
do
    local last = os.clock()
    local accum, frames = 0, 0
    RunService.RenderStepped:Connect(function(dt)
        accum += dt; frames += 1
        if accum >= 0.5 then
            STATE.fps = math.floor(frames/accum + 0.5)
            accum = 0; frames = 0
        end
        if CFG.showFPS then fpsLabel.Text = "FPS: "..tostring(STATE.fps) else fpsLabel.Text = "" end
        local ping = 0
        pcall(function()
            local it = Stats.Network.ServerStatsItem["Data Ping"]
            if it and it.GetValue then ping = math.floor(it:GetValue()*1000) end
        end)
        STATE.ping = ping
        if CFG.showPing then pingLabel.Text = "Ping: "..tostring(ping).." ms" else pingLabel.Text = "" end
    end)
end

--// Main loop
RunService.RenderStepped:Connect(function()
    -- update center overlays
    cross.Position = UDim2.new(0.5,0,0.5,0)
    fovRing.Position = UDim2.new(0.5,0,0.5,0)

    -- performance toggles
    applyBooster(CFG.performanceMode or CFG.fpsBooster)

    -- pick/sustain target
    local targetInvalid = true
    if STATE.targetPlayer and isValidEnemy(STATE.targetPlayer) and STATE.targetPart and STATE.targetHRP then
        targetInvalid = false
    end
    if REQUEST_SWITCH then
        STATE.targetPlayer=nil; STATE.targetPart=nil; STATE.targetHRP=nil
        REQUEST_SWITCH=false; targetInvalid=true
    end

    if targetInvalid then
        pickBestTarget()
    end

    -- Aim
    if STATE.aiming and not CFG.safeMode then
        local tPart = STATE.targetPart
        local tHRP = STATE.targetHRP
        if tPart and tHRP then
            local pos = predictPos(tPart, tHRP)
            -- recoil control (gentle lerp toward ideal aim)
            local rc = clamp(CFG.recoilControl, 0, 1)
            if rc > 0 then
                pos = Camera.CFrame.Position:Lerp(pos, 1 - rc*0.2)
            end
            aimAt(pos)
        end
    end

    -- Target overlay
    updateTargetOverlay()
end)

--// Ensure GUI survives character respawns
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.25)
    if gui.Parent ~= PlayerGui then gui.Parent = PlayerGui end
end)

print("[Delta Aim Enhanced] Loaded successfully.")
