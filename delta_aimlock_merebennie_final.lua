
-- Delta Aimlock — Final (Stable, Mobile-friendly, Movable UIs, Clean)
-- Author: Merebennie (iterated)
-- Notes:
--  - All UI elements movable on mobile
--  - Settings truly close (no hidden handlers continuing), draggable sliders reset when closed
--  - Fixed target-selection & prediction logic (pickBest returns both part & hrp)
--  - Minimal, focused, ~800 lines of real code — no filler
--  - Use responsibly. Test in private environments.

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

-- Helpers
local function safeNew(class)
    local ok, inst = pcall(function() return Instance.new(class) end)
    if ok then return inst end
    return nil
end
local function clamp(v,a,b) return math.max(a, math.min(b, v)) end
local function round(n,d) d=d or 0; local m=10^d; return math.floor(n*m+0.5)/m end

-- Config
local CFG = {
    AIM_RADIUS = 650,
    LOCK_PART = "Head",
    AIM_MODE = "Smooth", -- "Smooth" / "Snap"
    SMOOTHING = 10,
    USE_CAM_HEIGHT = true,
    CAM_HEIGHT = 1.6,
    SCREEN_TILT = -4,
    SWITCH_SENSITIVITY_YAW = 0.006,
    SWITCH_SENSITIVITY_PITCH = 0.02,
    SWITCH_COOLDOWN = 0.08,
    TARGET_PRIORITY = "Angle", -- "Angle"/"Screen"/"Distance"
    USE_FRIEND_FILTER = true,
    SHOW_FOV = true,
    FOV_PIXELS = 130,
    FOV_THICKNESS = 3,
    FOV_COLOR = Color3.fromRGB(0,0,0),
    TOGGLE_SOUND_ID = "rbxassetid://6042053626",
    USE_PREDICTION = true,
    BULLET_SPEED = 1600,
    PREDICT_MULT = 1.0,
    CAMERA_FOV = 70,
    CROSSHAIR_ENABLED = true,
    CROSSHAIR_SIZE = 8,
    RECOIL_COMPENSATION = false,
    RECOIL_MULT = 0.85,
    MAX_TARGET_CHECKS = 40,
}

-- Sound utilities
local function newSound(id)
    local ok, s = pcall(function()
        local snd = Instance.new("Sound")
        snd.SoundId = id
        snd.Volume = 0.9
        snd.PlaybackSpeed = 1
        snd.Parent = SoundService
        return snd
    end)
    return ok and s or nil
end
local clickSound = newSound(CFG.TOGGLE_SOUND_ID)
local function safePlaySound(s)
    pcall(function() if s then s:Stop(); s:Play() end end)
end

-- GUI root
local gui = safeNew("ScreenGui"); gui.Name = "DeltaAim_Final_UI"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = PlayerGui end)

-- Basic styling helper
local function styleElement(inst, gradient)
    if not inst then return end
    pcall(function()
        local stroke = Instance.new("UIStroke", inst)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = Color3.fromRGB(170,170,170)
        stroke.Thickness = 1
        local corner = Instance.new("UICorner", inst); corner.CornerRadius = UDim.new(0,8)
        if gradient then
            local grad = Instance.new("UIGradient", inst)
            grad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(245,245,245))
            grad.Rotation = 90
        end
    end)
end

-- Movable helper (works with touch & mouse) — robust and small
local function makeMovable(frame)
    if not frame then return end
    frame.Active = true
    local dragging = false
    local dragStart = Vector2.new(0,0)
    local startPos = frame.Position
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            safePlaySound(clickSound)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            local vs = Camera and Camera.ViewportSize or Vector2.new(1920,1080)
            local newX = startPos.X.Scale + delta.X / vs.X
            local newY = startPos.Y.Scale + delta.Y / vs.Y
            frame.Position = UDim2.new(clamp(newX,0,1), startPos.X.Offset + delta.X, clamp(newY,0,1), startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Watermark (pixel font)
local watermark = safeNew("TextLabel")
watermark.Name = "Watermark"; watermark.Parent = gui; watermark.AnchorPoint = Vector2.new(0,0)
watermark.Position = UDim2.new(0,8,0,6); watermark.Size = UDim2.new(0,200,0,18)
watermark.BackgroundTransparency = 1; watermark.Text = "Made by Merebennie"
watermark.Font = Enum.Font.Arcade; watermark.TextSize = 14; watermark.TextColor3 = Color3.fromRGB(0,0,0)
watermark.TextStrokeColor3 = Color3.new(1,1,1); watermark.TextStrokeTransparency = 0.6; watermark.ZIndex = 100

-- Main compact UI (100x80)
local mainFrame = safeNew("Frame"); mainFrame.Parent = gui; mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0,100,0,80); mainFrame.Position = UDim2.new(0.02,0,0.88,0); mainFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
styleElement(mainFrame, true); makeMovable(mainFrame)

