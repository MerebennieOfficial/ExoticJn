
-- Delta Aimlock (V2) - Full improved version by Merebennie
-- For Delta Mobile Executor (local Lua only)
-- Features:
--  - Compact main UI (100x80) with indicator
--  - Fully redesigned settings panel (scrollable)
--  - Functional draggable sliders for many settings (yaw, pitch, cooldown, FOV, camera FOV, smoothing)
--  - +/- buttons fixed and play sound
--  - UI outlines, gradients, rounded corners
--  - FOV ring draggable to adjust FOV size
--  - Sound plays on every click/interaction
--  - Improved aim selection, prediction, and smoothing preserved from previous version
--  - Clean, single-file script ready for Delta injection

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

local function safePlaySound(snd)
    pcall(function() if snd and snd.PlaybackState ~= Enum.PlaybackState.Playing then snd:Play() end end)
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
    AIM_MODE = "Smooth",
    SMOOTHING = 8.0,
    USE_CAM_HEIGHT = true,
    CAM_HEIGHT = 2,
    SCREEN_TILT = -5,
    SWITCH_SENSITIVITY_YAW = 0.006,
    SWITCH_SENSITIVITY_PITCH = 0.02,
    SWITCH_COOLDOWN = 0.08,
    TARGET_PRIORITY = "Angle",
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
    CAMERA_FOV = 70,
}

local aiming = false
local targetPart = nil
local targetHRP = nil
local lastYaw, lastPitch = nil, nil
local lastSwitchTick = 0
local lastRenderTick = tick()

local clickSound = newSound(CFG.TOGGLE_SOUND_ID)

-- GUI root
local gui = safeNew("ScreenGui")
if not gui then return end
gui.Name = "DeltaAim_UI_v2"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = PlayerGui end)

LocalPlayer.CharacterAdded:Connect(function()
    if not gui.Parent then pcall(function() gui.Parent = PlayerGui end) end
end)

-- Utility: add gradient and outline to UI element
local function styleElement(inst, gradientEnabled)
    if not inst then return end
    pcall(function()
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = Color3.fromRGB(180,180,180)
        stroke.Thickness = 1
        stroke.Parent = inst
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0,8)
        corner.Parent = inst
        if gradientEnabled then
            local grad = Instance.new("UIGradient")
            grad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(235,235,235))
            }
            grad.Rotation = 90
            grad.Parent = inst
        end
    end)
end

-- WATERMARK (top-left, pixel font, transparent)
local watermark = safeNew("TextLabel")
watermark.Name = "Watermark"
watermark.Parent = gui
watermark.AnchorPoint = Vector2.new(0,0)
watermark.Position = UDim2.new(0,8,0,6)
watermark.Size = UDim2.new(0,180,0,18)
watermark.BackgroundTransparency = 1
watermark.Text = "Made by Merebennie"
watermark.Font = Enum.Font.Arcade
watermark.TextSize = 14
watermark.TextColor3 = Color3.fromRGB(0,0,0)
watermark.TextStrokeColor3 = Color3.new(1,1,1)
watermark.TextStrokeTransparency = 0.6
watermark.ZIndex = 100

-- COMPACT MAIN UI (100x80)
local mainFrame = safeNew("Frame"); mainFrame.Parent = gui
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0,100,0,80)
mainFrame.Position = UDim2.new(0.02,0,0.88,0) -- bottom-left small
mainFrame.AnchorPoint = Vector2.new(0,0)
mainFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
styleElement(mainFrame, true)

-- Title small (hidden on compact, but keep for clarity)
local smallTitle = safeNew("TextLabel"); smallTitle.Parent = mainFrame
smallTitle.Size = UDim2.new(1,0,0,18); smallTitle.Position = UDim2.new(0,0,0,4)
smallTitle.BackgroundTransparency = 1; smallTitle.Font = Enum.Font.GothamBold; smallTitle.TextSize = 12
smallTitle.TextColor3 = Color3.new(0,0,0); smallTitle.Text = "Merebennie Aim"; smallTitle.TextXAlignment = Enum.TextXAlignment.Center

