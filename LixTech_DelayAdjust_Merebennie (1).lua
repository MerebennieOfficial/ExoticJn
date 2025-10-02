-- Executor-compatible local script
-- Lix Tech toggle + compact Delay Adjust UI (draggable, 30% transparent background)
-- Updated: moved +/- left, made symbols white, added watermark "Made by Merebennie on YouTube"
-- Watermark slides in/out, black background, white text, smooth edges, lasts 4.4s and copies discord link when clicked

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

---
-- Config / State

local firstSnapDelay = 0.30 -- adjustable (seconds)
local snapStep = 0.05
local snapMin = 0.05
local snapMax = 2.0

local Enabled = false
local debounce = false

-- Click sound (user-provided)
local CLICK_SOUND_ID = "rbxassetid://1127797184"
local DISCORD_LINK = "https://discord.gg/qZMqF4YRn7"

---
-- Helpers

local function protectGui(gui)
    if syn and syn.protect_gui then
        pcall(function() syn.protect_gui(gui) end)
    end
end

local function clamp(val, a, b)
    if val < a then return a end
    if val > b then return b end
    return val
end

local function formatDelay(v)
    local s = string.format("%.2f", v)
    s = s:gsub("(%..-)0+$", "%1")
    s = s:gsub("%.$", "")
    return s .. "s"
end

local function playClick(parent)
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = CLICK_SOUND_ID
        s.Volume = 0.7
        s.Parent = parent or workspace
        s:Play()
        Debris:AddItem(s, 2)
    end)
end

local function makePressAnimation(target, scaleDown, downTime, upTime)
    return function()
        pcall(function()
            local origSize = target.Size
            local origPos = target.Position
            local function scaled(ud, scale)
                local xs = ud.X.Scale * scale
                local xo = math.floor(ud.X.Offset * scale + 0.5)
                local ys = ud.Y.Scale * scale
                local yo = math.floor(ud.Y.Offset * scale + 0.5)
                return UDim2.new(xs, xo, ys, yo)
            end
            local newSize = scaled(origSize, scaleDown)
            local xoff = origPos.X.Offset + math.floor((origSize.X.Offset - newSize.X.Offset)/2 + 0.5)
            local yoff = origPos.Y.Offset + math.floor((origSize.Y.Offset - newSize.Y.Offset)/2 + 0.5)
            local newPos = UDim2.new(origPos.X.Scale, xoff, origPos.Y.Scale, yoff)
            TweenService:Create(target, TweenInfo.new(downTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = newSize, Position = newPos}):Play()
            task.wait(downTime)
            TweenService:Create(target, TweenInfo.new(upTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = origSize, Position = origPos}):Play()
        end)
    end
end

---
-- Create Lix Tech GUI (Toggle) - unchanged & separate

local lixGui = Instance.new("ScreenGui")
lixGui.Name = "LixTechGui"
lixGui.ResetOnSpawn = false
lixGui.Parent = game:GetService("CoreGui")
protectGui(lixGui)

local LixBtn = Instance.new("TextButton")
LixBtn.Size = UDim2.new(0,150,0,36)
LixBtn.Position = UDim2.new(0,18,0,180)
LixBtn.BackgroundColor3 = Color3.fromRGB(8,8,8)
LixBtn.BorderSizePixel = 0
LixBtn.Text = ""
LixBtn.Parent = lixGui
LixBtn.Active = true
LixBtn.AutoButtonColor = false
LixBtn.ZIndex = 5

local LixStroke = Instance.new("UIStroke")
LixStroke.Parent = LixBtn
LixStroke.Color = Color3.new(0,0,0)
LixStroke.Thickness = 1
LixStroke.Transparency = 0

local LixCorner = Instance.new("UICorner")
LixCorner.Parent = LixBtn
LixCorner.CornerRadius = UDim.new(0,8)

local TextBgOuter = Instance.new("Frame")
TextBgOuter.Size = UDim2.new(0.86, 0, 0.72, 0)
TextBgOuter.Position = UDim2.new(0.07, 0, 0.14, 0)
TextBgOuter.BackgroundColor3 = Color3.fromRGB(0,0,0)
TextBgOuter.BorderSizePixel = 0
TextBgOuter.Parent = LixBtn
TextBgOuter.ZIndex = 6

local TextOuterCorner = Instance.new("UICorner")
TextOuterCorner.CornerRadius = UDim.new(0,6)
TextOuterCorner.Parent = TextBgOuter