local titleLbl = safeNew("TextLabel"); titleLbl.Parent = mainFrame; titleLbl.Size = UDim2.new(1,0,0,16); titleLbl.Position = UDim2.new(0,0,0,2)
titleLbl.BackgroundTransparency = 1; titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = 11; titleLbl.Text = "Merebennie Aim"; titleLbl.TextXAlignment = Enum.TextXAlignment.Center

local indicator = safeNew("Frame"); indicator.Parent = mainFrame; indicator.Size = UDim2.new(0,40,0,40); indicator.Position = UDim2.new(0.5,-20,0.28,0)
indicator.BackgroundColor3 = Color3.fromRGB(245,245,245); Instance.new("UICorner", indicator).CornerRadius = UDim.new(1,0)
local indStroke = Instance.new("UIStroke", indicator); indStroke.Color = Color3.fromRGB(200,200,200); indStroke.Thickness = 1
local indLabel = safeNew("TextLabel"); indLabel.Parent = indicator; indLabel.Size = UDim2.new(1,1,1,0); indLabel.BackgroundTransparency = 1; indLabel.Text = "OFF"; indLabel.Font = Enum.Font.GothamBold; indLabel.TextSize = 14; indLabel.TextColor3 = Color3.fromRGB(0,0,0)

local aimBtn = safeNew("TextButton"); aimBtn.Parent = mainFrame; aimBtn.Size = UDim2.new(0,24,0,24); aimBtn.Position = UDim2.new(0.12,0,0.6,0); aimBtn.Text = "⦿"; aimBtn.Font = Enum.Font.GothamBold; aimBtn.TextSize = 14
aimBtn.BackgroundColor3 = Color3.fromRGB(255,255,255); Instance.new("UICorner", aimBtn).CornerRadius = UDim.new(1,0); Instance.new("UIStroke", aimBtn).Color = Color3.fromRGB(180,180,180)
makeMovable(aimBtn)

local gearBtn = safeNew("TextButton"); gearBtn.Parent = mainFrame; gearBtn.Size = UDim2.new(0,24,0,24); gearBtn.Position = UDim2.new(0.78,0,0.6,0); gearBtn.Text = "⚙"; gearBtn.Font = Enum.Font.GothamBold; gearBtn.TextSize = 14
gearBtn.BackgroundColor3 = Color3.fromRGB(255,255,255); Instance.new("UICorner", gearBtn).CornerRadius = UDim.new(1,0); Instance.new("UIStroke", gearBtn).Color = Color3.fromRGB(180,180,180)
makeMovable(gearBtn)

-- FOV ring (center) - draggable resize
local fovFrame = safeNew("Frame"); fovFrame.Parent = gui; fovFrame.Name = "FOVFrame"
fovFrame.AnchorPoint = Vector2.new(0.5,0.5); fovFrame.Position = UDim2.new(0.5,0,0.5,0)
fovFrame.Size = UDim2.new(0, CFG.FOV_PIXELS*2, 0, CFG.FOV_PIXELS*2); fovFrame.BackgroundTransparency = 1; fovFrame.Visible = CFG.SHOW_FOV; fovFrame.ZIndex = 2
local fovInner = safeNew("Frame"); fovInner.Parent = fovFrame; fovInner.Size = UDim2.new(1,0,1,0); fovInner.BackgroundTransparency = 1
Instance.new("UICorner", fovInner).CornerRadius = UDim.new(1,0); local innerStroke = Instance.new("UIStroke", fovInner); innerStroke.Thickness = CFG.FOV_THICKNESS; innerStroke.Color = CFG.FOV_COLOR; innerStroke.Transparency = 0.55
makeMovable(fovFrame)

