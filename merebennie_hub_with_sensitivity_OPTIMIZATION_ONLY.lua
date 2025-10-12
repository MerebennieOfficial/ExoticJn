-- Merebennie Hub | FFlags + Disable Shakes (Persistent) + Professional Resolution Toggle
-- Added: "Fps Booster + Better lighting" and "Slower physics" buttons
-- Rayfield loader (Delta compatible)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Aimlock + SemiFFlags | Made by Merebennie",
    LoadingTitle = "Aimlock + SemiFFlags | Made by Merebennie Initializing...",
    LoadingSubtitle = "by Merebennie",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Optimization", 4483362458)
local Section = Tab:CreateSection("Performance Enhancer")

-- Create a Main tab for the Instant Twisted / Supa buttons
local MainTab = Window:CreateTab("Main", 4483362458)

-- =========================
-- StretchScreen (Professional Resolution)
-- integrated from your provided code; does NOT auto-enable on load.
-- =========================

do
    local RunService = game:GetService("RunService")
    local workspace = game:GetService("Workspace")

    -- Config (keep these exact or tweak)
    local STRETCH_X = 0.92   -- < 1 = narrower width
    local STRETCH_Y = 0.58   -- vertical intensity

    -- Clean up old instance if present
    if getgenv().StretchScreen and type(getgenv().StretchScreen.disable) == "function" then
        pcall(function() getgenv().StretchScreen.disable() end)
    end

    -- Internal state for this closure
    local _connection
    local _enabled = false

    -- Build a custom stretch matrix
    local function makeStretchMatrix(xScale, yScale)
        -- Apply scale directly on right (X) and up (Y) vectors
        return CFrame.new(0,0,0,
            xScale, 0, 0,
            0,      yScale, 0,
            0,      0, 1)
    end

    local stretchCFrame = makeStretchMatrix(STRETCH_X, STRETCH_Y)

    -- Apply a single-frame stretch
    local function applyStretchToCamera()
        local cam = workspace.CurrentCamera
        if not cam then return end
        pcall(function()
            cam.CFrame = cam.CFrame * stretchCFrame
        end)
    end

    -- Enable: connects RenderStepped and applies every frame
    local function enable()
        if _enabled then return end
        _enabled = true
        _connection = RunService.RenderStepped:Connect(function()
            if workspace.CurrentCamera then
                applyStretchToCamera()
            end
        end)
    end

    -- Disable: safely disconnect
    local function disable()
        if not _enabled then return end
        _enabled = false
        if _connection and _connection.Connected then
            pcall(function() _connection:Disconnect() end)
        end
        _connection = nil
    end

    local function toggle()
        if _enabled then disable() else enable() end
    end

    -- Expose API globally (safe)
    getgenv().StretchScreen = getgenv().StretchScreen or {}
    getgenv().StretchScreen.enable = enable
    getgenv().StretchScreen.disable = disable
    getgenv().StretchScreen.toggle = toggle
    getgenv().StretchScreen.isEnabled = function() return _enabled end
    getgenv().StretchScreen._internal = { widthScale = STRETCH_X, heightScale = STRETCH_Y }

    -- Console feedback (non-blocking)
    pcall(function()
        print(string.format("[StretchScreen] Ready: width=%.2f height=%.2f. Toggle from UI or use getgenv().StretchScreen.enable()/disable().", STRETCH_X, STRETCH_Y))
    end)
end

-- =========================
-- Buttons: FFlags (exact) & Disable Shakes (persistent)
-- =========================

-- Faster Dash (exact)
Tab:CreateButton({
    Name = "⚡ Faster Dash + Better Hitbox Accuracy",
    Callback = function()
        Rayfield:Notify({
            Title = "Merebennie Hub",
            Content = "Activating FFlags...",
            Duration = 3
        })

        --// EXACT FUNCTION (Unchanged)
        pcall(function() setfflag("S2PhysicsSenderRate", "15000") end)
        task.wait(0.1)
        pcall(function() setfflag("PhysicsSenderMaxBandwidthBps", "20000") end)
        task.wait(0.1)

        Rayfield:Notify({
            Title = "Success!",
            Content = "FFlags Applied Successfully ✅",
            Duration = 3
        })
    end,
})

-- Disable Shakes (persistent across respawns)
Tab:CreateButton({
    Name = "Disable Shakes",
    Callback = function()
        Rayfield:Notify({
            Title = "Merebennie Hub",
            Content = "Disabling shakes and setting up auto reapply...",
            Duration = 3
        })

        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer

        local function tryHook()
            pcall(function()
                local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                -- safe wait for CharacterHandler and Client inside it
                if not char then return end
                local ok, clientScript = pcall(function() return char:WaitForChild("CharacterHandler",5):WaitForChild("Client",5) end)
                if not ok or not clientScript then return end

                local senv = getsenv(clientScript)
                if senv and senv.shared and senv.shared.addshake then
                    pcall(function()
                        hookfunction(senv.shared.addshake, function(...)
                            return nil
                        end)
                    end)
                end
            end)
        end

        -- initial attempt and reapply on respawn
        tryHook()
        -- protect from duplicate connections by only adding one listener
        if not _G.__Merebennie_ShakeHook_Connected then
            _G.__Merebennie_ShakeHook_Connected = true
            LocalPlayer.CharacterAdded:Connect(function()
                -- small delay to let CharacterHandler load
                task.wait(0.8)
                tryHook()
            end)
        end

        Rayfield:Notify({
            Title = "Success",
            Content = "Shakes disabled (will persist after respawn).",
            Duration = 4
        })
    end,
})

-- =========================
-- Toggle: Professional Resolution (uses getgenv().StretchScreen)
-- =========================