-- Indicator (status circle)
local indicator = safeNew("Frame"); indicator.Parent = mainFrame
indicator.Size = UDim2.new(0,40,0,40); indicator.Position = UDim2.new(0.5,-20,0.32,0)
indicator.BackgroundColor3 = Color3.fromRGB(245,245,245)
Instance.new("UICorner", indicator).CornerRadius = UDim.new(1,0)
local indStroke = Instance.new("UIStroke", indicator); indStroke.Color = Color3.fromRGB(200,200,200); indStroke.Thickness = 1
local indLabel = safeNew("TextLabel"); indLabel.Parent = indicator; indLabel.Size = UDim2.new(1,1,1,0); indLabel.BackgroundTransparency = 1; indLabel.Text = "OFF"; indLabel.Font = Enum.Font.GothamBold; indLabel.TextSize = 14; indLabel.TextColor3 = Color3.fromRGB(0,0,0)

-- Quick aim circle button (also draggable)
local aimBtn = safeNew("TextButton"); aimBtn.Parent = mainFrame
aimBtn.Size = UDim2.new(0,24,0,24); aimBtn.Position = UDim2.new(0.12,0,0.65,0)
aimBtn.AnchorPoint = Vector2.new(0,0)
aimBtn.Text = "⦿"; aimBtn.Font = Enum.Font.GothamBold; aimBtn.TextSize = 14
aimBtn.TextColor3 = Color3.new(0,0,0); aimBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", aimBtn).CornerRadius = UDim.new(1,0)
local aimStroke = Instance.new("UIStroke", aimBtn); aimStroke.Color = Color3.fromRGB(180,180,180); aimStroke.Thickness = 1
local aimGrad = Instance.new("UIGradient", aimBtn); aimGrad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(240,240,240))

-- SETTINGS TOGGLER (small gear) on main frame
local gearBtn = safeNew("TextButton"); gearBtn.Parent = mainFrame
gearBtn.Size = UDim2.new(0,24,0,24); gearBtn.Position = UDim2.new(0.78,0,0.65,0); gearBtn.Text = "⚙"; gearBtn.Font = Enum.Font.GothamBold; gearBtn.TextSize = 14
gearBtn.TextColor3 = Color3.new(0,0,0); gearBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", gearBtn).CornerRadius = UDim.new(1,0)
local gearStroke = Instance.new("UIStroke", gearBtn); gearStroke.Color = Color3.fromRGB(180,180,180); gearStroke.Thickness = 1
local gearGrad = Instance.new("UIGradient", gearBtn); gearGrad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(240,240,240))

-- FOV visual (circle) center screen with drag to change size
local fovFrame = safeNew("Frame"); fovFrame.Parent = gui
fovFrame.Name = "FOVFrame"; fovFrame.AnchorPoint = Vector2.new(0.5,0.5); fovFrame.Position = UDim2.new(0.5,0,0.5,0)
fovFrame.Size = UDim2.new(0, CFG.FOV_PIXELS*2, 0, CFG.FOV_PIXELS*2); fovFrame.BackgroundTransparency = 1; fovFrame.Visible = CFG.SHOW_FOV; fovFrame.ZIndex = 2
local fovInner = safeNew("Frame"); fovInner.Parent = fovFrame; fovInner.Size = UDim2.new(1,0,1,0); fovInner.BackgroundTransparency = 1
Instance.new("UICorner", fovInner).CornerRadius = UDim.new(1,0)
local innerStroke = Instance.new("UIStroke", fovInner); innerStroke.Thickness = CFG.FOV_THICKNESS; innerStroke.Color = CFG.FOV_COLOR; innerStroke.Transparency = 0.55; innerStroke.LineJoinMode = Enum.LineJoinMode.Round

-- SETTINGS PANEL (scrollable)
local settingsWindow = safeNew("Frame"); settingsWindow.Parent = gui
settingsWindow.Size = UDim2.new(0,360,0,420); settingsWindow.Position = UDim2.new(0.5,-180,0.06,0)
settingsWindow.AnchorPoint = Vector2.new(0,0)
settingsWindow.BackgroundColor3 = Color3.fromRGB(255,255,255)
styleElement(settingsWindow, true)

local settingsTitle = safeNew("TextLabel"); settingsTitle.Parent = settingsWindow
settingsTitle.Size = UDim2.new(1,0,0,28); settingsTitle.Position = UDim2.new(0,0,0,6)
settingsTitle.BackgroundTransparency = 1; settingsTitle.Font = Enum.Font.GothamBold; settingsTitle.TextSize = 16
settingsTitle.TextColor3 = Color3.new(0,0,0); settingsTitle.Text = "Aim Settings"; settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
settingsTitle.TextTransparency = 0

