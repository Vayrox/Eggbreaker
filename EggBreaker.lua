-- ══════════════════════════════════════════════════════════════
--  EggBreaker  |  Steal An Egg
--  Auto Steal · Instant Steal V2/V3 · Egg Finder · Admin Tools
--  Events: Halloween & The Hollow
-- ══════════════════════════════════════════════════════════════

-- ─── Supabase Config ─────────────────────────────────────────
-- 1. Create a free project at https://supabase.com
-- 2. Open SQL Editor → run the SQL in EggBreaker_SETUP.sql
-- 3. Go to Project Settings → API → paste URL and anon key below
local SUPABASE_URL = "https://lljzffleglvfkfnqiusy.supabase.co"
local SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxsanpmZmxlZ2x2ZmtmbnFpdXN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU0NTk4MzksImV4cCI6MjExMTAzNTgzOX0.vppBV4XtHE0T8vPM0mpjVdt_M-OlgYgv5LM_pIFsMxc"                       -- ← paste anon key from Supabase dashboard
local FINDER_ENABLED = SUPABASE_URL ~= "https://YOUR_PROJECT.supabase.co"

-- ─── Services ────────────────────────────────────────────────
local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local TeleportService  = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local HttpService      = game:GetService("HttpService")
local CollectionService= game:GetService("CollectionService")
local Workspace        = game:GetService("Workspace")

-- Normalize executor HTTP function (Synapse X / KRNL / Fluxus etc.)
local httpRequest = (typeof(request) == "function" and request)
    or (typeof(http_request) == "function" and http_request)
    or (syn and syn.request)
    or nil

-- ─── Player refs ─────────────────────────────────────────────
local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local HRP, Hum
do
    HRP = Char:WaitForChild("HumanoidRootPart", 10)
    Hum = Char:WaitForChild("Humanoid", 10)
end

LP.CharacterAdded:Connect(function(c)
    Char = c
    HRP  = c:WaitForChild("HumanoidRootPart", 10)
    Hum  = c:WaitForChild("Humanoid", 10)
end)

-- ─── Load Rayfield UI ─────────────────────────────────────────
local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok then
    ok, Rayfield = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()
    end)
    if not ok then
        warn("[EggBreaker] UI library failed to load. Script will still run headlessly.")
        Rayfield = nil
    end
end

-- ─── State ───────────────────────────────────────────────────
local State = {
    AutoSteal        = false,
    InstantSteal     = false,
    InstantVersion   = "V3",
    AutoSell         = true,
    WalkSpeed        = 16,
    JumpPower        = 50,
    Noclip           = false,
    Fly              = false,
    FinderActive     = false,
    FinderMinValue   = 50,
    FinderRarity     = 0,
    HalloweenMode    = false,
    HollowMode       = false,
    AutoCollectEvent = false,
    FlySpeed         = 50,
    InfiniteJump     = false,
    AntiKick         = false,
    ServerHopping    = false,
    NotifySteal      = false,
}

-- ─── Remote Detection ────────────────────────────────────────
local Remotes = {}

local function scanRemotes()
    local locations = {
        ReplicatedStorage,
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage:FindFirstChild("RE"),
        ReplicatedStorage:FindFirstChild("RemoteEvents"),
    }
    for _, folder in ipairs(locations) do
        if folder then
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    local n = obj.Name:lower()
                    if n:find("steal") or n:find("collect") or n:find("grab") or n:find("pick") then
                        Remotes.Steal = Remotes.Steal or obj
                    end
                    if n:find("sell") or n:find("cash") or n:find("redeem") then
                        Remotes.Sell = Remotes.Sell or obj
                    end
                    if n:find("rebirth") then
                        Remotes.Rebirth = Remotes.Rebirth or obj
                    end
                    if n:find("equip") or n:find("tool") then
                        Remotes.Equip = Remotes.Equip or obj
                    end
                    if n:find("event") or n:find("halloween") or n:find("hollow") then
                        Remotes.Event = Remotes.Event or obj
                    end
                    if n:find("zone") or n:find("teleport") or n:find("travel") then
                        Remotes.Zone = Remotes.Zone or obj
                    end
                end
            end
        end
    end
    return Remotes