Tab:CreateToggle({
    Name = "Professional Resolution",
    CurrentValue = getgenv().StretchScreen and getgenv().StretchScreen.isEnabled and getgenv().StretchScreen.isEnabled() or false,
    Flag = "ProfessionalResolutionToggle", -- optional
    Callback = function(value)
        -- value == true => ON; false => OFF
        if value then
            pcall(function() getgenv().StretchScreen.enable() end)
            Rayfield:Notify({
                Title = "Professional Resolution",
                Content = "Enabled ✅",
                Duration = 2
            })
        else
            pcall(function() getgenv().StretchScreen.disable() end)
            Rayfield:Notify({
                Title = "Professional Resolution",
                Content = "Disabled ⛔",
                Duration = 2
            })
        end
    end,
})

-- =========================
-- New Button: FPS Booster + Better lighting
-- =========================

Tab:CreateButton({
    Name = "Fps Booster + Better lighting",
    Callback = function()
        Rayfield:Notify({
            Title = "Merebennie Hub",
            Content = "Applying FPS Booster + Gray lighting...",
            Duration = 3
        })

        -- Wrap the provided FPSBooster code in a pcall to avoid script errors crashing the UI
        pcall(function()
            -- Executor-friendly FPS Booster + Full Gray Lighting & Sky
            local Players = game:GetService("Players")
            local Lighting = game:GetService("Lighting")
            local Workspace = game:GetService("Workspace")
            local RunService = game:GetService("RunService")

            -- ======= CONFIG =======
            local AUTO_APPLY = true
            local GRAY_COLOR = Color3.fromRGB(140,140,140) -- main gray tone
            local FOG_ENABLED = true
            local FOG_START = 0
            local FOG_END = 1e6
            local REMOVE_TEXTURES = false      -- destructive if true
            local WATCHER_ENABLED = true
            local HIDE_LOCAL_HEAD = true       -- hide your own head/accessories
            -- ======================

            -- robust local player reference for executors
            local LocalPlayer = Players.LocalPlayer
            if not LocalPlayer then
                for i = 1, 20 do
                    task.wait(0.03)
                    LocalPlayer = Players.LocalPlayer or LocalPlayer
                    if LocalPlayer then break end
                end
            end

            -- saved state for restore
            local _saved = {
                lighting = {},
                postEffects = {},
                particles = {},
                trails = {},
                beams = {},
                lights = {},
                decals = {},
                skies = {},
                atmospheres = {},
                createdSky = nil,
                createdAtmosphere = nil,
                playerVisuals = {},
                removedInstances = {},
            }

            local function safe(fn, ...) local ok, r = pcall(fn, ...) if ok then return r end return nil end

            -- ---------------- Lighting & Sky/Atmosphere ----------------
            local function saveLightingProps()
                local L = Lighting
                _saved.lighting.Ambient = safe(function() return L.Ambient end)
                _saved.lighting.OutdoorAmbient = safe(function() return L.OutdoorAmbient end)
                _saved.lighting.FogColor = safe(function() return L.FogColor end)
                _saved.lighting.FogStart = safe(function() return L.FogStart end)
                _saved.lighting.FogEnd = safe(function() return L.FogEnd end)
                _saved.lighting.GlobalShadows = safe(function() return L.GlobalShadows end)
                _saved.lighting.Brightness = safe(function() return L.Brightness end)
                -- try to save color shift/top-bottom if present
                _saved.lighting.ColorShiftTop = safe(function() return L.ColorShift_Top end)
                _saved.lighting.ColorShiftBottom = safe(function() return L.ColorShift_Bottom end)
                _saved.lighting.ClockTime = safe(function() return L.ClockTime end)
            end

            local function applyGrayLighting()
                saveLightingProps()
                safe(function() Lighting.Ambient = GRAY_COLOR end)
                safe(function() Lighting.OutdoorAmbient = GRAY_COLOR end)
                if FOG_ENABLED then
                    safe(function()
                        Lighting.FogColor = GRAY_COLOR
                        Lighting.FogStart = FOG_START
                        Lighting.FogEnd = FOG_END
                    end)
                end
                safe(function() Lighting.GlobalShadows = false end)
                -- try to set color-shift top/bottom if property exists
                pcall(function() Lighting.ColorShift_Top = GRAY_COLOR end)
                pcall(function() Lighting.ColorShift_Bottom = GRAY_COLOR end)
                -- reduce brightness a touch (optional, still gray)
                pcall(function() Lighting.Brightness = 1 end)
            end

            -- clone & remove existing Sky and Atmosphere (save clones for restore)
            local function cloneAndRemoveSkyAtmosphere()
                -- Skies in Lighting
                for _, s in ipairs(Lighting:GetChildren()) do
                    if s:IsA("Sky") then
                        local ok, clone = pcall(function() return s:Clone() end)
                        if ok and clone then table.insert(_saved.skies, clone) end
                        pcall(function() s:Destroy() end)
                    end
                end
                -- Sky objects inside workspace (rare)
                for _, s in ipairs(Workspace:GetDescendants()) do
                    if s:IsA("Sky") then
                        local ok, clone = pcall(function() return s:Clone() end)
                        if ok and clone then table.insert(_saved.skies, clone) end
                        pcall(function() s:Destroy() end)
                    end
                end

                -- Atmosphere  
                for _, a in ipairs(Lighting:GetChildren()) do  
                    if a:IsA("Atmosphere") then  
                        local ok, clone = pcall(function() return a:Clone() end)  
                        if ok and clone then table.insert(_saved.atmospheres, clone) end  
                        pcall(function() a:Destroy() end)  
                    end  
                end
            end

            -- create a simple blank Sky + gray Atmosphere to give uniform gray sky
            local function createGraySkyAtmosphere()
                -- create gray Atmosphere
                local atm = Instance.new("Atmosphere")
                pcall(function()
                    atm.Name = "FPSBooster_Atmosphere"
                    atm.Color = GRAY_COLOR
                    -- lighter density gives more uniform color; low values reduce haze
                    if pcall(function() atm.Density = 0.25 end) then end
                    if pcall(function() atm.Offset = 0 end) then end
                    atm.Parent = Lighting
                end)
                _saved.createdAtmosphere = atm

                -- create blank Sky (no textures)  
                local sky = Instance.new("Sky")  
                pcall(function()  
                    sky.Name = "FPSBooster_Sky"  
                    -- set any skybox texture fields to empty string (some properties may not exist)  
                    if pcall(function() sky.SkyboxBk = "" end) then end  
                    if pcall(function() sky.SkyboxDn = "" end) then end  
                    if pcall(function() sky.SkyboxFt = "" end) then end  
                    if pcall(function() sky.SkyboxLf = "" end) then end  
                    if pcall(function() sky.SkyboxRt = "" end) then end  
                    if pcall(function() sky.SkyboxUp = "" end) then end  
                    sky.Parent = Lighting  
                end)  
                _saved.createdSky = sky
            end

            -- ---------------- PostProcessing / VFX disabling ----------------
            local function disablePostProcessing()
                for _, child in ipairs(Lighting:GetChildren()) do
                    if child ~= nil and child.ClassName then
                        local ok, hasEnabled = pcall(function() return child.Enabled ~= nil end)
                        if ok and hasEnabled then
                            local prev = safe(function() return child.Enabled end)
                            if prev ~= nil then
                                _saved.postEffects[child] = prev
                                safe(function() child.Enabled = false end)
                            end
                        else
                            local prevIntensity = safe(function() return child.Intensity end)
                            if prevIntensity ~= nil then
                                _saved.postEffects[child] = {Intensity = prevIntensity}
                                safe(function() child.Intensity = 0 end)
                            end
                        end
                    end
                end
            end

            local function disableParticlesAndVFXInContainer(root)
                for _, desc in ipairs(root:GetDescendants()) do
                    if desc:IsA("ParticleEmitter") then
                        local ok, prev = pcall(function() return desc.Enabled end)
                        if ok then _saved.particles[desc] = prev; pcall(function() desc.Enabled = false end) end
                        pcall(function()
                            if desc.GetAttribute and desc:GetAttribute("FPSBooster_RateSaved") == nil then desc:SetAttribute("FPSBooster_RateSaved", desc.Rate) end
                            desc.Rate = 0
                        end)
                    elseif desc:IsA("Trail") then
                        local ok, prev = pcall(function() return desc.Enabled end)
                        if ok then _saved.trails[desc] = prev; pcall(function() desc.Enabled = false end) end
                    elseif desc:IsA("Beam") then
                        local ok, prev = pcall(function() return desc.Enabled end)
                        if ok then _saved.beams[desc] = prev; pcall(function() desc.Enabled = false end) end
                    elseif desc:IsA("Sparkles") or desc:IsA("Fire") or desc:IsA("Smoke") then
                        local ok, prev = pcall(function() return desc.Enabled end)
                        if ok then _saved.particles[desc] = prev; pcall(function() desc.Enabled = false end) end
                    elseif desc:IsA("PointLight") or desc:IsA("SurfaceLight") or desc:IsA("SpotLight") then
                        local ok, prev = pcall(function() return desc.Enabled end)
                        if ok then _saved.lights[desc] = prev; pcall(function() desc.Enabled = false end)
                        else
                            local ok2, b = pcall(function() return desc.Brightness end)
                            if ok2 then _saved.lights[desc] = {Brightness = b}; pcall(function() desc.Brightness = 0 end) end
                        end
                    elseif desc:IsA("Decal") or desc:IsA("Texture") then
                        local ok, prev = pcall(function() return desc.Transparency end)
                        if ok then
                            _saved.decals[desc] = prev
                            if REMOVE_TEXTURES then
                                if desc.Parent then table.insert(_saved.removedInstances, desc) end
                                pcall(function() desc:Destroy() end)
                            else
                                pcall(function() desc.Transparency = 1 end)
                            end
                        end
                    elseif desc:IsA("SurfaceGui") or desc:IsA("BillboardGui") then
                        pcall(function() desc.Enabled = false end)
                    end
                end
            end

            -- ---------------- Local player head/accessory hiding ----------------
            local charWatcherConnection
            local function saveVisualProps(inst)
                if not inst or not inst.Parent then return end
                if inst:IsA("BasePart") then
                    if _saved.playerVisuals[inst] == nil then
                        _saved.playerVisuals[inst] = {
                            Transparency = safe(function() return inst.Transparency end),
                            LocalTransparencyModifier = safe(function() return inst.LocalTransparencyModifier end)
                        }
                    end
                elseif inst:IsA("Decal") or inst:IsA("Texture") then
                    if _saved.playerVisuals[inst] == nil then
                        _saved.playerVisuals[inst] = {Transparency = safe(function() return inst.Transparency end)}
                    end
                elseif inst:IsA("Accessory") then
                    if _saved.playerVisuals[inst] == nil then _saved.playerVisuals[inst] = {Saved = true} end
                end
            end

            local function hideInstanceVisual(inst)
                if not inst or not inst.Parent then return end
                pcall(function()
                    if inst:IsA("BasePart") then
                        saveVisualProps(inst)
                        inst.Transparency = 1
                        if pcall(function() inst.LocalTransparencyModifier = 0 end) then end
                    elseif inst:IsA("Decal") or inst:IsA("Texture") then
                        saveVisualProps(inst)
                        inst.Transparency = 1
                    elseif inst:IsA("Accessory") then
                        local handle = inst:FindFirstChild("Handle")
                        if handle and handle:IsA("BasePart") then
                            saveVisualProps(handle)
                            handle.Transparency = 1
                        end
                        for _, sub in ipairs(inst:GetDescendants()) do
                            if sub:IsA("BasePart") then saveVisualProps(sub); sub.Transparency = 1
                            elseif sub:IsA("Decal") or sub:IsA("Texture") then saveVisualProps(sub); sub.Transparency = 1 end
                        end
                    end
                end)
            end

            local function hideCharacterHeadAndAccessories(character)
                if not character then return end
                for _, desc in ipairs(character:GetDescendants()) do
                    if desc:IsA("BasePart") and desc.Name == "Head" then
                        saveVisualProps(desc)
                        pcall(function() desc.Transparency = 1 end)
                        for _, d in ipairs(desc:GetDescendants()) do
                            if d:IsA("Decal") then saveVisualProps(d); pcall(function() d.Transparency = 1 end) end
                        end
                    end
                    if desc:IsA("Accessory") then
                        saveVisualProps(desc)
                        for _, sub in ipairs(desc:GetDescendants()) do
                            if sub:IsA("BasePart") then saveVisualProps(sub); pcall(function() sub.Transparency = 1 end)
                            elseif sub:IsA("Decal") or sub:IsA("Texture") then saveVisualProps(sub); pcall(function() sub.Transparency = 1 end) end
                        end
                    end
                    -- hair-like parts/meshes
                    if (desc:IsA("MeshPart") or desc:IsA("UnionOperation") or desc:IsA("Part")) then
                        local nm = tostring(desc.Name):lower()
                        local pn = desc.Parent and tostring(desc.Parent.Name):lower() or ""
                        if pn == "head" or nm:find("hair") or nm:find("hat") then saveVisualProps(desc); pcall(function() desc.Transparency = 1 end) end
                    end
                    if desc:IsA("Decal") and desc.Name:lower() == "face" then saveVisualProps(desc); pcall(function() desc.Transparency = 1 end) end
                end

                if charWatcherConnection then pcall(function() charWatcherConnection:Disconnect() end) end  
                charWatcherConnection = character.DescendantAdded:Connect(function(newDesc)  
                    task.wait(0.01)  
                    pcall(function()  
                        if newDesc:IsA("BasePart") and newDesc.Name == "Head" then saveVisualProps(newDesc); newDesc.Transparency = 1  
                        elseif newDesc:IsA("Accessory") then saveVisualProps(newDesc); for _, s in ipairs(newDesc:GetDescendants()) do if s:IsA("BasePart") then saveVisualProps(s); pcall(function() s.Transparency = 1 end) elseif s:IsA("Decal") or s:IsA("Texture") then saveVisualProps(s); pcall(function() s.Transparency = 1 end) end end  
                        elseif newDesc:IsA("Decal") and newDesc.Name:lower() == "face" then saveVisualProps(newDesc); newDesc.Transparency = 1  
                        else  
                            local nm = newDesc.Name:lower()  
                            local pn = newDesc.Parent and newDesc.Parent.Name:lower() or ""  
                            if pn == "head" or nm:find("hair") or nm:find("hat") then saveVisualProps(newDesc); pcall(function() newDesc.Transparency = 1 end) end  
                        end  
                    end)  
                end)
            end

            local function restoreLocalPlayerVisuals()
                for inst, props in pairs(_saved.playerVisuals) do
                    if inst and inst.Parent then
                        pcall(function()
                            if inst:IsA("BasePart") then
                                if props.Transparency ~= nil then inst.Transparency = props.Transparency end
                                if props.LocalTransparencyModifier ~= nil and pcall(function() inst.LocalTransparencyModifier = props.LocalTransparencyModifier end) then end
                            elseif inst:IsA("Decal") or inst:IsA("Texture") then
                                if props.Transparency ~= nil then inst.Transparency = props.Transparency end
                            end
                        end)
                    end
                end
                _saved.playerVisuals = {}
                if charWatcherConnection then pcall(function() charWatcherConnection:Disconnect() end) charWatcherConnection = nil end
            end

            -- ---------------- Apply & Restore ----------------
            local watcherConnection
            local function applyAll()
                applyGrayLighting()
                cloneAndRemoveSkyAtmosphere()
                createGraySkyAtmosphere()
                disablePostProcessing()
                disableParticlesAndVFXInContainer(Workspace)
                if LocalPlayer and LocalPlayer.Character then disableParticlesAndVFXInContainer(LocalPlayer.Character) end
                if HIDE_LOCAL_HEAD and LocalPlayer then
                    if LocalPlayer.Character then hideCharacterHeadAndAccessories(LocalPlayer.Character) end
                    LocalPlayer.CharacterAdded:Connect(function(char) task.wait(0.06); hideCharacterHeadAndAccessories(char) end)
                end
            end

            local function restore()
                -- restore lighting props
                pcall(function()
                    if _saved.lighting.Ambient then Lighting.Ambient = _saved.lighting.Ambient end
                    if _saved.lighting.OutdoorAmbient then Lighting.OutdoorAmbient = _saved.lighting.OutdoorAmbient end
                    if _saved.lighting.FogColor then Lighting.FogColor = _saved.lighting.FogColor end
                    if _saved.lighting.FogStart then Lighting.FogStart = _saved.lighting.FogStart end
                    if _saved.lighting.FogEnd then Lighting.FogEnd = _saved.lighting.FogEnd end
                    if _saved.lighting.GlobalShadows ~= nil then Lighting.GlobalShadows = _saved.lighting.GlobalShadows end
                    if _saved.lighting.Brightness then Lighting.Brightness = _saved.lighting.Brightness end
                    if _saved.lighting.ColorShiftTop then pcall(function() Lighting.ColorShift_Top = _saved.lighting.ColorShiftTop end) end
                    if _saved.lighting.ColorShiftBottom then pcall(function() Lighting.ColorShift_Bottom = _saved.lighting.ColorShiftBottom end) end
                    if _saved.lighting.ClockTime then pcall(function() Lighting.ClockTime = _saved.lighting.ClockTime end) end
                end)

                -- restore post effects  
                for inst, prev in pairs(_saved.postEffects) do  
                    if inst and inst.Parent then  
                        pcall(function()  
                            if type(prev) == "table" and prev.Intensity ~= nil then inst.Intensity = prev.Intensity else inst.Enabled = prev end  
                        end)  
                    end  
                end  

                -- restore particles  
                for inst, prev in pairs(_saved.particles) do  
                    if inst and inst.Parent then pcall(function() inst.Enabled = prev end)  
                        pcall(function()  
                            if inst.GetAttribute and inst:GetAttribute("FPSBooster_RateSaved") then  
                                inst.Rate = inst:GetAttribute("FPSBooster_RateSaved")  
                                inst:SetAttribute("FPSBooster_RateSaved", nil)  
                            end  
                        end)  
                    end  
                end  

                -- restore trails/beams/lights/decals  
                for inst, prev in pairs(_saved.trails) do if inst and inst.Parent then pcall(function() inst.Enabled = prev end) end end  
                for inst, prev in pairs(_saved.beams) do if inst and inst.Parent then pcall(function() inst.Enabled = prev end) end end  
                for inst, prev in pairs(_saved.lights) do if inst and inst.Parent then pcall(function() if type(prev) == "table" and prev.Brightness then inst.Brightness = prev.Brightness else inst.Enabled = prev end end) end end  
                for inst, prev in pairs(_saved.decals) do if inst and inst.Parent then pcall(function() inst.Transparency = prev end) end end  

                -- remove our created gray sky/atmosphere and reparent saved clones  
                if _saved.createdSky and _saved.createdSky.Parent then pcall(function() _saved.createdSky:Destroy() end) end  
                if _saved.createdAtmosphere and _saved.createdAtmosphere.Parent then pcall(function() _saved.createdAtmosphere:Destroy() end) end  

                for _, clone in ipairs(_saved.skies) do if clone and not clone.Parent then pcall(function() clone.Parent = Lighting end) end end  
                for _, clone in ipairs(_saved.atmospheres) do if clone and not clone.Parent then pcall(function() clone.Parent = Lighting end) end end  

                -- restore player visuals  
                restoreLocalPlayerVisuals()  

                -- note: any destroyed instances due to REMOVE_TEXTURES cannot be restored  

                -- cleanup saved tables (keep lighting saved if you want to reapply later)  
                _saved.postEffects = {}  
                _saved.particles = {}  
                _saved.trails = {}  
                _saved.beams = {}  
                _saved.lights = {}  
                _saved.decals = {}  
                _saved.skies = {}  
                _saved.atmospheres = {}  
                _saved.removedInstances = {}  

                if watcherConnection and watcherConnection.Connected then pcall(function() watcherConnection:Disconnect() end) end
            end

            -- expose to executor console
            getgenv().FPSBooster = getgenv().FPSBooster or {}
            getgenv().FPSBooster.apply = applyAll
            getgenv().FPSBooster.restore = restore
            getgenv().FPSBooster.config = {GRAY_COLOR = GRAY_COLOR, REMOVE_TEXTURES = REMOVE_TEXTURES, HIDE_LOCAL_HEAD = HIDE_LOCAL_HEAD}

            -- auto-apply
            if AUTO_APPLY then applyAll() end

            -- watcher to neutralize newly added visuals (keeps sky/atmosphere gray)
            if WATCHER_ENABLED then
                watcherConnection = Workspace.DescendantAdded:Connect(function(desc)
                    task.wait(0.02)
                    pcall(function()
                        if desc:IsA("Sky") then pcall(function() desc:Destroy() end)
                        elseif desc:IsA("Atmosphere") then pcall(function() desc:Destroy() end)
                        elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Sparkles") or desc:IsA("Fire") or desc:IsA("Smoke") then pcall(function() desc.Enabled = false end)
                        elseif desc:IsA("PointLight") or desc:IsA("SurfaceLight") or desc:IsA("SpotLight") then pcall(function() desc.Enabled = false end)
                        elseif desc:IsA("Decal") or desc:IsA("Texture") then
                            if REMOVE_TEXTURES then pcall(function() desc:Destroy() end) else pcall(function() desc.Transparency = 1 end) end
                        end
                    end)
                end)
            end

            pcall(function() print("[FPSBooster] Gray lighting + sky applied. Use getgenv().FPSBooster.restore() to undo.") end)
        end)

        Rayfield:Notify({
            Title = "Merebennie Hub",
            Content = "FPS Booster applied (check console for restore function).",
            Duration = 4
        })
    end,
})