local closeBtn = safeNew("TextButton"); closeBtn.Parent = settingsWindow
closeBtn.Size = UDim2.new(0,28,0,24); closeBtn.Position = UDim2.new(1,-36,0,6); closeBtn.Text = "✕"; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 16
closeBtn.BackgroundColor3 = Color3.fromRGB(247,247,247); Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)
Instance.new("UIStroke", closeBtn).Color = Color3.fromRGB(200,200,200)

-- Scrolling frame to contain many settings
local scroll = safeNew("ScrollingFrame"); scroll.Parent = settingsWindow
scroll.Size = UDim2.new(1,-24,1,-48); scroll.Position = UDim2.new(0,12,0,36)
scroll.CanvasSize = UDim2.new(0,0)
scroll.ScrollBarThickness = 6
scroll.BackgroundTransparency = 1
local listLayout = Instance.new("UIListLayout", scroll); listLayout.Padding = UDim.new(0,8); listLayout.SortOrder = Enum.SortOrder.LayoutOrder
local contentPadding = Instance.new("UIPadding", scroll); contentPadding.PaddingTop = UDim.new(0,6); contentPadding.PaddingBottom = UDim.new(0,12)

-- Helper: make label row
local function makeRowLabel(text)
    local row = safeNew("Frame"); row.Parent = scroll; row.Size = UDim2.new(1,0,0,28); row.BackgroundTransparency = 1
    local lbl = safeNew("TextLabel"); lbl.Parent = row; lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 14
    lbl.Text = text; lbl.TextColor3 = Color3.new(0,0,0); lbl.TextXAlignment = Enum.TextXAlignment.Left
    return row, lbl
end

-- Factory: button with outline & gradient that plays sound
local function makeButton(text, width)
    local b = safeNew("TextButton"); b.Parent = scroll; b.Size = UDim2.new(1,0,0,34); b.BackgroundColor3 = Color3.fromRGB(250,250,250);
    b.Font = Enum.Font.Gotham; b.TextSize = 14; b.Text = text; b.TextColor3 = Color3.new(0,0,0)
    styleElement(b, true)
    b.MouseButton1Click:Connect(function() safePlaySound(clickSound) end)
    return b
end

-- Factory: numeric +/- row (keeps for some settings, fixed)
local function makePlusMinus(label, min, max, step, default, onChange)
    local row = safeNew("Frame"); row.Parent = scroll; row.Size = UDim2.new(1,0,0,40); row.BackgroundTransparency = 1
    local lbl = safeNew("TextLabel"); lbl.Parent = row; lbl.Size = UDim2.new(0.62,0,1,0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextColor3 = Color3.new(0,0,0)
    local minus = safeNew("TextButton"); minus.Parent = row; minus.Size = UDim2.new(0,44,0,28); minus.Position = UDim2.new(0.66,6,0.5,-14); minus.Text = "-"; minus.Font = Enum.Font.GothamBold; minus.TextSize = 20; minus.BackgroundColor3 = Color3.fromRGB(245,245,245)
    local plus = safeNew("TextButton"); plus.Parent = row; plus.Size = UDim2.new(0,44,0,28); plus.Position = UDim2.new(0.86,6,0.5,-14); plus.Text = "+"; plus.Font = Enum.Font.GothamBold; plus.TextSize = 20; plus.BackgroundColor3 = Color3.fromRGB(245,245,245)
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0,6)
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", minus).Color = Color3.fromRGB(200,200,200)
    Instance.new("UIStroke", plus).Color = Color3.fromRGB(200,200,200)
    local value = default
    local function set(v)
        value = math.clamp(v, min, max)
        lbl.Text = label .. ": " .. (math.floor(value*100)/100)
        pcall(onChange, value)
    end
    minus.MouseButton1Click:Connect(function()
        set(value - step)
        safePlaySound(clickSound)
    end)
    plus.MouseButton1Click:Connect(function()
        set(value + step)
        safePlaySound(clickSound)
    end)
    set(default)
    return row, lbl
end

