-- Universal Aimlock Controller: Players & NPCs, Auto‑Switch & Dynamic Toggle (Bahasa Indonesia)
-- Layanan
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService     = game:GetService("SoundService")

-- Referensi
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- Konfigurasi Default
local AIM_RADIUS        = 500
local AIM_SPEED         = 5
local LOCK_PART         = "Head"
local USE_CAM_HEIGHT    = true
local CAM_HEIGHT        = 2
local SCREEN_TILT       = -5
local USE_FRIEND_FILTER = true
local USE_FACE_TARGET   = false
local USE_STEALTH_MODE  = false
local TOGGLE_KEY        = Enum.KeyCode.V

-- Status Script
local aiming     = false
local targetPart = nil
local targetHRP  = nil

-- Bersihkan target saat mati
local function clearTarget()
    targetPart = nil
    targetHRP  = nil
end

-- Setup GUI
local gui = Instance.new("ScreenGui")
gui.Name           = "AimlockUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if pcall(function() gui.Parent = game.CoreGui end) then else gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
LocalPlayer.CharacterAdded:Connect(function() gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)

-- Tambahkan Watermark
local watermark = Instance.new("TextLabel")
watermark.Name               = "Watermark"
watermark.Parent             = gui
watermark.AnchorPoint        = Vector2.new(1, 1)
watermark.Position           = UDim2.new(1, -10, 1, -10)
watermark.Size               = UDim2.new(0, 200, 0, 30)
watermark.BackgroundTransparency = 1
watermark.Text               = "Made by Suttann"
watermark.Font               = Enum.Font.GothamBold
watermark.TextSize           = 14
watermark.TextColor3         = Color3.new(1, 1, 1)
watermark.TextTransparency   = 0.2  -- 80% opacity
watermark.TextXAlignment     = Enum.TextXAlignment.Right

-- Suara Toggle Pengaturan
local toggleSound = Instance.new("Sound")
toggleSound.SoundId = "rbxassetid://1524549907"
toggleSound.Volume  = 1
toggleSound.Parent  = SoundService

-- Frame Utama
local frame = Instance.new("Frame", gui)
frame.Size             = UDim2.new(0,240,0,96)
frame.Position         = UDim2.new(0.5,-120,0.1,0)
frame.AnchorPoint      = Vector2.new(0.5,0)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.Active           = true
frame.Draggable        = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,12)
Instance.new("UIStroke", frame).Color = Color3.fromRGB(80,80,80)

-- Label Judul
local title = Instance.new("TextLabel", frame)
title.Text               = "Pengontrol Aimlock"
title.Font               = Enum.Font.GothamBold
title.TextSize           = 18
title.TextColor3         = Color3.new(1,1,1)
title.BackgroundTransparency = 1
title.Position           = UDim2.new(0,6,0,0)
title.Size               = UDim2.new(1,-40,0,28)
title.TextXAlignment     = Enum.TextXAlignment.Left

-- Tombol Pengaturan
local settingsBtn = Instance.new("TextButton", frame)
settingsBtn.Size         = UDim2.new(0,28,0,28)
settingsBtn.Position     = UDim2.new(1,-10,0,4)
settingsBtn.AnchorPoint  = Vector2.new(1,0)
settingsBtn.Text         = "-"
settingsBtn.Font         = Enum.Font.GothamBold
settingsBtn.TextSize     = 20
settingsBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
Instance.new("UICorner", settingsBtn).CornerRadius = UDim.new(1,0)
Instance.new("UIStroke", settingsBtn).Color = Color3.fromRGB(70,70,70)

-- Tombol Aimlock
local toggleBtn = Instance.new("TextButton", frame)
toggleBtn.Size             = UDim2.new(0.7,0,0,36)
toggleBtn.Position         = UDim2.new(0.05,0,0.52,0)
toggleBtn.Text             = "AIMBOT: NONAKTIF"
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.TextSize         = 18
toggleBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
toggleBtn.TextColor3       = Color3.fromRGB(180,180,180)
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,8)

-- Indikator Status
local dot = Instance.new("Frame", frame)
dot.Size                   = UDim2.new(0,18,0,18)
dot.Position               = UDim2.new(0.8,0,0.55,0)
dot.BackgroundColor3       = Color3.fromRGB(150,0,0)
Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

