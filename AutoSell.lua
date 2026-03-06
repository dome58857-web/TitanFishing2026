-- ================================================================
-- TITAN FISHING  |  Auto Sell  |  Mobile
-- Chuc nang: Tu dong cau + dem nguoc + tu dong ban ca
-- ================================================================
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local RS      = game:GetService("RunService")
local PFS     = game:GetService("PathfindingService")
local TS      = game:GetService("TweenService")
local VIM     = game:GetService("VirtualInputManager")
local GS      = game:GetService("GuiService")
local LP      = Players.LocalPlayer

-- ================================================================
-- STATE
-- ================================================================
local isRunning    = false
local statusText   = "Chua bat"
local sellCount    = 0
local fishMinutes  = 1
local countdownSec = 0
local isSelling    = false

local savedFishPos  = nil
local savedNPCPos   = nil
local savedSellPos  = nil
local savedClosePos = nil
local savedCastPos  = nil

-- INSET: AbsolutePosition = viewport coords, VIM can screen coords
-- â†’ cong INSET.Y vao Y khi gui click
local INSET = GS:GetGuiInset()

-- ================================================================
-- CLICK
-- ================================================================
local function doClick(vx, vy)
    local sx = vx
    local sy = vy + INSET.Y
    VIM:SendMouseButtonEvent(sx, sy, 0, true,  game, 0)
    task.wait(0.06)
    VIM:SendMouseButtonEvent(sx, sy, 0, false, game, 0)
end

local function uiClick(vx, vy)
    local sx = vx
    local sy = vy + INSET.Y
    pcall(function() VIM:SendMouseMoveEvent(sx, sy, game) end)
    task.wait(0.04)
    pcall(function() VIM:SendMouseButtonEvent(sx, sy, 0, true,  game, 0) end)
    task.wait(0.1)
    pcall(function() VIM:SendMouseButtonEvent(sx, sy, 0, false, game, 0) end)
    task.wait(0.05)
end

-- ================================================================
-- CAST LOOP
-- ================================================================
local castActive = false
local castToken  = 0

local function startCastLoop()
    castToken = castToken + 1
    local tk  = castToken
    task.spawn(function()
        while castActive and castToken == tk do
            if savedCastPos and not isSelling then
                pcall(doClick, savedCastPos.X, savedCastPos.Y)
            end
            task.wait(0.45)
        end
    end)
end

local function stopCast()
    castActive = false
    castToken  = castToken + 1
end

-- ================================================================
-- WALK
-- ================================================================
local function walkTo(pos, lbl)
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    statusText    = lbl or "Dang di..."
    hum.WalkSpeed = 24
    local path = PFS:CreatePath({AgentHeight = 5, AgentRadius = 2, AgentCanJump = true})
    local ok   = pcall(function() path:ComputeAsync(hrp.Position, pos) end)
    if ok and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if not isRunning then return end
            if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
            hum:MoveTo(wp.Position)
            hum.MoveToFinished:Wait(3)
            if (hrp.Position - pos).Magnitude < 8 then break end
        end
    else
        hum:MoveTo(pos)
        local t = 0
        while t < 12 and isRunning do
            task.wait(0.2); t = t + 0.2
            if (hrp.Position - pos).Magnitude < 8 then break end
        end
    end
end