-- Factory: draggable slider bar (better UX for mobile)
local function makeDraggableBar(label, min, max, default, onChange)
    local row = safeNew("Frame"); row.Parent = scroll; row.Size = UDim2.new(1,0,0,48); row.BackgroundTransparency = 1
    local lbl = safeNew("TextLabel"); lbl.Parent = row; lbl.Size = UDim2.new(1,0,0,18); lbl.Position = UDim2.new(0,0,0,0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextColor3 = Color3.new(0,0,0)
    local barBg = safeNew("Frame"); barBg.Parent = row; barBg.Size = UDim2.new(1,0,0,16); barBg.Position = UDim2.new(0,0,0,24); barBg.BackgroundColor3 = Color3.fromRGB(245,245,245)
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0,6)
    local stroke = Instance.new("UIStroke", barBg); stroke.Color = Color3.fromRGB(200,200,200)
    local fill = safeNew("Frame"); fill.Parent = barBg; fill.Size = UDim2.new(0.5,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(220,220,220)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,6)
    local handle = safeNew("Frame"); handle.Parent = fill; handle.Size = UDim2.new(0,16,1,0); handle.Position = UDim2.new(1,-8,0,0); handle.BackgroundColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", handle).CornerRadius = UDim.new(1,0)
    Instance.new("UIStroke", handle).Color = Color3.fromRGB(180,180,180)
    local dragging = false
    local sizeVal = default
    local function updateFromSize(v)
        sizeVal = math.clamp(v, min, max)
        local pct = (sizeVal - min) / math.max(1e-6, (max - min))
        fill.Size = UDim2.new(pct,0,1,0)
        lbl.Text = label .. ": " .. (math.floor(sizeVal*100)/100)
        pcall(onChange, sizeVal)
    end
    -- Input handling
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            safePlaySound(clickSound)
        end
    end)
    handle.InputEnded:Connect(function(input) dragging = false end)
    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            safePlaySound(clickSound)
            -- set on direct bar touch
            local absx = input.Position.X
            local relative = math.clamp((absx - barBg.AbsolutePosition.X) / math.max(1, barBg.AbsoluteSize.X), 0, 1)
            local newv = min + relative * (max - min)
            updateFromSize(newv)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local absx = input.Position.X
            local relative = math.clamp((absx - barBg.AbsolutePosition.X) / math.max(1, barBg.AbsoluteSize.X), 0, 1)
            local newv = min + relative * (max - min)
            updateFromSize(newv)
        end
    end)
    UserInputService.InputEnded:Connect(function(input) if dragging then dragging = false end end)
    updateFromSize(default)
    return row, lbl, updateFromSize
end

-- Build settings controls (use draggable bars for sensitive controls)
local _, _ = makeRowLabel("General")
makeButton("Reset to Defaults").MouseButton1Click:Connect(function()
    safePlaySound(clickSound)
    -- reset some core settings
    CFG.SMOOTHING = 8; CFG.SWITCH_SENSITIVITY_YAW = 0.006; CFG.SWITCH_SENSITIVITY_PITCH = 0.02; CFG.SWITCH_COOLDOWN = 0.08
    CFG.FOV_PIXELS = 120; CFG.CAMERA_FOV = 70
    -- update UI reflects by applying camera FOV
    pcall(function() Camera.FieldOfView = math.clamp(CFG.CAMERA_FOV,50,120) end)
end)

local _, _ = makeRowLabel("Aim Behaviour")
local smoothingRow, smoothingLbl, smoothingSet = makeDraggableBar("Smoothing", 1, 30, CFG.SMOOTHING, function(v) CFG.SMOOTHING = v end)

local yawRow, yawLbl, yawSet = makeDraggableBar("Switch Sensitivity (yaw)", 0.001, 0.02, CFG.SWITCH_SENSITIVITY_YAW, function(v) CFG.SWITCH_SENSITIVITY_YAW = v end)
local pitchRow, pitchLbl, pitchSet = makeDraggableBar("Switch Sensitivity (pitch)", 0.005, 0.12, CFG.SWITCH_SENSITIVITY_PITCH, function(v) CFG.SWITCH_SENSITIVITY_PITCH = v end)
local cooldownRow, cooldownLbl, cooldownSet = makeDraggableBar("Switch Cooldown (s)", 0.02, 0.5, CFG.SWITCH_COOLDOWN, function(v) CFG.SWITCH_COOLDOWN = v end)

-- other settings (kept as +/- rows)
local _, _ = makeRowLabel("Prediction & FOV")
makePlusMinus("Bullet Speed", 200, 5000, 50, CFG.BULLET_SPEED, function(v) CFG.BULLET_SPEED = v end)
local predRow, predLbl = makePlusMinus("Prediction Mult", 0, 3, 0.05, CFG.PREDICT_MULT, function(v) CFG.PREDICT_MULT = v end)

-- Camera FOV draggable
local camFovRow, camFovLbl, camFovSet = makeDraggableBar("Camera FOV", 50, 120, CFG.CAMERA_FOV, function(v)
    CFG.CAMERA_FOV = v
    pcall(function() Camera.FieldOfView = math.clamp(v,50,120) end)
end)