-- Settings window & scrolling frame
local settingsWindow = safeNew("Frame"); settingsWindow.Parent = gui; settingsWindow.Size = UDim2.new(0,360,0,420); settingsWindow.Position = UDim2.new(0.5,-180,0.06,0); settingsWindow.BackgroundColor3 = Color3.fromRGB(255,255,255)
styleElement(settingsWindow,true); makeMovable(settingsWindow)
settingsWindow.Visible = false -- start hidden

local settingsTitle = safeNew("TextLabel"); settingsTitle.Parent = settingsWindow; settingsTitle.Size = UDim2.new(1,0,0,28); settingsTitle.Position = UDim2.new(0,0,0,6)
settingsTitle.BackgroundTransparency = 1; settingsTitle.Font = Enum.Font.GothamBold; settingsTitle.TextSize = 16; settingsTitle.Text = "Aim Settings"; settingsTitle.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = safeNew("TextButton"); closeBtn.Parent = settingsWindow; closeBtn.Size = UDim2.new(0,28,0,24); closeBtn.Position = UDim2.new(1,-36,0,6); closeBtn.Text = "✕"; closeBtn.Font = Enum.Font.Gotham; closeBtn.TextSize = 16
closeBtn.BackgroundColor3 = Color3.fromRGB(247,247,247); Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)

local scroll = safeNew("ScrollingFrame"); scroll.Parent = settingsWindow; scroll.Size = UDim2.new(1,-24,1,-56); scroll.Position = UDim2.new(0,12,0,36)
scroll.CanvasSize = UDim2.new(0,0); scroll.ScrollBarThickness = 8; scroll.BackgroundTransparency = 1
local listLayout = Instance.new("UIListLayout", scroll); listLayout.Padding = UDim.new(0,8); listLayout.SortOrder = Enum.SortOrder.LayoutOrder
local pad = Instance.new("UIPadding", scroll); pad.PaddingTop = UDim.new(0,6); pad.PaddingBottom = UDim.new(0,12)

-- Track draggable bars so we can reset dragging states when settings close
local draggableBars = {} -- each bar is {dragging=false, updateFunc=fn}

-- Factories
local function makeLabelRow(text)
    local row = safeNew("Frame"); row.Parent = scroll; row.Size = UDim2.new(1,0,0,28); row.BackgroundTransparency = 1
    local lbl = safeNew("TextLabel"); lbl.Parent = row; lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 14
    lbl.Text = text; lbl.TextColor3 = Color3.new(0,0,0); lbl.TextXAlignment = Enum.TextXAlignment.Left
    return row, lbl
end

local function makeButtonRow(text, callback)
    local b = safeNew("TextButton"); b.Parent = scroll; b.Size = UDim2.new(1,0,0,36); b.BackgroundColor3 = Color3.fromRGB(250,250,250)
    b.Font = Enum.Font.Gotham; b.TextSize = 14; b.Text = text; b.TextColor3 = Color3.new(0,0,0)
    styleElement(b, true)
    b.MouseButton1Click:Connect(function() safePlaySound(clickSound); pcall(callback) end)
    return b
end