local function stopWalk()
    local c = LP.Character
    local h = c and c:FindFirstChild("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if h and r then h:MoveTo(r.Position) end
end

-- ================================================================
-- INTERACT + SELL
-- ================================================================
local function doInteract()
    statusText = "Mo cua hang..."
    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local best, bestD = nil, math.huge
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                local p = v.Parent
                if p and p:IsA("BasePart") then
                    local d = (hrp.Position - p.Position).Magnitude
                    if d < bestD then bestD = d; best = v end
                end
            end
        end
        if best and bestD < 20 then
            pcall(function() fireproximityprompt(best) end)
            task.wait(0.5)
        end
    end
    task.wait(0.8)
end

local function doSellAll()
    if not savedSellPos or not savedClosePos then
        statusText = "Chua luu SellAll/X!"
        task.wait(2)
        return
    end
    statusText = "Cho popup..."
    task.wait(0.8)
    uiClick(savedSellPos.X,  savedSellPos.Y)
    task.wait(1.2)
    uiClick(savedClosePos.X, savedClosePos.Y)
    task.wait(0.5)
    statusText = "Da ban xong!"
end

-- ================================================================
-- MAIN LOOP
-- ================================================================
local function mainLoop()
    local miss = {}
    if not savedFishPos  then table.insert(miss, "Vi tri cau") end
    if not savedNPCPos   then table.insert(miss, "Vi tri NPC") end
    if not savedSellPos  then table.insert(miss, "SellAll") end
    if not savedClosePos then table.insert(miss, "X dong") end
    if not savedCastPos  then table.insert(miss, "Nut Fishing") end
    if #miss > 0 then
        statusText = "Thieu: " .. table.concat(miss, ", ") .. "!"
        isRunning  = false
        return
    end

    while isRunning do
        -- === Pha cau ===
        isSelling = false
        stopCast()
        task.wait(0.15)

        local char = LP.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and savedFishPos and (hrp.Position - savedFishPos).Magnitude > 5 then
            walkTo(savedFishPos, "Di ve vi tri cau...")
            if not isRunning then break end
            stopWalk()
            task.wait(0.5)
        end

        castActive = true
        startCastLoop()

        countdownSec = fishMinutes * 60
        while countdownSec > 0 and isRunning do
            local m = math.floor(countdownSec / 60)
            local s = countdownSec % 60
            statusText = m .. ":" .. string.format("%02d", s)
                      .. "  Ban:" .. sellCount
            task.wait(1)
            countdownSec = countdownSec - 1
        end
        if not isRunning then break end

        -- === Pha ban ===
        isSelling = true
        stopCast()
        task.wait(0.2)

        statusText = "Het gio! Di ban..."
        walkTo(savedNPCPos, "Di toi NPC...")
        if not isRunning then break end
        stopWalk()
        task.wait(0.5)

        doInteract()
        task.wait(0.5)
        doSellAll()
        task.wait(0.5)

        sellCount  = sellCount + 1
        statusText = "Da ban lan " .. sellCount .. "!"
        task.wait(1)
    end

    stopCast()
    isSelling    = false
    countdownSec = 0
    statusText   = "Da tat"
end

-- ================================================================
-- GUI
-- ================================================================
local old = LP.PlayerGui:FindFirstChild("TFHub")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name           = "TFHub"
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = LP.PlayerGui

-- ================================================================
-- getCenter â†’ viewport coords (doClick/uiClick tu cong INSET)
-- ================================================================
local function getCenter(m)
    local ap = m.AbsolutePosition
    local as = m.AbsoluteSize
    return ap.X + as.X * 0.5,
           ap.Y + as.Y * 0.5
end

-- ================================================================
-- MARKER (vong tron keo tha de dat toa do click)
-- ================================================================
local function makeMarker(col, tag)
    local S = 70
    local m = Instance.new("TextButton")
    m.Size                   = UDim2.new(0, S, 0, S)
    m.Position               = UDim2.new(0.5, -S/2, 0.5, -S/2)
    m.BackgroundColor3       = col
    m.BackgroundTransparency = 0.3
    m.BorderSizePixel        = 0
    m.Text                   = ""
    m.ZIndex                 = 80
    m.Active                 = true
    m.Draggable              = true
    m.Visible                = false
    m.Parent                 = sg
    Instance.new("UICorner", m).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", m).Color        = Color3.new(1, 1, 1)

    local ch = Instance.new("Frame", m)
    ch.Size             = UDim2.new(1, 0, 0, 2)
    ch.Position         = UDim2.new(0, 0, 0.5, -1)
    ch.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
    ch.BorderSizePixel  = 0; ch.ZIndex = 81

    local cv = Instance.new("Frame", m)
    cv.Size             = UDim2.new(0, 2, 1, 0)
    cv.Position         = UDim2.new(0.5, -1, 0, 0)
    cv.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
    cv.BorderSizePixel  = 0; cv.ZIndex = 81

    local dot = Instance.new("Frame", m)
    dot.Size             = UDim2.new(0, 10, 0, 10)
    dot.Position         = UDim2.new(0.5, -5, 0.5, -5)
    dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    dot.BorderSizePixel  = 0; dot.ZIndex = 82
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local tl = Instance.new("TextLabel", m)
    tl.Size                   = UDim2.new(1, 0, 0, 16)
    tl.Position               = UDim2.new(0, 0, 1, 2)
    tl.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    tl.BackgroundTransparency = 0.4
    tl.Text                   = tag
    tl.TextColor3             = Color3.fromRGB(255, 255, 0)
    tl.Font                   = Enum.Font.GothamBlack
    tl.TextSize               = 11; tl.ZIndex = 82
    Instance.new("UICorner", tl).CornerRadius = UDim.new(0, 4)

    RS.Heartbeat:Connect(function()
        if m.Visible then
            m.BackgroundTransparency = 0.1 + math.abs(math.sin(tick() * 2.5)) * 0.35
        end
    end)

    return m
end

local markerSell  = makeMarker(Color3.fromRGB(20,  200, 100), "SELL")
local markerClose = makeMarker(Color3.fromRGB(220, 40,  60),  "CLOSE")
local markerCast  = makeMarker(Color3.fromRGB(255, 200, 0),   "FISHING")

-- ================================================================
-- HUB
-- ================================================================
local HW = 280
local HH = 420

local hub = Instance.new("Frame", sg)
hub.Name                   = "Hub"
hub.Size                   = UDim2.new(0, HW, 0, HH)
hub.Position               = UDim2.new(0, 8, 0, 50)
hub.BackgroundColor3       = Color3.fromRGB(14, 14, 24)
hub.BackgroundTransparency = 0.05
hub.BorderSizePixel        = 0
hub.Active                 = true
hub.Draggable              = true
hub.ClipsDescendants       = true
hub.ZIndex                 = 10
Instance.new("UICorner", hub).CornerRadius = UDim.new(0, 12)
local hubStroke = Instance.new("UIStroke", hub)
hubStroke.Color     = Color3.fromRGB(50, 50, 90)
hubStroke.Thickness = 1.5

-- Header
local HDR    = 40
local header = Instance.new("Frame", hub)
header.Size             = UDim2.new(1, 0, 0, HDR)
header.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
header.BorderSizePixel  = 0; header.ZIndex = 11
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)
local hg = Instance.new("UIGradient", header)
hg.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 20, 70)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 20)),
})
hg.Rotation = 90