end

task.spawn(scanRemotes)
task.delay(5, scanRemotes)

-- ─── Egg Detection ───────────────────────────────────────────
local EGG_TAGS     = {"Egg", "StealableEgg", "EggObject", "CollectibleEgg"}
local EGG_KEYWORDS = {"egg", "orb", "sphere", "gem"}

local function isEgg(obj)
    if not obj then return false end
    local n = obj.Name:lower()
    for _, kw in ipairs(EGG_KEYWORDS) do
        if n:find(kw) then return true end
    end
    for _, tag in ipairs(EGG_TAGS) do
        if CollectionService:HasTag(obj, tag) then return true end
    end
    return false
end

local function getEggs()
    local eggs = {}
    for _, tag in ipairs(EGG_TAGS) do
        for _, obj in ipairs(CollectionService:GetTagged(tag)) do
            if obj and obj.Parent and obj:IsDescendantOf(Workspace) then
                eggs[#eggs+1] = obj
            end
        end
    end
    if #eggs > 0 then return eggs end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            if isEgg(obj) and not table.find(eggs, obj) then
                eggs[#eggs+1] = obj
            end
        end
    end
    return eggs
end

local function getEggPosition(egg)
    if egg:IsA("Model") then
        local root = egg:FindFirstChild("HumanoidRootPart")
            or egg:FindFirstChild("Root")
            or egg.PrimaryPart
            or egg:FindFirstChildWhichIsA("BasePart")
        if root then return root.Position end
    elseif egg:IsA("BasePart") then
        return egg.Position
    end
    return nil
end

-- ─── Core Functions ──────────────────────────────────────────

local function tpTo(pos)
    if HRP and pos then
        HRP.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end
end

local function activateEgg(egg)
    local pp = egg:FindFirstChildOfClass("ProximityPrompt")
        or (egg:IsA("Model") and egg:FindFirstChildWhichIsA("ProximityPrompt", true))
    if pp then
        fireproximityprompt(pp)
        return true
    end
    local cd = egg:FindFirstChildOfClass("ClickDetector")
        or (egg:IsA("Model") and egg:FindFirstChildWhichIsA("ClickDetector", true))
    if cd then
        fireclickdetector(cd)
        return true
    end
    if Remotes.Steal then
        Remotes.Steal:FireServer(egg)
        return true
    end
    return false
end

local function instantStealV2()
    local eggs = getEggs()
    for _, egg in ipairs(eggs) do
        if Remotes.Steal then
            Remotes.Steal:FireServer(egg)
        end
        task.wait()
    end
end

local function instantStealV3()
    local eggs = getEggs()
    local orig = HRP and HRP.CFrame
    for _, egg in ipairs(eggs) do
        local pos = getEggPosition(egg)
        if pos then
            tpTo(pos)
            activateEgg(egg)
        end
        task.wait()
    end
    if orig and HRP then
        HRP.CFrame = orig
    end
end

local function tryAutoSell()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local n = obj.Name:lower()
            if n:find("sell") or n:find("cashout") or n:find("deposit") then
                local pos = obj:IsA("Model")
                    and obj.PrimaryPart and obj.PrimaryPart.Position
                    or (obj:IsA("BasePart") and obj.Position)
                if pos then
                    tpTo(pos)
                    if Remotes.Sell then
                        Remotes.Sell:FireServer()
                    end
                    task.wait(0.5)
                    return
                end
            end
        end
    end
end

-- ─── Auto Steal Loop ─────────────────────────────────────────
local autoStealConn
local function startAutoSteal()
    if autoStealConn then autoStealConn:Disconnect() end
    autoStealConn = RunService.Heartbeat:Connect(function()
        if not State.AutoSteal then return end
        if not HRP or not Hum or Hum.Health <= 0 then return end

        if State.InstantSteal then
            if State.InstantVersion == "V2" then
                instantStealV2()
            else
                instantStealV3()
            end
            task.wait(0.3)
        else
            local eggs = getEggs()
            local nearest, nearDist = nil, math.huge
            for _, egg in ipairs(eggs) do
                local pos = getEggPosition(egg)
                if pos then
                    local d = (HRP.Position - pos).Magnitude
                    if d < nearDist then
                        nearDist = d
                        nearest = egg
                    end
                end
            end
            if nearest then
                local pos = getEggPosition(nearest)
                if pos then
                    tpTo(pos)
                    activateEgg(nearest)
                end
            end
            task.wait(0.1)
        end

        if State.AutoSell then
            local leaderstats = LP:FindFirstChild("leaderstats")
            if leaderstats then
                local bag = leaderstats:FindFirstChild("Bag")
                    or leaderstats:FindFirstChild("Eggs")
                    or leaderstats:FindFirstChild("Count")
                if bag and tonumber(bag.Value) and tonumber(bag.Value) > 50 then
                    tryAutoSell()
                end
            end
        end
    end)
end
startAutoSteal()

-- ─── Fly ─────────────────────────────────────────────────────
local flyConn, flyBV
local function startFly()
    if not HRP then return end
    if flyBV then flyBV:Destroy() end
    flyBV = Instance.new("BodyVelocity", HRP)
    flyBV.Name = "EggBreakerFly"
    flyBV.Velocity = Vector3.zero
    flyBV.MaxForce = Vector3.new(1e5,1e5,1e5)

    local BG = Instance.new("BodyGyro", HRP)
    BG.Name = "EggBreakerGyro"
    BG.MaxTorque = Vector3.new(0,0,0)

    if flyConn then flyConn:Disconnect() end
    flyConn = RunService.RenderStepped:Connect(function()
        if not State.Fly then
            if flyBV then flyBV:Destroy(); flyBV = nil end
            if BG then BG:Destroy() end
            if flyConn then flyConn:Disconnect(); flyConn = nil end
            return
        end
        if not HRP then return end
        local cam = Workspace.CurrentCamera
        local spd = State.FlySpeed
        local vel = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel = vel + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel = vel - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel = vel - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel = vel + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0,1,0) end
        if flyBV then flyBV.Velocity = vel.Magnitude > 0 and vel.Unit * spd or Vector3.zero end
    end)
end

local function stopFly()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyConn then flyConn:Disconnect(); flyConn = nil end
end

-- ─── Noclip ──────────────────────────────────────────────────
local noclipConn
local function startNoclip()
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Stepped:Connect(function()
        if not State.Noclip then
            if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
            if Char then
                for _, p in ipairs(Char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
                end
            end
            return
        end
        if Char then
            for _, p in ipairs(Char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
end

-- ─── Infinite Jump ───────────────────────────────────────────
UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump and Hum then
        Hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- ─── Anti-Kick ───────────────────────────────────────────────
local function setupAntiKick()
    local mt = getrawmetatable and getrawmetatable(LP)
    if mt then
        local old = mt.__index
        setreadonly(mt, false)
        mt.__index = function(t, k)
            if k == "Kick" and State.AntiKick then
                return function() end
            end
            return old(t, k)
        end
        setreadonly(mt, true)
    end
end
pcall(setupAntiKick)

-- ─── Egg Value Estimator ─────────────────────────────────────
local function estimateEggValue(name)
    local n = name:lower()
    if n:find("skywhale")  then return 500 end
    if n:find("tideler")   then return 350 end
    if n:find("divine") or n:find("eternal") then return 300 end
    if n:find("pegasus") or n:find("abyssjaw") then return 250 end
    if n:find("nightflame") or n:find("storm") then return 200 end
    if n:find("secret")    then return 150 end
    if n:find("legendary") or n:find("royal") then return 80 end
    if n:find("epic") or n:find("rare") then return 30 end
    return 10
end

local function getLocalEggList()
    local list = {}
    local eggs = getEggs()
    for _, egg in ipairs(eggs) do
        local pos = getEggPosition(egg)
        if pos then
            local name = egg.Name
            local dist = HRP and (HRP.Position - pos).Magnitude or 0
            local value = estimateEggValue(name)
            list[#list+1] = { name=name, value=value, dist=dist, pos=pos, egg=egg }
        end
    end
    table.sort(list, function(a,b) return a.value > b.value end)
    return list
end

-- ─── Server Hop ──────────────────────────────────────────────
local function serverHop()
    State.ServerHopping = true
    local ok, err = pcall(function()
        TeleportService:Teleport(game.PlaceId, LP)
    end)
    if not ok then
        warn("[EggBreaker] Server hop failed: " .. tostring(err))
        State.ServerHopping = false
    end
end

-- ─── Supabase Reporter ───────────────────────────────────────
-- Sends this server's best egg snapshot every 30s.
-- Other players running EggBreaker contribute their server too,
-- building a live map of which servers have the rarest eggs.
local function reportServerToFinder()
    if not FINDER_ENABLED or not httpRequest then return end
    local eggs = getLocalEggList()
    if #eggs == 0 then return end
    local top = eggs[1]
    -- Sanitize egg name for JSON (remove quotes/backslashes)
    local safeName = top.name:gsub('[\\"]', "")
    local body = string.format(
        '{"job_id":"%s","place_id":%d,"top_egg":"%s","top_value":%d,"egg_count":%d}',
        tostring(game.JobId), game.PlaceId, safeName, top.value, #eggs
    )
    pcall(function()
        httpRequest({
            Url     = SUPABASE_URL .. "/rest/v1/egg_servers",
            Method  = "POST",
            Headers = {
                ["apikey"]        = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                ["Content-Type"]  = "application/json",
                ["Prefer"]        = "resolution=merge-duplicates",
            },
            Body = body,
        })
    end)
end

-- Start reporting loop (reports immediately, then every 30s)
if FINDER_ENABLED then
    task.spawn(function()
        task.wait(10) -- give game time to load eggs first
        while true do
            reportServerToFinder()
            task.wait(30)
        end
    end)
end

-- ─── Event Support ────────────────────────────────────────────
local EVENT_KEYWORDS = {
    halloween = {"pumpkin","bat","ghost","spider","web","candy","cauldron","witch"},
    hollow    = {"hollow","shadow","dark","void","abyss","bone","skull"},
}

local function collectEventItems(mode)
    local keywords = EVENT_KEYWORDS[mode] or {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local n = obj.Name:lower()
            for _, kw in ipairs(keywords) do
                if n:find(kw) then
                    local pos = obj:IsA("Model") and obj.PrimaryPart and obj.PrimaryPart.Position
                        or (obj:IsA("BasePart") and obj.Position)
                    if pos and HRP then
                        tpTo(pos)
                        local pp = obj:FindFirstChildOfClass("ProximityPrompt", true)
                        local cd = obj:FindFirstChildOfClass("ClickDetector", true)
                        if pp then fireproximityprompt(pp)
                        elseif cd then fireclickdetector(cd)
                        elseif Remotes.Event then Remotes.Event:FireServer(obj) end
                        task.wait(0.05)
                    end
                    break
                end
            end
        end
    end
end

local eventConn
local function startEventLoop()
    if eventConn then eventConn:Disconnect() end
    eventConn = RunService.Heartbeat:Connect(function()
        if State.AutoCollectEvent then
            if State.HalloweenMode then collectEventItems("halloween") end
            if State.HollowMode    then collectEventItems("hollow")    end
        end
        task.wait(1)
    end)
end
startEventLoop()

-- ─── Zone Teleporter ─────────────────────────────────────────
local ZONES = {
    ["Starter"]       = Vector3.new(0,   50, 0),
    ["Alien"]         = Vector3.new(500, 50, 0),
    ["Light Dark"]    = Vector3.new(-500,50, 0),
    ["Titan Temple"]  = Vector3.new(0,   50, 500),
    ["The Hollow"]    = Vector3.new(0,   50,-500),
}

local function tpToZone(zoneName)
    local pos = ZONES[zoneName]
    if pos then
        tpTo(pos)
    elseif Remotes.Zone then
        Remotes.Zone:FireServer(zoneName)
    end
end

-- ─── Speed/Jump Setters ───────────────────────────────────────
local function applySpeed()
    if Hum then
        Hum.WalkSpeed = State.WalkSpeed
        Hum.JumpPower = State.JumpPower
    end
end

LP.CharacterAdded:Connect(function(c)
    Char = c
    HRP  = c:WaitForChild("HumanoidRootPart",10)
    Hum  = c:WaitForChild("Humanoid",10)
    task.wait(1)
    applySpeed()
end)

-- ══════════════════════════════════════════════════════════════
--  RAYFIELD UI
-- ══════════════════════════════════════════════════════════════
if not Rayfield then
    warn("[EggBreaker] Running without UI — all features active headlessly.")
    State.AutoSteal    = true
    State.InstantSteal = true
    return
end

local Window = Rayfield:CreateWindow({
    Name            = "🥚 EggBreaker",
    Icon            = 0,
    LoadingTitle    = "EggBreaker",
    LoadingSubtitle = "Steal An Egg — All Features Free",
    Theme           = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = true,
    ConfigurationSaving    = { Enabled = true, FolderName = "EggBreaker", FileName = "Config" },
    Discord                = { Enabled = false },
    KeySystem              = false,
})

-- ─── Tab: Auto Steal ─────────────────────────────────────────
local AutoTab = Window:CreateTab("🥚 Auto Steal", 4483362458)

AutoTab:CreateToggle({
    Name         = "Auto Steal",
    CurrentValue = false,
    Flag         = "AutoSteal",
    Callback     = function(v) State.AutoSteal = v end,
})

AutoTab:CreateToggle({
    Name         = "Instant Steal",
    CurrentValue = false,
    Flag         = "InstantSteal",
    Callback     = function(v)
        State.InstantSteal = v
        Rayfield:Notify({ Title="Instant Steal", Content=v and "Enabled — "..State.InstantVersion or "Disabled", Duration=2 })
    end,
})

AutoTab:CreateDropdown({
    Name            = "Instant Steal Version",
    Options         = {"V2 (Remote Fire)", "V3 (TP + Activate)"},
    CurrentOption   = {"V3 (TP + Activate)"},
    MultipleOptions = false,
    Flag            = "StealVersion",
    Callback        = function(v)
        State.InstantVersion = v:find("V2") and "V2" or "V3"
    end,
})

AutoTab:CreateDivider()

AutoTab:CreateToggle({
    Name         = "Auto Sell",
    CurrentValue = true,
    Flag         = "AutoSell",
    Callback     = function(v) State.AutoSell = v end,
})

AutoTab:CreateButton({
    Name     = "Sell Now",
    Callback = function() tryAutoSell() end,
})

AutoTab:CreateDivider()

AutoTab:CreateSlider({
    Name         = "Walk Speed",
    Range        = {16, 250},
    Increment    = 1,
    CurrentValue = 16,
    Flag         = "WalkSpeed",
    Callback     = function(v) State.WalkSpeed = v; applySpeed() end,
})

AutoTab:CreateSlider({
    Name         = "Jump Power",
    Range        = {50, 400},
    Increment    = 5,
    CurrentValue = 50,
    Flag         = "JumpPower",
    Callback     = function(v) State.JumpPower = v; applySpeed() end,
})

AutoTab:CreateToggle({
    Name         = "Infinite Jump",
    CurrentValue = false,
    Flag         = "InfJump",
    Callback     = function(v) State.InfiniteJump = v end,
})

-- ─── Tab: Chilli Finder ───────────────────────────────────────
local FinderTab = Window:CreateTab("🔍 Egg Finder", 4483362458)

-- ── Live cross-server finder (requires Supabase keys) ─────────
FinderTab:CreateSection("🌐 Live Server Finder")

if not FINDER_ENABLED then
    FinderTab:CreateLabel("⚠ Add Supabase keys to the script to enable cross-server scanning.")
    FinderTab:CreateLabel("Free: supabase.com — takes ~2 min to set up.")
    FinderTab:CreateLabel("Run EggBreaker_SETUP.sql in your project's SQL Editor.")
else
    FinderTab:CreateLabel("✅ Supabase connected — scanner active.")
end

local finderMinValue = 50
FinderTab:CreateSlider({
    Name         = "Min Egg Value (B/s)",
    Range        = {0, 500},
    Increment    = 10,
    CurrentValue = 50,
    Flag         = "FinderMinVal",
    Callback     = function(v) finderMinValue = v end,
})

FinderTab:CreateButton({
    Name = "🌐 Find Best Server & Join",
    Callback = function()
        if not FINDER_ENABLED then
            Rayfield:Notify({ Title="Finder", Content="Set Supabase keys in the script first.", Duration=4 })
            return
        end
        if not httpRequest then
            Rayfield:Notify({ Title="Finder", Content="Your executor lacks http support (request / http_request).", Duration=4 })
            return
        end
        Rayfield:Notify({ Title="Finder", Content="Querying servers…", Duration=2 })
        task.spawn(function()
            -- Query Supabase for top servers above min value threshold
            local ok2, res = pcall(function()
                return httpRequest({
                    Url     = SUPABASE_URL
                        .. "/rest/v1/egg_servers"
                        .. "?top_value=gte." .. tostring(finderMinValue)
                        .. "&order=top_value.desc"
                        .. "&limit=10"
                        .. "&select=job_id,top_egg,top_value,egg_count",
                    Method  = "GET",
                    Headers = {
                        ["apikey"]        = SUPABASE_KEY,
                        ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                    },
                })
            end)
            if not ok2 or not res or not res.Body then
                Rayfield:Notify({ Title="Finder", Content="Query failed — check your keys.", Duration=4 })
                return
            end
            local ok3, servers = pcall(function()
                return HttpService:JSONDecode(res.Body)
            end)
            if not ok3 or type(servers) ~= "table" then
                Rayfield:Notify({ Title="Finder", Content="Bad response from server.", Duration=4 })
                return
            end
            if #servers == 0 then
                Rayfield:Notify({
                    Title   = "Finder",
                    Content = "No servers reporting yet — the more people run EggBreaker, the more data you get!",
                    Duration= 6,
                })
                return
            end
            -- Build top-5 display
            local lines = {}
            for i = 1, math.min(5, #servers) do
                local s = servers[i]
                lines[#lines+1] = string.format(
                    "#%d  %s  ~%dB/s  (%d eggs)",
                    i, s.top_egg or "?", s.top_value or 0, s.egg_count or 0
                )
            end
            Rayfield:Notify({
                Title   = string.format("Top Servers (%d found)", #servers),
                Content = table.concat(lines, "\n"),
                Duration= 10,
            })
            -- Join the best server if it's not this one
            local best = servers[1]
            if best and best.job_id and best.job_id ~= tostring(game.JobId) then
                task.wait(3)
                Rayfield:Notify({ Title="Finder", Content="Joining best server…", Duration=3 })
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, best.job_id, LP)
                end)
            else
                Rayfield:Notify({ Title="Finder", Content="You're already in the best server!", Duration=3 })
            end
        end)
    end,
})

FinderTab:CreateButton({
    Name = "📋 Show Top 10 (no auto-join)",
    Callback = function()
        if not FINDER_ENABLED or not httpRequest then
            Rayfield:Notify({ Title="Finder", Content="Supabase keys required.", Duration=3 })
            return
        end
        task.spawn(function()
            local ok2, res = pcall(function()
                return httpRequest({
                    Url     = SUPABASE_URL
                        .. "/rest/v1/egg_servers"
                        .. "?top_value=gte." .. tostring(finderMinValue)
                        .. "&order=top_value.desc&limit=10"
                        .. "&select=job_id,top_egg,top_value,egg_count",
                    Method  = "GET",
                    Headers = {
                        ["apikey"]        = SUPABASE_KEY,
                        ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                    },
                })
            end)
            if not ok2 or not res then return end
            local ok3, servers = pcall(function() return HttpService:JSONDecode(res.Body) end)
            if not ok3 or #servers == 0 then
                Rayfield:Notify({ Title="Finder", Content="No data yet.", Duration=3 })
                return
            end
            for i, s in ipairs(servers) do
                print(string.format("[EggBreaker Finder] #%d  %s  %dB/s  %d eggs  job=%s",
                    i, s.top_egg or "?", s.top_value or 0, s.egg_count or 0, s.job_id or "?"))
            end
            Rayfield:Notify({ Title="Finder", Content="Results printed to console (F9)", Duration=4 })
        end)
    end,
})

FinderTab:CreateDivider()

-- ── Local server scan ─────────────────────────────────────────
FinderTab:CreateSection("This Server")

FinderTab:CreateButton({
    Name     = "Scan Current Server",
    Callback = function()
        local list = getLocalEggList()
        if #list == 0 then
            Rayfield:Notify({ Title="Finder", Content="No eggs found in this server.", Duration=3 })
            return
        end
        local top5 = {}
        for i = 1, math.min(5, #list) do
            top5[#top5+1] = string.format("%d. %s (~%dB/s, %.0fm)", i, list[i].name, list[i].value, list[i].dist)
        end
        Rayfield:Notify({
            Title   = "Top Eggs (This Server)",
            Content = table.concat(top5, "\n"),
            Duration= 8,
        })
    end,
})

FinderTab:CreateButton({
    Name     = "TP to Best Egg",
    Callback = function()
        local list = getLocalEggList()
        if list[1] then
            tpTo(list[1].pos)
            activateEgg(list[1].egg)
            Rayfield:Notify({ Title="Finder", Content="Jumped to: "..list[1].name, Duration=2 })
        else
            Rayfield:Notify({ Title="Finder", Content="No eggs found.", Duration=2 })
        end
    end,
})

FinderTab:CreateDivider()
FinderTab:CreateSection("Server Hop")

FinderTab:CreateButton({
    Name     = "Server Hop (random)",
    Callback = function()
        Rayfield:Notify({ Title="Server Hop", Content="Teleporting to a new server…", Duration=3 })
        task.delay(1, serverHop)
    end,
})

FinderTab:CreateDivider()
FinderTab:CreateSection("Zone Teleporter")

for zoneName, _ in pairs(ZONES) do
    local name = zoneName
    FinderTab:CreateButton({
        Name     = "→ " .. name,
        Callback = function() tpToZone(name) end,
    })
end

-- ─── Tab: Events ─────────────────────────────────────────────
local EventTab = Window:CreateTab("🎃 Events", 4483362458)

EventTab:CreateSection("Halloween")

EventTab:CreateToggle({
    Name         = "Auto Collect Halloween",
    CurrentValue = false,
    Flag         = "Halloween",
    Callback     = function(v)
        State.HalloweenMode    = v
        State.AutoCollectEvent = v or State.HollowMode
    end,
})

EventTab:CreateButton({
    Name     = "Collect Halloween Items Now",
    Callback = function() collectEventItems("halloween") end,
})

EventTab:CreateDivider()
EventTab:CreateSection("The Hollow")

EventTab:CreateToggle({
    Name         = "Auto Collect The Hollow",
    CurrentValue = false,
    Flag         = "Hollow",
    Callback     = function(v)
        State.HollowMode       = v
        State.AutoCollectEvent = v or State.HalloweenMode
    end,
})

EventTab:CreateButton({
    Name     = "Collect Hollow Items Now",
    Callback = function() collectEventItems("hollow") end,
})

-- ─── Tab: Admin / Misc ────────────────────────────────────────
local AdminTab = Window:CreateTab("⚡ Admin Tools", 4483362458)

AdminTab:CreateSection("Movement")

AdminTab:CreateToggle({
    Name         = "Fly",
    CurrentValue = false,
    Flag         = "Fly",
    Callback     = function(v)
        State.Fly = v
        if v then startFly() else stopFly() end
    end,
})

AdminTab:CreateSlider({
    Name         = "Fly Speed",
    Range        = {10, 300},
    Increment    = 5,
    CurrentValue = 50,
    Flag         = "FlySpeed",
    Callback     = function(v) State.FlySpeed = v end,
})

AdminTab:CreateToggle({
    Name         = "Noclip",
    CurrentValue = false,
    Flag         = "Noclip",
    Callback     = function(v)
        State.Noclip = v
        if v then startNoclip() end
    end,
})

AdminTab:CreateDivider()
AdminTab:CreateSection("Player")

AdminTab:CreateToggle({
    Name         = "Anti-Kick",
    CurrentValue = false,
    Flag         = "AntiKick",
    Callback     = function(v) State.AntiKick = v end,
})

AdminTab:CreateButton({
    Name     = "Rejoin Server",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, LP)
    end,
})

AdminTab:CreateButton({
    Name     = "Reset Character",
    Callback = function()
        if Hum then Hum.Health = 0 end
    end,
})

AdminTab:CreateDivider()
AdminTab:CreateSection("Debug")

AdminTab:CreateButton({
    Name     = "Print Remote List (console)",
    Callback = function()
        scanRemotes()
        print("[EggBreaker] Remotes found:")
        for k, v in pairs(Remotes) do
            print("  " .. k .. " → " .. v:GetFullName())
        end
        Rayfield:Notify({ Title="Remotes", Content="Printed to console (F9)", Duration=3 })
    end,
})

AdminTab:CreateButton({
    Name     = "Force Scan All Eggs",
    Callback = function()
        local eggs = getEggs()
        Rayfield:Notify({ Title="Scan", Content="Found "..#eggs.." eggs in workspace.", Duration=3 })
    end,
})

AdminTab:CreateButton({
    Name     = "Force Report to Finder",
    Callback = function()
        if not FINDER_ENABLED then
            Rayfield:Notify({ Title="Reporter", Content="Supabase keys not set.", Duration=3 })
        else
            reportServerToFinder()
            Rayfield:Notify({ Title="Reporter", Content="Server data sent to Finder.", Duration=2 })
        end
    end,
})

-- ─── Tab: Settings ────────────────────────────────────────────
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)

SettingsTab:CreateSection("About")
SettingsTab:CreateLabel("EggBreaker")
SettingsTab:CreateLabel("Steal An Egg · All features unlocked")
SettingsTab:CreateLabel("UI: Rayfield  |  Finder: Supabase")
SettingsTab:CreateLabel(FINDER_ENABLED and "Finder: ✅ Connected" or "Finder: ⚠ Keys not set")

SettingsTab:CreateDivider()
SettingsTab:CreateSection("Notifications")

SettingsTab:CreateToggle({
    Name         = "Notify on Steal",
    CurrentValue = false,
    Flag         = "NotifySteal",
    Callback     = function(v) State.NotifySteal = v end,
})

SettingsTab:CreateDivider()

SettingsTab:CreateButton({
    Name     = "Save Config",
    Callback = function()
        Rayfield:Notify({ Title="Config", Content="Configuration saved.", Duration=2 })
    end,
})

SettingsTab:CreateButton({
    Name     = "Reset All Toggles",
    Callback = function()
        State.AutoSteal    = false
        State.InstantSteal = false
        State.Fly          = false
        State.Noclip       = false
        stopFly()
        Rayfield:Notify({ Title="Reset", Content="All toggles reset.", Duration=2 })
    end,
})

-- ══════════════════════════════════════════════════════════════
--  Notify on first load
-- ══════════════════════════════════════════════════════════════
task.delay(2, function()
    Rayfield:Notify({
        Title   = "🥚 EggBreaker Loaded",
        Content = FINDER_ENABLED
            and "Steal An Egg · Live Finder active."
            or  "Steal An Egg · Add Supabase keys to enable Live Finder.",
        Duration = 5,
    })
end)

-- ══════════════════════════════════════════════════════════════
--  END
-- ══════════════════════════════════════════════════════════════
