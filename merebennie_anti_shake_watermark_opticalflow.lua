-- Combined: Robust Anti-Shake (respawn-safe) + Watermark UI + Optical-Flow Camera Smoother
-- Paste into your executor (or LocalScript in an exec environment)
-- Filename: merebennie_anti_shake_watermark_opticalflow.lua

-- ======= Utilities & Services =======
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local function safePcall(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok and res or nil
end

-- ======= ANTI-SHAKE PART =======
local HOOKED = {}

local function tryHookEnv(scriptInstance)
    if not scriptInstance or not scriptInstance.Parent then return false end
    local senv = safePcall(getsenv, scriptInstance)
    if not senv then return false end

    local shared = senv.shared or senv
    local candidates = {}

    if shared.addshake and type(shared.addshake) == "function" then
        table.insert(candidates, {container = shared, name = "addshake"})
    end
    if senv.addshake and type(senv.addshake) == "function" then
        table.insert(candidates, {container = senv, name = "addshake"})
    end

    for _, entry in ipairs(candidates) do
        local container, name = entry.container, entry.name
        local marker = tostring(scriptInstance:GetFullName()) .. "|" .. tostring(name)
        if not HOOKED[marker] then
            local original = container[name]
            -- Try hookfunction first
            pcall(function()
                if type(original) == "function" and hookfunction then
                    hookfunction(original, function(...) return nil end)
                end
            end)
            -- fallback to direct overwrite
            pcall(function()
                container[name] = function(...) return nil end
            end)
            -- also replace any direct references in senv
            pcall(function()
                for k,v in pairs(senv) do
                    if v == original then
                        senv[k] = function(...) return nil end
                    end
                end
            end)
            HOOKED[marker] = true
            return true
        end
    end

    return false
end

local function scanContainer(container)
    if not container then return end
    if container:IsA("Model") and container:FindFirstChild("CharacterHandler") then
        pcall(tryHookEnv, container.CharacterHandler)
    end
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("LocalScript") or obj:IsA("ModuleScript") or obj:IsA("Script") then
            pcall(tryHookEnv, obj)
        end
    end
end

local function onCharacterAdded(char)
    if not char then return end
    scanContainer(char)
    local conn
    conn = char.DescendantAdded:Connect(function(desc)
        wait(0.05)
        pcall(tryHookEnv, desc)
    end)
    char.AncestryChanged:Connect(function()
        if not char:IsDescendantOf(game) and conn then
            conn:Disconnect()
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
    task.spawn(function() onCharacterAdded(LocalPlayer.Character) end)
end

-- Scan Player containers & hook new descendants
local function monitorContainer(container)
    if not container then return end
    scanContainer(container)
    container.DescendantAdded:Connect(function(desc)
        wait(0.05)
        pcall(tryHookEnv, desc)
    end)
end

monitorContainer(LocalPlayer)
if LocalPlayer:FindFirstChild("PlayerScripts") then monitorContainer(LocalPlayer.PlayerScripts) end
if LocalPlayer:FindFirstChild("PlayerGui") then monitorContainer(LocalPlayer.PlayerGui) end

task.spawn(function()
    while task.wait(1.0) do
        if not LocalPlayer or not LocalPlayer.Parent then break end
        if LocalPlayer.Character then scanContainer(LocalPlayer.Character) end
        scanContainer(LocalPlayer)
        if LocalPlayer:FindFirstChild("PlayerScripts") then scanContainer(LocalPlayer.PlayerScripts) end
        if LocalPlayer:FindFirstChild("PlayerGui") then scanContainer(LocalPlayer.PlayerGui) end
    end
end)

pcall(function()
    if rawget(_G, "addshake") then _G.addshake = function(...) return nil end end
end)

-- ======= WATERMARK UI PART =======
-- CONFIG (modify if desired)
local WATERMARK_NAME = "MerebennieWatermark"
local DEFAULT_TEXT = "Made by Merebennie  •  Discord: discord.gg/yourlink"
local SLIDE_TIME = 0.28
local HOLD_VISIBLE_SECONDS = 6

-- safe UI parent detection
local function getUIParent()
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui and typeof(hui) == "Instance" then return hui end
    end
    if syn and syn.protect_gui and game:GetService("CoreGui") then
        return game:GetService("CoreGui")
    end
    if game:GetService("CoreGui") then
        return game:GetService("CoreGui")
    end
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        return LocalPlayer:FindFirstChild("PlayerGui")
    end
    return nil
end

local function removeDuplicate(parent)
    local existing = parent:FindFirstChild(WATERMARK_NAME)
    if existing then existing:Destroy() end
end

local UIParent = getUIParent()
if not UIParent then
    warn("[Watermark] Could not find a UI parent. Watermark not created.")
else
    removeDuplicate(UIParent)
end

-- Build UI only if we have a parent
local screenGui, frame, bg, textLabel, copyBtn, statusLabel, fallbackBox
local Watermark = {} -- forward table

if UIParent then
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = WATERMARK_NAME
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = UIParent

    frame = Instance.new("Frame")
    frame.Name = "Frame"
    frame.Size = UDim2.new(0, 320, 0, 48)
    frame.AnchorPoint = Vector2.new(0, 1)
    frame.Position = UDim2.new(0, 12, 1, -12)
    frame.BackgroundTransparency = 1
    frame.Parent = screenGui

    bg = Instance.new("Frame")
    bg.Name = "BG"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.Position = UDim2.new(0, 0, 0, 0)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bg.BorderSizePixel = 0
    bg.BackgroundTransparency = 0.08
    bg.ClipsDescendants = true
    bg.Parent = frame

    local uicorner = Instance.new("UICorner")
    uicorner.CornerRadius = UDim.new(0, 10)
    uicorner.Parent = bg

    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.Size = UDim2.new(0, 6, 1, 0)
    accent.Position = UDim2.new(0, 0, 0, 0)
    accent.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    accent.BorderSizePixel = 0
    accent.Parent = bg

    local icon = Instance.new("Frame")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 34, 0, 34)
    icon.Position = UDim2.new(0, 12, 0.5, -17)
    icon.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    icon.BorderSizePixel = 0
    icon.Parent = bg
    local iconCorner = Instance.new("UICorner", icon)
    iconCorner.CornerRadius = UDim.new(1, 0)
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "IconLabel"
    iconLabel.Text = "M"
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.TextColor3 = Color3.fromRGB(220,220,220)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 16
    iconLabel.Parent = icon

    textLabel = Instance.new("TextLabel")
    textLabel.Name = "Text"
    textLabel.Text = DEFAULT_TEXT
    textLabel.Size = UDim2.new(1, -120, 1, 0)
    textLabel.Position = UDim2.new(0, 62, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 16
    textLabel.TextColor3 = Color3.fromRGB(230,230,230)
    textLabel.Parent = bg

    copyBtn = Instance.new("TextButton")
    copyBtn.Name = "CopyBtn"
    copyBtn.Size = UDim2.new(0, 88, 0, 34)
    copyBtn.Position = UDim2.new(1, -100, 0.5, -17)
    copyBtn.AnchorPoint = Vector2.new(0, 0)
    copyBtn.Text = "Copy Discord"
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 14
    copyBtn.TextColor3 = Color3.fromRGB(230,230,230)
    copyBtn.BackgroundColor3 = Color3.fromRGB(55,55,55)
    copyBtn.BorderSizePixel = 0
    copyBtn.Parent = bg
    local copyCorner = Instance.new("UICorner", copyBtn)
    copyCorner.CornerRadius = UDim.new(0, 8)

    statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(0, 0, 0, 18)
    statusLabel.Position = UDim2.new(1, -100, 0, 6)
    statusLabel.AnchorPoint = Vector2.new(0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.TextColor3 = Color3.fromRGB(160,160,160)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = bg

    fallbackBox = Instance.new("TextBox")
    fallbackBox.Name = "FallbackBox"
    fallbackBox.Size = UDim2.new(0, 200, 0, 28)
    fallbackBox.Position = UDim2.new(1, -320, 0.5, -14)
    fallbackBox.AnchorPoint = Vector2.new(0, 0.5)
    fallbackBox.Visible = false
    fallbackBox.Text = ""
    fallbackBox.ClearTextOnFocus = false
    fallbackBox.BackgroundTransparency = 0.12
    fallbackBox.BorderSizePixel = 0
    fallbackBox.Font = Enum.Font.Gotham
    fallbackBox.TextSize = 14
    fallbackBox.TextColor3 = Color3.fromRGB(230,230,230)
    fallbackBox.Parent = bg
    local fbCorner = Instance.new("UICorner", fallbackBox)
    fbCorner.CornerRadius = UDim.new(0, 6)

    screenGui.Parent = UIParent
    screenGui.ResetOnSpawn = false
end

-- Clipboard helpers
local function trySetClipboard(text)
    if type(setclipboard) == "function" then
        local ok, err = pcall(setclipboard, text)
        return ok, (ok and "Copied to clipboard." or ("setclipboard failed: "..tostring(err)))
    end
    if type(clipboard) == "function" then
        local ok, err = pcall(clipboard, text)
        return ok, (ok and "Copied to clipboard." or ("clipboard failed: "..tostring(err)))
    end
    if type(set_clipboard) == "function" then
        local ok, err = pcall(set_clipboard, text)
        return ok, (ok and "Copied to clipboard." or ("set_clipboard failed: "..tostring(err)))
    end
    if syn and syn.write_clipboard then
        local ok, err = pcall(syn.write_clipboard, text)
        return ok, (ok and "Copied to clipboard." or ("syn.write_clipboard failed: "..tostring(err)))
    end
    return false, "No clipboard API available, fallback provided."
end

-- Status helper
local function showStatus(msg, time)
    if not statusLabel then return end
    statusLabel.Text = msg or ""
    statusLabel.Size = UDim2.new(0, 88, 0, 18)
    statusLabel.Visible = true
    task.delay(time or 2, function()
        if statusLabel then
            statusLabel.Text = ""
            statusLabel.Visible = false
        end
    end)
end

-- slide/tween helpers
local tweenInfo = TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local shown = false
local autoHideTimer = nil

local function scheduleAutoHide()
    if HOLD_VISIBLE_SECONDS > 0 then
        if autoHideTimer then
            pcall(function() autoHideTimer:Cancel() end)
            autoHideTimer = nil
        end
        autoHideTimer = task.delay(HOLD_VISIBLE_SECONDS, function()
            pcall(function() Watermark.Hide() end)
        end)
    end
end

local function slideIn()
    if not frame or shown then return end
    shown = true
    -- ensure start off-screen left
    frame.Position = UDim2.new(0, -frame.AbsoluteSize.X - 20, 1, -12)
    frame.Visible = true
    local target = UDim2.new(0, 12, 1, -12)
    TweenService:Create(frame, tweenInfo, {Position = target}):Play()
    if bg then
        bg.BackgroundTransparency = 1
        TweenService:Create(bg, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.08}):Play()
    end
    scheduleAutoHide()
end

local function slideOut()
    if not frame or not shown then return end
    shown = false
    local off = UDim2.new(0, -frame.AbsoluteSize.X - 20, 1, -12)
    local t = TweenService:Create(frame, tweenInfo, {Position = off})
    t:Play()
    if bg then
        TweenService:Create(bg, TweenInfo.new(SLIDE_TIME*0.9, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
    end
    t.Completed:Wait()
    if not shown and frame then frame.Visible = false end
end

-- Watermark API (if UI exists)
function Watermark.Show()
    slideIn()
end
function Watermark.Hide()
    slideOut()
end
function Watermark.Toggle()
    if shown then Watermark.Hide() else Watermark.Show() end
end
function Watermark.SetText(str)
    if not textLabel or typeof(str) ~= "string" then return end
    textLabel.Text = str
end
function Watermark.CopyDiscord(link)
    if not textLabel then return false, "no ui" end
    local tocopy = nil
    if typeof(link) == "string" and #link > 0 then
        tocopy = link
    else
        local s = textLabel.Text or ""
        local found = string.match(s, "(discord%.gg/%S+)") or string.match(s, "(https?://discord%.gg/%S+)") or string.match(s, "(discordapp%.com/invite/%S+)")
        tocopy = found or s
    end

    if not tocopy or #tostring(tocopy) < 1 then
        showStatus("Nothing to copy.", 2)
        return false, "nothing to copy"
    end

    local ok, msg = trySetClipboard(tocopy)
    if ok then
        showStatus("Copied!", 2)
        return true, msg
    else
        if fallbackBox then
            fallbackBox.Visible = true
            fallbackBox.Text = tostring(tocopy)
            pcall(function() fallbackBox:CaptureFocus() end)
            showStatus("Tap the box to copy", 4)
        end
        return false, msg
    end
end

-- Connect copy button
if copyBtn then
    copyBtn.MouseButton1Click:Connect(function()
        Watermark.CopyDiscord()
    end)
end

-- Mobile / touch toggle
if UIS and frame then
    UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Touch then
            local pos = input.Position
            local absPos = frame.AbsolutePosition
            local absSize = frame.AbsoluteSize
            if pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y then
                Watermark.Toggle()
            end
        end
    end)
end

-- Reparent guard: ensure GUI remains in a safe parent across respawns / coregui resets
local function ensureGuiParent()
    local parent = getUIParent()
    if not parent then return end
    -- remove duplicate
    removeDuplicate(parent)
    if screenGui and screenGui.Parent ~= parent then
        screenGui.Parent = parent
    end
end

-- Try to reparent on important signals
if LocalPlayer then
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.1)
        ensureGuiParent()
    end)
end
RunService.Heartbeat:Connect(function()
    -- quick check every few heartbeats to avoid heavy work
    if screenGui and (not screenGui.Parent or not screenGui:IsDescendantOf(game)) then
        ensureGuiParent()
    end
end)

-- Expose globally (avoid duplicate)
_G.MerebennieWatermark = Watermark

-- Auto show once on load (if UI exists)
if screenGui then
    Watermark.Show()
end

-- ======= OPTICAL-FLOW / CAMERA SMOOTHER =======
-- Principles:
--  * When camera movement is tiny (micro-jitter), smoothly interpolate (low-pass filter).
--  * When camera movement is large/fast (player intentionally moving, teleport, cutscene), pass through immediately.
--  * Works per-frame (RenderStepped). Respawn-safe. Toggleable.

local CameraSmoother = {}
CameraSmoother.enabled = true
CameraSmoother.smoothing = 12        -- higher -> faster convergence (per-second)
CameraSmoother.sensitivity = 0.06    -- threshold (combined pos + rot metric) above which movement is considered intentional
CameraSmoother.maxDelta = 1.0       -- a large snap threshold (teleport etc) that forces immediate pass-through
CameraSmoother._conn = nil
CameraSmoother._filtered = nil
CameraSmoother._lastRaw = nil
CameraSmoother._camera = nil

-- utility: rotational difference approx using lookVector dot
local function rotDifference(a, b)
    local la = a.LookVector
    local lb = b.LookVector
    local dot = math.clamp(la:Dot(lb), -1, 1)
    local angle = math.acos(dot) -- radians
    return angle
end

local function startCameraSmoother()
    if CameraSmoother._conn then return end
    CameraSmoother._camera = workspace.CurrentCamera
    if not CameraSmoother._camera then return end
    CameraSmoother._lastRaw = CameraSmoother._camera.CFrame
    CameraSmoother._filtered = CameraSmoother._lastRaw

    CameraSmoother._conn = RunService.RenderStepped:Connect(function(dt)
        local cam = CameraSmoother._camera
        if not cam or not cam.CFrame then return end

        local ok, raw = pcall(function() return cam.CFrame end)
        if not ok or not raw then return end

        -- compute movement metric: position delta + rotational magnitude
        local posDelta = (raw.Position - (CameraSmoother._lastRaw and CameraSmoother._lastRaw.Position or raw.Position)).Magnitude
        local rotDelta = rotDifference(raw, (CameraSmoother._lastRaw or raw))
        local metric = posDelta + (rotDelta * 0.5) -- weight rotation less

        -- extremely large snap -> pass through immediately
        if metric >= CameraSmoother.maxDelta then
            CameraSmoother._filtered = raw
            pcall(function() cam.CFrame = CameraSmoother._filtered end)
            CameraSmoother._lastRaw = raw
            return
        end

        -- intentional movement: allow direct pass-through if movement larger than sensitivity
        if metric >= CameraSmoother.sensitivity then
            CameraSmoother._filtered = raw
            pcall(function() cam.CFrame = CameraSmoother._filtered end)
            CameraSmoother._lastRaw = raw
            return
        end

        -- tiny jitter: smooth by exponential lerp based on dt and smoothing speed
        local alpha = 1 - math.exp(-CameraSmoother.smoothing * dt) -- stable, framerate-independent
        CameraSmoother._filtered = CameraSmoother._filtered:Lerp(raw, alpha)
        pcall(function() cam.CFrame = CameraSmoother._filtered end)

        CameraSmoother._lastRaw = raw
    end)
end

local function stopCameraSmoother()
    if CameraSmoother._conn then
        CameraSmoother._conn:Disconnect()
        CameraSmoother._conn = nil
    end
    CameraSmoother._camera = nil
    CameraSmoother._filtered = nil
    CameraSmoother._lastRaw = nil
end

-- Start automatically if enabled
if CameraSmoother.enabled then
    pcall(startCameraSmoother)
end

-- Expose API on Watermark
function Watermark.EnableOpticalFlow(val)
    CameraSmoother.enabled = not not val
    if CameraSmoother.enabled then
        pcall(startCameraSmoother)
    else
        pcall(stopCameraSmoother)
    end
    return CameraSmoother.enabled
end

function Watermark.SetOpticalFlowParams(params)
    if type(params) ~= "table" then return false end
    if params.smoothing and type(params.smoothing) == "number" then
        CameraSmoother.smoothing = math.clamp(params.smoothing, 0.1, 100)
    end
    if params.sensitivity and type(params.sensitivity) == "number" then
        CameraSmoother.sensitivity = math.clamp(params.sensitivity, 0, 10)
    end
    if params.maxDelta and type(params.maxDelta) == "number" then
        CameraSmoother.maxDelta = math.clamp(params.maxDelta, 0.1, 1000)
    end
    return true
end

-- Provide quick getters
function Watermark.GetOpticalFlowState()
    return {
        enabled = CameraSmoother.enabled,
        smoothing = CameraSmoother.smoothing,
        sensitivity = CameraSmoother.sensitivity,
        maxDelta = CameraSmoother.maxDelta,
    }
end

-- Keep smoother alive / respawn-safe: restart if camera changes
local cameraChangedConn
cameraChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    -- small delay to let new camera initialize
    task.wait(0.03)
    if CameraSmoother.enabled then
        pcall(function()
            stopCameraSmoother()
            startCameraSmoother()
        end)
    end
end)

-- Stop smoother when script / player leaves (cleanup)
LocalPlayer.AncestryChanged:Connect(function()
    if not LocalPlayer:IsDescendantOf(game) then
        pcall(stopCameraSmoother)
        if cameraChangedConn then cameraChangedConn:Disconnect() end
    end
end)

-- ======= Final friendly console message =======
pcall(function()
    print("[Merebennie] Anti-shake + Watermark + OpticalFlow loaded.")
end)