-- =========================
-- New Button: Slower physics
-- =========================

Tab:CreateButton({
    Name = "Slower physics",
    Callback = function()
        Rayfield:Notify({
            Title = "Merebennie Hub",
            Content = "Applying slower physics FFlag...",
            Duration = 2
        })

        pcall(function() setfflag("PhysicsImprovedCyclicExecutiveThrottleThresholdTenth", "-999999999") end)
        task.wait(0.1)

        Rayfield:Notify({
            Title = "Merebennie Hub",
            Content = "Slower physics flag applied ✅",
            Duration = 3
        })
    end,
})

-- =========================
-- NEW: Join our Discord! copy button (placed in Optimization tab)
-- =========================

Tab:CreateButton({
    Name = "Join our Discord!",
    Callback = function()
        local discord_link = "https://raw.githubusercontent.com/MerebennieOfficial/ExoticJn/refs/heads/main/Instant%20Twisted"
        local ok = false
        -- try to copy to clipboard (depends on executor supporting setclipboard)
        ok = pcall(function() setclipboard(discord_link) end)
        if ok then
            Rayfield:Notify({
                Title = "Discord Link",
                Content = "Link copied to clipboard ✅",
                Duration = 3
            })
        else
            -- fallback: show full link in notification (user can copy manually)
            Rayfield:Notify({
                Title = "Copy failed",
                Content = "Automatic copy failed. Link:\n" .. discord_link,
                Duration = 6
            })
        end
    end,
})