-- Panel Pengaturan
local settingsFrame = Instance.new("Frame", gui)
settingsFrame.Size       = UDim2.new(0,0,0,0)
settingsFrame.Position   = frame.Position + UDim2.new(0,frame.Size.X.Offset/2+8,0,0)
settingsFrame.AnchorPoint= Vector2.new(0.5,0)
settingsFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
settingsFrame.Active     = true
settingsFrame.Draggable  = true
settingsFrame.ClipsDescendants = true
settingsFrame.Visible    = false
Instance.new("UICorner", settingsFrame).CornerRadius = UDim.new(0,12)
Instance.new("UIStroke", settingsFrame).Color = Color3.fromRGB(85,85,85)
local padding = Instance.new("UIPadding", settingsFrame)
padding.PaddingTop   = UDim.new(0,8)
padding.PaddingLeft  = UDim.new(0,8)
padding.PaddingRight = UDim.new(0,8)
local layout = Instance.new("UIListLayout", settingsFrame)
layout.Padding           = UDim.new(0,8)
layout.SortOrder         = Enum.SortOrder.LayoutOrder
layout.VerticalAlignment = Enum.VerticalAlignment.Top

-- Fungsi Pabrik Kontrol
local function makeButton(txt)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,28)
    btn.Font = Enum.Font.Gotham; btn.TextSize=14; btn.TextColor3=Color3.new(1,1,1)
    btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
    Instance.new("UICorner", btn).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke", btn).Color=Color3.fromRGB(70,70,70)
    btn.Text = txt
    return btn
end
local function makeSlider(lbl,mn,mx,stp,def,cb)
    local f = Instance.new("Frame", settingsFrame)
    f.Size=UDim2.new(1,0,0,28); f.BackgroundTransparency=1
    local label=Instance.new("TextLabel",f)
    label.Font=Enum.Font.Gotham; label.TextSize=14; label.TextColor3=Color3.new(1,1,1)
    label.BackgroundTransparency=1; label.Size=UDim2.new(0.6,0,1,0); label.TextXAlignment=Enum.TextXAlignment.Left
    local minus=makeButton("-"); minus.Size=UDim2.new(0,26,1,0); minus.Position=UDim2.new(0.6,4,0,0)
    local plus =makeButton("+"); plus.Size=UDim2.new(0,26,1,0); plus.Position=UDim2.new(0.6,36,0,0)
    minus.Parent=f; plus.Parent=f
    local v=def
    local function upd(val)
        v=math.clamp(val,mn,mx)
        label.Text=lbl..": "..string.format("%.1f",v)
        cb(v)
    end
    minus.MouseButton1Click:Connect(function() upd(v-stp) end)
    plus.MouseButton1Click:Connect(function() upd(v+stp) end)
    label.Parent=f; upd(def)
end
local function makeToggle(lbl,def,cb)
    local btn=makeButton(""); btn.Text=lbl..": "..(def and "AKTIF" or "NONAKTIF")
    local v=def
    btn.MouseButton1Click:Connect(function() v=not v; btn.Text=lbl..": "..(v and "AKTIF" or "NONAKTIF"); cb(v) end)
    btn.Parent=settingsFrame
end
local function makeDropdown(lbl,opts,def,cb)
    local btn=makeButton(""); local v=def; btn.Text=lbl..": "..v
    btn.MouseButton1Click:Connect(function() v=(v==opts[1] and opts[2] or opts[1]); btn.Text=lbl..": "..v; cb(v) end)
    btn.Parent=settingsFrame
end

-- Isi Kontrol Pengaturan
makeSlider("Kecepatan Aimlock",1,20,0.5,AIM_SPEED,function(v) AIM_SPEED=v; clearTarget() end)
makeToggle("Offset Ketinggian",USE_CAM_HEIGHT,function(v) USE_CAM_HEIGHT=v; clearTarget() end)
makeSlider("Sudut Miring",-15,15,1,SCREEN_TILT,function(v) SCREEN_TILT=v; clearTarget() end)
makeToggle("Filter Teman",USE_FRIEND_FILTER,function(v) USE_FRIEND_FILTER=v; clearTarget() end)
makeToggle("Menghadap Target",USE_FACE_TARGET,function(v) USE_FACE_TARGET=v; clearTarget() end)
makeToggle("Mode Siluman",USE_STEALTH_MODE,function(v) USE_STEALTH_MODE=v; clearTarget() end)
makeDropdown("Bagian Terkunci",{"Head","Torso"},LOCK_PART,function(v) LOCK_PART=v; clearTarget() end)