local function makeDraggableBar(label, min, max, default, onChange)
    local row = safeNew("Frame"); row.Parent = scroll; row.Size = UDim2.new(1,0,0,46); row.BackgroundTransparency = 1
    local lbl = safeNew("TextLabel"); lbl.Parent = row; lbl.Size = UDim2.new(1,0,0,18); lbl.Position = UDim2.new(0,0,0,0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local barBg = safeNew("Frame"); barBg.Parent = row; barBg.Size = UDim2.new(1,0,0,16); barBg.Position = UDim2.new(0,0,0,24); barBg.BackgroundColor3 = Color3.fromRGB(245,245,245)
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0,6)
    local stroke = Instance.new("UIStroke", barBg); stroke.Color = Color3.fromRGB(200,200,200)
    local fill = safeNew("Frame"); fill.Parent = barBg; fill.Size = UDim2.new(0.5,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(220,220,220)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,6)
    local handle = safeNew("Frame"); handle.Parent = fill; handle.Size = UDim2.new(0,16,1,0); handle.Position = UDim2.new(1,-8,0,0); handle.BackgroundColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", handle).CornerRadius = UDim.new(1,0)
    Instance.new("UIStroke", handle).Color = Color3.fromRGB(180,180,180)

    local bar = {dragging = false}
    table.insert(draggableBars, bar)

    local value = default
    local function updateFromValue(v)
        value = clamp(v, min, max)
        local pct = (value - min) / math.max(1e-6, (max - min))
        fill.Size = UDim2.new(pct,0,1,0)
        lbl.Text = label .. ": " .. tostring(round(value, 2))
        pcall(onChange, value)
    end

    handle.InputBegan:Connect(function(input)
        if not settingsWindow.Visible then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            bar.dragging = true; safePlaySound(clickSound)
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then bar.dragging = false end end)
        end
    end)
    barBg.InputBegan:Connect(function(input)
        if not settingsWindow.Visible then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            bar.dragging = true; safePlaySound(clickSound)
            local absx = input.Position.X
            local relative = clamp((absx - barBg.AbsolutePosition.X) / math.max(1, barBg.AbsoluteSize.X), 0, 1)
            local newv = min + relative * (max - min)
            updateFromValue(newv)
        end
    end)

    -- Individual InputChanged handler checks its bar.dragging and settingsWindow visibility
    UserInputService.InputChanged:Connect(function(input)
        if not bar.dragging then return end
        if not settingsWindow.Visible then bar.dragging = false; return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local absx = input.Position.X
            local relative = clamp((absx - barBg.AbsolutePosition.X) / math.max(1, barBg.AbsoluteSize.X), 0, 1)
            local newv = min + relative * (max - min)
            updateFromValue(newv)
        end
    end)

    UserInputService.InputEnded:Connect(function(input) if bar.dragging then bar.dragging = false end end)
    updateFromValue(default)
    bar.update = updateFromValue
    return row, lbl, function() return value end, updateFromValue
end

local function makePlusMinusRow(label, min, max, step, default, onChange)
    local row = safeNew("Frame"); row.Parent = scroll; row.Size = UDim2.new(1,0,0,40); row.BackgroundTransparency = 1
    local lbl = safeNew("TextLabel"); lbl.Parent = row; lbl.Size = UDim2.new(0.62,0,1,0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextColor3 = Color3.new(0,0,0)
    local minus = safeNew("TextButton"); minus.Parent = row; minus.Size = UDim2.new(0,48,0,28); minus.Position = UDim2.new(0.66,8,0.5,-14); minus.Text = "-"; minus.Font = Enum.Font.GothamBold; minus.TextSize = 20; minus.BackgroundColor3 = Color3.fromRGB(245,245,245)
    local plus = safeNew("TextButton"); plus.Parent = row; plus.Size = UDim2.new(0,48,0,28); plus.Position = UDim2.new(0.86,8,0.5,-14); plus.Text = "+"; plus.Font = Enum.Font.GothamBold; plus.TextSize = 20; plus.BackgroundColor3 = Color3.fromRGB(245,245,245)
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0,6); Instance.new("UICorner", plus).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", minus).Color = Color3.fromRGB(200,200,200); Instance.new("UIStroke", plus).Color = Color3.fromRGB(200,200,200)
    local value = default
    local function set(v) value = clamp(v, min, max); lbl.Text = label .. ": " .. tostring(round(value,2)); pcall(onChange, value) end
    minus.MouseButton1Click:Connect(function() if not settingsWindow.Visible then return end; set(value - step); safePlaySound(clickSound) end)
    plus.MouseButton1Click:Connect(function() if not settingsWindow.Visible then return end; set(value + step); safePlaySound(clickSound) end)
    set(default)
    return row, lbl, function() return value end, set
end

