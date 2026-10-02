-- Paraware Glass | WindUI universal hub
-- Exporter: UniversalSynSaveInstance https://discord.gg/wx4ThpAsmw
-- License: https://github.com/luau/UniversalSynSaveInstance/blob/main/LICENSE
-- Edit the registry below to add your own game modules. No game-specific modules ship here.
local Config = {
    LogoAsset = "rbxassetid://101729681688072", -- Your supplied PW logo.
    LogoFile = "paraware-logo.png", -- Relative to the executor's workspace folder.
    ToggleKey = Enum.KeyCode.RightShift,
    FlyKey = Enum.KeyCode.F,
    WindUIUrl = "https://raw.githubusercontent.com/Footagesus/WindUI/7dd8a34a6bb59635c7b5f18ce9d46558a8cde138/dist/main.lua",
    ExporterUrl = "https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/a6c93592f03791e6971261ee5586fba0a367b4b4/saveinstance.luau",
}
local embeddedLogo

local GameModules = { Places = {}, Universes = {} }
-- GameModules.Places[123456789] = { Name = "My game", Build = function(context) ... end }
-- Build receives Window, WindUI, Tab, Player, Log, Connect, OnCleanup, PlaceId, and UniverseId.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Marketplace = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")
local Player = Players.LocalPlayer
assert(Player, "Paraware must run on the Roblox client.")

local env = (getgenv and getgenv()) or _G
local previous = env.ParawareSession
if previous and type(previous.Unload) == "function" then
    previous.Unload()
    task.wait(0.65) -- WindUI destroys its GUI asynchronously.
end

local loaded, WindUI = pcall(function()
    return loadstring(game:HttpGet(Config.WindUIUrl))()
end)
if not loaded or type(WindUI) ~= "table" then
    error("Paraware could not load WindUI. Check HTTP/loadstring support and retry. " .. tostring(WindUI))
end

local Session = { Alive = true }
env.ParawareSession = Session
local connections, cleanups, toggles = {}, {}, {}
local state = {
    SpeedEnabled = false, Speed = 32,
    JumpEnabled = false, JumpPower = 70, JumpHeight = 12,
    Fly = false, FlySpeed = 50, Altitude = "Level",
    InfiniteJump = false, Noclip = false,
    FovEnabled = false, Fov = 80, Fullbright = false,
    Picker = false, PickMode = "Nearest model",
}
local character, humanoid, root, baseline, flight
local collisions, cameraDefaults = {}, {}
local lightDefault
local windowFocused = true
local logs, console, characterStatus = {}, nil, nil
local Window
local pickerHighlight, exportStatus, exporter, exportBusy
local exportCounter = 0