-- Logo
local logoF = Instance.new("Frame", header)
logoF.Size             = UDim2.new(0, 28, 0, 28)
logoF.Position         = UDim2.new(0, 6, 0.5, -14)
logoF.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
logoF.BorderSizePixel  = 0; logoF.ZIndex = 12
Instance.new("UICorner", logoF).CornerRadius = UDim.new(1, 0)
local logoL = Instance.new("TextLabel", logoF)
logoL.Size               = UDim2.new(1, 0, 1, 0)
logoL.BackgroundTransparency = 1
logoL.Text               = "TF"
logoL.Font               = Enum.Font.GothamBlack
logoL.TextSize           = 10
logoL.TextColor3         = Color3.new(1, 1, 1)
logoL.ZIndex             = 13

local titleL = Instance.new("TextLabel", header)
titleL.Size               = UDim2.new(0, 140, 1, 0)
titleL.Position           = UDim2.new(0, 40, 0, 0)
titleL.BackgroundTransparency = 1
titleL.Text               = "Titan Fishing  Auto Sell"
titleL.Font               = Enum.Font.GothamBlack
titleL.TextSize           = 11
titleL.TextColor3         = Color3.new(1, 1, 1)
titleL.TextXAlignment     = Enum.TextXAlignment.Left
titleL.ZIndex             = 12