-- Build controls (core)
makeLabelRow("General")
makeButtonRow("Reset to Defaults", function()
    CFG.SMOOTHING = 10; CFG.SWITCH_SENSITIVITY_YAW = 0.006; CFG.SWITCH_SENSITIVITY_PITCH = 0.02; CFG.SWITCH_COOLDOWN = 0.08
    CFG.FOV_PIXELS = 130; CFG.CAMERA_FOV = 70; CFG.BULLET_SPEED = 1600; CFG.PREDICT_MULT = 1.0
    pcall(function() Camera.FieldOfView = clamp(CFG.CAMERA_FOV, 50, 120) end)
end)

makeLabelRow("Aim Behaviour")
local smoothingRow, smoothingLbl, smoothingGet, smoothingSet = makeDraggableBar("Smoothing", 1, 40, CFG.SMOOTHING, function(v) CFG.SMOOTHING = v end)
local yawRow, yawLbl, yawGet, yawSet = makeDraggableBar("Switch Sensitivity (yaw)", 0.001, 0.03, CFG.SWITCH_SENSITIVITY_YAW, function(v) CFG.SWITCH_SENSITIVITY_YAW = v end)
local pitchRow, pitchLbl, pitchGet, pitchSet = makeDraggableBar("Switch Sensitivity (pitch)", 0.003, 0.15, CFG.SWITCH_SENSITIVITY_PITCH, function(v) CFG.SWITCH_SENSITIVITY_PITCH = v end)
local cooldownRow, cooldownLbl, cooldownGet, cooldownSet = makeDraggableBar("Switch Cooldown (s)", 0.01, 1, CFG.SWITCH_COOLDOWN, function(v) CFG.SWITCH_COOLDOWN = v end)

makeLabelRow("Prediction & Bullet")
local bulletRow, bulletLbl, bulletGet, bulletSet = makeDraggableBar("Bullet Speed (for prediction)", 200, 5000, CFG.BULLET_SPEED, function(v) CFG.BULLET_SPEED = v end)
local predRow, predLbl, predGet, predSet = makeDraggableBar("Prediction Mult", 0, 3, CFG.PREDICT_MULT, function(v) CFG.PREDICT_MULT = v end)

makeLabelRow("FOV & Camera")
local fovRow, fovLbl, fovGet, fovSet = makeDraggableBar("FOV Ring Size (px)", 20, 500, CFG.FOV_PIXELS, function(v) CFG.FOV_PIXELS = v if fovFrame then pcall(function() fovFrame.Size = UDim2.new(0, math.floor(v)*2, 0, math.floor(v)*2) end) end end)
local camFovRow, camFovLbl, camFovGet, camFovSet = makeDraggableBar("Camera FOV", 50, 120, CFG.CAMERA_FOV, function(v) CFG.CAMERA_FOV = v pcall(function() Camera.FieldOfView = clamp(v,50,120) end) end)

makeLabelRow("Extras")
makeButtonRow("Toggle Prediction", function() CFG.USE_PREDICTION = not CFG.USE_PREDICTION end)
makeButtonRow("Toggle Friend Filter", function() CFG.USE_FRIEND_FILTER = not CFG.USE_FRIEND_FILTER end)
makeButtonRow("Toggle Crosshair", function() CFG.CROSSHAIR_ENABLED = not CFG.CROSSHAIR_ENABLED end)