local TextBgInner = Instance.new("Frame")
TextBgInner.Size = UDim2.new(1, -4, 1, -4)
TextBgInner.Position = UDim2.new(0,2,0,2)
TextBgInner.BackgroundColor3 = Color3.fromRGB(33,180,83)
TextBgInner.BorderSizePixel = 0
TextBgInner.Parent = TextBgOuter
TextBgInner.ZIndex = 7

local TextInnerCorner = Instance.new("UICorner")
TextInnerCorner.CornerRadius = UDim.new(0,5)
TextInnerCorner.Parent = TextBgInner

local TextAreaStroke = Instance.new("UIStroke")
TextAreaStroke.Parent = TextBgOuter
TextAreaStroke.Color = Color3.new(0,0,0)
TextAreaStroke.Thickness = 1
TextAreaStroke.Transparency = 0

local LixText = Instance.new("TextLabel")
LixText.Size = UDim2.new(1, 0, 1, 0)
LixText.BackgroundTransparency = 1
LixText.Text = "Lix Tech: OFF"
LixText.Font = Enum.Font.GothamBold
LixText.TextSize = 18
LixText.TextColor3 = Color3.fromRGB(255,255,255)
LixText.TextStrokeColor3 = Color3.fromRGB(0,0,0)
LixText.TextStrokeTransparency = 0
LixText.Parent = TextBgInner
LixText.ZIndex = 8
LixText.TextXAlignment = Enum.TextXAlignment.Center
LixText.TextYAlignment = Enum.TextYAlignment.Center

local LixSound = Instance.new("Sound")
LixSound.SoundId = CLICK_SOUND_ID
LixSound.Volume = 0.7
LixSound.Parent = LixBtn

local LixPress = makePressAnimation(LixBtn, 0.96, 0.06, 0.12)

-- Lix drag (unchanged)
do
    local dragging = false
    local dragInput, dragStart, startPos
    LixBtn.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = LixBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    LixBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and dragInput and input == dragInput then
            local delta = input.Position - dragStart
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y
            local cam = workspace.CurrentCamera
            local vx = (cam and cam.ViewportSize.X) or 1920
            local vy = (cam and cam.ViewportSize.Y) or 1080
            local clampedX = math.clamp(newX, 0, math.max(0, vx - LixBtn.AbsoluteSize.X))
            local clampedY = math.clamp(newY, 0, math.max(0, vy - LixBtn.AbsoluteSize.Y))
            LixBtn.Position = UDim2.new(startPos.X.Scale, clampedX, startPos.Y.Scale, clampedY)
        end
    end)
end

LixBtn.MouseButton1Click:Connect(function()
    LixPress()
    playClick(LixBtn)
    Enabled = not Enabled
    LixText.Text = Enabled and "Lix Tech: ON" or "Lix Tech: OFF"
end)


---
-- Create Delay Adjust UI (smaller, draggable via top grip, 30% transparent)

local adjGui = Instance.new("ScreenGui")
adjGui.Name = "LixAdjustGui"
adjGui.ResetOnSpawn = false
adjGui.Parent = game:GetService("CoreGui")
protectGui(adjGui)

local AdjFrame = Instance.new("Frame")
AdjFrame.Size = UDim2.new(0,160,0,64) -- smaller
AdjFrame.Position = UDim2.new(0,18,0,230)
AdjFrame.BackgroundColor3 = Color3.fromRGB(12,12,12)
AdjFrame.BackgroundTransparency = 0.30 -- 30% transparent
AdjFrame.BorderSizePixel = 0
AdjFrame.Parent = adjGui
AdjFrame.ZIndex = 5

local AdjCorner = Instance.new("UICorner")
AdjCorner.Parent = AdjFrame
AdjCorner.CornerRadius = UDim.new(0,8)

local AdjStroke = Instance.new("UIStroke")
AdjStroke.Parent = AdjFrame
AdjStroke.Color = Color3.new(0,0,0)
AdjStroke.Thickness = 1
AdjStroke.Transparency = 0