-- Status dot
local sDot = Instance.new("Frame", header)
sDot.Size             = UDim2.new(0, 8, 0, 8)
sDot.Position         = UDim2.new(1, -52, 0.5, -4)
sDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
sDot.BorderSizePixel  = 0; sDot.ZIndex = 12
Instance.new("UICorner", sDot).CornerRadius = UDim.new(1, 0)

-- X button
local xBtn = Instance.new("TextButton", header)
xBtn.Size             = UDim2.new(0, 26, 0, 26)
xBtn.Position         = UDim2.new(1, -32, 0.5, -13)
xBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
xBtn.BorderSizePixel  = 0
xBtn.Text             = "X"
xBtn.TextColor3       = Color3.new(1, 1, 1)
xBtn.Font             = Enum.Font.GothamBlack
xBtn.TextSize         = 12; xBtn.ZIndex = 13
Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, 7)

-- Open button
local openBtn = Instance.new("TextButton", sg)
openBtn.Size             = UDim2.new(0, 62, 0, 28)
openBtn.Position         = UDim2.new(0, 8, 0, 50)
openBtn.BackgroundColor3 = Color3.fromRGB(255, 130, 0)
openBtn.BorderSizePixel  = 0
openBtn.Text             = "OPEN"
openBtn.TextColor3       = Color3.new(1, 1, 1)
openBtn.Font             = Enum.Font.GothamBlack
openBtn.TextSize         = 12; openBtn.ZIndex = 30
openBtn.Visible          = false; openBtn.Active = true
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke",  openBtn).Color       = Color3.fromRGB(255, 200, 80)

local hubOpen = true

local function showHub()
    hubOpen = true; hub.Visible = true; openBtn.Visible = false
    hub.Size     = UDim2.new(0, 0, 0, 0)
    hub.Position = UDim2.new(0, 8 + HW/2, 0, 50 + HH/2)
    TS:Create(hub, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, HW, 0, HH), Position = UDim2.new(0, 8, 0, 50),
    }):Play()
end
local function hideHub()
    hubOpen = false
    TS:Create(hub, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0, 8 + HW/2, 0, 50 + HH/2),
    }):Play()
    task.delay(0.18, function() hub.Visible = false; openBtn.Visible = true end)
end
xBtn.MouseButton1Click:Connect(hideHub)
openBtn.MouseButton1Click:Connect(showHub)

-- ================================================================
-- CONTENT  (scroll)
-- ================================================================
local body = Instance.new("ScrollingFrame", hub)
body.Size                 = UDim2.new(1, 0, 1, -HDR)
body.Position             = UDim2.new(0, 0, 0, HDR)
body.BackgroundTransparency = 1
body.BorderSizePixel      = 0
body.ScrollBarThickness   = 3
body.ScrollBarImageColor3 = Color3.fromRGB(255, 140, 0)
body.ZIndex               = 11

local PAD = 8
local CW  = HW - PAD * 2
local bY  = PAD

-- helpers
local function mkSec(Y, txt)
    local l = Instance.new("TextLabel", body)
    l.Size               = UDim2.new(0, CW, 0, 16)
    l.Position           = UDim2.new(0, PAD, 0, Y)
    l.BackgroundTransparency = 1
    l.Text               = txt
    l.TextColor3         = Color3.fromRGB(255, 140, 0)
    l.Font               = Enum.Font.GothamBlack
    l.TextSize           = 10
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.ZIndex             = 13
end

local function mkDiv(Y)
    local d = Instance.new("Frame", body)
    d.Size             = UDim2.new(0, CW, 0, 1)
    d.Position         = UDim2.new(0, PAD, 0, Y)
    d.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    d.BorderSizePixel  = 0; d.ZIndex = 12
end

local function mkRow(Y, h)
    local f = Instance.new("Frame", body)
    f.Size             = UDim2.new(0, CW, 0, h)
    f.Position         = UDim2.new(0, PAD, 0, Y)
    f.BackgroundColor3 = Color3.fromRGB(16, 16, 30)
    f.BorderSizePixel  = 0; f.ZIndex = 12
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke",  f).Color       = Color3.fromRGB(38, 38, 60)
    return f
