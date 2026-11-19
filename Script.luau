
-- Spotify Lyrics Player
-- Client-side executor script

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local SPOTIFY_TOKEN = "PASTE_YOUR_ACCESS_TOKEN_HERE"

local POLL_INTERVAL = 5
local GUI_NAME = "SpotifyLyricsPlayer"

local PURPLE = Color3.fromRGB(151, 91, 255)
local BG = Color3.fromRGB(13, 11, 18)
local PANEL = Color3.fromRGB(22, 19, 29)
local MUTED = Color3.fromRGB(135, 128, 148)
local WHITE = Color3.fromRGB(245, 242, 250)

local alive = true
local minimized = false
local currentTrackId = nil
local lyricLabels = {}
local lyricData = {}
local activeIndex = 0

-- HTTP
local executorRequest =
    (syn and syn.request)
    or http_request
    or request

local function httpRequest(url, method, headers)
    local options = {
        Url = url,
        Method = method or "GET",
        Headers = headers or {}
    }

    if executorRequest then
        return executorRequest(options)
    end

    return HttpService:RequestAsync(options)
end

local function httpGet(url, headers)
    local ok, response = pcall(function()
        return httpRequest(url, "GET", headers)
    end)

    if not ok then
        warn("[SpotifyLyrics] HTTP error:", response)
        return nil, tostring(response)
    end

    local status = response.StatusCode or response.Status

    if status == 204 then
        return false, "NO_CONTENT"
    end

    if status and (status < 200 or status >= 300) then
        warn("[SpotifyLyrics] HTTP status:", status, response.Body)
        return nil, "HTTP " .. tostring(status)
    end

    local success, decoded = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)

    if not success then
        warn("[SpotifyLyrics] JSON error:", decoded)
        return nil, "Invalid JSON"
    end

    return decoded
end

-- GUI PARENT
local guiParent

if gethui then
    local ok, result = pcall(gethui)
    if ok and result then
        guiParent = result
    end
end

guiParent = guiParent or CoreGui

if not guiParent then
    guiParent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local existing = guiParent:FindFirstChild(GUI_NAME)

if existing then
    existing:Destroy()
end

-- UI HELPERS
local function create(class, properties, parent)
    local object = Instance.new(class)

    for key, value in pairs(properties or {}) do
        object[key] = value
    end

    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius)
    }, parent)
end

-- MAIN GUI
local gui = create("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, guiParent)

local main = create("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(420, 560),
    Position = UDim2.new(0.5, -210, 0.5, -280),
    BackgroundColor3 = BG,
    BorderSizePixel = 0,
    ClipsDescendants = true
}, gui)

corner(main, 16)

create("UIStroke", {
    Color = Color3.fromRGB(75, 52, 105),
    Transparency = 0.2,
    Thickness = 1.3
}, main)

-- HEADER
local header = create("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0
}, main)

corner(header, 16)

create("Frame", {
    Position = UDim2.new(0, 0, 1, -12),
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0
}, header)

create("TextLabel", {
    Position = UDim2.fromOffset(16, 0),
    Size = UDim2.fromOffset(30, 52),
    BackgroundTransparency = 1,
    Text = "♫",
    TextColor3 = PURPLE,
    TextSize = 28,
    Font = Enum.Font.GothamBold
}, header)