local function decodeBase64(data)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local values, chunks = {}, {}
    for i = 1, #alphabet do values[alphabet:sub(i, i)] = i - 1 end
    data = data:gsub("%s", "")
    for i = 1, #data, 4 do
        local a, b, c, d = data:sub(i, i), data:sub(i + 1, i + 1), data:sub(i + 2, i + 2), data:sub(i + 3, i + 3)
        local n = values[a] * 262144 + values[b] * 4096 + (values[c] or 0) * 64 + (values[d] or 0)
        chunks[#chunks + 1] = string.char(math.floor(n / 65536) % 256)
            .. (c ~= "=" and string.char(math.floor(n / 256) % 256) or "")
            .. (d ~= "=" and string.char(n % 256) or "")
    end
    return table.concat(chunks)
end

local function resolveLogo()
    if Config.LogoAsset ~= "" then
        local asset = tostring(Config.LogoAsset)
        if asset:match("^%d+$") then asset = "rbxassetid://" .. asset end
        return asset, "PW logo: " .. asset
    end
    local customAsset = getcustomasset or getsynasset
    if type(customAsset) ~= "function" then return "", "Custom images unavailable. Showing PW text." end
    local ok, asset = pcall(function()
        -- Always refresh the file so a stale/missing local logo cannot hide the supplied artwork.
        if writefile and embeddedLogo then writefile(Config.LogoFile, decodeBase64(embeddedLogo)) end
        return customAsset(Config.LogoFile)
    end)
    if ok and type(asset) == "string" and asset ~= "" then return asset, "Embedded PW logo" end
    return "", "Logo could not load. Showing PW text."
end

local function connect(signal, fn)
    local connection = signal:Connect(function(...)
        if Session.Alive then fn(...) end
    end)
    table.insert(connections, connection)
    return connection
end

local function log(message)
    table.insert(logs, os.date("%H:%M:%S") .. "  " .. tostring(message))
    if #logs > 12 then table.remove(logs, 1) end
    if console and Session.Alive then console:SetDesc(table.concat(logs, "\n")) end
end

local function notify(message)
    log(message)
    if Session.Alive then
        WindUI:Notify({ Title = "Paraware", Content = message, Duration = 3 })
    end
end

local function restoreCollisions()
    for part, value in pairs(collisions) do
        if part.Parent then part.CanCollide = value end
    end
    collisions = {}
end

local function stopFlight()
    if not flight then return end
    for _, instance in ipairs(flight.Instances) do instance:Destroy() end
    if flight.Humanoid.Parent then
        flight.Humanoid.PlatformStand = flight.PlatformStand
        flight.Humanoid.AutoRotate = flight.AutoRotate
        if not flight.PlatformStand and flight.Humanoid.Health > 0 then
            flight.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
    if flight.Root.Parent then
        flight.Root.AssemblyLinearVelocity = Vector3.zero
        flight.Root.AssemblyAngularVelocity = Vector3.zero
    end
    flight = nil
end

local function restoreCharacter()
    stopFlight()
    restoreCollisions()
    if humanoid and humanoid.Parent and baseline then
        humanoid.WalkSpeed = baseline.Speed
        humanoid.JumpPower = baseline.JumpPower
        humanoid.JumpHeight = baseline.JumpHeight
    end
end

local function applyMovement()
    if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then return end
    if state.SpeedEnabled then humanoid.WalkSpeed = state.Speed end
    if state.JumpEnabled then
        if humanoid.UseJumpPower then
            humanoid.JumpPower = state.JumpPower
        else
            humanoid.JumpHeight = state.JumpHeight
        end
    end
end

local function startFlight()
    if flight or not root or not root.Parent or not humanoid or humanoid.Health <= 0 then return end
    local attachment = Instance.new("Attachment")
    attachment.Name = "ParawareFlightAttachment"
    attachment.Parent = root
    local velocity = Instance.new("LinearVelocity")
    velocity.Name = "ParawareFlightVelocity"
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    velocity.MaxForce = math.huge
    velocity.VectorVelocity = Vector3.zero
    velocity.Parent = root
    local orientation = Instance.new("AlignOrientation")
    orientation.Name = "ParawareFlightOrientation"
    orientation.Attachment0 = attachment
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.MaxTorque = math.huge
    orientation.Responsiveness = 20
    orientation.CFrame = root.CFrame.Rotation
    orientation.Parent = root
    flight = {
        Instances = { velocity, orientation, attachment },
        Velocity = velocity, Orientation = orientation,
        Root = root, Humanoid = humanoid,
        PlatformStand = humanoid.PlatformStand, AutoRotate = humanoid.AutoRotate,
    }
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
end

local function setFly(value)
    state.Fly = value
    state.Altitude = "Level"
    if value then startFlight() else stopFlight() end
    if not value and not state.Noclip then restoreCollisions() end
    log("Fly " .. (value and "enabled" or "disabled"))
end

local function setFov(value)
    state.FovEnabled = value
    if value then
        local camera = workspace.CurrentCamera
        if camera then
            if cameraDefaults[camera] == nil then cameraDefaults[camera] = camera.FieldOfView end
            camera.FieldOfView = state.Fov
        end
    else
        for camera, original in pairs(cameraDefaults) do
            if camera.Parent then camera.FieldOfView = original end
        end
        cameraDefaults = {}
    end
end

local function setFullbright(value)
    state.Fullbright = value
    if value then
        lightDefault = {
            Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
            Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        }
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
    elseif lightDefault then
        for key, original in pairs(lightDefault) do Lighting[key] = original end
        lightDefault = nil
    end
end

local function reset()
    state.SpeedEnabled, state.JumpEnabled = false, false
    state.Fly, state.InfiniteJump, state.Noclip = false, false, false
    state.Altitude = "Level"
    state.Picker = false
    if pickerHighlight then pickerHighlight.Adornee = nil end
    restoreCharacter()
    setFov(false)
    setFullbright(false)
    for _, toggle in pairs(toggles) do toggle:Set(false, false) end
    log("Restored character, collisions, camera, and lighting.")
end

local function cleanup()
    if not Session.Alive then return end
    Session.Alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    if pickerHighlight then pickerHighlight:Destroy(); pickerHighlight = nil end
    for i = #cleanups, 1, -1 do
        local ok, err = pcall(cleanups[i])
        if not ok then warn("[Paraware] Module cleanup: " .. tostring(err)) end
    end
    restoreCharacter()
    setFov(false)
    setFullbright(false)
    if env.ParawareSession == Session then env.ParawareSession = nil end
end

function Session.Unload()
    cleanup()
    if Window and not Window.Destroyed then Window:Destroy() end
end

local function bindCharacter(newCharacter)
    if not Session.Alive or Player.Character ~= newCharacter then return end
    restoreCharacter()
    character, humanoid, root, baseline = newCharacter, nil, nil, nil
    if characterStatus then characterStatus:SetDesc("Waiting for your character...") end
    local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
    local newRoot = newCharacter:WaitForChild("HumanoidRootPart", 10)
    -- An older spawn may finish waiting after a newer CharacterAdded event.
    if not Session.Alive or Player.Character ~= newCharacter or character ~= newCharacter then return end
    if not newHumanoid or not newRoot then
        log("Character has no standard Humanoid/root. Movement controls are unavailable.")
        if characterStatus then characterStatus:SetDesc("Unsupported character rig. Respawn to retry.") end
        return
    end
    humanoid, root = newHumanoid, newRoot
    baseline = {
        Speed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight,
    }
    applyMovement()
    if state.Fly then startFlight() end
    if characterStatus then characterStatus:SetDesc("Character ready. Enabled controls apply after respawning.") end
    log("Character ready: " .. (humanoid.UseJumpPower and "jump power" or "jump height") .. " mode.")
end

local function exportMessage(title, detail)
    if exportStatus and Session.Alive then
        exportStatus:SetTitle(title)
        exportStatus:SetDesc(detail)
    end
end

local function overHub(position)
    if not Window or Window.Closed or not Window.UIElements then return false end
    local frame = Window.UIElements.Main
    if not frame.AbsolutePosition or not frame.AbsoluteSize then return false end
    local origin, size = frame.AbsolutePosition, frame.AbsoluteSize
    return position.X >= origin.X and position.X <= origin.X + size.X
        and position.Y >= origin.Y and position.Y <= origin.Y + size.Y
end

local function pickObject(position)
    if overHub(position) then return nil end
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local inset = GuiService:GetGuiInset()
    local ray = camera:ViewportPointToRay(position.X - inset.X, position.Y - inset.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = Player.Character and { Player.Character } or {}
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
    if not hit or hit.Instance:IsA("Terrain") then return nil end
    local target = hit.Instance
    if state.PickMode == "Nearest model" then
        target = target:FindFirstAncestorOfClass("Model") or target
    end
    return target
end

local function exportObject(target)
    if exportBusy or not target or not target.Parent then return end
    if not writefile then
        exportMessage("Export unavailable", "Your runtime needs writefile to save .rbxm files.")
        notify("Object export requires writefile.")
        return
    end
    exportBusy = true
    local name = target.Name
    exportMessage("Preparing " .. name, "Loading the model exporter. Keep the object loaded.")
    task.spawn(function()
        local wrote, path = false, nil
        local ok, err = pcall(function()
            if not exporter then
                exporter = loadstring(game:HttpGet(Config.ExporterUrl), "ParawareExporter")()
                assert(type(exporter) == "function", "Exporter did not return a function")
            end
            if not Session.Alive then return end
            local safeName = name:gsub("[^%w_-]", "_"):sub(1, 48)
            if safeName == "" then safeName = "object" end
            local prefix = "Paraware-"
            if makefolder then
                local made = pcall(function()
                    if not isfolder or not isfolder("Paraware-Exports") then makefolder("Paraware-Exports") end
                end)
                if made then prefix = "Paraware-Exports/" end
            end
            repeat
                exportCounter = exportCounter + 1
                path = prefix .. safeName .. "-" .. os.date("%Y%m%d-%H%M%S") .. "-" .. exportCounter .. ".rbxm"
            until not isfile or not isfile(path)
            exportMessage("Saving " .. name, "Serializing this object and its loaded descendants...")
            exporter({
                Object = target, IsModel = true, mode = "full", Binary = true, CompressionMode = false,
                Decompile = false, SaveBytecode = false, ReadMe = false,
                IgnoreList = { "Script", "LocalScript", "ModuleScript" },
                SafeMode = false, KillAllScripts = false, BoostFPS = false,
                ShutdownWhenDone = false, AntiIdle = false, ShowStatus = false,
                SavePlayerCharacters = true, IgnoreDefaultPlayerScripts = false,
                FilePath = path,
                Callback = function(data)
                    if not Session.Alive then return end
                    assert(type(data) == "string" and data:sub(1, 8) == "<roblox!", "Exporter returned invalid binary model data")
                    writefile(path, data)
                    if isfile then assert(isfile(path), "Runtime did not create the output file") end
                    if readfile then
                        local saved = readfile(path)
                        assert(#saved == #data and saved:sub(1, 8) == "<roblox!", "Output file failed verification")
                    end
                    wrote = true
                end,
            })
            assert(wrote or not Session.Alive, "Exporter produced no file. It may be busy or unsupported by this runtime.")
        end)
        exportBusy = false
        if not Session.Alive then return end
        if ok and wrote then
            exportMessage("Model saved", path .. "\nOpen this .rbxm in Roblox Studio.")
            notify("Saved " .. path)
        else
            exportMessage("Export failed", tostring(err) .. "\nCheck runtime support, then click the object again.")
            log("Export failed: " .. tostring(err))
        end
    end)
end

local function build()
    WindUI:AddTheme({
        Name = "Paraware",
        Accent = Color3.fromHex("#242424"), Background = Color3.fromHex("#090909"),
        Dialog = Color3.fromHex("#161616"), Outline = Color3.fromHex("#B8B8B8"),
        Text = Color3.fromHex("#F5F5F5"), Placeholder = Color3.fromHex("#BDBDBD"),
        Button = Color3.fromHex("#303030"), Icon = Color3.fromHex("#E7E7E7"),
        Toggle = Color3.fromHex("#F5F5F5"), Slider = Color3.fromHex("#F5F5F5"),
        Checkbox = Color3.fromHex("#F5F5F5"), Primary = Color3.fromHex("#F5F5F5"),
        SliderIcon = Color3.fromHex("#656565"),
        PanelBackground = Color3.fromHex("#181818"), PanelBackgroundTransparency = 0.08,
        ElementBackground = Color3.fromHex("#1D1D1D"), ElementBackgroundTransparency = 0,
        LabelBackground = Color3.fromHex("#303030"), LabelBackgroundTransparency = 0,
        SectionBox = Color3.fromHex("#121212"), SectionBoxTransparency = 0,
        SectionBoxBorder = Color3.fromHex("#B8B8B8"), SectionBoxBorderTransparency = 0.85,
        SectionTitle = Color3.fromHex("#F5F5F5"),
        SectionDesc = Color3.fromHex("#BDBDBD"), SectionDescTransparency = 0,
        TabBackgroundActive = Color3.fromHex("#383838"), TabBackgroundActiveTransparency = 0,
        TabBackgroundHover = Color3.fromHex("#292929"), TabBackgroundHoverTransparency = 0,
        TabTextTransparency = 0.15, TabTextTransparencyActive = 0,
    })
    local logo, logoStatus = resolveLogo()
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
    local width = viewport and math.clamp(viewport.X - 32, 320, 920) or 920
    local height = viewport and math.clamp(viewport.Y - 64, 300, 600) or 600
    local sidebarWidth = width < 680 and 125 or 180
    Window = WindUI:CreateWindow({
        Title = "Paraware", Author = "Glass edition", Icon = logo,
        IconSize = 24, IconThemed = false, IconRadius = 6,
        Theme = "Paraware", Folder = "Paraware", Size = UDim2.fromOffset(width, height),
        MinSize = Vector2.new(math.min(width, 520), 300), MaxSize = Vector2.new(1120, 800),
        SideBarWidth = sidebarWidth, Radius = 18, ElementsRadius = 10, NewElements = false,
        Transparent = true, Acrylic = true, AutoScale = false, HideSearchBar = true,
        HidePanelBackground = false,
        ToggleKey = Config.ToggleKey, Topbar = { Height = 50, ButtonsType = "Default" },
        OpenButton = {
            Title = "Paraware", Enabled = true, Draggable = true, OnlyMobile = false,
            CornerRadius = UDim.new(0, 16), StrokeThickness = 1,
            Color = ColorSequence.new(Color3.fromHex("#CFCFCF"), Color3.fromHex("#FFFFFF")),
        },
    })
    Window:OnDestroy(cleanup)

    local home = Window:Tab({ Title = "Controls", Icon = "sliders-horizontal" })
    local assets = Window:Tab({ Title = "Object export", Icon = "box" })
    local settings = Window:Tab({ Title = "Session", Icon = "settings" })
    if Window.UIElements then
        Window.UIElements.SideBarContainer.Visible = true
        local background = Window.UIElements.Main:FindFirstChild("Background")
        if background then
            local sheen = Instance.new("UIGradient")
            sheen.Rotation = 115
            sheen.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(155, 155, 155))
            sheen.Parent = background
        end
        local rim = Instance.new("UIStroke")
        rim.Color = Color3.fromRGB(238, 238, 238)
        rim.Transparency = 0.66
        rim.Thickness = 1
        rim.Parent = Window.UIElements.Main
    end

    local detected = GameModules.Places[game.PlaceId] or GameModules.Universes[game.GameId]
    local gameInfo = home:Paragraph({
        Title = "Detecting game...",
        Desc = "Place: " .. game.PlaceId .. "\nUniverse: " .. game.GameId,
        Image = game.GameId > 0 and ("rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150") or nil,
        ImageSize = 52,
    })
    characterStatus = settings:Paragraph({ Title = "Character", Desc = "Waiting for your character..." })
    if logo == "" then home:Paragraph({ Title = "PW / Paraware", Desc = logoStatus }) end

    local function toggle(tab, key, title, desc, callback)
        toggles[key] = tab:Toggle({ Title = title, Desc = desc, Value = false, Callback = callback })
    end
    local function slider(tab, title, desc, min, max, default, callback)
        return tab:Slider({
            Title = title, Desc = desc, Step = 1, IsTextbox = true,
            Value = { Min = min, Max = max, Default = default },
            Callback = function(value)
                local number = tonumber(value)
                if number and number == number then callback(math.clamp(number, min, max)) end
            end,
        })
    end

    local movement = home:Section({ Title = "Movement", Icon = "user", Opened = true, Box = true })
    toggle(movement, "Speed", "Custom speed", "Turn off to restore your character's original speed.", function(value)
        if value and not state.SpeedEnabled and humanoid and baseline then baseline.Speed = humanoid.WalkSpeed end
        state.SpeedEnabled = value
        if not value and humanoid and baseline then humanoid.WalkSpeed = baseline.Speed end
        applyMovement(); log("Custom speed " .. tostring(value))
    end)
    slider(movement, "Walk speed", "Studs per second", 0, 150, state.Speed, function(value) state.Speed = value; applyMovement() end)
    toggle(movement, "Jump", "Custom jump", "Uses the character's existing jump mode.", function(value)
        if value and not state.JumpEnabled and humanoid and baseline then
            baseline.JumpPower, baseline.JumpHeight = humanoid.JumpPower, humanoid.JumpHeight
        end
        state.JumpEnabled = value
        if not value and humanoid and baseline then
            humanoid.JumpPower, humanoid.JumpHeight = baseline.JumpPower, baseline.JumpHeight
        end
        applyMovement(); log("Custom jump " .. tostring(value))
    end)
    slider(movement, "Jump power", "For characters with UseJumpPower enabled", 0, 200, state.JumpPower, function(value) state.JumpPower = value; applyMovement() end)
    slider(movement, "Jump height", "For characters with UseJumpPower disabled", 0, 50, state.JumpHeight, function(value) state.JumpHeight = value; applyMovement() end)
    toggle(movement, "InfiniteJump", "Infinite jump", "Jump again while airborne.", function(value) state.InfiniteJump = value; log("Infinite jump " .. tostring(value)) end)
    toggle(movement, "Noclip", "Noclip", "Pass through collidable parts. Turning off restores collisions.", function(value)
        state.Noclip = value
        if not value and not state.Fly then restoreCollisions() end
        log("Noclip " .. tostring(value))
    end)

    local flyTab = home:Section({ Title = "Flight", Icon = "plane", Opened = false, Box = true })
    flyTab:Paragraph({ Title = "Flight controls", Desc = "F toggles fly. WASD or thumbstick moves. E/Space rises; Q/Left Ctrl descends." })
    toggle(flyTab, "Fly", "Fly", "F toggles flight when you're not typing.", setFly)
    slider(flyTab, "Fly speed", "Studs per second", 5, 200, state.FlySpeed, function(value) state.FlySpeed = value end)
    flyTab:Button({ Title = "Rise", Desc = "Touch control: rise until you press Hold altitude.", Callback = function()
        if not state.Fly then notify("Enable Fly first."); return end
        state.Altitude = "Rise"; log("Flight: rising")
    end })
    flyTab:Button({ Title = "Hold altitude", Callback = function() state.Altitude = "Level"; log("Flight: level") end })
    flyTab:Button({ Title = "Descend", Desc = "Touch control: descend until you press Hold altitude.", Callback = function()
        if not state.Fly then notify("Enable Fly first."); return end
        state.Altitude = "Descend"; log("Flight: descending")
    end })
    flyTab:Button({ Title = "Stop flight", Callback = function() setFly(false); toggles.Fly:Set(false, false) end })

    local visual = home:Section({ Title = "Camera & world", Icon = "eye", Opened = false, Box = true })
    toggle(visual, "Fov", "Custom field of view", "Turn off to restore each camera's original field of view.", function(value) setFov(value); log("Custom FOV " .. tostring(value)) end)
    slider(visual, "Field of view", "Degrees", 40, 120, state.Fov, function(value) state.Fov = value; if state.FovEnabled then setFov(true) end end)
    visual:Button({ Title = "Reset camera to player", Callback = function()
        local camera = workspace.CurrentCamera
        if not camera or not humanoid then notify("Character or camera unavailable."); return end
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
        notify("Camera returned to your character.")
    end })
    toggle(visual, "Fullbright", "Fullbright", "Local daylight and reduced shadows. Off restores captured lighting.", function(value)
        if value ~= state.Fullbright then setFullbright(value) end
        log("Fullbright " .. tostring(value))
    end)

    assets:Paragraph({ Title = "Click to save a model", Desc = "Enable the picker, then click or tap an object in the world. Saves the selected object and loaded descendants as a binary .rbxm model." })
    toggle(assets, "Picker", "Object picker", "Highlights the target under your cursor. Clicking exports it.", function(value)
        state.Picker = value
        if not value and pickerHighlight then pickerHighlight.Adornee = nil end
        exportMessage(value and "Picker ready" or "Picker off", value and "Click an object outside the hub to save it." or "Enable the picker to choose an object.")
        log("Object picker " .. tostring(value))
    end)
    assets:Dropdown({ Title = "Selection", Values = { "Nearest model", "Clicked part" }, Value = state.PickMode,
        Callback = function(value) state.PickMode = value end })
    exportStatus = assets:Paragraph({ Title = "Picker off", Desc = "Enable the picker to choose an object." })
    assets:Paragraph({ Title = "Exporter", Desc = "UniversalSynSaveInstance https://discord.gg/wx4ThpAsmw\nExports loaded client objects. Scripts are excluded. Files are written to your executor's workspace." })

    local consoleTab = settings
    console = consoleTab:Paragraph({ Title = "Session log", Desc = "No actions yet. Changes and errors appear here." })
    consoleTab:Button({ Title = "Clear console", Callback = function() logs = {}; console:SetDesc("Console cleared. New actions will appear here.") end })
    consoleTab:Button({ Title = "Copy log", Callback = function()
        if not setclipboard then notify("Clipboard isn't supported by this runtime."); return end
        local ok = pcall(setclipboard, table.concat(logs, "\n"))
        notify(ok and "Log copied." or "Could not copy the log.")
    end })
    settings:Paragraph({ Title = "Shortcuts", Desc = "Right Shift: show/hide\nF: toggle fly\n" .. logoStatus })
    settings:Button({ Title = "Copy game IDs", Callback = function()
        if not setclipboard then notify("Clipboard isn't supported by this runtime."); return end
        local ok = pcall(setclipboard, "PlaceId = " .. game.PlaceId .. "\nGameId = " .. game.GameId)
        notify(ok and "Game IDs copied." or "Could not copy game IDs.")
    end })
    settings:Button({ Title = "Restore all controls", Callback = function() reset(); notify("All controls restored.") end })
    settings:Button({ Title = "Unload Paraware", Desc = "Restore values, stop flight, and disconnect the hub.", Callback = Session.Unload })
    if detected then
        local gameTab = home:Section({ Title = detected.Name or "Game module", Opened = false, Box = true })
        gameTab:Paragraph({ Title = detected.Name or "Detected module", Desc = "This module was selected by the current place or universe ID." })
        local ok, err = pcall(detected.Build, {
            Window = Window, WindUI = WindUI, Tab = gameTab, Player = Player, Log = log,
            Connect = connect, OnCleanup = function(fn) assert(type(fn) == "function"); table.insert(cleanups, fn) end,
            PlaceId = game.PlaceId, UniverseId = game.GameId,
        })
        if not ok then
            gameTab:Paragraph({ Title = "Module failed", Desc = "Universal controls remain available. Check Console for details." })
            log("Module error: " .. tostring(err))
        end
    end
    home:Select()
    task.spawn(function()
        local ok, info = pcall(Marketplace.GetProductInfo, Marketplace, game.PlaceId)
        if not Session.Alive then return end
        gameInfo:SetTitle(ok and info.Name or ("Place " .. game.PlaceId))
        gameInfo:SetDesc("Place: " .. game.PlaceId .. "\nUniverse: " .. game.GameId .. "\nModule: " .. (detected and (detected.Name or "Registered module") or "Universal") .. (ok and "" or "\nGame name unavailable; detection uses IDs."))
        log(ok and ("Detected " .. info.Name) or "Game name lookup failed. ID detection remains available.")
    end)
end

-- EMBEDDED_LOGO_DATA
local built, buildError = pcall(build)
if not built then
    Session.Unload()
    error("Paraware UI failed to initialize: " .. tostring(buildError))
end

connect(Player.CharacterAdded, function(newCharacter) task.spawn(bindCharacter, newCharacter) end)
connect(Player.CharacterRemoving, function(oldCharacter)
    if oldCharacter == character then
        restoreCharacter()
        character, humanoid, root, baseline = nil, nil, nil, nil
        characterStatus:SetDesc("Respawning. Waiting for your character...")
    end
end)
if Player.Character then task.spawn(bindCharacter, Player.Character) end

connect(Input.InputBegan, function(input, processed)
    if processed or Input:GetFocusedTextBox() then return end
    if state.Picker and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local target = pickObject(input.Position)
        if target then exportObject(target) else exportMessage("No object selected", "Click a loaded object within reach. Terrain is not supported.") end
        return
    end
    if input.KeyCode == Config.FlyKey then
        setFly(not state.Fly)
        toggles.Fly:Set(state.Fly, false)
    end
end)
connect(Input.TouchTapInWorld, function(position, processed)
    if processed or not state.Picker or Input:GetFocusedTextBox() then return end
    local target = pickObject(position)
    if target then exportObject(target) else exportMessage("No object selected", "Tap a loaded object. Terrain is not supported.") end
end)
pickerHighlight = Instance.new("Highlight")
pickerHighlight.Name = "ParawareObjectPicker"
pickerHighlight.FillColor = Color3.fromHex("#FFFFFF")
pickerHighlight.OutlineColor = Color3.fromHex("#FFFFFF")
pickerHighlight.FillTransparency = 0.85
pickerHighlight.OutlineTransparency = 0.15
pickerHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
pickerHighlight.Parent = workspace
connect(RunService.RenderStepped, function()
    if not pickerHighlight then return end
    if state.Picker and windowFocused and not Input:GetFocusedTextBox() and Input.MouseEnabled then
        pickerHighlight.Adornee = pickObject(Input:GetMouseLocation())
    else
        pickerHighlight.Adornee = nil
    end
end)
connect(Input.JumpRequest, function()
    if state.InfiniteJump and not state.Fly and not Input:GetFocusedTextBox() and humanoid and humanoid.Health > 0 then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
connect(Input.WindowFocusReleased, function() windowFocused = false; state.Altitude = "Level" end)
connect(Input.WindowFocused, function() windowFocused = true end)
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    if state.FovEnabled then setFov(true) end
end)
connect(RunService.PreSimulation, function()
    applyMovement()
    if (state.Noclip or state.Fly) and character and humanoid and humanoid.Health > 0 then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if collisions[part] == nil then collisions[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end
end)
connect(RunService.RenderStepped, function()
    if not state.Fly then return end
    if not humanoid or humanoid.Health <= 0 or not root or not root.Parent then
        stopFlight(); restoreCollisions(); return
    end
    if not flight then startFlight() end
    if not flight then return end
    local camera = workspace.CurrentCamera
    local direction = Vector3.zero
    local vertical = 0
    if windowFocused and not Input:GetFocusedTextBox() then
        direction = humanoid.MoveDirection
        -- Keyboard flight works even if the game's character controller disables MoveDirection.
        if camera and Input.KeyboardEnabled then
            local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
            local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
            if forward.Magnitude > 0.001 then forward = forward.Unit end
            if right.Magnitude > 0.001 then right = right.Unit end
            local keyboard = Vector3.zero
            if Input:IsKeyDown(Enum.KeyCode.W) then keyboard = keyboard + forward end
            if Input:IsKeyDown(Enum.KeyCode.S) then keyboard = keyboard - forward end
            if Input:IsKeyDown(Enum.KeyCode.D) then keyboard = keyboard + right end
            if Input:IsKeyDown(Enum.KeyCode.A) then keyboard = keyboard - right end
            if keyboard.Magnitude > 0 then direction = keyboard end
        end
        vertical = state.Altitude == "Rise" and 1 or (state.Altitude == "Descend" and -1 or 0)
        if Input:IsKeyDown(Enum.KeyCode.E) or Input:IsKeyDown(Enum.KeyCode.Space) then vertical = vertical + 1 end
        if Input:IsKeyDown(Enum.KeyCode.Q) or Input:IsKeyDown(Enum.KeyCode.LeftControl) then vertical = vertical - 1 end
    end
    local velocity = Vector3.new(direction.X, vertical, direction.Z)
    if velocity.Magnitude > 1 then velocity = velocity.Unit end
    flight.Velocity.VectorVelocity = velocity * state.FlySpeed
    if camera then flight.Orientation.CFrame = camera.CFrame.Rotation end
end)
log("Paraware loaded. Right Shift opens or hides the hub.")