end

local function mkBtn(Y, h, bg, txt, fs)
    local b = Instance.new("TextButton", body)
    b.Size             = UDim2.new(0, CW, 0, h)
    b.Position         = UDim2.new(0, PAD, 0, Y)
    b.BackgroundColor3 = bg
    b.BorderSizePixel  = 0
    b.Text             = txt
    b.TextColor3       = Color3.new(1, 1, 1)
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = fs or 12
    b.TextWrapped      = true; b.ZIndex = 13
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local function mkInfoRow(Y, txt, col)
    local f = mkRow(Y, 26)
    local l = Instance.new("TextLabel", f)
    l.Size               = UDim2.new(1, -8, 1, 0)
    l.Position           = UDim2.new(0, 6, 0, 0)
    l.BackgroundTransparency = 1
    l.Text               = txt
    l.TextColor3         = col or Color3.fromRGB(160, 160, 200)
    l.Font               = Enum.Font.GothamBold
    l.TextSize           = 10
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.TextTruncate       = Enum.TextTruncate.AtEnd
    l.ZIndex             = 13
    return l
end

local function mkStepper(Y, lbl, initVal, col)
    local f  = mkRow(Y, 30)
    local ll = Instance.new("TextLabel", f)
    ll.Size               = UDim2.new(0, 100, 1, 0)
    ll.Position           = UDim2.new(0, 6, 0, 0)
    ll.BackgroundTransparency = 1
    ll.Text               = lbl
    ll.TextColor3         = Color3.fromRGB(180, 180, 220)
    ll.Font               = Enum.Font.GothamBold
    ll.TextSize           = 10
    ll.TextXAlignment     = Enum.TextXAlignment.Left
    ll.ZIndex             = 13

    local vl = Instance.new("TextLabel", f)
    vl.Size               = UDim2.new(0, 36, 1, 0)
    vl.Position           = UDim2.new(0, 108, 0, 0)
    vl.BackgroundTransparency = 1
    vl.Text               = initVal
    vl.TextColor3         = col or Color3.fromRGB(255, 220, 80)
    vl.Font               = Enum.Font.GothamBold
    vl.TextSize           = 11; vl.ZIndex = 13

    local bm = Instance.new("TextButton", f)
    bm.Size             = UDim2.new(0, 26, 0, 22)
    bm.Position         = UDim2.new(1, -56, 0.5, -11)
    bm.BackgroundColor3 = Color3.fromRGB(160, 30, 30)
    bm.BorderSizePixel  = 0
    bm.Text             = "-"; bm.TextColor3 = Color3.new(1,1,1)
    bm.Font             = Enum.Font.GothamBold; bm.TextSize = 15; bm.ZIndex = 13
    Instance.new("UICorner", bm).CornerRadius = UDim.new(0, 5)

    local bp = Instance.new("TextButton", f)
    bp.Size             = UDim2.new(0, 26, 0, 22)
    bp.Position         = UDim2.new(1, -28, 0.5, -11)
    bp.BackgroundColor3 = Color3.fromRGB(25, 140, 50)
    bp.BorderSizePixel  = 0
    bp.Text             = "+"; bp.TextColor3 = Color3.new(1,1,1)
    bp.Font             = Enum.Font.GothamBold; bp.TextSize = 15; bp.ZIndex = 13
    Instance.new("UICorner", bp).CornerRadius = UDim.new(0, 5)

    return vl, bm, bp
end

-- ----------------------------------------------------------------
-- SECTION: DIEU KHIEN
-- ----------------------------------------------------------------
mkSec(bY, "DIEU KHIEN"); bY = bY + 20

