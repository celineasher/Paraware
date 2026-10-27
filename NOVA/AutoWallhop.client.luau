--[[
    NOVA / AUTO WALLHOP
    Roblox Studio • LocalScript • StarterPlayer > StarterPlayerScripts

    This is a game-side assisted wall-jump mechanic for an experience you develop.
    It is NOT a universal executor script or an implementation of the
    camera-flick collision glitch used in some third-party obbies.

    Keybinds:
       G          Toggle assistance
       RightShift Collapse / expand interface

    Notes:
      • Works with R6 and R15; uses HumanoidRootPart.
      • Client-owned default player characters will respond to velocity changes.
      • For competitive published games, validate wallhop requests on the server.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local existing = playerGui:FindFirstChild("NOVA_Wallhop")
if existing then existing:Destroy() end

-- User settings
local settings = {
    enabled = true,
    power = 68,                 -- 0–100
    distance = 4.0,            -- 2.0–6.0 studs
    maxChain = 3,              -- 1–3 airborne hops
    cooldown = 0.27,           -- seconds between hops
    scanInterval = 0.045,      -- seconds between wall queries
}

-- Visual palette
local C = {
    bg = Color3.fromRGB(10, 14, 22),
    panel = Color3.fromRGB(17, 23, 33),
    elevated = Color3.fromRGB(24, 32, 44),
    inset = Color3.fromRGB(13, 19, 28),
    border = Color3.fromRGB(48, 61, 74),
    white = Color3.fromRGB(240, 250, 255),
    muted = Color3.fromRGB(137, 155, 169),
    subtle = Color3.fromRGB(94, 112, 126),
    accent = Color3.fromRGB(100, 241, 201),
    accent2 = Color3.fromRGB(79, 190, 234),
    off = Color3.fromRGB(94, 105, 119),
    warning = Color3.fromRGB(255, 201, 107),
}

local function create(className, parent, properties)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        instance[property] = value
    end
    instance.Parent = parent
    return instance
end

local function corners(parent, radius)
    return create("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function outline(parent, color, transparency, thickness)
    return create("UIStroke", parent, {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = color or C.border,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
    })
end

local function gradient(parent, first, second, rotation)
    return create("UIGradient", parent, {
        Color = ColorSequence.new(first, second),
        Rotation = rotation or 90,
    })
end

local function label(parent, content, position, size, fontSize, color, bold)
    return create("TextLabel", parent, {
        BackgroundTransparency = 1,
        Text = content,
        Position = position,
        Size = size,
        Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
        TextSize = fontSize,
        TextColor3 = color or C.white,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
end

local function animate(object, props, duration, ease)
    local tween = TweenService:Create(object, TweenInfo.new(
        duration or 0.2,
        ease or Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    ), props)
    tween:Play()
    return tween
end

-- Main player GUI
local screen = create("ScreenGui", playerGui, {
    Name = "NOVA_Wallhop",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 50,
})

local scale = create("UIScale", nil, { Scale = 1 })
local main = create("Frame", screen, {
    Name = "Dashboard",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -24, 0.5, 0),
    Size = UDim2.fromOffset(400, 566),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    ClipsDescendants = false,
})
scale.Parent = main
corners(main, 20)
outline(main, C.border, 0.14, 1)
gradient(main, C.panel, C.bg, 115)

-- Subtle layered shadow (behind main)
local shadow = create("Frame", screen, {
    Name = "BackdropShadow",
    AnchorPoint = main.AnchorPoint,
    Position = main.Position + UDim2.fromOffset(0, 7),
    Size = main.Size,
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.58,
    BorderSizePixel = 0,
    ZIndex = 0,
})
corners(shadow, 22)
local shadowScale = create("UIScale", shadow, { Scale = 1 })
main.ZIndex = 2

-- Interface header
local header = create("Frame", main, {
    Name = "DragHeader",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 0, 88),
    BackgroundTransparency = 1,
    Active = true,
})

local logo = create("Frame", header, {
    Position = UDim2.fromOffset(22, 20),
    Size = UDim2.fromOffset(46, 46),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
})
corners(logo, 13)
gradient(logo, C.accent, C.accent2, 135)
local logoLetter = label(logo, "N", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 25, C.bg, true)
logoLetter.TextXAlignment = Enum.TextXAlignment.Center

label(header, "NOVA", UDim2.fromOffset(81, 20), UDim2.fromOffset(160, 30), 23, C.white, true)
local subtitle = label(header, "W A L L H O P   E N G I N E", UDim2.fromOffset(82, 47), UDim2.fromOffset(220, 17), 9, C.muted)

local collapseButton = create("TextButton", header, {
    Name = "Collapse",
    Position = UDim2.fromOffset(342, 26),
    Size = UDim2.fromOffset(34, 34),
    BackgroundColor3 = C.elevated,
    Text = "−",
    Font = Enum.Font.GothamBold,
    TextSize = 23,
    TextColor3 = C.muted,
    AutoButtonColor = false,
    BorderSizePixel = 0,
})
corners(collapseButton, 10)
outline(collapseButton, C.border, 0.4)

create("Frame", main, {
    Position = UDim2.fromOffset(22, 85),
    Size = UDim2.fromOffset(356, 1),
    BackgroundColor3 = C.border,
    BackgroundTransparency = 0.52,
    BorderSizePixel = 0,
})

-- Hero control
local hero = create("Frame", main, {
    Name = "PowerCard",
    Position = UDim2.fromOffset(22, 101),
    Size = UDim2.fromOffset(356, 107),
    BackgroundColor3 = C.elevated,
    BorderSizePixel = 0,
})
corners(hero, 15)
outline(hero, C.border, 0.4)
gradient(hero, C.elevated, C.panel, 0)

local heroIconBox = create("Frame", hero, {
    Position = UDim2.fromOffset(15, 17),
    Size = UDim2.fromOffset(51, 51),
    BackgroundColor3 = C.accent,
    BackgroundTransparency = 0.87,
    BorderSizePixel = 0,
})
corners(heroIconBox, 13)
local heroGlyph = label(heroIconBox, "↗", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 31, C.accent, true)
heroGlyph.TextXAlignment = Enum.TextXAlignment.Center

label(hero, "AUTO WALLHOP", UDim2.fromOffset(79, 17), UDim2.fromOffset(200, 24), 15, C.white, true)
label(hero, "Proximity-based movement assist", UDim2.fromOffset(79, 42), UDim2.fromOffset(225, 19), 10, C.muted)

local statusDot = create("Frame", hero, {
    Position = UDim2.fromOffset(81, 78),
    Size = UDim2.fromOffset(7, 7),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
})
corners(statusDot, 5)
local statusText = label(hero, "SYSTEM ARMED", UDim2.fromOffset(96, 71), UDim2.fromOffset(164, 22), 10, C.accent, true)

local toggle = create("TextButton", hero, {
    Name = "EnableSwitch",
    Position = UDim2.fromOffset(281, 21),
    Size = UDim2.fromOffset(56, 32),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
})
corners(toggle, 16)
local toggleKnob = create("Frame", toggle, {
    Position = UDim2.fromOffset(27, 4),
    Size = UDim2.fromOffset(24, 24),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
})
corners(toggleKnob, 13)

-- Realtime scanner card
local scanner = create("Frame", main, {
    Position = UDim2.fromOffset(22, 220),
    Size = UDim2.fromOffset(356, 89),
    BackgroundColor3 = C.inset,
    BorderSizePixel = 0,
})
corners(scanner, 14)
outline(scanner, C.border, 0.55)
label(scanner, "PROXIMITY SENSOR", UDim2.fromOffset(16, 11), UDim2.fromOffset(190, 21), 10, C.muted, true)
local scanState = label(scanner, "SEARCHING", UDim2.fromOffset(16, 30), UDim2.fromOffset(230, 28), 17, C.white, true)
local scanDistance = label(scanner, "-- STUDS", UDim2.fromOffset(252, 30), UDim2.fromOffset(87, 28), 10, C.muted, true)
scanDistance.TextXAlignment = Enum.TextXAlignment.Right

local meter = create("Frame", scanner, {
    Position = UDim2.fromOffset(16, 72),
    Size = UDim2.fromOffset(324, 4),
    BackgroundColor3 = C.elevated,
    BorderSizePixel = 0,
})
corners(meter, 3)
local meterFill = create("Frame", meter, {
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
})
corners(meterFill, 3)
gradient(meterFill, C.accent2, C.accent, 0)

-- Parameter sliders
local sliderRefs = {}
local function makeSlider(title, y, minVal, maxVal, initial, formatValue, onChange)
    label(main, title, UDim2.fromOffset(23, y), UDim2.fromOffset(230, 23), 11, C.muted, true)
    local valueLabel = label(main, formatValue(initial), UDim2.fromOffset(289, y), UDim2.fromOffset(87, 23), 11, C.accent, true)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local bar = create("Frame", main, {
        Active = true,
        Position = UDim2.fromOffset(25, y + 36),
        Size = UDim2.fromOffset(348, 9),
        BackgroundColor3 = C.elevated,
        BorderSizePixel = 0,
    })
    corners(bar, 5)
    local fill = create("Frame", bar, {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    })
    corners(fill, 5)
    gradient(fill, C.accent2, C.accent, 0)
    local thumb = create("Frame", bar, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(19, 19),
        BackgroundColor3 = C.white,
        BorderSizePixel = 0,
    })
    corners(thumb, 10)
    outline(thumb, C.accent, 0, 2)

    local sliding = false
    local function setValue(value)
        value = math.clamp(value, minVal, maxVal)
        local fraction = (value - minVal) / (maxVal - minVal)
        fill.Size = UDim2.fromScale(fraction, 1)
        thumb.Position = UDim2.fromScale(fraction, 0.5)
        valueLabel.Text = formatValue(value)
        onChange(value)
    end
    local function updateFromX(x)
        local width = math.max(bar.AbsoluteSize.X, 1)
        local fraction = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
        setValue(minVal + (maxVal - minVal) * fraction)
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateFromX(input.Position.X)
        end
    end)
    table.insert(sliderRefs, {
        update = function(input)
            if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromX(input.Position.X)
            end
        end,
        release = function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = false
            end
        end,
    })
    setValue(initial)
end

makeSlider("LAUNCH POWER", 320, 0, 100, settings.power,
    function(v) return string.format("%d%%", math.floor(v + 0.5)) end,
    function(v) settings.power = math.floor(v + 0.5) end)
makeSlider("DETECTION RANGE", 398, 2, 6, settings.distance,
    function(v) return string.format("%.1f studs", v) end,
    function(v) settings.distance = v end)

label(main, "CHAIN LIMIT", UDim2.fromOffset(23, 476), UDim2.fromOffset(174, 24), 11, C.muted, true)
local chainButtons = {}
for i = 1, 3 do
    local button = create("TextButton", main, {
        Name = "Chain" .. i,
        Position = UDim2.fromOffset(222 + (i - 1) * 52, 475),
        Size = UDim2.fromOffset(45, 30),
        BackgroundColor3 = C.elevated,
        Text = tostring(i),
        TextColor3 = C.muted,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    corners(button, 9)
    local stroke = outline(button, C.border, 0.55)
    chainButtons[i] = { button = button, stroke = stroke }
    button.Activated:Connect(function()
        settings.maxChain = i
        for j, data in ipairs(chainButtons) do
            animate(data.button, {
                BackgroundColor3 = (j == i) and C.accent or C.elevated,
                TextColor3 = (j == i) and C.bg or C.muted,
            }, 0.18)
            data.stroke.Color = (j == i) and C.accent or C.border
        end
    end)
end
chainButtons[3].button.BackgroundColor3 = C.accent
chainButtons[3].button.TextColor3 = C.bg
chainButtons[3].stroke.Color = C.accent

create("Frame", main, {
    Position = UDim2.fromOffset(22, 523),
    Size = UDim2.fromOffset(356, 1),
    BackgroundColor3 = C.border,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
})
local hopsLabel = label(main, "HOPS  000", UDim2.fromOffset(22, 533), UDim2.fromOffset(100, 19), 10, C.accent, true)
local foot = label(main, "G  TOGGLE   •   RSHIFT  HIDE", UDim2.fromOffset(123, 533), UDim2.fromOffset(254, 19), 10, C.subtle)
foot.TextXAlignment = Enum.TextXAlignment.Right

-- Small re-open control. Always reachable after collapse.
local pill = create("TextButton", screen, {
    Name = "MinimizedLauncher",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -22, 0.5, 0),
    Size = UDim2.fromOffset(72, 60),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    Visible = false,
})
corners(pill, 18)
outline(pill, C.accent, 0.17, 1.5)
local pillMark = label(pill, "N", UDim2.fromOffset(0, 3), UDim2.fromOffset(72, 36), 29, C.accent, true)
pillMark.TextXAlignment = Enum.TextXAlignment.Center
local pillCaption = label(pill, "NOVA", UDim2.fromOffset(0, 37), UDim2.fromOffset(72, 14), 9, C.muted, true)
pillCaption.TextXAlignment = Enum.TextXAlignment.Center

local function updateToggleVisual()
    animate(toggle, { BackgroundColor3 = settings.enabled and C.accent or C.off }, 0.24)
    animate(toggleKnob, { Position = settings.enabled and UDim2.fromOffset(27, 4) or UDim2.fromOffset(4, 4) }, 0.24)
    animate(heroIconBox, { BackgroundTransparency = settings.enabled and 0.87 or 0.94 }, 0.2)
    statusText.Text = settings.enabled and "SYSTEM ARMED" or "SYSTEM DISABLED"
    statusText.TextColor3 = settings.enabled and C.accent or C.muted
    statusDot.BackgroundColor3 = settings.enabled and C.accent or C.off
end

toggle.Activated:Connect(function()
    settings.enabled = not settings.enabled
    updateToggleVisual()
end)

local collapsed = false
local function setCollapsed(value)
    collapsed = value
    main.Visible = not value
    shadow.Visible = not value
    pill.Visible = value
end
collapseButton.Activated:Connect(function() setCollapsed(true) end)
pill.Activated:Connect(function() setCollapsed(false) end)

-- Drag only by the header, so sliders and switches remain fully usable.
local dragging, dragOrigin, panelOrigin = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        -- Exclude the collapse button region.
        if input.Position.X >= collapseButton.AbsolutePosition.X
            and input.Position.X <= collapseButton.AbsolutePosition.X + collapseButton.AbsoluteSize.X
            and input.Position.Y >= collapseButton.AbsolutePosition.Y
            and input.Position.Y <= collapseButton.AbsolutePosition.Y + collapseButton.AbsoluteSize.Y then
            return
        end
        dragging = true
        dragOrigin = input.Position
        panelOrigin = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragOrigin
        local goal = UDim2.new(
            panelOrigin.X.Scale, panelOrigin.X.Offset + delta.X,
            panelOrigin.Y.Scale, panelOrigin.Y.Offset + delta.Y
        )
        main.Position = goal
        shadow.Position = goal + UDim2.fromOffset(0, 7)
    end
    for _, reference in ipairs(sliderRefs) do reference.update(input) end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
    for _, reference in ipairs(sliderRefs) do reference.release(input) end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.G then
        settings.enabled = not settings.enabled
        updateToggleVisual()
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        setCollapsed(not collapsed)
    end
end)

-- Fit the dashboard to mobile/tablet widths, without changing its internal layout.
local function updateScale()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local nextScale = math.clamp(math.min((viewport.X - 30) / 400, (viewport.Y - 30) / 566), 0.54, 1)
    scale.Scale = nextScale
    shadowScale.Scale = nextScale
end
updateScale()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
local camera = Workspace.CurrentCamera
if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end

-- Character binding / respawn support
local character, humanoid, root
local groundedAt = os.clock()
local lastHopAt = -math.huge
local hopsThisAir = 0
local totalHops = 0
local lastFlashAt = -math.huge
local nextScanAt = 0
local latestHit = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function bindCharacter(model)
    character = model
    humanoid = model:WaitForChild("Humanoid")
    root = model:WaitForChild("HumanoidRootPart")
    rayParams.FilterDescendantsInstances = { model }
    groundedAt = os.clock()
    lastHopAt = -math.huge
    hopsThisAir = 0
    latestHit = nil
end
player.CharacterAdded:Connect(bindCharacter)
if player.Character then bindCharacter(player.Character) end

local function validMovementState()
    if not humanoid or humanoid.Health <= 0 or not root or not root.Parent then return false end
    local state = humanoid:GetState()
    return state ~= Enum.HumanoidStateType.Dead
        and state ~= Enum.HumanoidStateType.Seated
        and state ~= Enum.HumanoidStateType.Swimming
        and state ~= Enum.HumanoidStateType.Climbing
        and state ~= Enum.HumanoidStateType.Ragdoll
        and state ~= Enum.HumanoidStateType.Physics
end

local function scanWall()
    if not root or not humanoid then return nil end
    local motion = humanoid.MoveDirection
    if motion.Magnitude < 0.15 then return nil end
    local direction = Vector3.new(motion.X, 0, motion.Z)
    if direction.Magnitude < 0.1 then return nil end
    direction = direction.Unit

    -- Three heights improve detection across R6/R15 and uneven surfaces.
    local center = root.Position
    local starts = {
        center + Vector3.new(0, 1.25, 0),
        center + Vector3.new(0, 0.1, 0),
        center + Vector3.new(0, -1.15, 0),
    }
    local nearest = nil
    for _, start in ipairs(starts) do
        local result = Workspace:Raycast(start, direction * settings.distance, rayParams)
        if result
            and result.Instance.CanCollide
            and math.abs(result.Normal.Y) <= 0.22
            and direction:Dot(-result.Normal) > 0.35 then
            if not nearest or result.Distance < nearest.Distance then
                nearest = result
            end
        end
    end
    return nearest
end

local function performWallhop(hit, now)
    if not root or not humanoid then return end
    local current = root.AssemblyLinearVelocity
    local wallNormal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
    if wallNormal.Magnitude < 0.1 then return end
    wallNormal = wallNormal.Unit

    -- Retain movement parallel to wall, then add a small outward kick.
    local move = humanoid.MoveDirection
    local parallel = move - wallNormal * move:Dot(wallNormal)
    if parallel.Magnitude > 0.1 then
        parallel = parallel.Unit * 18
    else
        parallel = Vector3.zero
    end

    local lateralCurrent = Vector3.new(current.X, 0, current.Z)
    local lateralPreserved = lateralCurrent * 0.4
    local outward = wallNormal * (11 + settings.power * 0.075)
    local horizontal = parallel + lateralPreserved + outward
    if horizontal.Magnitude > 35 then horizontal = horizontal.Unit * 35 end

    -- Gravity-aware jump height: moderate upward boost, not arbitrary teleportation.
    local jumpHeight = 6.3 + (settings.power / 100) * 5.7
    local verticalSpeed = math.sqrt(2 * Workspace.Gravity * jumpHeight)
    root.AssemblyLinearVelocity = Vector3.new(horizontal.X, verticalSpeed, horizontal.Z)
    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

    lastHopAt = now
    lastFlashAt = now
    hopsThisAir += 1
    totalHops += 1
    hopsLabel.Text = string.format("HOPS  %03d", totalHops % 1000)
    animate(heroIconBox, { BackgroundTransparency = 0.56 }, 0.08)
    task.delay(0.19, function()
        if heroIconBox.Parent then
            animate(heroIconBox, { BackgroundTransparency = settings.enabled and 0.87 or 0.94 }, 0.28)
        end
    end)
end

-- Scans are throttled; UI and physics use the same result.
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if not validMovementState() then
        latestHit = nil
        scanState.Text = "AWAITING PLAYER"
        scanState.TextColor3 = C.muted
        scanDistance.Text = "-- STUDS"
        meterFill.Size = UDim2.fromScale(0, 1)
        return
    end

    local isGrounded = humanoid.FloorMaterial ~= Enum.Material.Air
    if isGrounded then
        groundedAt = now
        hopsThisAir = 0
    end

    if now < nextScanAt then return end
    nextScanAt = now + settings.scanInterval

    if not settings.enabled then
        latestHit = nil
        scanState.Text = "STANDBY"
        scanState.TextColor3 = C.off
        scanDistance.Text = "-- STUDS"
        meterFill.Size = UDim2.fromScale(0, 1)
        return
    end

    latestHit = scanWall()
    if latestHit then
        scanDistance.Text = string.format("%.1f STUDS", latestHit.Distance)
        local closeness = 1 - (latestHit.Distance / settings.distance)
        animate(meterFill, { Size = UDim2.fromScale(math.clamp(closeness, 0.06, 1), 1) }, 0.09)
        if now - lastFlashAt < 0.35 then
            scanState.Text = "HOP EXECUTED"
            scanState.TextColor3 = C.accent
        elseif hopsThisAir >= settings.maxChain and not isGrounded then
            scanState.Text = "CHAIN EXHAUSTED"
            scanState.TextColor3 = C.warning
        elseif isGrounded then
            scanState.Text = "WALL IN RANGE"
            scanState.TextColor3 = C.accent2
        else
            scanState.Text = "TARGET LOCKED"
            scanState.TextColor3 = C.accent
        end
    else
        scanState.Text = isGrounded and "READY TO JUMP" or "SEARCHING"
        scanState.TextColor3 = C.white
        scanDistance.Text = "-- STUDS"
        animate(meterFill, { Size = UDim2.fromScale(0, 1) }, 0.12)
    end

    if not latestHit or isGrounded then return end
    if hopsThisAir >= settings.maxChain then return end
    if now - lastHopAt < settings.cooldown then return end
    if now - groundedAt < 0.13 then return end

    -- Don't fire just after a regular jump, or during dangerous terminal falls.
    local ySpeed = root.AssemblyLinearVelocity.Y
    if ySpeed > 16 or ySpeed < -85 then return end

    performWallhop(latestHit, now)
end)