-- Drag handle (top area) so buttons remain clickable
local DragGrip = Instance.new("Frame")
DragGrip.Name = "DragGrip"
DragGrip.Size = UDim2.new(1, 0, 0, 20)
DragGrip.Position = UDim2.new(0, 0, 0, 0)
DragGrip.BackgroundTransparency = 1
DragGrip.BorderSizePixel = 0
DragGrip.Parent = AdjFrame
DragGrip.ZIndex = 6

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -12, 0, 18)
Title.Position = UDim2.new(0,6,0,2)
Title.BackgroundTransparency = 1
Title.Text = "Delay Adjust"
Title.Font = Enum.Font.GothamSemibold
Title.TextSize = 13
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Parent = AdjFrame
Title.ZIndex = 7
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Value display (green inner, black outer)
local ValueOuter = Instance.new("Frame")
ValueOuter.Size = UDim2.new(0.56, 0, 0, 24)
ValueOuter.Position = UDim2.new(0.06, 0, 0, 22)
ValueOuter.BackgroundColor3 = Color3.fromRGB(0,0,0)
ValueOuter.Parent = AdjFrame
ValueOuter.ZIndex = 6

local ValueOuterCorner = Instance.new("UICorner")
ValueOuterCorner.CornerRadius = UDim.new(0,6)
ValueOuterCorner.Parent = ValueOuter

local ValueInner = Instance.new("Frame")
ValueInner.Size = UDim2.new(1, -4, 1, -4)
ValueInner.Position = UDim2.new(0,2,0,2)
ValueInner.BackgroundColor3 = Color3.fromRGB(33,180,83)
ValueInner.Parent = ValueOuter
ValueInner.ZIndex = 7

local ValueLabel = Instance.new("TextLabel")
ValueLabel.Size = UDim2.new(1, 0, 1, 0)
ValueLabel.BackgroundTransparency = 1
ValueLabel.Text = formatDelay(firstSnapDelay)
ValueLabel.Font = Enum.Font.GothamBold
ValueLabel.TextSize = 14
ValueLabel.TextColor3 = Color3.fromRGB(255,255,255)
ValueLabel.TextStrokeTransparency = 0
ValueLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
ValueLabel.Parent = ValueInner
ValueLabel.ZIndex = 8
ValueLabel.TextXAlignment = Enum.TextXAlignment.Center
ValueLabel.TextYAlignment = Enum.TextYAlignment.Center

-- Create circular +/- buttons (moved a bit left, white symbols)
local function makeCircleButton(parent, xPos, symbol)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,28,0,28)
    btn.Position = UDim2.new(xPos, 0, 0, 22)
    btn.BackgroundColor3 = Color3.fromRGB(33,180,83)
    btn.BorderSizePixel = 0
    btn.Text = symbol
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.TextColor3 = Color3.fromRGB(255,255,255) -- white
    btn.Parent = parent
    btn.ZIndex = 6

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Parent = btn
    stroke.Color = Color3.new(0,0,0)
    stroke.Thickness = 1
    stroke.Transparency = 0

    return btn

end

-- moved x positions slightly left so they fit inside frame
local MinusBtn = makeCircleButton(AdjFrame, 0.62, "−")
local PlusBtn  = makeCircleButton(AdjFrame, 0.80, "+")

-- Add press & sound behavior to +/- buttons
local function attachPressAndSound(btn)
    local press = makePressAnimation(btn, 0.86, 0.06, 0.10)
    btn.MouseButton1Down:Connect(function()
        press()
        playClick(btn)
    end)
end

attachPressAndSound(MinusBtn)
attachPressAndSound(PlusBtn)

-- Adjust logic
local function updateValueDisplay()
    ValueLabel.Text = formatDelay(firstSnapDelay)
end

MinusBtn.MouseButton1Click:Connect(function()
    firstSnapDelay = clamp(math.floor((firstSnapDelay - snapStep) * 100 + 0.5)/100, snapMin, snapMax)
    updateValueDisplay()
end)

PlusBtn.MouseButton1Click:Connect(function()
    firstSnapDelay = clamp(math.floor((firstSnapDelay + snapStep) * 100 + 0.5)/100, snapMin, snapMax)
    updateValueDisplay()
end)