-- =========================
-- MAIN TAB: Instant Twisted + Supa buttons
-- =========================

MainTab:CreateButton({
    Name = "Instant Twisted (Pair with Aimlock)",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/MerebennieOfficial/ExoticJn/refs/heads/main/Instant%20Twisted"))()
        end)
    end,
})

MainTab:CreateButton({
    Name = "Supa V2 Tech",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/MerebennieOfficial/ExoticJn/refs/heads/main/Supa%20V3"))()
        end)
    end,
})

-- =========================
-- NEW: Aimlock button (runs the Aimlock UI/function provided)
-- =========================

MainTab:CreateButton({
    Name = "Aimlock (Recommend to use unshiftlocked) only on the Rayfield button",
    Callback = function()
        pcall(function()
--// A I M L O C K  - By Merebennie
--// Supports Players + NPCs, smooth nearest-part aiming, no prediction
--// UI: no white flash on click, button press animation, click sound
--// Now: if target is >= 8 studs vertically above you, aim directly at the target's Head.
--//      Otherwise continue aiming at nearest part (smooth switches). Character faces target (yaw),
--//      but will not rotate while ragdolled.

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

-- Local refs
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Config (tweakable)
local targetLerpEnabled = 0.45
local targetLerpDisabled = 0.3
local lerpSpeed = 0.50          -- camera lerp responsiveness (higher => snappier)
local aimPosLerpSpeed = 0.70    -- aim-point smoothing (higher => faster switch)
local heightOffset = 1.6
local tiltDown = math.rad(-5)

-- Rotation config: character faces target while aimlock active
local rotationLerp = 0.90       -- how fast character turns to face target yaw (0..1). 1 = instant.

-- RIGHT OFFSET (tweakable)
local rightOffset = 0.8

-- VERTICAL HEAD RULE
local verticalHeadThreshold = 8  -- if target is this many studs or more above player, aim directly to Head

-- UI Setup (draggable button)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AimlockUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

local Button = Instance.new("TextButton")
Button.Name = "AimlockButton"
Button.Parent = ScreenGui
Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Button.Position = UDim2.new(0.4, 0, 0.5, 0)
Button.Size = UDim2.new(0, 120, 0, 50)
Button.Font = Enum.Font.Cartoon
Button.Text = "Aimlock (Recommend to use unshiftlocked)"
Button.TextColor3 = Color3.fromRGB(255, 255, 255)
Button.TextScaled = true
Button.Active = true
Button.AutoButtonColor = false      -- prevents default white flash on press

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = Button

-- Click sound (plays locally)
local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://5852470908"
clickSound.Volume = 1
clickSound.Parent = SoundService

-- Intouch (press) animation setup
local pressTweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local releaseTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local pressedSize = UDim2.new(0, 110, 0, 46) -- slightly smaller
local normalSize = Button.Size

-- Dragging for the button
local dragging = false
local dragInput, dragStart, startPos

Button.InputBegan:Connect(function(input)
 if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
  dragging = true
  dragStart = input.Position
  startPos = Button.Position
  input.Changed:Connect(function()
   if input.UserInputState == Enum.UserInputState.End then
    dragging = false
   end
  end)
 end
end)

Button.InputChanged:Connect(function(input)
 if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
  dragInput = input
 end
end)

UserInputService.InputChanged:Connect(function(input)
 if input == dragInput and dragging then
  local delta = input.Position - dragStart
  Button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
 end
end)

-- INTRO: "Made by Merebennie" fade in/out label
do
 -- create label
 local IntroLabel = Instance.new("TextLabel")
 IntroLabel.Name = "IntroMadeBy"
 IntroLabel.Parent = ScreenGui
 IntroLabel.AnchorPoint = Vector2.new(0.5, 0.5)
 IntroLabel.Position = UDim2.new(0.5, 0, 0.15, 0) -- top-center
 IntroLabel.Size = UDim2.new(0.6, 0, 0, 80) -- width is 60% of screen, height 80px
 IntroLabel.BackgroundTransparency = 1
 IntroLabel.Text = "Made by Merebennie"
 IntroLabel.Font = Enum.Font.Cartoon -- cartoonish font
 IntroLabel.TextScaled = true
 IntroLabel.TextColor3 = Color3.fromRGB(255,255,255)
 IntroLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0) -- black outline
 IntroLabel.TextStrokeTransparency = 1 -- start invisible, will tween to 0
 IntroLabel.TextTransparency = 1 -- start invisible, will tween to 0
 IntroLabel.ZIndex = 999 -- on top

 -- optional slight shadow behind (subtle), created as a second label slightly offset
 local Shadow = Instance.new("TextLabel")
 Shadow.Name = "IntroShadow"
 Shadow.Parent = ScreenGui
 Shadow.AnchorPoint = IntroLabel.AnchorPoint
 Shadow.Position = IntroLabel.Position + UDim2.new(0, 2, 0, 2) -- small offset
 Shadow.Size = IntroLabel.Size
 Shadow.BackgroundTransparency = 1
 Shadow.Text = IntroLabel.Text
 Shadow.Font = IntroLabel.Font
 Shadow.TextScaled = IntroLabel.TextScaled
 Shadow.TextColor3 = Color3.fromRGB(0,0,0)
 Shadow.TextTransparency = 1
 Shadow.TextStrokeTransparency = 1
 Shadow.ZIndex = IntroLabel.ZIndex - 1

 -- Tween setup
 local fadeInInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
 local fadeOutInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
 local holdTime = 1.6

 local fadeIn = TweenService:Create(IntroLabel, fadeInInfo, {TextTransparency = 0, TextStrokeTransparency = 0})
 local fadeInShadow = TweenService:Create(Shadow, fadeInInfo, {TextTransparency = 0.3})
 local fadeOut = TweenService:Create(IntroLabel, fadeOutInfo, {TextTransparency = 1, TextStrokeTransparency = 1})
 local fadeOutShadow = TweenService:Create(Shadow, fadeOutInfo, {TextTransparency = 1})

 -- play sequence without blocking main thread
 coroutine.wrap(function()
  fadeIn:Play()
  fadeInShadow:Play()
  fadeIn.Completed:Wait()
  wait(holdTime)
  fadeOut:Play()
  fadeOutShadow:Play()
  fadeOut.Completed:Wait()
  -- cleanup
  if IntroLabel and IntroLabel.Parent then IntroLabel:Destroy() end
  if Shadow and Shadow.Parent then Shadow:Destroy() end
 end)()
end
-- END INTRO

-- Aimlock state
local aimlockEnabled = false
local target = nil          -- target is a Model (player character or NPC Model)
local currentLerp = targetLerpDisabled
local aimPosSmoothed = nil  -- smoothed world position we look at

-- Helper: gather candidate targets (players + NPC models with Humanoid)
local function gatherTargets()
 local list = {}

 -- players' characters first
 for _, p in pairs(Players:GetPlayers()) do
  if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
   table.insert(list, p.Character)
  end
 end

 -- NPCs: find models in workspace that have a Humanoid and a BasePart (avoid player chars)
 for _, obj in pairs(workspace:GetDescendants()) do
  if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
   local humanoid = obj:FindFirstChildOfClass("Humanoid")
   if humanoid and humanoid.Health > 0 then
   local foundPart = nil
   if obj:FindFirstChild("HumanoidRootPart") and obj.HumanoidRootPart:IsA("BasePart") then
    foundPart = obj.HumanoidRootPart
   elseif obj:FindFirstChild("Head") and obj.Head:IsA("BasePart") then
    foundPart = obj.Head
   end
   if foundPart then
    table.insert(list, obj)
   end
   end
  end
 end

 return list
end

-- Helper: pick the nearest BasePart of a character/model relative to fromPos
local function getNearestPartOfModel(model, fromPos)
 if not model or not fromPos then return nil end
 local nearestPart, shortest = nil, math.huge

 local preferredNames = {
  "Head","UpperTorso","LowerTorso","HumanoidRootPart",
  "LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm",
  "LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg",
  "LeftHand","RightHand","LeftFoot","RightFoot"
 }
 for _,name in ipairs(preferredNames) do
  local part = model:FindFirstChild(name)
  if part and part:IsA("BasePart") then
   local d = (part.Position - fromPos).Magnitude
   if d < shortest then
   shortest = d
   nearestPart = part
   end
  end
 end

 -- fallback: scan all BaseParts
 if not nearestPart then
  for _,desc in pairs(model:GetDescendants()) do
   if desc:IsA("BasePart") then
    local d = (desc.Position - fromPos).Magnitude
    if d < shortest then
     shortest = d
     nearestPart = desc
    end
   end
  end
 end

 return nearestPart
end

-- Helper: find the nearest target (model) to the local player
local function acquireNearestTarget()
 if not LocalPlayer or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
  return nil
 end
 local origin = LocalPlayer.Character.HumanoidRootPart.Position
 local candidates = gatherTargets()
 local nearestModel, shortest = nil, math.huge
 for _, model in ipairs(candidates) do
  local checkPart = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
  if checkPart and checkPart:IsA("BasePart") then
   local d = (checkPart.Position - origin).Magnitude
   if d < shortest then
    shortest = d
    nearestModel = model
   end
  end
 end
 return nearestModel
end

-- Ragdoll detection helper: checks common ragdoll signals and custom BoolValues
local function isRagdolled(humanoid)
 if not humanoid then return false end
 if humanoid.Health <= 0 then return true end
 if humanoid.PlatformStand then return true end
 if humanoid.Sit then return true end

 local ok, state = pcall(function() return humanoid:GetState() end)
 if ok and state then
  if state == Enum.HumanoidStateType.FallingDown then
   return true
  end
  local ok2, _ = pcall(function() return Enum.HumanoidStateType.Physics end)
  if ok2 then
   local ok3, state2 = pcall(function() return humanoid:GetState() end)
   if ok3 and state2 == Enum.HumanoidStateType.Physics then
    return true
   end
  end
 end

 local parent = humanoid.Parent
 if parent then
  local rv = parent:FindFirstChild("Ragdoll") or parent:FindFirstChild("Ragdolled")
  if rv and rv:IsA("BoolValue") and rv.Value == true then
   return true
  end
 end

 return false
end

-- Main Camera Loop
RunService.RenderStepped:Connect(function()
 -- approach desired camera lerp alpha
 local desired = aimlockEnabled and targetLerpEnabled or targetLerpDisabled
 currentLerp = currentLerp + (desired - currentLerp) * lerpSpeed

 if aimlockEnabled then
  -- ensure we have a valid target; if not, acquire one
  if not target or not target.Parent or not target:FindFirstChildOfClass("Humanoid") or (target:FindFirstChildOfClass("Humanoid") and target:FindFirstChildOfClass("Humanoid").Health <= 0) then
   target = acquireNearestTarget()
   -- initialize aimPosSmoothed to avoid pop
   if target and LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
    local initPart = getNearestPartOfModel(target, LocalPlayer.Character.HumanoidRootPart.Position)
    if initPart then aimPosSmoothed = initPart.Position end
   end
  end

  -- if we have a valid target -> decide whether to aim at Head (vertical rule) or nearest part
  if target and LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
   local myHRP = LocalPlayer.Character.HumanoidRootPart
   local targetHead = target:FindFirstChild("Head")
   local targetHRP = target:FindFirstChild("HumanoidRootPart")
   -- determine vertical difference: use head if available, otherwise HRP
   local targetVerticalPos = nil
   if targetHead and targetHead:IsA("BasePart") then
    targetVerticalPos = targetHead.Position.Y
   elseif targetHRP and targetHRP:IsA("BasePart") then
    targetVerticalPos = targetHRP.Position.Y
   end

   local useHead = false
   if targetVerticalPos and (targetVerticalPos - myHRP.Position.Y) >= verticalHeadThreshold then
    -- target is verticalHeadThreshold studs or more above player: use head aiming
    if targetHead and targetHead:IsA("BasePart") then
     useHead = true
    else
     -- if head doesn't exist but vertical rule satisfied, fallback to nearest part
     useHead = false
    end
   end

   -- pick aim position
   local desiredAim
   if useHead then
    desiredAim = targetHead.Position
   else
    local nearestPart = getNearestPartOfModel(target, myHRP.Position)
    if nearestPart and nearestPart:IsA("BasePart") then
     desiredAim = nearestPart.Position
    else
    
Rayfield:Notify({
    Title = "Merebennie Hub",
    Content = "Loaded Successfully! ⚙️",
    Duration = 4
})



-- =========================
-- Touch Sensitivity (Rayfield Slider on Optimization Tab Only)
-- =========================

do
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")

    local player = Players.LocalPlayer

    local CONFIG = {
        MIN_SENSITIVITY = 0.1,
        MAX_SENSITIVITY = 10,
        DEFAULT_SENSITIVITY = 1,
        SAVE_FOLDER = "TouchSensitivity",
        SAVE_FILE = "settings.txt"
    }

    local hasFileSystem = pcall(function()
        return isfolder and makefolder and isfile and readfile and writefile
    end)

    local currentSensitivity = CONFIG.DEFAULT_SENSITIVITY
    local cameraInputModule = nil
    local hookActive = false

    if hasFileSystem then
        pcall(function()
            if not isfolder(CONFIG.SAVE_FOLDER) then
                makefolder(CONFIG.SAVE_FOLDER)
            end
            local filePath = CONFIG.SAVE_FOLDER .. "/" .. CONFIG.SAVE_FILE
            if isfile(filePath) then
                local saved = tonumber(readfile(filePath))
                if saved then currentSensitivity = saved end
            end
        end)
    end

    local function saveSettings(value)
        if hasFileSystem then
            pcall(function()
                writefile(CONFIG.SAVE_FOLDER .. "/" .. CONFIG.SAVE_FILE, tostring(value))
            end)
        end
    end

    local function setupCameraHook()
        local success = false
        pcall(function()
            local playerScripts = player:FindFirstChild("PlayerScripts")
            if not playerScripts then return end

            local playerModule = playerScripts:FindFirstChild("PlayerModule")
            if not playerModule then return end

            local cameraModule = playerModule:FindFirstChild("CameraModule")
            if cameraModule then
                local cameraInput = cameraModule:FindFirstChild("CameraInput")
                if cameraInput then
                    local ok, req = pcall(function() return require(cameraInput) end)
                    if ok and req and req.getRotation then
                        cameraInputModule = req
                        local originalGetRotation = cameraInputModule.getRotation
                        cameraInputModule.getRotation = function(disableRotation)
                            local rotation = originalGetRotation(disableRotation)
                            if UserInputService.TouchEnabled then
                                return rotation * currentSensitivity
                            end
                            return rotation
                        end
                        success = true
                        hookActive = true
                    end
                end
            end
        end)

        if not success then
            pcall(function()
                local oldIndex
                oldIndex = hookmetamethod(game, "__index", function(self, key)
                    if self == UserInputService and key == "MouseDelta" and UserInputService.TouchEnabled then
                        local original = oldIndex(self, key)
                        return original * currentSensitivity
                    end
                    return oldIndex(self, key)
                end)
                success = true
                hookActive = true
            end)
        end
        return success
    end

    local function applySensitivity(value)
        currentSensitivity = math.clamp(value, CONFIG.MIN_SENSITIVITY, CONFIG.MAX_SENSITIVITY)
        saveSettings(currentSensitivity)
        pcall(function()
            print("[TouchSensitivity] Applied sensitivity:", currentSensitivity)
        end)
    end

    local cameraHooked = setupCameraHook()
    applySensitivity(currentSensitivity)

    -- Create Rayfield slider only on Optimization tab
    pcall(function()
        if Tab and Tab.CreateSlider then
            Tab:CreateSlider({
                Name = "Sensitivity",
                Range = {CONFIG.MIN_SENSITIVITY, CONFIG.MAX_SENSITIVITY},
                Increment = 0.1,
                CurrentValue = currentSensitivity,
                Flag = "TouchSensitivity",
                Callback = function(value)
                    applySensitivity(value)
                    pcall(function()
                        Rayfield:Notify({
                            Title = "Touch Sensitivity",
                            Content = "Set to " .. tostring(value),
                            Duration = 1.5
                        })
                    end)
                end
            })
        else
            warn("[TouchSensitivity] Optimization Tab not found. Make sure 'Tab' is defined.")
        end
    end)
end