create("TextLabel", {
    Position = UDim2.fromOffset(49, 0),
    Size = UDim2.fromOffset(200, 52),
    BackgroundTransparency = 1,
    Text = "SPOTIFY LYRICS",
    TextColor3 = WHITE,
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, header)

local minimize = create("TextButton", {
    Position = UDim2.new(1, -76, 0, 8),
    Size = UDim2.fromOffset(30, 34),
    BackgroundColor3 = Color3.fromRGB(39, 34, 48),
    Text = "−",
    TextColor3 = WHITE,
    TextSize = 22,
    Font = Enum.Font.Gotham
}, header)

corner(minimize, 8)

local close = create("TextButton", {
    Position = UDim2.new(1, -39, 0, 8),
    Size = UDim2.fromOffset(30, 34),
    BackgroundColor3 = Color3.fromRGB(55, 29, 40),
    Text = "×",
    TextColor3 = Color3.fromRGB(255, 115, 135),
    TextSize = 20,
    Font = Enum.Font.Gotham
}, header)

corner(close, 8)

-- CONTENT
local content = create("Frame", {
    Position = UDim2.fromOffset(0, 52),
    Size = UDim2.new(1, 0, 1, -52),
    BackgroundTransparency = 1
}, main)

-- ALBUM ART
local cover = create("ImageLabel", {
    Position = UDim2.fromOffset(18, 17),
    Size = UDim2.fromOffset(92, 92),
    BackgroundColor3 = PANEL,
    Image = "",
    ScaleType = Enum.ScaleType.Crop
}, content)

corner(cover, 12)

-- TRACK INFORMATION
local songTitle = create("TextLabel", {
    Position = UDim2.fromOffset(125, 22),
    Size = UDim2.new(1, -145, 0, 28),
    BackgroundTransparency = 1,
    Text = "Waiting for Spotify...",
    TextColor3 = WHITE,
    TextSize = 17,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd
}, content)

local artist = create("TextLabel", {
    Position = UDim2.fromOffset(125, 52),
    Size = UDim2.new(1, -145, 0, 22),
    BackgroundTransparency = 1,
    Text = "Connect your account",
    TextColor3 = MUTED,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd
}, content)

local status = create("TextLabel", {
    Position = UDim2.fromOffset(125, 80),
    Size = UDim2.new(1, -145, 0, 20),
    BackgroundTransparency = 1,
    Text = "● CONNECTING",
    TextColor3 = PURPLE,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, content)

-- PROGRESS BAR
local progressBG = create("Frame", {
    Position = UDim2.fromOffset(18, 122),
    Size = UDim2.new(1, -36, 0, 4),
    BackgroundColor3 = Color3.fromRGB(48, 42, 57),
    BorderSizePixel = 0
}, content)

corner(progressBG, 10)

local progress = create("Frame", {
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = PURPLE,
    BorderSizePixel = 0
}, progressBG)

corner(progress, 10)

local times = create("Frame", {
    Position = UDim2.fromOffset(18, 130),
    Size = UDim2.new(1, -36, 0, 17),
    BackgroundTransparency = 1
}, content)

local elapsed = create("TextLabel", {
    Size = UDim2.fromOffset(80, 17),
    BackgroundTransparency = 1,
    Text = "0:00",
    TextColor3 = MUTED,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left
}, times)

local duration = create("TextLabel", {
    Position = UDim2.new(1, -80, 0, 0),
    Size = UDim2.fromOffset(80, 17),
    BackgroundTransparency = 1,
    Text = "0:00",
    TextColor3 = MUTED,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Right
}, times)

-- LYRICS
create("TextLabel", {
    Position = UDim2.fromOffset(19, 159),
    Size = UDim2.new(1, -38, 0, 25),
    BackgroundTransparency = 1,
    Text = "LYRICS",
    TextColor3 = WHITE,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, content)

local lyricsFrame = create("ScrollingFrame", {
    Position = UDim2.fromOffset(13, 188),
    Size = UDim2.new(1, -26, 1, -247),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = PURPLE,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, content)

corner(lyricsFrame, 12)

create("UIPadding", {
    PaddingTop = UDim.new(0, 90),
    PaddingBottom = UDim.new(0, 90),
    PaddingLeft = UDim.new(0, 15),
    PaddingRight = UDim.new(0, 15)
}, lyricsFrame)

create("UIListLayout", {
    Padding = UDim.new(0, 19),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center
}, lyricsFrame)

create("TextLabel", {
    Position = UDim2.new(0, 0, 1, -44),
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Text = "POWERED BY SPOTIFY + LRCLIB",
    TextColor3 = Color3.fromRGB(90, 82, 103),
    TextSize = 9,
    Font = Enum.Font.GothamBold
}, content)

-- TIME FORMAT
local function formatTime(ms)
    local seconds = math.floor((ms or 0) / 1000)

    return string.format(
        "%d:%02d",
        math.floor(seconds / 60),
        seconds % 60
    )
end

-- CLEAR LYRICS
local function clearLyrics(message)
    for _, label in ipairs(lyricLabels) do
        label:Destroy()
    end

    table.clear(lyricLabels)
    table.clear(lyricData)

    activeIndex = 0

    local label = create("TextLabel", {
        Size = UDim2.new(1, -20, 0, 70),
        BackgroundTransparency = 1,
        Text = message or "Waiting for lyrics...",
        TextColor3 = MUTED,
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        TextWrapped = true,
        LayoutOrder = 1
    }, lyricsFrame)

    table.insert(lyricLabels, label)
end

-- LRC PARSER
local function parseLRC(lrc)
    local result = {}

    for line in lrc:gmatch("[^\r\n]+") do
        local minutes, seconds, fraction, text =
            line:match("%[(%d+):(%d+)%.(%d+)%](.*)")

        if not minutes then
            minutes, seconds, text =
                line:match("%[(%d+):(%d+)%](.*)")

            fraction = "0"
        end

        if minutes and seconds then
            local timestamp =
                tonumber(minutes) * 60 +
                tonumber(seconds) +
                (tonumber("0." .. fraction) or 0)

            text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")

            if text ~= "" then
                table.insert(result, {
                    time = timestamp,
                    text = text
                })
            end
        end
    end

    table.sort(result, function(a, b)
        return a.time < b.time
    end)

    return result
end

-- LOAD LYRICS
local function loadLyrics(track)
    clearLyrics("Searching for lyrics...")

    local artistName =
        track.artists and
        track.artists[1] and
        track.artists[1].name or ""

    local albumName =
        track.album and
        track.album.name or ""

    local query =
        "https://lrclib.net/api/get?track_name=" ..
        HttpService:UrlEncode(track.name or "") ..
        "&artist_name=" ..
        HttpService:UrlEncode(artistName) ..
        "&album_name=" ..
        HttpService:UrlEncode(albumName) ..
        "&duration=" ..
        tostring(math.floor((track.duration_ms or 0) / 1000))

    local data, err = httpGet(query, {
        ["User-Agent"] = "RobloxSpotifyLyrics/1.0"
    })

    if not data then
        clearLyrics(
            err == "NO_CONTENT"
            and "No lyrics available."
            or "Couldn't retrieve lyrics."
        )
        return
    end

    local lines = {}

    if data.syncedLyrics then
        lines = parseLRC(data.syncedLyrics)
    elseif data.plainLyrics then
        for line in data.plainLyrics:gmatch("[^\r\n]+") do
            if line:match("%S") then
                table.insert(lines, {
                    time = nil,
                    text = line
                })
            end
        end
    end

    if #lines == 0 then
        clearLyrics("No lyrics found for this track.")
        return
    end

    for _, label in ipairs(lyricLabels) do
        label:Destroy()
    end

    table.clear(lyricLabels)
    table.clear(lyricData)

    for i, line in ipairs(lines) do
        local label = create("TextLabel", {
            Size = UDim2.new(1, -10, 0, 38),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = line.text,
            TextColor3 = Color3.fromRGB(112, 104, 124),
            TextSize = 16,
            Font = Enum.Font.GothamBold,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            LayoutOrder = i
        }, lyricsFrame)

        table.insert(lyricLabels, label)
        table.insert(lyricData, line)
    end
end

-- SYNCHRONIZED LYRICS
local function updateLyrics(position)
    if #lyricData == 0 then
        return
    end

    local index = 0

    for i, line in ipairs(lyricData) do
        if line.time and position >= line.time then
            index = i
        end
    end

    if index == 0 or index == activeIndex then
        return
    end

    activeIndex = index

    for i, label in ipairs(lyricLabels) do
        if i == index then
            label.TextColor3 = WHITE

            TweenService:Create(
                label,
                TweenInfo.new(0.3, Enum.EasingStyle.Quint),
                {TextColor3 = PURPLE}
            ):Play()

            local target = math.max(
                0,
                label.AbsolutePosition.Y -
                lyricsFrame.AbsolutePosition.Y -
                lyricsFrame.AbsoluteSize.Y / 2 +
                label.AbsoluteSize.Y / 2
            )

            TweenService:Create(
                lyricsFrame,
                TweenInfo.new(0.4, Enum.EasingStyle.Quint),
                {
                    CanvasPosition = Vector2.new(0, target)
                }
            ):Play()
        else
            label.TextColor3 = Color3.fromRGB(105, 97, 118)
        end
    end
end

-- SPOTIFY API
local function getCurrentTrack()
    return httpGet(
        "https://api.spotify.com/v1/me/player/currently-playing",
        {
            ["Authorization"] = "Bearer " .. SPOTIFY_TOKEN
        }
    )
end

local function update()
    if SPOTIFY_TOKEN == "" or
        SPOTIFY_TOKEN == "PASTE_YOUR_ACCESS_TOKEN_HERE" then

        status.Text = "● TOKEN REQUIRED"
        status.TextColor3 = Color3.fromRGB(255, 125, 135)

        clearLyrics("Paste your Spotify access token into the script.")
        return
    end

    local data, err = getCurrentTrack()

    if data == false or err == "NO_CONTENT" then
        status.Text = "● NOTHING PLAYING"
        status.TextColor3 = MUTED

        songTitle.Text = "Nothing playing"
        artist.Text = "Start listening on Spotify"
        cover.Image = ""

        currentTrackId = nil
        clearLyrics("Your Spotify player is currently idle.")
        return
    end

    if not data then
        status.Text = "● CONNECTION ERROR"
        status.TextColor3 = Color3.fromRGB(255, 125, 135)

        warn("[SpotifyLyrics] Spotify error:", err)
        return
    end

    local track = data.item

    if not track then
        status.Text = "● NOTHING PLAYING"
        status.TextColor3 = MUTED

        currentTrackId = nil
        clearLyrics("Your Spotify player is currently idle.")
        return
    end

    local trackId = track.id or track.name

    if trackId ~= currentTrackId then
        currentTrackId = trackId

        songTitle.Text = track.name or "Unknown track"

        artist.Text =
            track.artists and
            track.artists[1] and
            track.artists[1].name or
            "Unknown artist"

        cover.Image =
            track.album and
            track.album.images and
            track.album.images[1] and
            track.album.images[1].url or ""

        task.spawn(function()
            local ok, errorMessage = pcall(loadLyrics, track)

            if not ok then
                warn("[SpotifyLyrics] Lyrics error:", errorMessage)
                clearLyrics("Failed to load lyrics.")
            end
        end)
    end

    local position = data.progress_ms or 0
    local durationMs = track.duration_ms or 1

    elapsed.Text = formatTime(position)
    duration.Text = formatTime(durationMs)

    progress.Size = UDim2.new(
        math.clamp(position / durationMs, 0, 1),
        0,
        1,
        0
    )

    if data.is_playing then
        status.Text = "● NOW PLAYING"
        status.TextColor3 = PURPLE
    else
        status.Text = "● PAUSED"
        status.TextColor3 = MUTED
    end

    updateLyrics(position / 1000)
end

-- DRAGGING
local dragging = false
local dragStart
local startPosition

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then

        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = false
    end
end)

-- MINIMIZE
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized

    content.Visible = not minimized

    main.Size = minimized
        and UDim2.fromOffset(420, 52)
        or UDim2.fromOffset(420, 560)

    minimize.Text = minimized and "+" or "−"
end)

-- CLOSE
close.MouseButton1Click:Connect(function()
    alive = false
    gui:Destroy()
end)

-- START
clearLyrics("Waiting for Spotify...")

task.spawn(function()
    while alive and gui.Parent do
        local ok, err = pcall(update)

        if not ok then
            warn("[SpotifyLyrics] Update error:", err)

            status.Text = "● SCRIPT ERROR"
            status.TextColor3 = Color3.fromRGB(255, 125, 135)
        end

        task.wait(POLL_INTERVAL)
    end
end)