-- Drag logic for AdjFrame using the DragGrip (so buttons remain clickable)
do
    local dragging = false
    local dragInput, dragStart, startPos
    local function startDrag(input)
        dragging = true
        dragStart = input.Position
        startPos = AdjFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end

    DragGrip.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startDrag(input)
            dragInput = input
        end
    end)

    DragGrip.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragInput and dragging and input == dragInput then
            local delta = input.Position - dragStart
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y
            local cam = workspace.CurrentCamera
            local vx = (cam and cam.ViewportSize.X) or 1920
            local vy = (cam and cam.ViewportSize.Y) or 1080
            local clampedX = math.clamp(newX, 0, math.max(0, vx - AdjFrame.AbsoluteSize.X))
            local clampedY = math.clamp(newY, 0, math.max(0, vy - AdjFrame.AbsoluteSize.Y))
            AdjFrame.Position = UDim2.new(startPos.X.Scale, clampedX, startPos.Y.Scale, clampedY)
        end
    end)

end

---
-- Utility: safe getnilinstances() wrapper (works in common executors)

local function getNil(name,class)
    if not getnilinstances then return nil end
    for _,v in pairs(getnilinstances()) do
        if v and v.ClassName == class and v.Name == name then
            return v
        end
    end
    return nil
end

---
-- Animation watcher logic (uses firstSnapDelay)

local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")

local function saveHumanoidSettings(h)
    if not h then return {WalkSpeed = 16, JumpPower = 50, PlatformStand = false, AutoRotate = true} end
    return { WalkSpeed = h.WalkSpeed, JumpPower = h.JumpPower, PlatformStand = h.PlatformStand, AutoRotate = h.AutoRotate }
end

local origSettings = saveHumanoidSettings(humanoid)

local function detectAnim(track)
    if not Enabled or debounce then return end
    if not track or not track.Animation then return end

    local ok, id = pcall(function()
        local s = track.Animation.AnimationId or ""
        return tonumber(s:match("%d+"))
    end)
    if not ok or not id then return end

    if id == 13379003796 or id == 10503381238 then
        debounce = true
        humanoid = (char and char:FindFirstChildOfClass("Humanoid")) or humanoid
        hrp = (char and char:FindFirstChild("HumanoidRootPart")) or hrp

        local beforeSettings = saveHumanoidSettings(humanoid)

        task.wait(firstSnapDelay) -- adjustable delay

        local args1 = {
            [1] = {
                ["Dash"] = Enum.KeyCode.W,
                ["Key"] = Enum.KeyCode.Q,
                ["Goal"] = "KeyPress"
            }
        }
        if char and char:FindFirstChild("Communicate") then
            pcall(function() char.Communicate:FireServer(table.unpack(args1)) end)
        end

        local bv = getNil("moveme","BodyVelocity")
        local bvParent = nil
        if bv then
            bvParent = bv.Parent
            pcall(function() bv.Parent = nil end)
        end

        local args2 = {
            [1] = {
                ["Goal"] = "delete bv",
                ["BV"] = bv
            }
        }
        if char and char:FindFirstChild("Communicate") then
            pcall(function() char.Communicate:FireServer(table.unpack(args2)) end)
        end

        task.wait(0.3)

        if hrp then
            pcall(function()
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(180), 0)
            end)
        end

        if bv and bv.Parent == nil and bvParent then
            if bv and bv.Parent == nil then
                pcall(function() bv.Parent = bvParent end)
            end
        end

        if humanoid then
            pcall(function()
                humanoid.WalkSpeed = beforeSettings.WalkSpeed or origSettings.WalkSpeed or 16
                humanoid.JumpPower = beforeSettings.JumpPower or origSettings.JumpPower or 50
                humanoid.PlatformStand = beforeSettings.PlatformStand or origSettings.PlatformStand or false
                humanoid.AutoRotate = beforeSettings.AutoRotate or origSettings.AutoRotate or true
            end)
        end

        task.wait(0.4)
        hrp = (char and char:FindFirstChild("HumanoidRootPart")) or hrp
        if hrp then
            pcall(function()
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(180), 0)
            end)
        end

        task.wait(0.15)
        debounce = false
    end

end

local function attachToCharacter(c)
    char = c
    humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
    hrp = char:FindFirstChild("HumanoidRootPart")
    origSettings = saveHumanoidSettings(humanoid)
    if humanoid then
        humanoid.AnimationPlayed:Connect(detectAnim)
    end
end

if LocalPlayer.Character then
    attachToCharacter(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(newChar)
    task.wait(0.1)
    attachToCharacter(newChar)
end)

-- Safety: if UI is closed or disabled, disable script
lixGui.DescendantRemoving:Connect(function(desc)
    if desc == LixBtn then
        Enabled = false
    end
end)

adjGui.DescendantRemoving:Connect(function(desc)
    if desc == AdjFrame then
        -- nothing critical
    end
end)