-- FOV ring size draggable
local fovRow, fovLbl, fovSet = makeDraggableBar("FOV Ring Size (px)", 20, 400, CFG.FOV_PIXELS, function(v)
    CFG.FOV_PIXELS = v
    if fovFrame then
        pcall(function() fovFrame.Size = UDim2.new(0, math.floor(v)*2, 0, math.floor(v)*2) end)
    end
end)

-- Toggle rows
makeButton("Toggle Prediction (click to toggle)").MouseButton1Click:Connect(function()
    CFG.USE_PREDICTION = not CFG.USE_PREDICTION
    safePlaySound(clickSound)
end)
makeButton("Toggle Friend Filter (click to toggle)").MouseButton1Click:Connect(function()
    CFG.USE_FRIEND_FILTER = not CFG.USE_FRIEND_FILTER
    safePlaySound(clickSound)
end)

-- Apply dynamic canvas sizing for scrolling frame
local function refreshCanvas()
    task.spawn(function()
        task.wait(0.05)
        scroll.CanvasSize = UDim2.new(0,0,0, listLayout.AbsoluteContentSize.Y + 8)
    end)
end
listLayout.Changed:Connect(refreshCanvas)
refreshCanvas()

-- Close button behaviour
closeBtn.MouseButton1Click:Connect(function()
    safePlaySound(clickSound)
    settingsWindow.Visible = false
end)

-- Toggle settings visibility with gearBtn
gearBtn.MouseButton1Click:Connect(function()
    safePlaySound(clickSound)
    settingsWindow.Visible = not settingsWindow.Visible
end)

-- Aim button toggle
aimBtn.MouseButton1Click:Connect(function()
    aiming = not aiming
    safePlaySound(clickSound)
    indLabel.Text = aiming and "ON" or "OFF"
    indicator.BackgroundColor3 = aiming and Color3.fromRGB(230,255,230) or Color3.fromRGB(245,245,245)
end)

-- Ensure main indicator updates when toggled by other UI
local function updateIndicator()
    indLabel.Text = aiming and "ON" or "OFF"
    indicator.BackgroundColor3 = aiming and Color3.fromRGB(230,255,230) or Color3.fromRGB(245,245,245)
end

-- Make +/- and other buttons play sound on click (already wired in factories)
-- Also make all draggable bars play a sound when user interacts: handled in makeDraggableBar.

-- FOV drag handling: allow dragging on the ring to change FOV ring size
do
    local dragging = false
    local function pointerPosToFov(pos)
        local center = fovFrame.AbsolutePosition + fovFrame.AbsoluteSize/2
        local dist = (Vector2.new(pos.X,pos.Y) - Vector2.new(center.X, center.Y)).Magnitude
        local newPixels = math.clamp(dist/1, 20, 400)
        return newPixels
    end
    fovFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            safePlaySound(clickSound)
            local newv = pointerPosToFov(input.Position)
            CFG.FOV_PIXELS = newv
            if fovFrame then fovFrame.Size = UDim2.new(0, newv*2, 0, newv*2) end
            fovSet(newv)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            local newv = pointerPosToFov(input.Position)
            CFG.FOV_PIXELS = newv
            if fovFrame then fovFrame.Size = UDim2.new(0, newv*2, 0, newv*2) end
            fovSet(newv)
        end
    end)
    UserInputService.InputEnded:Connect(function(input) dragging = false end)
end

-- Core: ESP minimal (kept simple)
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

-- Prediction helper
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

local function isAirborne(hrp)
    if not hrp then return false end
    local vy = hrp.Velocity and hrp.Velocity.Y or 0
    return math.abs(vy) > 12
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
                        -- skip switching to airborne if configured
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

-- RenderStepped loop with improved switching logic using yaw/pitch from camera
RunService.RenderStepped:Connect(function()
    local now = tick()
    local dt = math.max(0.0001, now - lastRenderTick)
    lastRenderTick = now

    -- update fov visual
    if fovFrame then
        pcall(function()
            fovFrame.Position = UDim2.new(0.5,0,0.5,0)
            fovFrame.Size = UDim2.new(0, math.floor(CFG.FOV_PIXELS)*2, 0, math.floor(CFG.FOV_PIXELS)*2)
            innerStroke.Thickness = math.max(1, CFG.FOV_THICKNESS)
            innerStroke.Color = CFG.FOV_COLOR
        end)
    end

    -- yaw/pitch detection
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

-- Final: print ready
print("[DeltaAim V2] Loaded - Made by Merebennie")
