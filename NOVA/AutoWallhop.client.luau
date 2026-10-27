--[[
    NOVA / AUTO WALLHOP
    Roblox Studio • LocalScript • StarterPlayer > StarterPlayerScripts

    This is a game-side assisted wall-jump mechanic for an experience you develop.
    Classic-mode assist: detects adjoining wall Parts and briefly rotates
    the character at the seam. Uses normal humanoid jumps (no velocity boost).
    Real wallhop collision behaviour depends on the game's wall geometry.

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
    angle = 45,                -- brief character-facing flick in degrees
    distance = 2.8,            -- short range improves seam precision
    maxChain = math.huge,      -- keep climbing until grounded
    cooldown = 0.16,          -- minimum interval between flick attempts
    scanInterval = 0.018,      -- seam scan frequency
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
label(hero, "Seam-based flicks · native jump physics", UDim2.fromOffset(79, 42), UDim2.fromOffset(225, 19), 10, C.muted)

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
label(scanner, "SEAM DETECTOR", UDim2.fromOffset(16, 11), UDim2.fromOffset(190, 21), 10, C.muted, true)
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

makeSlider("FLICK ANGLE", 320, 25, 75, settings.angle,
    function(v) return string.format("%d°", math.floor(v + 0.5)) end,
    function(v) settings.angle = math.floor(v + 0.5) end)
makeSlider("DETECTION RANGE", 398, 1.4, 4.2, settings.distance,
    function(v) return string.format("%.1f studs", v) end,
    function(v) settings.distance = v end)

label(main, "HOP LIMIT", UDim2.fromOffset(23, 476), UDim2.fromOffset(174, 24), 11, C.muted, true)
local chainButtons = {}
local chainChoices = { 1, 3, math.huge }
for i = 1, 3 do
    local button = create("TextButton", main, {
        Name = "Chain" .. i,
        Position = UDim2.fromOffset(222 + (i - 1) * 52, 475),
        Size = UDim2.fromOffset(45, 30),
        BackgroundColor3 = C.elevated,
        Text = (i == 3) and "∞" or tostring(chainChoices[i]),
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
        settings.maxChain = chainChoices[i]
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

local dragChangedConnection = UserInputService.InputChanged:Connect(function(input)
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

local dragEndedConnection = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
    for _, reference in ipairs(sliderRefs) do reference.release(input) end
end)

local keyConnection = UserInputService.InputBegan:Connect(function(input, processed)
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
local cameraChangedConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
local camera = Workspace.CurrentCamera
local viewportConnection = camera and camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- CLASSIC WALLHOP ENGINE (NOVA v2)
-- Actual Roblox-style wallhops depend on joints between collidable Parts.
-- This mode does not teleport, change gravity, or set AssemblyLinearVelocity.
-- It turns the character briefly at a detected seam and buffers a normal jump.

local alive = true
local connections = {}
local function track(connection)
    table.insert(connections, connection)
    return connection
end

local character, humanoid, root
local stateConnection
local lastAttemptAt = -math.huge
local lastGroundJumpAt = -math.huge
local lastSuccessAt = -math.huge
local lastSeamAt = -math.huge
local lastSeamPart = nil
local lastSeamY = nil
local groundedSince = nil
local jumpsThisAir = 0
local totalHops = 0
local pendingUntil = 0
local nextScanAt = 0
local nextUiAt = 0
local lastWall = nil
local lastScan = nil
local flick = nil
local flickSide = 1

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true

local function cancelFlick()
    if not flick then return end
    local saved = flick
    flick = nil
    if saved.root and saved.root.Parent then
        saved.root.CFrame = CFrame.new(saved.root.Position) * saved.rotation
    end
    if saved.humanoid and saved.humanoid.Parent then
        saved.humanoid.AutoRotate = saved.autoRotate
    end
end

local function bindCharacter(model)
    cancelFlick()
    if stateConnection then stateConnection:Disconnect() end
    character = model
    humanoid = model:WaitForChild("Humanoid")
    root = model:WaitForChild("HumanoidRootPart")
    rayParams.FilterDescendantsInstances = { model }
    lastAttemptAt = -math.huge
    lastGroundJumpAt = -math.huge
    lastSeamPart = nil
    lastSeamY = nil
    jumpsThisAir = 0
    groundedSince = os.clock()
    pendingUntil = 0
    lastScan = nil
    lastWall = nil

    -- Count ONLY confirmed Humanoid jumps caused by a buffered wallhop.
    stateConnection = humanoid.StateChanged:Connect(function(_, newState)
        if not alive then return end
        if newState == Enum.HumanoidStateType.Jumping and os.clock() <= pendingUntil then
            pendingUntil = 0
            jumpsThisAir += 1
            totalHops += 1
            lastSuccessAt = os.clock()
            hopsLabel.Text = string.format("HOPS  %03d", totalHops % 1000)
            animate(heroIconBox, { BackgroundTransparency = 0.57 }, 0.07)
            task.delay(0.16, function()
                if alive and heroIconBox.Parent then
                    animate(heroIconBox, { BackgroundTransparency = settings.enabled and 0.87 or 0.94 }, 0.18)
                end
            end)
        end
    end)
end

track(player.CharacterAdded:Connect(bindCharacter))
if player.Character then
    bindCharacter(player.Character)
end

local function ableToHop()
    if not humanoid or humanoid.Health <= 0 or not root or not root.Parent then return false end
    local state = humanoid:GetState()
    return state ~= Enum.HumanoidStateType.Dead
        and state ~= Enum.HumanoidStateType.Seated
        and state ~= Enum.HumanoidStateType.Swimming
        and state ~= Enum.HumanoidStateType.Climbing
        and state ~= Enum.HumanoidStateType.Ragdoll
        and state ~= Enum.HumanoidStateType.Physics
end

local function getFootY()
    if humanoid.RigType == Enum.HumanoidRigType.R6 then
        return root.Position.Y - 2.85
    end
    return root.Position.Y - humanoid.HipHeight - root.Size.Y * 0.5
end

local function directionIntoWall()
    local move = humanoid.MoveDirection
    if move.Magnitude < 0.14 then return nil end -- Hold forward into the wall.
    return Vector3.new(move.X, 0, move.Z).Unit
end

local function validFace(hit, direction)
    return hit and hit.Instance and hit.Instance:IsA("BasePart")
        and hit.Instance.CanCollide
        and math.abs(hit.Normal.Y) < 0.13
        and direction:Dot(-hit.Normal) > 0.48
end

-- Detect a real horizontal join: consecutive sample rays must hit DISTINCT
-- BaseParts, with almost identical normals and front-face depth.
-- A striped Decal/Texture on one solid Part will NOT count as a seam.
local function scanSeam()
    local direction = directionIntoWall()
    if not direction then return nil end

    local footY = getFootY()
    local offsets = { -0.52, -0.33, -0.17, 0.00, 0.17, 0.33, 0.52, 0.70, 0.91 }
    local previous, previousY
    local nearestWall, bestSeam
    for _, offset in ipairs(offsets) do
        local origin = Vector3.new(root.Position.X, footY + offset, root.Position.Z)
        local hit = Workspace:Raycast(origin, direction * settings.distance, rayParams)
        local y = footY + offset
        if not validFace(hit, direction) then
            previous = nil
        else
            if not nearestWall or hit.Distance < nearestWall.Distance then
                nearestWall = hit
            end
            if previous and hit.Instance ~= previous.Instance
                and hit.Normal:Dot(previous.Normal) > 0.985
                and math.abs(hit.Distance - previous.Distance) < 0.20 then
                local seamY = (previousY + y) * 0.5
                local offsetFromFoot = math.abs(seamY - footY)
                if not bestSeam or offsetFromFoot < bestSeam.footGap then
                    bestSeam = {
                        lower = previous,
                        upper = hit,
                        part = hit.Instance,
                        y = seamY,
                        footGap = offsetFromFoot,
                        distance = math.min(hit.Distance, previous.Distance),
                    }
                end
            end
            previous, previousY = hit, y
        end
    end

    return { wall = nearestWall, seam = bestSeam, footY = footY }
end

local function initiateFlick(now, scan)
    local seam = scan.seam
    if not seam or flick or jumpsThisAir >= settings.maxChain then return end
    if now - lastAttemptAt < settings.cooldown then return end
    if seam.footGap > 0.37 then return end
    if lastSeamPart == seam.part and lastSeamY
        and math.abs(lastSeamY - seam.y) < 0.20
        and now - lastSeamAt < 0.65 then
        return
    end

    -- Direct rotation emulates the character-facing part of a shift-lock
    -- camera flick, but does not create fake upward speed or wall forces.
    flickSide = -flickSide
    flick = {
        root = root,
        humanoid = humanoid,
        rotation = root.CFrame.Rotation,
        autoRotate = humanoid.AutoRotate,
        untilTime = now + 0.048,
    }
    humanoid.AutoRotate = false
    root.CFrame = CFrame.new(root.Position)
        * flick.rotation
        * CFrame.Angles(0, math.rad(settings.angle * flickSide), 0)
    humanoid.Jump = true -- Accepted only when Roblox grants jump contact.

    lastAttemptAt = now
    lastSeamAt = now
    lastSeamPart = seam.part
    lastSeamY = seam.y
    pendingUntil = now + 0.24
end

local function updateInterface(now, scan, ground)
    if now < nextUiAt then return end
    nextUiAt = now + 0.08

    local hit = scan and scan.wall
    local seam = scan and scan.seam
    if not settings.enabled then
        scanState.Text = "STANDBY"
        scanState.TextColor3 = C.off
        scanDistance.Text = "-- STUDS"
        meterFill.Size = UDim2.fromScale(0, 1)
    elseif not ableToHop() then
        scanState.Text = "AWAITING PLAYER"
        scanState.TextColor3 = C.muted
        scanDistance.Text = "-- STUDS"
        meterFill.Size = UDim2.fromScale(0, 1)
    elseif not hit then
        scanState.Text = ground and "APPROACH WALL" or "SEARCHING"
        scanState.TextColor3 = C.muted
        scanDistance.Text = "-- STUDS"
        meterFill.Size = UDim2.fromScale(0, 1)
    else
        scanDistance.Text = string.format("%.1f STUDS", hit.Distance)
        meterFill.Size = UDim2.fromScale(math.clamp(1 - hit.Distance / settings.distance, 0.04, 1), 1)
        if now - lastSuccessAt < 0.34 then
            scanState.Text = "HOP CONFIRMED"
            scanState.TextColor3 = C.accent
        elseif seam and jumpsThisAir >= settings.maxChain and not ground then
            scanState.Text = "LIMIT REACHED"
            scanState.TextColor3 = C.warning
        elseif seam and flick then
            scanState.Text = "FLICKING"
            scanState.TextColor3 = C.accent
        elseif seam and seam.footGap <= 0.37 then
            scanState.Text = "SEAM ALIGNED"
            scanState.TextColor3 = C.accent
        elseif seam then
            scanState.Text = "SEAM DETECTED"
            scanState.TextColor3 = C.accent2
        else
            scanState.Text = "SOLID WALL"
            scanState.TextColor3 = C.warning
        end
    end
end

local engineConnection = RunService.PreSimulation:Connect(function()
    if not alive then return end
    local now = os.clock()

    if flick then
        if not settings.enabled or not ableToHop() or now >= flick.untilTime then
            cancelFlick()
        else
            -- Keep the regular jump buffer active while seam physics resolves.
            humanoid.Jump = true
        end
    end

    if not ableToHop() then
        lastScan = nil
        updateInterface(now, nil, false)
        return
    end

    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
    if grounded then
        groundedSince = groundedSince or now
        -- A genuine wallhop can report a 1-frame floor contact at a seam.
        -- Only reset a chain after a sustained real ground contact.
        if now - groundedSince > 0.17 then
            jumpsThisAir = 0
            lastSeamPart = nil
            lastSeamY = nil
        end
    else
        groundedSince = nil
    end

    if not settings.enabled then
        lastScan = nil
        updateInterface(now, nil, grounded)
        return
    end

    if now >= nextScanAt then
        nextScanAt = now + settings.scanInterval
        lastScan = scanSeam()
    end

    local scan = lastScan
    if scan and scan.seam and not flick then
        if grounded then
            -- Automatically initiate an ordinary jump at an actual seam.
            if now - lastGroundJumpAt >= 0.46 and scan.seam.footGap < 0.87 then
                humanoid.Jump = true
                lastGroundJumpAt = now
            end
        else
            -- Classic wallhops are typically caught as the legs descend
            -- through the shared edge between stacked wall Parts.
            local vy = root.AssemblyLinearVelocity.Y
            if vy <= 4 and vy > -62 then
                initiateFlick(now, scan)
            end
        end
    end
    updateInterface(now, scan, grounded)
end)
track(engineConnection)

screen.Destroying:Connect(function()
    alive = false
    cancelFlick()
    if stateConnection then stateConnection:Disconnect() end
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    if dragChangedConnection then dragChangedConnection:Disconnect() end
    if dragEndedConnection then dragEndedConnection:Disconnect() end
    if keyConnection then keyConnection:Disconnect() end
    if cameraChangedConnection then cameraChangedConnection:Disconnect() end
    if viewportConnection then viewportConnection:Disconnect() end
end)