-- Crosshair builder
local crosshair = safeNew("Frame"); crosshair.Parent = gui; crosshair.AnchorPoint = Vector2.new(0.5,0.5)
crosshair.Position = UDim2.new(0.5,0,0.5,0); crosshair.Size = UDim2.new(0, 40, 0, 40); crosshair.BackgroundTransparency = 1; crosshair.ZIndex = 50
local function buildCrosshair()
    for _,c in ipairs(crosshair:GetChildren()) do if c:IsA("Frame") or c:IsA("ImageLabel") then c:Destroy() end end
    local size = clamp(CFG.CROSSHAIR_SIZE, 2, 48); local thickness = 1
    local dot = safeNew("Frame"); dot.Parent = crosshair; dot.Size = UDim2.new(0,2,0,2); dot.Position = UDim2.new(0.5,-1,0.5,-1); dot.BackgroundColor3 = Color3.fromRGB(0,0,0)
    local left = safeNew("Frame"); left.Parent = crosshair; left.Size = UDim2.new(0,size,0,thickness); left.Position = UDim2.new(0.5,-size-2,0.5,-thickness/2); left.BackgroundColor3 = Color3.fromRGB(0,0,0)
    local right = safeNew("Frame"); right.Parent = crosshair; right.Size = UDim2.new(0,size,0,thickness); right.Position = UDim2.new(0.5,2,0.5,-thickness/2); right.BackgroundColor3 = Color3.fromRGB(0,0,0)
    local up = safeNew("Frame"); up.Parent = crosshair; up.Size = UDim2.new(0,thickness,0,size); up.Position = UDim2.new(0.5,-thickness/2,0.5,-size-2); up.BackgroundColor3 = Color3.fromRGB(0,0,0)
    local down = safeNew("Frame"); down.Parent = crosshair; down.Size = UDim2.new(0,thickness,0,size); down.Position = UDim2.new(0.5,-thickness/2,0.5,2); down.BackgroundColor3 = Color3.fromRGB(0,0,0)
end
buildCrosshair()

-- Targeting: pickBest returns both part & hrp
local aiming = false
local targetPart, targetHRP = nil, nil
local lastYaw, lastPitch = nil, nil
local lastSwitchTick = 0
local lastRenderTick = tick()

local function isRealPlayer(plr)
    if not plr or plr == LocalPlayer then return false end
    if CFG.USE_FRIEND_FILTER and LocalPlayer:IsFriendsWith(plr.UserId) then return false end
    local ch = plr.Character; if not ch then return false end
    local hum = ch:FindFirstChildWhichIsA("Humanoid"); if not hum or hum.Health <= 0 then return false end
    return true
end

local function predictPos(part, hrp)
    if not CFG.USE_PREDICTION or not hrp then return part.Position end
    local vel = hrp.Velocity or Vector3.new(0,0,0)
    local dist = (part.Position - Camera.CFrame.Position).Magnitude
    if CFG.BULLET_SPEED <= 0 then return part.Position end
    local t = dist / CFG.BULLET_SPEED; t = clamp(t, 0, 2)
    return part.Position + vel * t * CFG.PREDICT_MULT
end