-- Status display
local statusRow = mkRow(bY, 32)
local statusDot = Instance.new("Frame", statusRow)
statusDot.Size             = UDim2.new(0, 8, 0, 8)
statusDot.Position         = UDim2.new(0, 8, 0.5, -4)
statusDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
statusDot.BorderSizePixel  = 0; statusDot.ZIndex = 13
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)
local statusLbl = Instance.new("TextLabel", statusRow)
statusLbl.Size               = UDim2.new(1, -20, 1, 0)
statusLbl.Position           = UDim2.new(0, 20, 0, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text               = "Chua bat"
statusLbl.TextColor3         = Color3.fromRGB(255, 100, 100)
statusLbl.Font               = Enum.Font.GothamBold
statusLbl.TextSize           = 10
statusLbl.TextXAlignment     = Enum.TextXAlignment.Left
statusLbl.TextTruncate       = Enum.TextTruncate.AtEnd
statusLbl.ZIndex             = 13
bY = bY + 38

-- Timer display
local timerRow = mkRow(bY, 32)
local timerLbl = Instance.new("TextLabel", timerRow)
timerLbl.Size               = UDim2.new(1, -8, 1, 0)
timerLbl.Position           = UDim2.new(0, 8, 0, 0)
timerLbl.BackgroundTransparency = 1
timerLbl.Text               = "0:00  Ban: 0"
timerLbl.TextColor3         = Color3.fromRGB(255, 220, 80)
timerLbl.Font               = Enum.Font.GothamBold
timerLbl.TextSize           = 13
timerLbl.TextXAlignment     = Enum.TextXAlignment.Center
timerLbl.ZIndex             = 13
bY = bY + 38

-- START / STOP
local toggleBtn = mkBtn(bY, 44, Color3.fromRGB(30, 180, 65), "START AUTO", 15)
local tGrad     = Instance.new("UIGradient", toggleBtn); tGrad.Rotation = 90
tGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 220, 85)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 145, 48)),
})
bY = bY + 50

-- Ban ngay
local sellNowBtn = mkBtn(bY, 30, Color3.fromRGB(200, 100, 0), "BAN NGAY", 11)
bY = bY + 36

-- Thoi gian cau
local timLbl, timMin, timPlus = mkStepper(bY, "Cau (phut):", fishMinutes .. "p", Color3.fromRGB(255, 220, 80))
bY = bY + 36

timMin.MouseButton1Click:Connect(function()
    fishMinutes = math.max(1, fishMinutes - 1); timLbl.Text = fishMinutes .. "p"
end)
timPlus.MouseButton1Click:Connect(function()
    fishMinutes = fishMinutes + 1; timLbl.Text = fishMinutes .. "p"
end)

mkDiv(bY); bY = bY + 10

-- ----------------------------------------------------------------
-- SECTION: VI TRI TRONG GAME
-- ----------------------------------------------------------------
mkSec(bY, "VI TRI TRONG GAME"); bY = bY + 20

local p1Lbl = mkInfoRow(bY, "Cau: Chua luu",  Color3.fromRGB(120, 180, 255)); bY = bY + 30
local saveFishBtn = mkBtn(bY, 26, Color3.fromRGB(25, 100, 210), "SAVE vi tri cau", 11); bY = bY + 32
local p2Lbl = mkInfoRow(bY, "NPC: Chua luu",  Color3.fromRGB(255, 180, 80));  bY = bY + 30
local saveNPCBtn  = mkBtn(bY, 26, Color3.fromRGB(110, 35, 180), "SAVE vi tri NPC", 11); bY = bY + 32

mkDiv(bY); bY = bY + 10

-- ----------------------------------------------------------------
-- SECTION: NUT TREN MAN HINH (marker)
-- ----------------------------------------------------------------
mkSec(bY, "NUT TREN MAN HINH"); bY = bY + 20

local p3Lbl    = mkInfoRow(bY, "SellAll: Chua luu", Color3.fromRGB(80, 255, 180)); bY = bY + 30
local showSellBtn  = mkBtn(bY, 26, Color3.fromRGB(18, 140, 72),  "HIEN vong SellAll",  11); bY = bY + 32
local p4Lbl    = mkInfoRow(bY, "X dong: Chua luu",  Color3.fromRGB(255, 130, 180)); bY = bY + 30
local showCloseBtn = mkBtn(bY, 26, Color3.fromRGB(175, 35, 55),  "HIEN vong X dong",   11); bY = bY + 32
local p5Lbl    = mkInfoRow(bY, "Fishing: Chua luu", Color3.fromRGB(255, 230, 80));  bY = bY + 30
local showCastBtn  = mkBtn(bY, 26, Color3.fromRGB(155, 115, 0),  "HIEN vong Fishing",  11); bY = bY + 32