-- Toggle Panel Pengaturan
settingsBtn.MouseButton1Click:Connect(function()
    toggleSound:Play()
    settingsFrame.Visible = not settingsFrame.Visible
    if settingsFrame.Visible then
        TweenService:Create(settingsFrame,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,220,0,settingsFrame.UIListLayout.AbsoluteContentSize.Y+16)}):Play()
    else
        TweenService:Create(settingsFrame,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(0,0,0,0)}):Play()
        task.delay(0.2,function() settingsFrame.Visible=false end)
    end
end)

-- Perbarui Tampilan UI
local function updateUI()
    toggleBtn.Text = aiming and "AIMBOT: AKTIF" or "AIMBOT: NONAKTIF"
    toggleBtn.TextColor3 = aiming and Color3.fromRGB(0,220,0) or Color3.fromRGB(180,180,180)
    dot.BackgroundColor3 = aiming and Color3.fromRGB(0,200,0) or Color3.fromRGB(150,0,0)
end
updateUI()
toggleBtn.MouseButton1Click:Connect(function() aiming=not aiming; clearTarget(); updateUI() end)
UserInputService.InputBegan:Connect(function(i,p)
    if not p and i.UserInputType==Enum.UserInputType.Keyboard and i.KeyCode==TOGGLE_KEY then aiming=not aiming; clearTarget(); updateUI() end
end)

-- Logika Pencarian Target (Player & NPC)
local function findTarget()
    local best,dist = nil,AIM_RADIUS
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and (not USE_FRIEND_FILTER or not LocalPlayer:IsFriendsWith(plr.UserId)) then
            local char=plr.Character
            if char then
                local part=char:FindFirstChild(LOCK_PART)
                local hrp=char:FindFirstChild("HumanoidRootPart")
                local hum=char:FindFirstChildWhichIsA("Humanoid")
                if part and hrp and hum and hum.Health>0 then
                    local d=(part.Position-Camera.CFrame.Position).Magnitude
                    if d<dist then dist,best=d,part; targetHRP=hrp; hum.Died:Connect(clearTarget) end
                end
            end
        end
    end
    for _,model in ipairs(workspace:GetDescendants()) do
        local hum=model:FindFirstChildWhichIsA("Humanoid")
        if hum and hum.Health>0 then
            local char=hum.Parent
            if char~=LocalPlayer.Character then
                local part=char:FindFirstChild(LOCK_PART) or char:FindFirstChild("HumanoidRootPart")
                if part then
                    local d=(part.Position-Camera.CFrame.Position).Magnitude
                    if d<dist then dist,best=d,part; targetHRP=char:FindFirstChild("HumanoidRootPart"); hum.Died:Connect(clearTarget) end
                end
            end
        end
    end
    return best
end

-- Loop Aimbot
RunService.RenderStepped:Connect(function()
    if aiming then
        if not targetPart or (targetPart.Position-Camera.CFrame.Position).Magnitude>AIM_RADIUS then
            targetPart=findTarget()
        end
        if targetPart and targetHRP then
            local origin=Camera.CFrame.Position
            if USE_CAM_HEIGHT then origin=origin+Vector3.new(0,CAM_HEIGHT,0) end
            local goal=targetPart.Position
            if USE_STEALTH_MODE then goal=goal+Vector3.new((math.random()-0.5)*0.02,(math.random()-0.5)*0.02,(math.random()-0.5)*0.02) end
            if USE_FACE_TARGET and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
                LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(LocalPlayer.Character.PrimaryPart.Position,goal))
            end
            Camera.CFrame=CFrame.new(origin,goal)*CFrame.Angles(math.rad(SCREEN_TILT),0,0)
        end
    end
end)