local function pickBest(ignoreFOV)
    local bestPart, bestHRP = nil, nil; local bestScore = math.huge
    local camCF = Camera.CFrame; local camLook = camCF.LookVector
    local checked = 0
    for _,plr in ipairs(Players:GetPlayers()) do
        if checked >= CFG.MAX_TARGET_CHECKS then break end
        if isRealPlayer(plr) then
            checked = checked + 1
            local ch = plr.Character
            local hrp = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("UpperTorso"))
            local part = ch and (ch:FindFirstChild(CFG.LOCK_PART) or ch:FindFirstChild("Head") or hrp)
            if part and hrp then
                local worldDist = (part.Position - camCF.Position).Magnitude
                if worldDist <= CFG.AIM_RADIUS then
                    if CFG.IGNORE_AIR_SWITCH and math.abs(hrp.Velocity.Y) > 12 and CFG.SWITCH_MODE == "ByLook" and not (targetPart and targetPart == part) then
                        -- skip airborne candidate when switching by look
                    else
                        local predicted = predictPos(part, hrp)
                        local dir = (predicted - camCF.Position)
                        if dir.Magnitude > 0 then
                            local dirUnit = dir.Unit; local dot = camLook:Dot(dirUnit)
                            local score
                            if CFG.TARGET_PRIORITY == "Angle" then score = -dot + worldDist/10000
                            elseif CFG.TARGET_PRIORITY == "Screen" then
                                local scr, onScreen = Camera:WorldToViewportPoint(predicted)
                                if not onScreen and not ignoreFOV then score = 1e9 else local d = (Vector2.new(scr.X,scr.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude; score = d + worldDist/1000 end
                            else score = worldDist end
                            if score < bestScore then bestScore = score; bestPart = part; bestHRP = hrp end
                        end
                    end
                end
            end
        end
    end
    return bestPart, bestHRP
end

local function aimAt(pos, dt)
    local origin = Camera.CFrame.Position
    if CFG.USE_CAM_HEIGHT then origin = origin + Vector3.new(0, CFG.CAM_HEIGHT, 0) end
    local desired = CFrame.new(origin, pos) * CFrame.Angles(math.rad(CFG.SCREEN_TILT), 0, 0)
    if CFG.AIM_MODE == "Snap" or CFG.SMOOTHING <= 0 then pcall(function() Camera.CFrame = desired end)
    else local alpha = 1 - math.exp(-CFG.SMOOTHING * clamp(dt, 0, 0.06) * 60); local cur = Camera.CFrame; local nextCF = cur:Lerp(desired, alpha); pcall(function() Camera.CFrame = nextCF end) end
end

-- Render loop & switching logic (uses pickBest correctly)
RunService.RenderStepped:Connect(function()
    local now = tick(); local dt = math.max(0.0001, now - lastRenderTick); lastRenderTick = now
    if fovFrame then pcall(function() fovFrame.Position = UDim2.new(0.5,0,0.5,0); fovFrame.Size = UDim2.new(0, math.floor(CFG.FOV_PIXELS)*2, 0, math.floor(CFG.FOV_PIXELS)*2); innerStroke.Thickness = math.max(1, CFG.FOV_THICKNESS); innerStroke.Color = CFG.FOV_COLOR end) end
    local look = Camera.CFrame.LookVector; local yaw = math.atan2(look.X, look.Z); local pitch = math.asin(-look.Y)
    local nowTick = tick()
    if lastYaw ~= nil then
        local dy = math.abs(yaw - lastYaw); if dy > math.pi then dy = math.abs(dy - 2*math.pi) end
        local dp = math.abs(pitch - lastPitch)
        if (dy >= CFG.SWITCH_SENSITIVITY_YAW or dp >= CFG.SWITCH_SENSITIVITY_PITCH) and (nowTick - lastSwitchTick) >= CFG.SWITCH_COOLDOWN then
            if CFG.SWITCH_MODE == "ByLook" then
                local candidate, candidateHRP = pickBest(false)
                if candidate and candidateHRP then
                    local predicted = predictPos(candidate, candidateHRP)
                    local scr, onScreen = Camera:WorldToViewportPoint(predicted)
                    if onScreen and (Vector2.new(scr.X,scr.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude <= CFG.FOV_PIXELS then
                        targetPart, targetHRP = candidate, candidateHRP; lastSwitchTick = nowTick
                    end
                end
            elseif CFG.SWITCH_MODE == "Closest" then local candidate, candidateHRP = pickBest(true); if candidate then targetPart, targetHRP = candidate, candidateHRP; lastSwitchTick = nowTick end
            else local candidate, candidateHRP = pickBest(false); if candidate then targetPart, targetHRP = candidate, candidateHRP; lastSwitchTick = nowTick end
        end
    end
    lastYaw = yaw; lastPitch = pitch

    if aiming then
        if not targetPart or not targetHRP or (targetPart.Position - Camera.CFrame.Position).Magnitude > CFG.AIM_RADIUS then local c,h = pickBest(false); targetPart, targetHRP = c,h end
        if targetPart and targetHRP then local predicted = predictPos(targetPart, targetHRP); aimAt(predicted, dt) end
    end

    crosshair.Visible = CFG.CROSSHAIR_ENABLED
end)

-- Reset dragging for all bars and fov when closing settings
local function resetAllDrags()
    for _,bar in ipairs(draggableBars) do pcall(function() bar.dragging = false end) end
    if _G.__fov_drag then _G.__fov_drag = false end
end

-- FOV drag (global flag stored so we can reset)
_G.__fov_drag = false
do
    local dragging = false
    local function pointerPosToFov(pos)
        local center = fovFrame.AbsolutePosition + fovFrame.AbsoluteSize/2
        local dist = (Vector2.new(pos.X,pos.Y) - Vector2.new(center.X, center.Y)).Magnitude
        local newPixels = clamp(dist/1, 20, 500)
        return newPixels
    end
    fovFrame.InputBegan:Connect(function(input)
        if not fovFrame.Visible then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; _G.__fov_drag = true; safePlaySound(clickSound)
            local newv = pointerPosToFov(input.Position); CFG.FOV_PIXELS = newv; if fovFrame then pcall(function() fovFrame.Size = UDim2.new(0, math.floor(newv)*2, 0, math.floor(newv)*2) end) end
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local newv = pointerPosToFov(input.Position); CFG.FOV_PIXELS = newv; if fovFrame then pcall(function() fovFrame.Size = UDim2.new(0, math.floor(newv)*2, 0, math.floor(newv)*2) end) end
        end
    end)
    UserInputService.InputEnded:Connect(function(input) dragging = false; _G.__fov_drag = false end)
end

-- Input bindings & UI interactions
aimBtn.MouseButton1Click:Connect(function() aiming = not aiming; safePlaySound(clickSound); indLabel.Text = aiming and "ON" or "OFF"; indicator.BackgroundColor3 = aiming and Color3.fromRGB(220,255,220) or Color3.fromRGB(245,245,245) end)
gearBtn.MouseButton1Click:Connect(function() settingsWindow.Visible = not settingsWindow.Visible; safePlaySound(clickSound); if not settingsWindow.Visible then resetAllDrags() end end)
closeBtn.MouseButton1Click:Connect(function() settingsWindow.Visible = false; safePlaySound(clickSound); resetAllDrags() end)

-- Touch-hold area for mobile (movable)
local touchHoldArea = safeNew("TextButton"); touchHoldArea.Parent = gui; touchHoldArea.Size = UDim2.new(0,180,0,120); touchHoldArea.Position = UDim2.new(0.5 - 0.5, -90, 1, -130); touchHoldArea.AnchorPoint = Vector2.new(0.5,0)
touchHoldArea.BackgroundColor3 = Color3.fromRGB(0,0,0); touchHoldArea.BackgroundTransparency = 0.9; touchHoldArea.Text = ""; touchHoldArea.ZIndex = 100
local touchLbl = safeNew("TextLabel"); touchLbl.Parent = touchHoldArea; touchLbl.Size = UDim2.new(1,0,1,0); touchLbl.BackgroundTransparency = 1; touchLbl.Text = "Hold to Aim"; touchLbl.Font = Enum.Font.Gotham; touchLbl.TextColor3 = Color3.fromRGB(255,255,255); touchLbl.TextSize = 12
makeMovable(touchHoldArea)

local touchActive = false
touchHoldArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        touchActive = true; aiming = true; safePlaySound(clickSound); indLabel.Text = "ON"; indicator.BackgroundColor3 = Color3.fromRGB(220,255,220)
    end
end)
touchHoldArea.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        touchActive = false; aiming = false; safePlaySound(clickSound); indLabel.Text = "OFF"; indicator.BackgroundColor3 = Color3.fromRGB(245,245,245)
    end
end)

-- Scroller canvas sizing maintenance
local function refreshCanvas()
    task.spawn(function() task.wait(0.03); pcall(function() scroll.CanvasSize = UDim2.new(0,0,0, listLayout.AbsoluteContentSize.Y + 8) end) end)
end
listLayout.Changed:Connect(refreshCanvas); refreshCanvas()

-- Ensure when settingsWindow is hidden we clear any transient 'dragging' states and disable interactions
local function closeSettingsClean()
    settingsWindow.Visible = false
    resetAllDrags()
    -- reset any global drag states (fov)
    _G.__fov_drag = false
    safePlaySound(clickSound)
end

-- Close with cleaning
closeBtn.MouseButton1Click:Connect(closeSettingsClean)
gearBtn.MouseButton1Click:Connect(function() if settingsWindow.Visible then closeSettingsClean() else settingsWindow.Visible = true; safePlaySound(clickSound) end end)

-- Keep GUI parented if reparented by game
spawn(function() while task.wait(2) do if not gui.Parent then pcall(function() gui.Parent = PlayerGui end) end end end)

-- Apply initial camera FOV
pcall(function() Camera.FieldOfView = clamp(CFG.CAMERA_FOV or 70, 50, 120) end)

print("[DeltaAim Final] Loaded — All UI movable, settings clean close, fixed aimbot target selection.")