mkDiv(bY); bY = bY + 10

-- ----------------------------------------------------------------
-- SECTION: CHECKLIST
-- ----------------------------------------------------------------
mkSec(bY, "TRANG THAI SETUP"); bY = bY + 20

local checkLabels = {}
local chkList = {
    {k = "fish",  l = "Vi tri cau"},
    {k = "npc",   l = "Vi tri NPC"},
    {k = "sell",  l = "SellAll"},
    {k = "close", l = "X dong"},
    {k = "cast",  l = "Nut Fishing"},
}
for _, c in ipairs(chkList) do
    local f   = mkRow(bY, 26)
    local dot = Instance.new("Frame", f)
    dot.Size             = UDim2.new(0, 9, 0, 9)
    dot.Position         = UDim2.new(0, 7, 0.5, -4.5)
    dot.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    dot.BorderSizePixel  = 0; dot.ZIndex = 13
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    local lbl = Instance.new("TextLabel", f)
    lbl.Size               = UDim2.new(1, -22, 1, 0)
    lbl.Position           = UDim2.new(0, 20, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = c.l
    lbl.TextColor3         = Color3.fromRGB(200, 60, 60)
    lbl.Font               = Enum.Font.GothamBold; lbl.TextSize = 10
    lbl.TextXAlignment     = Enum.TextXAlignment.Left; lbl.ZIndex = 13
    checkLabels[c.k] = {lbl = lbl, dot = dot}
    bY = bY + 32
end

body.CanvasSize = UDim2.new(0, 0, 0, bY + PAD)

-- ================================================================
-- MARKER BINDINGS
-- ================================================================
local function bindMarker(marker, showBtn, onSave)
    showBtn.MouseButton1Click:Connect(function()
        marker.Visible = not marker.Visible
        showBtn.BackgroundColor3 = marker.Visible
            and Color3.fromRGB(120, 50, 10)
            or  showBtn.BackgroundColor3
    end)
    marker.MouseButton1Click:Connect(function()
        local cx, cy = getCenter(marker)
        onSave(Vector2.new(cx, cy), cx, cy)
        marker.BackgroundColor3  = Color3.fromRGB(30, 60, 170)
        showBtn.BackgroundColor3 = Color3.fromRGB(18, 80, 18)
        statusText = "Luu (" .. math.floor(cx) .. "," .. math.floor(cy) .. ")"
    end)
end

bindMarker(markerSell, showSellBtn, function(v2, x, y)
    savedSellPos = v2
    p3Lbl.Text = "OK (" .. math.floor(x) .. "," .. math.floor(y) .. ")"
    p3Lbl.TextColor3 = Color3.fromRGB(80, 255, 180)
    showSellBtn.Text = "âœ” SellAll da luu"
end)

bindMarker(markerClose, showCloseBtn, function(v2, x, y)
    savedClosePos = v2
    p4Lbl.Text = "OK (" .. math.floor(x) .. "," .. math.floor(y) .. ")"
    p4Lbl.TextColor3 = Color3.fromRGB(255, 150, 200)
    showCloseBtn.Text = "âœ” X dong da luu"
end)

bindMarker(markerCast, showCastBtn, function(v2, x, y)
    savedCastPos = v2
    p5Lbl.Text = "OK (" .. math.floor(x) .. "," .. math.floor(y) .. ")"
    p5Lbl.TextColor3 = Color3.fromRGB(255, 230, 80)
    showCastBtn.Text = "âœ” Fishing da luu"
end)

saveFishBtn.MouseButton1Click:Connect(function()
    local c = LP.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedFishPos = r.Position
        p1Lbl.Text = "OK " .. math.floor(r.Position.X) .. "," .. math.floor(r.Position.Z)
        p1Lbl.TextColor3 = Color3.fromRGB(80, 255, 120)
        saveFishBtn.Text = "âœ” Da luu vi tri cau"
        saveFishBtn.BackgroundColor3 = Color3.fromRGB(12, 90, 40)
    end
end)

saveNPCBtn.MouseButton1Click:Connect(function()
    local c = LP.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedNPCPos = r.Position
        p2Lbl.Text = "OK " .. math.floor(r.Position.X) .. "," .. math.floor(r.Position.Z)
        p2Lbl.TextColor3 = Color3.fromRGB(255, 220, 60)
        saveNPCBtn.Text = "âœ” Da luu vi tri NPC"
        saveNPCBtn.BackgroundColor3 = Color3.fromRGB(70, 15, 120)
    end
end)

-- ================================================================
-- BUTTON EVENTS
-- ================================================================
local COL_STOP = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 50,  50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(155, 18,  18)),
})
local COL_START = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(50,  220, 85)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18,  145, 48)),
})