-- small helper: try to set clipboard using common executor functions
local function trySetClipboard(text)
    local ok = false
    pcall(function()
        if setclipboard then setclipboard(text); ok = true; return end
    end)
    pcall(function()
        if syn and syn.set_clipboard then syn.set_clipboard(text); ok = true; return end
    end)
    pcall(function()
        if set_clipboard then set_clipboard(text); ok = true; return end
    end)
    pcall(function()
        if writeclipboard then writeclipboard(text); ok = true; return end
    end)
    return ok
end

-- small toast function
local function showToast(parent, text, dur)
    dur = dur or 1.8
    local toast = Instance.new("TextLabel")
    toast.Size = UDim2.new(0,180,0,28)
    toast.Position = UDim2.new(0.5, -90, 0, -40)
    toast.AnchorPoint = Vector2.new(0.5, 0)
    toast.BackgroundTransparency = 0
    toast.BackgroundColor3 = Color3.new(0,0,0)
    toast.TextColor3 = Color3.new(1,1,1)
    toast.Text = text
    toast.Font = Enum.Font.GothamBold
    toast.TextSize = 14
    toast.ZIndex = 1000
    local corner = Instance.new("UICorner", toast)
    corner.CornerRadius = UDim.new(0,6)
    toast.Parent = parent
    toast.TextWrapped = true
    toast.TextXAlignment = Enum.TextXAlignment.Center
    toast.TextYAlignment = Enum.TextYAlignment.Center
    task.spawn(function()
        task.wait(dur)
        pcall(function() toast:Destroy() end)
    end)
    return toast
end

-- Watermark: smooth edges, black bg, white text, slide in/out, clickable to copy link
local function showWatermarkOnce()
    -- create a button so it can be clicked
    local wm = Instance.new("TextButton")
    wm.Size = UDim2.new(0,280,0,40)
    -- start off-screen to the right
    wm.Position = UDim2.new(0.5, 420, 0.95, -10)
    wm.AnchorPoint = Vector2.new(0.5, 1)
    wm.BackgroundColor3 = Color3.new(0,0,0)
    wm.BackgroundTransparency = 0
    wm.AutoButtonColor = false
    wm.BorderSizePixel = 0
    wm.ZIndex = 100
    wm.Parent = adjGui

    local wmCorner = Instance.new("UICorner")
    wmCorner.CornerRadius = UDim.new(0,8)
    wmCorner.Parent = wm

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.98, 0, 0.5, 0)
    title.Position = UDim2.new(0.01, 0, 0, 2)
    title.BackgroundTransparency = 1
    title.Text = "Made by Merebennie on YouTube"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = wm
    title.ZIndex = 101

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(0.98, 0, 0.5, 0)
    desc.Position = UDim2.new(0.01, 0, 0.5, -2)
    desc.BackgroundTransparency = 1
    desc.Text = "Click me to join our discord server!"
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 12
    desc.TextColor3 = Color3.fromRGB(255,255,255)
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = wm
    desc.ZIndex = 101

    -- slide in
    local inPos = UDim2.new(0.5, 0, 0.95, -10)
    local outPos = UDim2.new(0.5, 420, 0.95, -10)
    local tweenIn = TweenService:Create(wm, TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = inPos})
    local tweenOut = TweenService:Create(wm, TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = outPos})
    tweenIn:Play()

    local displayed = true

    -- handle click
    wm.MouseButton1Click:Connect(function()
        playClick(wm)
        local ok = trySetClipboard(DISCORD_LINK)
        if ok then
            showToast(adjGui, "Successfully Copied", 1.8)
        else
            showToast(adjGui, "Copied to clipboard failed on this executor", 2.6)
        end
    end)

    -- keep for 4.4 seconds (after tween in), then slide out and destroy
    task.spawn(function()
        task.wait(0.30 + 4.4)
        if displayed then
            tweenOut:Play()
            task.wait(0.32)
            pcall(function() wm:Destroy() end)
            displayed = false
        end
    end)

    return wm
end

-- expose the watermark via a small clickable watermark trigger on the AdjFrame title (optional)
Title.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        showWatermarkOnce()
    end
end)

-- also show watermark once at start (uncomment if you want it to appear automatically)
-- task.spawn(showWatermarkOnce)

print("[Script] Lix Tech + Compact Delay Adjust loaded.")