toggleBtn.MouseButton1Click:Connect(function()
    isRunning = not isRunning
    if isRunning then
        sellCount  = 0
        statusText = "Khoi dong..."
        task.spawn(mainLoop)
    else
        stopCast(); stopWalk()
        isSelling = false; statusText = "Da tat"
    end
end)

sellNowBtn.MouseButton1Click:Connect(function()
    if not isRunning then statusText = "Bat tu dong truoc!"; return end
    countdownSec = 0
    sellNowBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 0)
    task.delay(0.6, function() sellNowBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0) end)
end)

UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.F then toggleBtn.MouseButton1Click:Fire() end
    if inp.KeyCode == Enum.KeyCode.H then
        if hubOpen then hideHub() else showHub() end
    end
end)

-- ================================================================
-- UPDATE LOOP
-- ================================================================
local _pSt = ""; local _pRun = nil; local _chkPrev = {}
local chkNames = {fish="Vi tri cau",npc="Vi tri NPC",sell="SellAll",close="X dong",cast="Nut Fishing"}

task.spawn(function()
    while true do
        task.wait(0.25)

        if statusText ~= _pSt then
            _pSt = statusText
            statusLbl.Text = statusText
        end

        if isRunning ~= _pRun then
            _pRun = isRunning
            if isRunning then
                statusLbl.TextColor3      = Color3.fromRGB(80, 255, 140)
                statusDot.BackgroundColor3 = Color3.fromRGB(60, 255, 80)
                sDot.BackgroundColor3      = Color3.fromRGB(60, 255, 80)
                toggleBtn.Text             = "STOP AUTO"
                tGrad.Color                = COL_STOP
            else
                statusLbl.TextColor3      = Color3.fromRGB(255, 100, 100)
                statusDot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
                sDot.BackgroundColor3      = Color3.fromRGB(255, 80, 80)
                toggleBtn.Text             = "START AUTO"
                tGrad.Color                = COL_START
            end
        end

        timerLbl.Text = isSelling
            and ("Dang ban...  Ban: " .. sellCount)
            or  (math.floor(countdownSec/60) .. ":" .. string.format("%02d", countdownSec%60)
                 .. "  Ban: " .. sellCount)

        local checks = {
            fish  = savedFishPos  ~= nil,
            npc   = savedNPCPos   ~= nil,
            sell  = savedSellPos  ~= nil,
            close = savedClosePos ~= nil,
            cast  = savedCastPos  ~= nil,
        }
        local green = Color3.fromRGB(80,  255, 120)
        local red   = Color3.fromRGB(200, 60,  60)
        for k, v in pairs(checks) do
            if v ~= _chkPrev[k] and checkLabels[k] then
                _chkPrev[k] = v
                local ck = checkLabels[k]
                ck.lbl.Text             = (v and "âœ” " or "âœ— ") .. chkNames[k]
                ck.lbl.TextColor3       = v and green or red
                ck.dot.BackgroundColor3 = v and green or red
            end
        end
    end
end)

print("[TF AutoSell] Ready | F=bat/tat | H=an/hien")
