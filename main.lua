--[[
    naturally alkaline · v3.0.0
    Chests · mobs · ores · village ammo · collection · saved settings.
]]
if typeof(getgenv) == "function" then
    local environment, called = getgenv(), {}
    for key, callback in pairs(environment) do
        if type(key) == "string" and type(callback) == "function" and not called[callback]
            and (key == "NATURALLY_ALKALINE_UNLOAD" or key:match("_DTEC_UNLOAD$")) then
            called[callback] = true
            pcall(callback)
        end
    end
end

local NA = {
    placeId = 74507545904779,
    game = "Drill to Earth's Core",
    version = "3.0.0",
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

if game.PlaceId ~= NA.placeId and game.PlaceId ~= 101906032112547 then
    warn("[NA DTEC] PlaceId mismatch:", game.PlaceId, "expected", NA.placeId)
end

local HUB_NAME = "naturally alkaline"

local State = {
    fly = false,
    noclip = false,
    fullbright = true,
    flySpeed = 1,
    speedHack = false,
    speedBoost = 50,
    speedMultiplier = 2,
    jumpPower = 50,
    connections = {},
    savedLighting = nil,
}

local Autofarm = {
    enabled = false,
    busy = false,
    segmentStuds = 400,
    mapStartMeters = 0,
    mapEndMeters = 100000,
    mapStartStuds = 0,
    mapEndStuds = 100000,
    axis = "+Z",
    trackForward = true,
    routeDirBase = nil,
    routeDir = nil,
    flyY = 70,
    tweenSpeed = 1500,
    origin = nil,
    distance = 0,
    activeTween = nil,
    ownedNoclip = false,
    hoverLocked = false,
    moving = false,
    ownedCamAssist = false,
    camBackup = nil,
    depthHudVisible = false,
    
    autoLoot = false,
    autoSell = true,
    sellThreshold = 10, 
    dropInDrill = false, 
    dropInShredder = false, 
    drillDropTypes = { "Coal" }, 
    _pendingDrillDrop = false,
    _dropDrillOwnedLock = false, 
    scrapFarm = false, 
    scrapPhase = "seek_pick", 
    scrapOreTypes = { "Gold" }, 
    scrapSeekLaps = 0, 
    scrapSeekMinLaps = 2, 
    scrapSaved = nil, 
    _scrapOwnedAutofarm = false, 
    _scrapHadAutofarm = false, 
    lootRange = 10000,
    resumePocketDistance = nil,
    resumePocketPos = nil,
    sellFromPos = nil,
    debugHud = true, 
    enterMines = false, 
    mineDetectRange = 3000, 
    skipMinesUntil = {},
    _activeMine = nil,
    _visitGen = 0,
    suppressMinesUntil = 0,
    openChests = false, 
    chestUnderDepth = 11, 
    chestTypes = {}, 
    lockedChestSkip = {},
    autoEquipBest = false, 
    oreUnderEnabled = false, 
    oreUnderTypes = {}, 
    oreUnderDepth = 11,
    breakDeathWormOres = true,
    enterDungeons = false,
    miningBusy = false,
    _miningBusySince = nil,
    _busySince = nil,
    _cycleGen = 0,
    _cycleAbort = false,
    autoUnloadFuelLock = false,
}

local GearEquip = {
    enabled = false,
    categories = {}, 
    range = 120,
    busy = false,
    lastPassAt = 0,
    slotBest = {}, 
    triedAt = {},
}

local CHEST_CATALOG = {
    { label = "Free Chest", canon = "free" },
    { label = "Tutorial Chest", canon = "tutorialcommon" },
    { label = "Wooden Chest", canon = "common" },
    { label = "Rusty Chest", canon = "rusty" },
    { label = "Steel Chest", canon = "steel" },
    { label = "Golden Chest", canon = "gold" },
    { label = "Diamond Chest", canon = "diamond" },
    { label = "Void Chest", canon = "void" },
    { label = "Phoenix Chest", canon = "phoenix" },
    { label = "Core Chest", canon = "core" },
    { label = "Mimic", canon = "mimic" },
}

local CHEST_TYPE_OPTIONS = {}
local CHEST_ALIAS = {
    free = "free",
    freechest = "free",
    tutorial = "tutorialcommon",
    tutorialcommon = "tutorialcommon",
    tutorialchest = "tutorialcommon",
    wooden = "common",
    wood = "common",
    woodenchest = "common",
    common = "common",
    commonchest = "common",
    rusty = "rusty",
    rustychest = "rusty",
    steel = "steel",
    steelchest = "steel",
    gold = "gold",
    golden = "gold",
    goldenchest = "gold",
    goldchest = "gold",
    diamond = "diamond",
    diamondchest = "diamond",
    void = "void",
    voidchest = "void",
    phoenix = "phoenix",
    phoenixchest = "phoenix",
    chestphoenix = "phoenix",
    core = "core",
    cores = "core",
    corechest = "core",
    coreschest = "core",
    chestcore = "core",
    mimic = "mimic",
}
for _, entry in ipairs(CHEST_CATALOG) do
    table.insert(CHEST_TYPE_OPTIONS, entry.label)
end

local ORE_DROPDOWN_OPTIONS = {
    "Coal",
    "Copper",
    "Gold",
    "Diamond",
    "Ruby",
    "Emerald",
    "HeartGem",
}

local BLACKLIST_OPTIONS = {
    "Scrap",
    "Fuel",
    "Ore",
    "Coal",
    "Copper",
    "Gold",
    "Diamond",
    "Ruby",
    "Emerald",
    "HeartGem",
    "Bar",
    "Corpse",
    "Consumable",
    "Armor",
    "Primary Weapon",
    "Secondary Weapon",
    "Pickaxe",
    "Sword",
    "Medkit",
    "Tool",
}

local BLACKLIST_ORE_TYPES = {}
for _, name in ipairs(ORE_DROPDOWN_OPTIONS) do
    BLACKLIST_ORE_TYPES[string.lower(name)] = name
end
BLACKLIST_ORE_TYPES.iron = "Copper"
BLACKLIST_ORE_TYPES.heart = "HeartGem"
BLACKLIST_ORE_TYPES.heartgem = "HeartGem"

local ESP_LOOT_OPTIONS = { "All Items" }
for _, name in ipairs(BLACKLIST_OPTIONS) do
    table.insert(ESP_LOOT_OPTIONS, name)
end

local Services = {}
local Knit

local S = {}
local CoreFarm

function S.coreInventoryLocked()
    return not S._unloaded and ((type(CoreFarm) == "table" and (CoreFarm._ownedRun == true or CoreFarm._leaving == true))
        or (S._finishSettings and S._finishSettings.busy == true) or S._chestInteraction ~= nil)
end

function S.getKnit()
    if Knit then
        return Knit
    end

    local packages = ReplicatedStorage:WaitForChild("Packages", 30)
    if not packages then
        return nil
    end

    local knitModule = packages:WaitForChild("Knit", 30)
    if not knitModule then
        return nil
    end

    local ok, lib = pcall(require, knitModule)
    if ok then
        Knit = lib
    end

    return Knit
end

local Controls

function S.copyToClipboard(text)
    text = tostring(text or "")
    if text == "" then
        return false
    end
    if typeof(setclipboard) == "function" then
        setclipboard(text)
        return true
    end
    if typeof(toclipboard) == "function" then
        toclipboard(text)
        return true
    end
    if syn and typeof(syn.write_clipboard) == "function" then
        syn.write_clipboard(text)
        return true
    end
    return false
end

local function dropdownList(value)
    if type(value) ~= "table" then
        if type(value) == "string" then
            return { value }
        end
        return value
    end
    if value[1] ~= nil then
        return value
    end
    local out = {}
    for key, item in pairs(value) do
        if type(key) == "string" and item == true then
            out[#out + 1] = key
        elseif type(item) == "string" then
            out[#out + 1] = item
        end
    end
    return out
end

S._finishSettings = { freeSlots = true, equip = true, legendaryFirst = true, autoChurch = true }

function S.createFarmUi()
    local ui={connections={},cache={},closed=false};local library={Unloaded=false,UnloadSignals={},Toggles={},Options={}}
    local controls={Flags={}};local W,H=540,600
    local C={background=Color3.fromHex("10171b"),panel=Color3.fromHex("172228"),raised=Color3.fromHex("203038"),
        border=Color3.fromHex("2a3b43"),white=Color3.fromHex("e7eff2"),muted=Color3.fromHex("94a6af"),
        accent=Color3.fromHex("88c9d7"),water=Color3.fromHex("5595ad"),purple=Color3.fromHex("c4a0f5"),gold=Color3.fromHex("ebcd83")}
    S._farmUi=ui;ui.library,ui.colors=library,C
    local function connect(signal,fn)
        local c=signal:Connect(function(...)if not library.Unloaded then fn(...)end end)
        ui.connections[#ui.connections+1]=c;return c
    end
    local function create(class,name,parent,props)
        local obj=Instance.new(class);obj.Name=name
        for key,value in pairs(props or {})do obj[key]=value end;obj.Parent=parent;return obj
    end
    local function corner(obj)create("UICorner","Corner",obj,{CornerRadius=UDim.new(0,5)})end
    local function box(name,parent,x,y,w,h,color)
        local obj=create("Frame",name,parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            BackgroundColor3=color or C.panel,BorderSizePixel=0});corner(obj);return obj
    end
    local function text(name,parent,x,y,w,h,value,color,size)
        return create("TextLabel",name,parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            BackgroundTransparency=1,Text=value or "",TextColor3=color or C.white,TextSize=size or 12,
            Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
    end
    local function button(name,parent,x,y,w,h,value)
        local obj=create("TextButton",name,parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            BackgroundColor3=C.raised,BorderSizePixel=0,Text=value or "",TextSize=12,Font=Enum.Font.GothamMedium,
            TextColor3=C.white,AutoButtonColor=true});corner(obj);return obj
    end
    local function label(obj,value)if obj and obj.Text~=tostring(value)then obj.Text=tostring(value)end end
    local function flag(name,value,fn)
        local f={CurrentValue=value,_value={Value=value}}
        function f:Set(v)self.CurrentValue=v;self._value.Value=v;if fn then fn(v)end end
        controls.Flags[name]=f
        if type(value)=="boolean"then library.Toggles[name]=f._value else library.Options[name]=f._value end
        return f
    end
    function library:OnUnload(fn)self.UnloadSignals[#self.UnloadSignals+1]=fn end
    function library:Unload()
        if self.Unloaded then return end;self.Unloaded=true
        for _,c in ipairs(ui.connections)do pcall(function()c:Disconnect()end)end;ui.connections={}
        for _,fn in ipairs(self.UnloadSignals)do pcall(fn)end;self.UnloadSignals={}
        if self.ScreenGui then self.ScreenGui:Destroy()end
    end
    function library:Notify(message,duration)
        if not ui.toast or self.Unloaded then return end
        ui.toastToken=(ui.toastToken or 0)+1;local token=ui.toastToken
        label(ui.toastText,message);ui.toast.Visible=true
        task.delay(duration or 5,function()if not self.Unloaded and ui.toastToken==token then ui.toast.Visible=false end end)
    end
    function library:Toggle()
        if not ui.main then return end;ui.main.Visible=not ui.main.Visible;ui.restore.Visible=not ui.main.Visible;ui.drag=nil
    end
    function controls:Notify(options)library:Notify(options.Content,options.Duration)end
    function ui:mount()
        if self.main then return end
        local pg=LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui",15)
        if not pg then error("PlayerGui not ready")end
        local screen=create("ScreenGui","NaturallyAlkaline",pg,{ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=100,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
        library.ScreenGui=screen
        local main=box("FarmWindow",screen,0,0,W,H,C.background);self.main=main
        main.AnchorPoint=Vector2.new(0.5,0.5);main.Position=UDim2.fromScale(0.5,0.5);main.Active=true
        create("UIStroke","Outline",main,{Color=C.border,Thickness=1})
        self.scale=create("UIScale","ResponsiveScale",main,{Scale=1})
        local header=button("DragHeader",main,1,1,W-2,64,"");header.BackgroundColor3=C.panel
        local bottle=box("WaterBottleIcon",header,18,16,20,34,C.white)
        box("BottleCap",bottle,5,-5,10,6,C.accent);box("Water",bottle,2,16,16,15,C.water)
        box("BottleLabel",bottle,2,10,16,8,C.accent)
        text("Title",header,52,12,390,24,"naturally alkaline",C.white,19)
        text("Version",header,53,36,380,16,"3.0  /  Drill to Earth's Core",C.muted,10)
        local hide=button("HideMenu",header,W-48,20,28,26,"−");connect(hide.Activated,function()library:Toggle()end)
        self.pages,self.nav={},{}
        local pageNames={"Cycle","Hunt","Resources","Villages","Settings"}
        for i,name in ipairs(pageNames)do
            local tab=button("Tab"..name,main,16+(i-1)*103,74,97,28,name);self.nav[name]=tab
            local page=create("ScrollingFrame",name.."Page",main,{Position=UDim2.fromOffset(16,158),Size=UDim2.fromOffset(508,382),
                BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.muted,
                CanvasSize=UDim2.fromOffset(0,380),Visible=i==1})
            self.pages[name]=page
            connect(tab.Activated,function()
                self.selected=name
                for key,p in pairs(self.pages)do p.Visible=key==name;self.nav[key].TextColor3=key==name and C.accent or C.muted end
                self:refresh()
            end)
        end
        self.selected="Cycle";self.nav.Cycle.TextColor3=C.accent
        local status=box("StatusPanel",main,16,113,508,35,C.panel)
        self.status=text("CycleStatus",status,10,0,377,35,"Starting",C.white)
        self.master=button("CycleToggle",status,397,5,102,25,"Stop all")
        flag("dtec_core_open",CoreFarm.enabled,function(v)label(self.master,v and "Stop all" or "Start")end)
        connect(self.master.Activated,function()
            if S._v3Running then S.v3Park("Stopped") else S.v3Start()end;self:refresh()
        end)
        self.toggles={}
        local function toggle(page,y,key,title)
            local b=button("Toggle_"..key,page,0,y,496,32,"")
            self.toggles[key]={button=b,title=title}
            connect(b.Activated,function()S.v3Set(key,not S._v3[key])end);return b
        end
        local function choice(page,y,key,title,choices)
            text(key.."Label",page,4,y,200,30,title,C.muted)
            local buttons={};local width=math.floor(280/#choices)
            for i,value in ipairs(choices)do
                local b=button(key..value,page,212+(i-1)*width,y,width-5,29,value);buttons[value]=b
                connect(b.Activated,function()S.v3Set(key,value);self:refresh()end)
            end
            self.choices=self.choices or {};self.choices[key]=buttons
        end
        local function multi(page,y,key,title,values)
            text(key.."Label",page,3,y,490,24,title,C.muted);y+=28
            local rows={}
            for i,value in ipairs(values)do
                local row=button(key.."_"..value,page,((i-1)%3)*166,y+math.floor((i-1)/3)*32,160,28,"");rows[value]=row
                connect(row.Activated,function()
                    local picked=table.clone(S._v3[key]);picked[value]=not picked[value] or nil
                    S.v3Set(key,picked)
                end)
            end
            self.multi=self.multi or {};self.multi[key]=rows
            return y+math.ceil(#values/3)*32
        end
        local function stepper(page,y,key,title,step,min,max)
            text(key.."Label",page,4,y,260,30,title,C.muted)
            local minus=button(key.."Minus",page,328,y,34,28,"−")
            local value=text(key.."Value",page,368,y,80,28,"",C.white)
            local plus=button(key.."Plus",page,456,y,34,28,"+")
            self.steps=self.steps or {};self.steps[key]=value
            connect(minus.Activated,function()S.v3Set(key,math.clamp(S._v3[key]-step,min,max))end)
            connect(plus.Activated,function()S.v3Set(key,math.clamp(S._v3[key]+step,min,max))end)
        end
        local cycle=self.pages.Cycle
        toggle(cycle,0,"chests","Farm chests")
        stepper(cycle,41,"laps","Laps per run",1,1,10)
        toggle(cycle,80,"church","Save at church & return after chest laps")
        self.progressText=text("LapProgress",cycle,4,123,230,25,"0 / 2 laps",C.white,16)
        self.kept=text("KeptValue",cycle,250,123,240,25,"0 items kept",C.muted)
        local progress=box("ProgressTrack",cycle,4,157,486,2,C.border)
        self.progressFill=box("ProgressFill",progress,0,0,0,2,C.accent)
        text("ChestTypesLabel",cycle,4,176,480,24,"Chest types",C.muted)
        self.chestRows={};local chosen={}
        for _,name in ipairs(CoreFarm.chestTypes)do chosen[name]=true end
        flag("dtec_core_chest_types",CoreFarm.chestTypes,function(value)
            chosen={};for _,name in ipairs(value)do chosen[name]=true end
        end)
        flag("dtec_core_rescan",CoreFarm.rescans)
        local all=button("SelectAllChests",cycle,360,174,130,26,"Select all")
        connect(all.Activated,function()S.v3Set("chestTypes",table.clone(CHEST_TYPE_OPTIONS))end)
        for i,name in ipairs(CHEST_TYPE_OPTIONS)do
            local b=button("ChestOption"..i,cycle,((i-1)%2)*250,208+math.floor((i-1)/2)*31,244,27,"");self.chestRows[name]=b
            connect(b.Activated,function()
                local nextList={};local removing=chosen[name]
                for _,option in ipairs(CHEST_TYPE_OPTIONS)do if (option~=name and chosen[option]) or (option==name and not removing)then nextList[#nextList+1]=option end end
                if #nextList==0 then return end;S.v3Set("chestTypes",nextList)
            end)
        end
        local save=button("SaveReturn",cycle,0,408,245,31,"Save & return now")
        local retry=button("RetryReturn",cycle,251,408,245,31,"Retry church return")
        local retryChest=button("RetryChests",cycle,0,447,496,30,"Retry unconfirmed chests")
        connect(save.Activated,function()S.v3CancelActivity();S.coreSaveReturnNow()end)
        connect(retry.Activated,S.coreRetryChurchReturn);connect(retryChest.Activated,S.coreRetryMissedChests)
        cycle.CanvasSize=UDim2.fromOffset(0,490)
        local hunt=self.pages.Hunt
        toggle(hunt,0,"hunt","Farm selected mobs across the map")
        toggle(hunt,40,"aura","Kill aura · nearby mobs")
        stepper(hunt,83,"auraRange","Aura range",6,6,60)
        self.killCount=text("KillCount",hunt,4,123,490,24,"0 confirmed kills",C.muted)
        text("TargetsCaption",hunt,4,155,490,24,"Targets · updates as mobs load",C.muted)
        self.mobRows={};self.mobPage=hunt
        local resources=self.pages.Resources
        toggle(resources,0,"mine","Mine selected ores")
        toggle(resources,40,"mines","Visit mine interiors")
        local oreY=multi(resources,82,"ores","Ore selection",{"Coal","Copper","Iron","Gold","Diamond","Ruby","Emerald","HeartGem"})
        toggle(resources,oreY+8,"collect","Auto collect selected items")
        local lootY=multi(resources,oreY+49,"loot","Collect",{"Shards","Gear","Valuables","Ores","Scrap","Consumables","Other"})
        toggle(resources,lootY+6,"corpses","Collect corpses")
        toggle(resources,lootY+46,"bounties","Collect bounty corpses")
        self.mined=text("Mined",resources,4,lootY+88,490,25,"0 ores mined",C.muted)
        resources.CanvasSize=UDim2.fromOffset(0,lootY+130)
        local villages=self.pages.Villages
        toggle(villages,0,"ammoBuy","Visit villages & buy selected ammo")
        local ammoY=multi(villages,41,"ammo","Ammo types",{"Pistol","Rifle","Special","Shotgun"})
        stepper(villages,ammoY+6,"spendLimit","Session spending cap · coins",500,0,100000000)
        stepper(villages,ammoY+45,"reserveCoins","Keep at least · coins",500,0,100000000)
        toggle(villages,ammoY+87,"stock","Stock highlights & rare-item alerts")
        self.stockInfo=text("StockInfo",villages,4,ammoY+128,490,24,"Loaded stock · refreshed as villages stream",C.muted)
        self.stockParent=villages;self.stockY=ammoY+159;self.stockLabels={}
        local settings=self.pages.Settings
        toggle(settings,0,"autoStart","Start saved farms when executed")
        toggle(settings,40,"autoQueue","Auto queue · solo")
        choice(settings,82,"queueMode","Queue mode",{"Unranked","Ranked"})
        toggle(settings,122,"executeOnTeleport","Execute again after teleport")
        self.queueInfo=text("QueueInfo",settings,4,162,490,25,"",C.muted)
        stepper(settings,202,"speed","Travel speed",100,100,1500)
        local saveCfg=button("SaveConfig",settings,0,245,245,32,"Save settings")
        local loadCfg=button("ReloadConfig",settings,251,245,245,32,"Reload settings")
        connect(saveCfg.Activated,function()S.v3SaveConfig();self:refresh()end)
        connect(loadCfg.Activated,function()
            S.v3Park("Loading settings");S.v3LoadConfig()
            S.trySetControlsFlag("dtec_core_chest_types",CoreFarm.chestTypes)
            if S._v3.autoStart then S.v3Start()end;self:refresh()
        end)
        self.configInfo=text("ConfigInfo",settings,4,285,490,30,"",C.muted)
        text("ConfigPath",settings,4,320,490,24,"naturally_alkaline_v3.json",C.muted,10)
        box("FooterRule",main,16,549,508,1,C.border)
        self.sack=text("SackCapacity",main,19,560,270,24,"Sack · waiting for counter",C.muted,11)
        local copy=button("CopyLog",main,322,560,100,25,"Copy log")
        local unload=button("UnloadScript",main,430,560,94,25,"Unload")
        connect(copy.Activated,S.coreCopyDebug);connect(unload.Activated,function()library:Unload()end)
        self.restore=button("RestoreFarm",screen,18,100,166,32,"naturally alkaline");self.restore.Visible=false
        connect(self.restore.Activated,function()library:Toggle()end)
        self.toast=box("Notification",screen,0,0,400,62,C.panel)
        self.toast.AnchorPoint=Vector2.new(1,1);self.toast.Position=UDim2.new(1,-18,1,-18);self.toast.Visible=false
        self.toastText=text("ToastText",self.toast,12,6,376,50,"",C.purple,12);self.toastText.TextWrapped=true
        local function fit()
            local camera=Workspace.CurrentCamera;self.viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
            self.scale.Scale=math.max(0.2,math.min(1,(self.viewport.X-24)/W,(self.viewport.Y-36)/H));main.Position=UDim2.fromScale(0.5,0.5)
        end
        fit()
        if Workspace.CurrentCamera then self.cameraConnection=connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit)end
        connect(Workspace:GetPropertyChangedSignal("CurrentCamera"),function()
            if self.cameraConnection then self.cameraConnection:Disconnect()end
            if Workspace.CurrentCamera then self.cameraConnection=connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit)end;fit()
        end)
        connect(header.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self.drag={input=input,x=input.Position.X,y=input.Position.Y,position=main.Position}end
        end)
        connect(UserInputService.InputChanged,function(input)
            local d=self.drag;if not d or not screen.Enabled then return end
            if input.UserInputType~=Enum.UserInputType.MouseMovement and input~=d.input then return end
            local xBound=math.max(0,(self.viewport.X-W*self.scale.Scale)*0.5-10)
            local yBound=math.max(0,(self.viewport.Y-H*self.scale.Scale)*0.5-10)
            main.Position=UDim2.new(0.5,math.clamp(d.position.X.Offset+input.Position.X-d.x,-xBound,xBound),0.5,math.clamp(d.position.Y.Offset+input.Position.Y-d.y,-yBound,yBound))
        end)
        connect(UserInputService.InputEnded,function(input)if self.drag and (input==self.drag.input or input.UserInputType==Enum.UserInputType.MouseButton1)then self.drag=nil end end)
        connect(UserInputService.InputBegan,function(input,processed)
            if not processed and input.KeyCode==Enum.KeyCode.RightControl and not UserInputService:GetFocusedTextBox()then library:Toggle()end
        end)
        self:refresh()
    end
    function ui:refresh()
        if not self.main or library.Unloaded or not S._v3 then return end
        local cfg=S._v3
        label(self.status,S.coreStatusCaption(CoreFarm._statusText))
        label(self.master,S._v3Running and "Stop all" or "Start")
        local need=CoreFarm.rescans or 2;local laps=math.min(need,CoreFarm.laps or 0)
        label(self.progressText,laps.." / "..need.." laps");label(self.kept,(CoreFarm._keptCount or 0).." items kept")
        local ratio=laps/need;if self.cache.ratio~=ratio then self.cache.ratio=ratio;self.progressFill.Size=UDim2.fromOffset(486*ratio,2)end
        for key,row in pairs(self.toggles)do label(row.button,(cfg[key] and "ON    " or "OFF   ")..row.title);row.button.TextColor3=cfg[key] and C.accent or C.muted end
        for key,rows in pairs(self.choices or {})do for value,b in pairs(rows)do b.TextColor3=cfg[key]==value and C.accent or C.muted end end
        for key,rows in pairs(self.multi or {})do for value,b in pairs(rows)do label(b,(cfg[key][value] and "✓  " or "    ")..value);b.TextColor3=cfg[key][value] and C.accent or C.muted end end
        for key,node in pairs(self.steps or {})do label(node,cfg[key])end
        for name,row in pairs(self.chestRows)do local on=table.find(CoreFarm.chestTypes,name)~=nil;label(row,(on and "✓  " or "    ")..name);row.TextColor3=on and C.accent or C.muted end
        local count,capacity=S.coreSackCount();label(self.sack,count and capacity and ("Sack  "..count.." / "..capacity) or "Sack · waiting for counter")
        label(self.killCount,(S._v3Kills or 0).." confirmed kills");label(self.mined,(S._v3Mined or 0).." ores mined")
        label(self.configInfo,S._configStatus or "");label(self.queueInfo,S._queueStatus or "Auto execute needs executor teleport support")
        if self.selected=="Hunt" then
            local names={All=true}
            if S._v3Index then for mob in pairs(S._v3Index.mobs)do if mob.Parent then names[S.v3MobName(mob)]=true end end end
            for name in pairs(cfg.mobs)do names[name]=true end
            local sorted={};for name in pairs(names)do sorted[#sorted+1]=name end;table.sort(sorted)
            for _,row in pairs(self.mobRows)do row.Visible=false end
            for i,name in ipairs(sorted)do
                local row=self.mobRows[name]
                if not row then
                    row=button("Mob_"..name,self.mobPage,0,0,496,28,"");self.mobRows[name]=row
                    connect(row.Activated,function()
                        local picked=table.clone(S._v3.mobs)
                        if name=="All" then picked=picked.All and {} or {All=true} else picked.All=nil;picked[name]=not picked[name] or nil end
                        S.v3Set("mobs",picked)
                    end)
                end
                row.Visible=true;row.Position=UDim2.fromOffset(0,188+(i-1)*32)
                label(row,(cfg.mobs[name] and "✓  " or "    ")..name);row.TextColor3=cfg.mobs[name] and C.accent or C.muted
            end
            self.mobPage.CanvasSize=UDim2.fromOffset(0,200+#sorted*32)
        end
        if cfg.stock or self.selected=="Villages" then
            local rows=S.v3StockRows()
            if self.selected=="Villages" then
                local visible=math.min(80,#rows)
                label(self.stockInfo,#rows.." loaded stock items · "..(S._v3AmmoBought or 0).." ammo claims · "..(S._v3Spent or 0).." coins reserved / spent · "..S.v3RestockText())
                for i=1,visible do
                    local row=rows[i];local node=self.stockLabels[i]
                    if not node then node=text("StockRow"..i,self.stockParent,4,self.stockY+(i-1)*27,490,25,"");self.stockLabels[i]=node end
                    node.Visible=true;label(node,row.location.."  /  "..row.name)
                    node.TextColor3=row.quality>=2 and C.purple or row.quality==1 and C.gold or C.muted
                end
                for i=visible+1,#self.stockLabels do self.stockLabels[i].Visible=false end
                self.stockParent.CanvasSize=UDim2.fromOffset(0,self.stockY+math.max(1,visible)*27+12)
            end
        end
    end
    return controls,library
end

do
    local controls, library = S.createFarmUi()
    Controls = controls
    S._alkalineLibrary, S._alkalineWindow = library, controls
    library:OnUnload(function()
        if not S._unloaded then S.unloadAlkaline() end
    end)
end

if not Controls then
    return warn("[naturally alkaline] UI failed to load")
end

function S.hubLog(message)
    S.interactionNote("system", message)
end

function S.notify(title, text, duration)
    text = tostring(text or "")
    local routine = title == "Core" and (text:match("^Lap %d") or text:find("Run on", 1, true)
        or text:find("Chest laps done", 1, true) or text:find("Selected items ready", 1, true))
    if routine and S._quietNotifications ~= false then
        S.interactionNote("info", text)
        return
    end
    pcall(function() Controls:Notify({ Title = title, Content = text, Duration = duration or 4 }) end)
end

function S.getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

function S.getRoot()
    local player = Players.LocalPlayer or LocalPlayer
    local char = player and player.Character
    if not char then
        return nil
    end
    return char:FindFirstChild("HumanoidRootPart")
        or char.PrimaryPart
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("LowerTorso")
        or char:FindFirstChildWhichIsA("BasePart")
end

function S.disconnectAll(key)
    if State.connections[key] then
        pcall(function()
        State.connections[key]:Disconnect()
        end)
        State.connections[key] = nil
    end
end

function S.disconnectEveryConnection()
    for key, conn in pairs(State.connections) do
        if conn then
            pcall(function()
                conn:Disconnect()
            end)
        end
        State.connections[key] = nil
    end
end

function S.unloadAlkaline()
    if S._unloading or S._unloaded then return end
    pcall(S.v3SaveConfig)
    pcall(S.v3CancelActivity)
    S._v3Running=false
    local root = S.getRoot()
    local returnTo = not CoreFarm._teleportPending and game.PlaceId == NA.placeId and S.getDrillReturnCFrame()
    S._unloading, S._unloaded = true, true
    CoreFarm._finishGen, CoreFarm._applyGen = (CoreFarm._finishGen or 0) + 1, (CoreFarm._applyGen or 0) + 1
    CoreFarm.enabled, CoreFarm.openAll, CoreFarm._ownedRun, CoreFarm._leaving = false, false, false, false
    CoreFarm._userStop = true
    Autofarm.enabled = false
    Autofarm._returnGen = (Autofarm._returnGen or 0) + 1
    pcall(S.coreStopLootWatch)
    pcall(S.forceReleaseFarmCharacter)
    pcall(S.setAntiAfk, false)
    pcall(S.disconnectEveryConnection)
    if root and root == S.getRoot() and returnTo then
        root.CFrame = returnTo
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    end
    local library = S._alkalineLibrary
    S._alkalineLibrary, S._alkalineWindow = nil, nil
    if library and not library.Unloaded then library:Unload() end
    if typeof(getgenv) == "function" then getgenv().NATURALLY_ALKALINE_UNLOAD = nil end
    S._unloading = false
end

if typeof(getgenv) == "function" then
    getgenv().NATURALLY_ALKALINE_UNLOAD = S.unloadAlkaline
end

local DEPTH_TARGET_END_METERS = 100000
local DEPTH_LEGACY_STUDS_PER_METER = 2

function S.computeDepthMetersDump(pos)
    if typeof(pos) ~= "Vector3" then
        return 0
    end

    local offset = Workspace:GetAttribute("InfiniteDepthOffsetMeters")
    if typeof(offset) ~= "number" then
        offset = 0
    end

    local start = Workspace:GetAttribute("Start_Position")
    local endPos = Workspace:GetAttribute("End_Position")

    if typeof(start) == "Vector3" and typeof(endPos) == "Vector3" then
        local routeMag = (endPos - start).Magnitude
        if routeMag > 0 then
            local scale = routeMag / DEPTH_TARGET_END_METERS
            return (start - pos).Magnitude / scale + offset
        end
    end

    if typeof(start) == "Vector3" then
        return (start - pos).Magnitude / DEPTH_LEGACY_STUDS_PER_METER + offset
    end

    return offset
end

function S.getDrillDepthMeters()
    local drill = S.getDrill()
    if not drill then
        return nil
    end

    local ok, pos = pcall(function()
        if drill:IsA("Model") then
            return drill:GetPivot().Position
        end
        if drill:IsA("BasePart") then
            return drill.Position
        end
        local part = drill:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end)
    if not ok or typeof(pos) ~= "Vector3" then
        return nil
    end

    local ds = S.getDepthScale()
    if ds and type(ds.GetMetersFromWorldPosition) == "function" then
        local dsOk, meters = pcall(ds.GetMetersFromWorldPosition, ds, pos)
        if dsOk and type(meters) == "number" and meters == meters then
            return meters
        end
    end

    return S.computeDepthMetersDump(pos)
end

function S.computeAutofarmDepthWindow(drillMeters)
    drillMeters = math.max(0, tonumber(drillMeters) or 0)
    local startM = math.floor(drillMeters / DEPTH_TARGET_END_METERS) * DEPTH_TARGET_END_METERS
    return startM, startM + DEPTH_TARGET_END_METERS
end

function S.getWorldPositionAtDepthMeters(meters)
    meters = tonumber(meters) or 0
    local offset = Workspace:GetAttribute("InfiniteDepthOffsetMeters")
    if typeof(offset) ~= "number" then
        offset = 0
    end

    local start = Workspace:GetAttribute("Start_Position")
    local endPos = Workspace:GetAttribute("End_Position")
    if typeof(start) ~= "Vector3" or typeof(endPos) ~= "Vector3" then
        return nil
    end

    local routeMag = (endPos - start).Magnitude
    if routeMag <= 0 then
        return nil
    end

    local scale = routeMag / DEPTH_TARGET_END_METERS
    local along = (meters - offset) * scale
    local dir = start - endPos
    if dir.Magnitude < 0.001 then
        return nil
    end

    return start - dir.Unit * along
end

function S.getWorldFlatAtDepthMeters(meters)
    local pos = S.getWorldPositionAtDepthMeters(meters)
    if not pos then
        return nil
    end
    return Vector3.new(pos.X, S.getAutofarmFlyY(), pos.Z)
end

function S.syncAutofarmWindowFromDrill()
    local drillM = S.getDrillDepthMeters()
    if not drillM then
        drillM = tonumber(Autofarm.mapStartMeters) or 0
        if tonumber(Autofarm.mapEndMeters) then
            drillM = drillM + (Autofarm.mapEndMeters - drillM) * 0.5
        else
            drillM = DEPTH_TARGET_END_METERS * 0.5
        end
    end

    local startM, endM = S.computeAutofarmDepthWindow(drillM)
    local prevStart = tonumber(Autofarm.mapStartMeters)
    local windowChanged = prevStart == nil or prevStart ~= startM
    local spp = S.getAutofarmStudsPerMeter()

    Autofarm.mapStartMeters = startM
    Autofarm.mapEndMeters = endM
    Autofarm.mapStartStuds = 0
    Autofarm.mapEndStuds = DEPTH_TARGET_END_METERS * spp

    if windowChanged then
        local flat = S.getWorldFlatAtDepthMeters(startM)
        if flat then
            Autofarm.origin = flat
            S.refreshAutofarmRouteDir()
        end
        S.syncAutofarmDistanceFromRoot()
        if Autofarm.enabled then
            S.setAutofarmPose(Autofarm.distance or 0)
        end
    end

    return windowChanged, startM, endM
end

function S.getAutofarmStudsPerMeter()
    local start = Workspace:GetAttribute("Start_Position")
    local endPos = Workspace:GetAttribute("End_Position")
    if typeof(start) == "Vector3" and typeof(endPos) == "Vector3" then
        local route = (endPos - start).Magnitude
        if route > 0 then
            return route / DEPTH_TARGET_END_METERS
        end
    end
    return DEPTH_LEGACY_STUDS_PER_METER
end

function S.syncAutofarmMapEndFromMeters()
    local _, startM, endM = S.syncAutofarmWindowFromDrill()
    return Autofarm.mapEndStuds, startM, endM
end

local DepthScaleModule = nil
function S.getDepthScale()
    if DepthScaleModule ~= nil then
        return DepthScaleModule ~= false and DepthScaleModule or nil
    end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local util = shared and shared:FindFirstChild("Util")
    local modInst = util and util:FindFirstChild("DepthScale")
    if not modInst then
        return nil
    end
    local ok, mod = pcall(require, modInst)
    DepthScaleModule = (ok and type(mod) == "table") and mod or false
    return DepthScaleModule ~= false and DepthScaleModule or nil
end

local EXCLUDED_ITEMS = { Money_Sack = true, SoulOrb = true }

function S.resolveWorldItem(instance)
    local current = instance
    local itemsFolder = Workspace:FindFirstChild("Items")
    if not itemsFolder then
        return nil
    end

    while current and current ~= itemsFolder do
        if current.Parent == itemsFolder then
            return current
        end
        current = current.Parent
    end

    return nil
end

function S.getItemPosition(item)
    if item:IsA("Model") then
        return item:GetPivot().Position
    end
    if item:IsA("BasePart") then
        return item.Position
    end
    local part = item:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

function S.stripRarityPrefix(text, rarityAttr)
    local s = string.lower(tostring(text or "")):gsub("^%s+", ""):gsub("%s+$", "")
    local function cut(prefix)
        prefix = string.lower(tostring(prefix or "")):gsub("^%s+", ""):gsub("%s+$", "")
        if prefix == "" then
            return nil
        end
        if s == prefix then
            return ""
        end
        local lead = prefix .. " "
        if s:sub(1, #lead) == lead then
            return s:sub(#lead + 1)
        end
        return nil
    end
    local fromAttr = cut(rarityAttr)
    if fromAttr ~= nil then
        return fromAttr
    end
    for _, rarity in ipairs({
        "common",
        "uncommon",
        "rare",
        "epic",
        "legendary",
        "mythic",
        "divine",
        "exotic",
        "unique",
    }) do
        local cutOne = cut(rarity)
        if cutOne ~= nil then
            return cutOne
        end
    end
    return s
end

function S.normalizeLootCategory(cat)
    cat = string.lower(tostring(cat or ""))
    if cat == "secondary gun" or cat == "secondary weapon" or cat == "secondary" then
        return "secondary weapon"
    end
    if cat == "primary gun" or cat == "primary weapon" or cat == "primary" then
        return "primary weapon"
    end
    if cat == "consume" or cat == "consumable" then
        return "consumable"
    end
    if cat == "melee" then
        return "sword"
    end
    return cat
end

function S.itemCategoryKey(item)
    if not item then return "" end
    local rarity = item:GetAttribute("Rarity")
    for _, field in ipairs({"DisplayCategory", "Category", "Class", "ItemType", "Type"}) do
        local raw = item:GetAttribute(field)
        if raw ~= nil and tostring(raw) ~= "" then
            local category = S.normalizeLootCategory(S.stripRarityPrefix(raw, rarity))
            if category ~= "" then return category end
        end
    end
    return ""
end

function S.isHardExcluded(item)
    if not item then
        return true
    end
    if S.coreStorageObject(item) then return true end
    local name = item.Name
    if name and EXCLUDED_ITEMS[name] then
        return true
    end
    local ok, tagged = pcall(function()
        return CollectionService:HasTag(item, "ShopItem")
    end)
    if ok and tagged then
        return true
    end
    return false
end

function S.forEachWorldLootItem(callback)
    local itemsFolder = Workspace:FindFirstChild("Items")
    if itemsFolder then
        for _, child in ipairs(itemsFolder:GetChildren()) do
            callback(child)
        end
    end

    for _, tagged in ipairs(CollectionService:GetTagged("DungeonLootHighlightTarget")) do
        callback(S.resolveWorldItem(tagged))
    end
end

function S.isItemBagTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end
    local class = tool:GetAttribute("Class")
    local name = tool.Name or ""
    if class == "ItemBag" or name == "ItemBag" or name == "Large_Sack" then
        return true
    end
    return name:find("Sack", 1, true) ~= nil or name:find("Bag", 1, true) ~= nil
end

function S.isPickaxeTool(tool)
    if not tool then
        return false
    end
    local class = tool:GetAttribute("Class") or ""
    return class == "Pickaxe" or tool.Name:lower():find("pickaxe", 1, true) ~= nil
end

local PICKAXE_TIER_KEYS = {
    { key = "kings", rank = 100 },
    { key = "king", rank = 100 },
    { key = "phoenix", rank = 90 },
    { key = "void", rank = 80 },
    { key = "diamond", rank = 70 },
    { key = "golden", rank = 60 },
    { key = "gold", rank = 60 },
    { key = "steel", rank = 40 },
    { key = "rusty", rank = 20 },
    { key = "wooden", rank = 10 },
    { key = "wood", rank = 10 },
}

local SWORD_TIER_KEYS = {
    { key = "excalibur", rank = 120 },
    { key = "kingslayer", rank = 110 },
    { key = "kings", rank = 110 },
    { key = "executioner", rank = 105 },
    { key = "samurai", rank = 100 },
    { key = "katana", rank = 100 },
    { key = "phoenix", rank = 90 },
    { key = "void", rank = 80 },
    { key = "diamond", rank = 70 },
    { key = "bountyhunter", rank = 60 },
    { key = "golden", rank = 50 },
    { key = "gold", rank = 50 },
    { key = "steel", rank = 40 },
    { key = "rusty", rank = 20 },
    { key = "wooden", rank = 10 },
    { key = "wood", rank = 10 },
}

local ARMOR_TIER_KEYS = {
    { key = "kings", rank = 100 },
    { key = "king", rank = 100 },
    { key = "phoenix", rank = 90 },
    { key = "void", rank = 80 },
    { key = "diamond", rank = 70 },
    { key = "golden", rank = 60 },
    { key = "gold", rank = 60 },
    { key = "steel", rank = 50 },
    { key = "rusty", rank = 40 },
    { key = "executioner", rank = 36 },
    { key = "samurai", rank = 35 },
    { key = "goblinking", rank = 34 },
    { key = "bountyhunter", rank = 33 },
    { key = "pirate", rank = 32 },
    { key = "princess", rank = 31 },
    { key = "reaper", rank = 30 },
    { key = "bruiser", rank = 28 },
    { key = "gunslinger", rank = 27 },
    { key = "demolitionist", rank = 26 },
    { key = "mechanic", rank = 24 },
    { key = "luckylooter", rank = 23 },
    { key = "scout", rank = 22 },
    { key = "racer", rank = 21 },
    { key = "driller", rank = 20 },
    { key = "tank", rank = 19 },
    { key = "healer", rank = 18 },
    { key = "medic", rank = 18 },
    { key = "miner", rank = 10 },
}

function S.getDrill()
    return Workspace:FindFirstChild("Drill")
end

function S.getDrillCabinSeat()
    local drill = S.getDrill()
    if not drill then
        return nil
    end

    local names = { "LocalDriverSeat", "DrillPhysicsSeat", "VehicleSeat" }
    for _, name in ipairs(names) do
        local seat = drill:FindFirstChild(name, true)
        if seat and seat:IsA("BasePart") then
            return seat
        end
    end

    for _, desc in ipairs(drill:GetDescendants()) do
        if desc:IsA("VehicleSeat") then
            return desc
        end
    end

    return nil
end

function S.leaveDrillCabin()
    local humanoid = S.getHumanoid()
    if humanoid then
        pcall(function()
            humanoid.Sit = false
        end)
    end
end

function S.releaseAutofarmSeat()
    S.leaveDrillCabin()
    local char = LocalPlayer.Character
    if not char then
        return
    end
    pcall(function()
        for _, inst in ipairs(char:GetDescendants()) do
            if inst:IsA("Weld") and inst.Name == "SeatWeld" then
                inst:Destroy()
            end
        end
    end)
end

function S.getDrillBedWeldPart()
    local drill = S.getDrill()
    if not drill then
        return nil
    end

    local fuelTouch = drill:FindFirstChild("FuelTouchPart", true)
    local furnace = drill:FindFirstChild("Furnace", true)
    local best, bestArea = nil, 0

    for _, part in ipairs(drill:GetDescendants()) do
        if part:IsA("BasePart") and CollectionService:HasTag(part, "WeldPart") then
            if part == fuelTouch or part == furnace then
                continue
            end
            local n = string.lower(part.Name or "")
            if n:find("fuel", 1, true) or n:find("furnace", 1, true) or n:find("fire", 1, true) then
                continue
            end
            local area = part.Size.X * part.Size.Z
            if area > bestArea then
                bestArea = area
                best = part
            end
        end
    end

    if best then
        return best
    end

    for _, part in ipairs(drill:GetDescendants()) do
        if part:IsA("BasePart")
            and CollectionService:HasTag(part, "WeldPart")
            and part ~= fuelTouch
            and part ~= furnace
        then
            return part
        end
    end

    return drill.PrimaryPart or drill:FindFirstChildWhichIsA("BasePart", true)
end

function S.getDrillTrailerBackDirection(bed, drill)
    drill = drill or S.getDrill()
    bed = bed or S.getDrillBedWeldPart()

    local fuel = nil
    if drill then
        fuel = drill:FindFirstChild("FuelTouchPart", true)
            or drill:FindFirstChild("Furnace", true)
            or drill:FindFirstChild("DrillHead", true)
    end

    local origin = (bed and bed.Position) or (drill and drill:GetPivot().Position)
    if not origin then
        return Vector3.new(0, 0, 1)
    end

    if fuel and fuel:IsA("BasePart") then
        
        local flat = Vector3.new(origin.X - fuel.Position.X, 0, origin.Z - fuel.Position.Z)
        if flat.Magnitude > 0.5 then
            return flat.Unit
        end
    end

    local dig = S.getDrillFlatLook and S.getDrillFlatLook() or nil
    if dig and dig.Magnitude > 0.05 then
        return -dig.Unit 
    end

    if bed then
        local look = Vector3.new(bed.CFrame.LookVector.X, 0, bed.CFrame.LookVector.Z)
        if look.Magnitude > 0.05 then
            return -look.Unit
        end
    end

    return Vector3.new(0, 0, 1)
end

function S.getDrillBedParkCFrame(index)
    local bed = S.getDrillBedWeldPart()
    local drill = S.getDrill()
    if not bed and not drill then
        return nil
    end

    index = tonumber(index) or 0
    local col = index % 4
    local row = math.floor(index / 4)
    local ox = (col - 1.5) * 1.4
    local rowBack = (row % 4) * 1.15
    local backDir = S.getDrillTrailerBackDirection(bed, drill)
    local right = Vector3.new(-backDir.Z, 0, backDir.X)

    if bed then
        
        local halfDepth = math.max(bed.Size.X, bed.Size.Z) * 0.5
        local rearBias = math.max(10, halfDepth * 0.75)
        local up = bed.Size.Y * 0.5 + 1.25
        local pos = bed.Position
            + backDir * (rearBias + rowBack)
            + right * ox
            + Vector3.new(0, up, 0)
        return CFrame.lookAt(pos, pos + backDir)
    end

    local pivot = drill:GetPivot().Position
    local pos = pivot + backDir * (14 + rowBack) + right * ox + Vector3.new(0, 3.5, 0)
    return CFrame.lookAt(pos, pos + backDir)
end

function S.getDrillTrailerStandPosition()
    local bed = S.getDrillBedWeldPart()
    local drill = S.getDrill()
    local park = S.getDrillBedParkCFrame(0)
    local backDir = S.getDrillTrailerBackDirection(bed, drill)
    if park then
        return park.Position + Vector3.new(0, 2.4, 0) + backDir * 2
    end
    if bed then
        return bed.Position + backDir * 12 + Vector3.new(0, 4, 0)
    end
    if drill then
        return drill:GetPivot().Position + backDir * 16 + Vector3.new(0, 5, 0)
    end
    return nil
end

function S.getDrillReturnCFrame()
    local stand = S.getDrillTrailerStandPosition()
    if stand then
        return CFrame.new(stand)
    end
    local seat = S.getDrillCabinSeat()
    if seat then
        return seat.CFrame * CFrame.new(0, 3.5, 0)
    end
    local drill = S.getDrill()
    if drill then
        return drill:GetPivot() * CFrame.new(0, 6, 14)
    end
    return nil
end

function S.stopFarmLoopsSoft()
    Autofarm.busy = false
    Autofarm._cycleRunning = false
    Autofarm.moving = false
    Autofarm.miningBusy = false
    Autofarm._oreHuntMode = false
    Autofarm._miningBusySince = nil
    Autofarm._busySince = nil
    Autofarm._cycleAbort = true
    Autofarm._gatePinY = nil
    Autofarm.resumePocketDistance = nil
    Autofarm.resumePocketPos = nil
    Autofarm.sellFromPos = nil
    S.cancelAutofarmTween()
    S.releaseCharacterHold()
    S.clearDragTarget()
end

function S.forceReleaseFarmCharacter()
    Autofarm._farmShuttingDown = true
    Autofarm._returningToDrill = false
    Autofarm.hoverLocked = false
    S.stopFarmLoopsSoft()
    S.disconnectAll("autofarm")
    S.disconnectAll("autofarmGlide")
    S.disconnectAll("autofarmHover")
    S.disconnectAll("autofarmAntiFall")
    S.ensureAutofarmAntiFall(false)
    S.lockAutofarmHover(false)
    S.resetAutofarmCharacterState()
    S.setAutofarmCameraAssist(false)
    local humanoid = S.getHumanoid()
    if humanoid then
        pcall(function()
            humanoid.Sit = false
            humanoid.PlatformStand = false
        end)
    end
    local root = S.getRoot()
    if root then
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    if Autofarm.ownedNoclip then
        S.setNoclip(false)
        Autofarm.ownedNoclip = false
    end
    Autofarm._farmShuttingDown = false
end

function S.returnToDrillAfterFarmStop(opts)
    opts = type(opts) == "table" and opts or {}
    local keepEngine = opts.keepEngine == true
    local force = opts.force == true

    if Autofarm._returningToDrill and not force then
        return
    end
    Autofarm._returnGen = (Autofarm._returnGen or 0) + 1
    local gen = Autofarm._returnGen
    Autofarm._returningToDrill = true
    Autofarm._farmShuttingDown = true

    local function stale()
        return Autofarm.enabled == true or gen ~= Autofarm._returnGen
    end

    task.spawn(function()
        local ok, err = pcall(function()
            task.wait(0.05)
            if stale() then
                return
            end
            S.stopFarmLoopsSoft()
            S.ensureAutofarmAntiFall(false)
            S.lockAutofarmHover(false)

            local humanoid = S.getHumanoid()
            if humanoid then
                pcall(function()
                    humanoid.Sit = false
                    humanoid.PlatformStand = false
                end)
            end

            local target = S.getDrillReturnCFrame()
            local root = S.getRoot()
            if root and target then
                pcall(function()
                    S.requestStreamAround(target.Position, 1.0)
                end)
                task.wait(0.1)
                if stale() then
                    return
                end
                root = S.getRoot()
                if root then
                    root.Anchored = false
                    root.CFrame = target
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    task.wait(0.08)
                    if stale() then
                        return
                    end
                    root = S.getRoot()
                    if root then
                        root.CFrame = target
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end

            if stale() then
                return
            end
            if keepEngine and Autofarm.enabled then
                Autofarm._farmShuttingDown = false
                S.resetAutofarmStart()
                S.setAutofarmPlatformStand(true)
                S.ensureAutofarmAntiFall(true)
                S.lockAutofarmHover(true)
                S.notify("Autofarm", "Back at drill", 3)
            else
                S.forceReleaseFarmCharacter()
                S.notify("Autofarm", "Stopped — back at drill", 3)
            end
        end)

        if not ok then
            warn("[naturally alkaline] returnToDrill", err)
            pcall(S.forceReleaseFarmCharacter)
        end
        Autofarm._returningToDrill = false
        Autofarm._farmShuttingDown = false
    end)
end

function S.setDragTarget(item)
    local knit = S.getKnit()
    if not knit then
        return false
    end
    return pcall(function()
        local drag = knit.GetController("DragController")
        if not drag then
            return
        end
        drag.Target = item
        if drag.TargetChanged then
            drag.TargetChanged:Fire(item)
        end
    end)
end

function S.trySetControlsFlag(name, value)
    local control = Controls and Controls.Flags and Controls.Flags[name]
    if not control then return false end
    control:Set(value)
    return true
end

function S.getDrillFlatLook()
    local drill = S.getDrill()
    if drill then
        local flat = Vector3.new(drill:GetPivot().LookVector.X, 0, drill:GetPivot().LookVector.Z)
        if flat.Magnitude > 0.05 then
            return flat.Unit
        end

        local head = drill:FindFirstChild("DrillHead", true)
        if head and head:IsA("BasePart") then
            flat = Vector3.new(head.CFrame.LookVector.X, 0, head.CFrame.LookVector.Z)
            if flat.Magnitude > 0.05 then
                return flat.Unit
            end
        end

        if drill.PrimaryPart then
            flat = Vector3.new(drill.PrimaryPart.CFrame.LookVector.X, 0, drill.PrimaryPart.CFrame.LookVector.Z)
            if flat.Magnitude > 0.05 then
                return flat.Unit
            end
        end
    end

    return Vector3.new(0, 0, -1)
end

function S.getInstancePosition(inst)
    if not inst then
        return nil
    end
    if inst:IsA("BasePart") then
        return inst.Position
    end
    if inst:IsA("Attachment") then
        return inst.WorldPosition
    end
    if inst:IsA("Model") then
        return inst:GetPivot().Position
    end
    if inst:IsA("Folder") or inst:IsA("Configuration") then
        local part = inst:FindFirstChildWhichIsA("BasePart", true)
            or inst:FindFirstChildWhichIsA("Attachment", true)
        if part then
            return S.getInstancePosition(part)
        end
    end
    local part = inst:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return part.Position
    end
    local att = inst:FindFirstChildWhichIsA("Attachment", true)
    return att and att.WorldPosition or nil
end

function S.collectProximityPrompts(instance)
    local prompts = {}
    if not instance then
        return prompts
    end
    if instance:IsA("ProximityPrompt") and instance.Enabled then
        table.insert(prompts, instance)
    end
    for _, desc in ipairs(instance:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            table.insert(prompts, desc)
        end
    end
    return prompts
end

function S.getPromptWorldPosition(prompt)
    if not prompt then return nil end
    local parent = prompt.Parent
    if not parent then return nil end
    if parent:IsA("Attachment") then return parent.WorldPosition end
    if parent:IsA("BasePart") then return parent.Position end
    if parent:IsA("Model") then

        return parent.PrimaryPart and parent.PrimaryPart.Position or nil
    end
    return nil
end

function S.faceCharacterToward(worldPos)
    local root = S.getRoot()
    if not root or not worldPos then
        return
    end
    local pos = root.Position
    local flat = Vector3.new(worldPos.X, pos.Y, worldPos.Z)
    if (flat - pos).Magnitude < 0.05 then
        return
    end
    root.CFrame = CFrame.lookAt(pos, flat)
    root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
    root.AssemblyAngularVelocity = Vector3.zero
end

function S.aimCameraAtWorld(worldPos, saved)
    local cam = Workspace.CurrentCamera
    if not cam or not worldPos then
        return saved
    end

    if not saved then
        saved = {
            cf = cam.CFrame,
            cameraType = cam.CameraType,
            subject = cam.CameraSubject,
        }
    end

    local root = S.getRoot()
    local eye = (root and (root.Position + Vector3.new(0, 2.2, 0))) or cam.CFrame.Position
    pcall(function()
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = CFrame.lookAt(eye, worldPos)
    end)
    return saved
end

function S.restoreCameraAim(saved)
    if not saved then
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then
        return
    end
    pcall(function()
        cam.CameraType = saved.cameraType or Enum.CameraType.Custom
        if saved.subject then
            cam.CameraSubject = saved.subject
        end
        if saved.cf then
            cam.CFrame = saved.cf
        end
    end)
end

function S.preparePromptsForHold(prompts)
    local backup = {}
    for _, prompt in ipairs(prompts) do
        local entry = {
            prompt = prompt,
            requiresLOS = prompt.RequiresLineOfSight,
            maxDist = prompt.MaxActivationDistance,
            exclusivity = prompt.Exclusivity,
        }
        pcall(function()
            prompt.RequiresLineOfSight = false
            prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
        end)
        table.insert(backup, entry)
    end
    return backup
end

function S.restorePromptsAfterHold(backup)
    if type(backup) ~= "table" then
        return
    end
    for _, entry in ipairs(backup) do
        local prompt = entry.prompt
        if prompt and prompt.Parent then
            pcall(function()
                prompt.RequiresLineOfSight = entry.requiresLOS
                prompt.MaxActivationDistance = entry.maxDist
                prompt.Exclusivity = entry.exclusivity
            end)
        end
    end
end

function S.chestInteractionActive(context)
    return context ~= nil and not S._unloaded and not S._unloading
        and S._chestInteraction == context and LocalPlayer.Character == context.character
        and S.getRoot() == context.root and context.root.Parent ~= nil
        and (not context.farm or (Autofarm.enabled and Autofarm._cycleGen == context.cycle))
        and not CoreFarm._userStop and not CoreFarm._leaving
end

function S.chestPrompt(chest)
    local best, score = nil, -math.huge
    for _, prompt in ipairs(S.collectProximityPrompts(chest)) do
        local action = string.lower(prompt.ActionText or "")
        if prompt.Enabled and not action:find("buy", 1, true) and not action:find("purchase", 1, true)
            and not action:find("equip", 1, true) and not S.chestTextLocked(action) and not S.chestTextLocked(prompt.ObjectText) then
            local pos = S.getPromptWorldPosition(prompt)
            local root = S.getRoot()
            local range = tonumber(prompt.MaxActivationDistance) or 10
            if pos and range > 0 then
                local value = (action:find("open", 1, true) and 100 or action == "interact" and 80 or 10)
                    - (root and (root.Position - pos).Magnitude or 0) * 0.001
                if value > score then best, score = prompt, value end
            end
        end
    end
    return best
end

function S.pinChestInteraction(context, prompt)
    if not S.chestInteractionActive(context) or not prompt or not prompt.Parent then return false end
    local pos = S.getPromptWorldPosition(prompt)
    local range = tonumber(prompt.MaxActivationDistance) or 10
    if not pos or range <= 0 then return false end
    local drop = math.min(tonumber(Autofarm.chestUnderDepth) or 11, range * 0.35)
    local side = math.min(1.5, range * 0.15) * ((context.attempt or 1) % 2 == 0 and -1 or 1)
    local stand = pos + Vector3.new(0, -drop, side)
    local root = context.root
    Autofarm._mineHoldPos, Autofarm._mineLookAt, Autofarm._gatePinY = stand, pos, stand.Y
    root.Anchored = false
    root.CFrame = CFrame.new(stand)
    root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    S.setAutofarmPlatformStand(true)
    S.faceCharacterToward(pos)
    context.camera = S.aimCameraAtWorld(pos, context.camera)
    return (root.Position - pos).Magnitude <= range
end

function S.chestInteractionTarget(chest, prompt, attempt)
    if (attempt or 1) % 2 == 0 then return chest end
    local node = prompt and prompt.Parent
    while node and node ~= chest.Parent do
        if CollectionService:HasTag(node, "Interactive") then return node end
        if node == chest then break end
        node = node.Parent
    end
    -- Both targets are used by the game's existing InteractionService path.
    return chest:FindFirstChild("Chest", true) or (prompt and prompt.Parent) or chest
end

function S.chestServerInteract(context, prompt)
    if not S.chestInteractionActive(context) or not context.chest.Parent or not Services.InteractionService then return false end
    if S.isChestPadlocked(context.chest) then return false end
    if not S.pinChestInteraction(context, prompt) then return false end
    local target = S.chestInteractionTarget(context.chest, prompt, context.attempt)
    if not target or not target.Parent then return false end
    S.setDragTarget(target)
    local ok, promise = pcall(function() return Services.InteractionService:Interact(target) end)
    if not ok then
        S.interactionNote("chest request", tostring(promise):sub(1, 120))
        return false
    end
    -- Dispatching a promise is not opening the chest. Reward/state confirmation
    -- is checked separately, including after this promise resolves.
    if type(promise) == "table" and type(promise.catch) == "function" then
        pcall(function() promise:catch(function(err)
            if S.chestInteractionActive(context) then
                S.interactionNote("chest server", tostring(err):sub(1, 100))
            end
        end) end)
    end
    return true
end

function S.chestTextLocked(text)
    local lower = string.lower(tostring(text or ""))
    -- "Unlocked" and "unlocked chest" are positive states, not lock notices.
    lower = lower:gsub("unlocked", "")
    if lower:match("^locked") or lower:match("^padlocked") then return true end
    for _, phrase in ipairs({"requires a", "require a", "needs a", "need a", "use a", "use key", "unlock", "defeat", "clear dungeon", "complete dungeon"}) do
        if lower:find(phrase, 1, true) and (lower:find("key", 1, true) or lower:find("defeat", 1, true)
            or lower:find("dungeon", 1, true) or phrase == "unlock") then return true end
    end
    return lower:match("%f[%a]locked%f[%A]") ~= nil
        or lower:match("%f[%a]padlocked%f[%A]") ~= nil
        or lower:find("requires key", 1, true) ~= nil
        or lower:find("requires a key", 1, true) ~= nil
        or lower:find("need a key", 1, true) ~= nil
        or lower:find("key required", 1, true) ~= nil
end

function S.chestProgress()
    local result = { opened = 0, pending = 0, locked = 0, blocked = 0, waiting = 0, unloaded = 0 }
    S.forEachWorldChestNode(function(chest) S.rememberFarmChest(chest) end)
    for _, entry in pairs(S._knownFarmChests or {}) do
        local chest = entry.chest
        if not S.chestMatchesAutofarmWhitelist(chest) then continue end
        local record = S.chestAttemptRecord(chest)
        if entry.done or record.done or S.chestOpened(chest) then
            record.done, entry.done = true, true
            result.opened += 1
        elseif (chest.Parent and S.chestLockStatus(chest)) or (not chest.Parent and entry.locked) then
            entry.locked = true
            result.locked += 1
        else
            entry.locked = false
            result.pending += 1
            if not chest.Parent then result.unloaded += 1 end
            if record.blocked or entry.blocked then result.blocked += 1
            elseif os.clock() < (record.retryAt or 0) then result.waiting += 1 end
        end
    end
    return result
end

function S.rememberFarmChest(chest)
    if not chest or not chest.Parent or S.coreStorageObject(chest) or S.isDecorativeOrShopChest(chest)
        or CollectionService:HasTag(chest, "ShopItem") or CollectionService:HasTag(chest, "SupplyCrate") then return nil end
    S._knownFarmChests, S._farmChestInstances = S._knownFarmChests or {}, S._farmChestInstances or setmetatable({}, {__mode = "k"})
    if S._farmChestInstances[chest] then return S._farmChestInstances[chest] end
    local pos = S.getInstancePosition(chest)
    if not pos or pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z
        or math.abs(pos.X) == math.huge or math.abs(pos.Y) == math.huge or math.abs(pos.Z) == math.huge then return nil end
    local key = chest.Name .. string.format(":%.0f:%.0f:%.0f", pos.X * 2, pos.Y * 2, pos.Z * 2)
    local entry = S._knownFarmChests[key] or {position = pos, name = chest.Name}
    entry.chest = chest
    entry.blocked, entry.streamTries = false, 0
    S._knownFarmChests[key], S._farmChestInstances[chest] = entry, entry
    if entry.done then S.chestAttemptRecord(chest).done = true end
    return entry
end

function S.restreamPendingChest()
    if os.clock() < (CoreFarm._nextChestStream or 0) then return end
    CoreFarm._nextChestStream = os.clock() + 2
    for _, entry in pairs(S._knownFarmChests or {}) do
        if not entry.done and not entry.locked and not entry.chest.Parent and not entry.blocked
            and S.chestMatchesAutofarmWhitelist(entry.chest) then
            entry.streamTries = (entry.streamTries or 0) + 1
            if entry.streamTries > 3 then
                entry.blocked = true
                S.interactionNote("chest streaming", entry.name .. ": not loaded; Retry chests to retry")
            else
                S.coreSetStatus("Reloading missed chest · " .. entry.name)
                pcall(S.requestStreamAround, entry.position, 1.2)
            end
            return
        end
    end
end

function S.coreCompleteChestRun()
    if CoreFarm._leaving or CoreFarm._userStop or S._unloaded then return end
    CoreFarm._chestSummary = S.chestProgress()
    CoreFarm._drainingChests = false
    CoreFarm._leaving, CoreFarm.openAll, CoreFarm._ownedRun, CoreFarm._runStarted = true, false, false, false
    CoreFarm._finishGen = (CoreFarm._finishGen or 0) + 1
    local gen, before = CoreFarm._finishGen, CoreFarm._coresBefore
    S.disconnectAll("autofarmGlide")
    S.disconnectAll("autofarm")
    task.spawn(function()
        local ok, err = pcall(S.coreFinishRun, before, gen)
        if not ok and S.coreFinishActive(gen) then
            S.coreStopLootWatch()
            S.clearDragTarget()
            S.notify("Core", "Return paused: " .. tostring(err), 8)
        end
    end)
end

function S.coreDrainChestsTick()
    if not CoreFarm._drainingChests or CoreFarm._leaving or CoreFarm._userStop or S._chestInteraction then return end
    local summary = S.chestProgress()
    CoreFarm._chestSummary = summary
    local index = S.ensureChestIndex()
    if summary.pending > 0 then
        CoreFarm._chestQuietSince = nil
        local message = summary.blocked == summary.pending
            and ("Chest retries paused · " .. summary.pending .. " unconfirmed · Retry chests")
            or ("Finishing chests · " .. summary.pending .. " remaining")
        CoreFarm._drainStatus = message
        S.coreSetStatus(message)
        if summary.unloaded > 0 then S.restreamPendingChest() end
        return
    end
    -- Let the streaming/index queue settle before deciding the two laps are done.
    if index and (index.running or index.head <= index.tail) then
        CoreFarm._chestQuietSince = nil
        S.coreSetStatus("Finishing chest scan")
        return
    end
    CoreFarm._chestQuietSince = CoreFarm._chestQuietSince or os.clock()
    if os.clock() - CoreFarm._chestQuietSince >= 2 then S.coreCompleteChestRun() end
end

function S.coreRetryMissedChests()
    if S._unloaded or S._chestInteraction or CoreFarm._leaving then return false end
    local reset = 0
    for chest, record in pairs(S._chestAttempts or {}) do
        if chest.Parent and not record.done then
            record.tries, record.retryAt, record.blocked, record.missingPrompt = 0, 0, false, 0
            reset += 1
        end
    end
    for _, entry in pairs(S._knownFarmChests or {}) do
        if not entry.done then
            entry.blocked, entry.streamTries = false, 0
            local record = S.chestAttemptRecord(entry.chest)
            if not record.done then record.tries, record.retryAt, record.blocked, record.missingPrompt = 0, 0, false, 0 end
        end
    end
    CoreFarm._chestQuietSince = nil
    S.interactionNote("chests", reset .. " unconfirmed chest attempts reset")
    S.coreSetStatus(CoreFarm._drainingChests and "Retrying remaining chests" or "Retrying missed chests")
    return true
end

function S.holdChestInteract(instance, seconds, context)
    if not instance or not instance.Parent or S._unloaded or S.coreStorageObject(instance) or S.isChestPadlocked(instance) then return false end
    local owns = context == nil
    if owns then
        if S._chestInteraction then return false end
        local root = S.getRoot()
        if not root then return false end
        context = { chest = instance, root = root, character = LocalPlayer.Character,
            cycle = Autofarm._cycleGen, farm = Autofarm.enabled, attempt = 1 }
        S._chestInteraction = context
    elseif S._chestInteraction ~= context then return false end
    local prompt = S.chestPrompt(instance)
    if not prompt or not S.chestInteractionActive(context) then
        if owns and S._chestInteraction == context then S._chestInteraction = nil end
        return false
    end
    local focused
    pcall(function() focused = UserInputService:GetFocusedTextBox() end)
    if focused then
        if owns and S._chestInteraction == context then S._chestInteraction = nil end
        return false
    end
    local hold = math.max(tonumber(seconds) or 0, tonumber(prompt.HoldDuration) or 0) + 0.4
    if hold ~= hold or hold > 180 then
        if owns and S._chestInteraction == context then S._chestInteraction = nil end
        return false
    end
    local backup, method, complete = S.preparePromptsForHold({prompt}), nil, false
    context.inputStarted = false
    local keyAttempted = false
    local key = prompt.KeyboardKeyCode or Enum.KeyCode.E
    local function keyDown()
        keyAttempted = true
        return S.sendNativeKey(key, true)
    end
    local ok, err = pcall(function()
        if not S.pinChestInteraction(context, prompt) then return end
        local target = S.chestInteractionTarget(instance, prompt, context.attempt)
        if target then S.setDragTarget(target) end
        task.wait(0.2)
        if not S.chestInteractionActive(context) or S.isChestPadlocked(instance) then return end
        -- Try native keyboard input first, so the game's own input controller
        -- gets the complete hold. Later attempts use prompt input as a fallback.
        if (context.attempt or 1) % 2 == 1 and keyDown() then method = "key"
        elseif pcall(function() prompt:InputHoldBegin() end) then method = "prompt"
        elseif keyDown() then method = "key"
        elseif typeof(fireproximityprompt) == "function" then
            method = "executor"
            fireproximityprompt(prompt, tonumber(prompt.HoldDuration) or 0)
        else return end
        context.inputStarted = true
        local deadline = os.clock() + hold
        while S.chestInteractionActive(context) and os.clock() < deadline do
            if type(context.coresBefore) == "number"
                and (tonumber(LocalPlayer:GetAttribute("Cores")) or 0) > context.coresBefore then
                complete = true
                break
            end
            if S.chestLockStatus(instance) then return end
            if not instance.Parent or not prompt.Parent or not S.pinChestInteraction(context, prompt) then return end
            task.wait(0.08)
        end
        complete = complete or (S.chestInteractionActive(context) and os.clock() >= deadline)
    end)
    -- Releasing is unconditional, including stops, respawns and input failures.
    if keyAttempted then pcall(S.sendNativeKey, key, false) end
    if method == "prompt" then pcall(function() prompt:InputHoldEnd() end) end
    pcall(S.restorePromptsAfterHold, backup)
    if owns then
        pcall(S.restoreCameraAim, context.camera)
        if S._chestInteraction == context then S._chestInteraction = nil end
    end
    if not ok then S.interactionNote("chest hold", tostring(err):sub(1, 120)) end
    -- True means the hold finished; only chestOpened() confirms a reward/open.
    return ok and complete
end

function S.isArmorWorldItem(item)
    if not item then
        return false
    end
    if item:GetAttribute("Armor") ~= nil or item:GetAttribute("ArmorType") ~= nil then
        return true
    end
    local cat = S.itemCategoryKey(item)
    local class = string.lower(tostring(item:GetAttribute("Class") or ""))
    if cat == "armor" or class == "armor" then
        return true
    end
    
    if cat ~= "" and cat ~= "armor" then
        return false
    end
    if class ~= "" and class ~= "armor" then
        return false
    end
    local name = string.lower(item.Name or "")
    
    if CollectionService:HasTag(item, "Interactive") and item:FindFirstChildWhichIsA("ProximityPrompt", true) then
        return false
    end
    if name:find("helmet", 1, true)
        or name:find("boot", 1, true)
        or name:find("torso", 1, true)
        or name:find("vest", 1, true)
        or name:find("_legs", 1, true)
        or name:find("legs_", 1, true)
        or (name:find("chest", 1, true) and not name:find("chestnode", 1, true))
    then
        return true
    end
    return false
end

function S.isSwordWorldItem(item)
    if not item then
        return false
    end
    if S.isPickaxeWorldItem(item) then
        return false
    end
    local class = string.lower(tostring(item:GetAttribute("Class") or ""))
    local name = string.lower(item.Name or "")
    local display = string.lower(tostring(item:GetAttribute("DisplayName") or ""))
    local cat = S.itemCategoryKey(item)
    if class == "pickaxe" or cat == "pickaxe" or cat == "scrap" or cat == "fuel" or cat == "ore" then
        return false
    end
    if class == "sword" or cat == "sword" or cat == "melee" then
        return true
    end
    return S.looksLikeSwordName(S.normalizeGearToken(name .. display))
end

function S.isPickaxeWorldItem(item)
    if not item then
        return false
    end
    local class = string.lower(tostring(item:GetAttribute("Class") or ""))
    local name = string.lower(item.Name or "")
    local display = string.lower(tostring(item:GetAttribute("DisplayName") or ""))
    local cat = S.itemCategoryKey(item)
    if class == "pickaxe" or cat == "pickaxe" then
        return true
    end
    if name:find("pickaxe", 1, true) or display:find("pickaxe", 1, true) then
        return true
    end
    
    if (cat == "tool" or class == "tool") and (
        name:find("pick", 1, true) or display:find("pick", 1, true)
            or name:find("picareta", 1, true)
    ) then
        return true
    end
    
    if S.getPickaxeRank(item.Name) > 0 then
        return true
    end
    return false
end

function S.getGearItemCategory(item)
    if S.isPickaxeWorldItem(item) then
        return "Pickaxe"
    end
    if S.isSwordWorldItem(item) then
        return "Sword"
    end
    if S.isArmorWorldItem(item) then
        return "Armor"
    end
    return nil
end

function S.normalizeGearToken(name)
    return string.lower(tostring(name or "")):gsub("[^%a%d]", "")
end

function S.tierFromKeys(token, keys)
    local best = 0
    for _, entry in ipairs(keys) do
        if token:find(entry.key, 1, true) and entry.rank > best then
            best = entry.rank
        end
    end
    return best
end

function S.looksLikeSwordName(token)
    return token:find("sword", 1, true)
        or token:find("excalibur", 1, true)
        or token:find("katana", 1, true)
        or token:find("kingslayer", 1, true)
        or token:find("executioner", 1, true)
        or token:find("samurai", 1, true)
end

function S.getPickaxeRank(name)
    local token = S.normalizeGearToken(name)
    if not token:find("pick", 1, true) and not token:find("picareta", 1, true) then
        return 0
    end
    return S.tierFromKeys(token, PICKAXE_TIER_KEYS)
end

function S.getSwordRank(name)
    local token = S.normalizeGearToken(name)
    if not S.looksLikeSwordName(token) then
        return 0
    end
    return S.tierFromKeys(token, SWORD_TIER_KEYS)
end

function S.getArmorMaterialRank(name)
    local token = S.normalizeGearToken(name)
    if token:find("goblinking", 1, true) then return 34 end
    return S.tierFromKeys(S.normalizeGearToken(name), ARMOR_TIER_KEYS)
end

function S.armorLabel(item)
    if not item then
        return ""
    end
    local bits = { tostring(item.Name or ""), tostring(item:GetAttribute("DisplayName") or "") }
    for _, key in ipairs({
        "ArmorType",
        "Material",
        "ArmorMaterial",
        "Set",
        "ArmorSet",
        "Skin",
        "Tier",
        "ArmorName",
        "ItemId",
    }) do
        local value = item:GetAttribute(key)
        if typeof(value) == "string" then
            table.insert(bits, value)
        end
    end
    pcall(function()
        for _, child in ipairs(item:GetChildren()) do
            table.insert(bits, child.Name)
            local display = child:GetAttribute("DisplayName")
            if typeof(display) == "string" then
                table.insert(bits, display)
            end
        end
    end)
    return table.concat(bits, " ")
end

function S.getArmorSlotKey(item)
    if not item then
        return "Chest"
    end
    local armorType = item:GetAttribute("ArmorType")
    local t = typeof(armorType) == "string" and armorType or ""
    local name = string.lower(S.armorLabel(item))
    local tl = string.lower(t)
    local acc = ""
    pcall(function()
        if item:IsA("Accessory") then
            acc = string.lower(tostring(item.AccessoryType))
        end
    end)
    
    if tl == "head" or tl == "helmet" or acc:find("hat", 1, true) or name:find("helmet", 1, true) or name:find("hat", 1, true) then
        return "Helmet"
    end
    if tl == "boots" or tl == "boot" or tl == "feet" or tl == "foot" or name:find("boot", 1, true) then
        return "Boots"
    end
    if tl == "legs" or tl == "leg" or name:find("legs", 1, true) or name:find("pants", 1, true) then
        return "Legs"
    end
    if tl == "torso" or tl == "chest" or name:find("chest", 1, true) or name:find("torso", 1, true) or name:find("vest", 1, true) then
        return "Chest"
    end
        if tl == "helmet" or tl == "chest" or tl == "legs" or tl == "boots" then
            return t
    end
    return "Chest"
end

function S.getWorldGearScore(item)
    if not item then
        return -1
    end
    local category = S.getGearItemCategory(item)
    local dmg = math.clamp(tonumber(S.getToolDamage(item)) or 0, 0, 50000)
    local label = tostring(item.Name or "") .. tostring(item:GetAttribute("DisplayName") or "")

    if category == "Pickaxe" then
        local rank = S.tierFromKeys(S.normalizeGearToken(label), PICKAXE_TIER_KEYS)
        if rank > 0 then
            return rank * 100000 + dmg
        end
        return dmg
    end
    if category == "Sword" then
        local rank = S.getSwordRank(label)
        if rank > 0 then
            return rank * 100000 + dmg
        end
        return dmg
    end
    if category == "Armor" then
        local armorHp = item:GetAttribute("Armor")
        local defense = item:GetAttribute("Defense")
        local value = item:GetAttribute("Value")

        local mat = S.getArmorMaterialRank(S.armorLabel(item))
        local hp = 0
        if typeof(armorHp) == "number" then
            hp = armorHp
        elseif typeof(defense) == "number" then
            hp = defense
        elseif typeof(value) == "number" then
            hp = value
        end
        if mat > 0 then
            return mat * 100000 + math.clamp(hp, 0, 50000)
        end
        return math.clamp(hp, 0, 50000)
    end
    return -1
end

function S.getEquippedArmorPiece(slotKey)
    local char = LocalPlayer.Character
    if not char or not slotKey then
        return nil
    end
    local best, bestScore = nil, -1
    local function consider(child)
        if not child or child == char then
            return
        end
        local armorName = child:GetAttribute("ArmorName")
        local hasArmor = typeof(armorName) == "string"
            or child:GetAttribute("ArmorType") ~= nil
            or child:GetAttribute("Armor") ~= nil
            or child:GetAttribute("ArmorIcon") ~= nil
        if not hasArmor and not S.isArmorWorldItem(child) then
            return
        end
        if S.getArmorSlotKey(child) ~= slotKey then
            return
        end
        local score = S.getWorldGearScore(child)
        if score > bestScore then
            bestScore = score
            best = child
        end
    end
    for _, child in ipairs(char:GetChildren()) do
        consider(child)
    end
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Accessory") then
            consider(desc)
        end
    end
    return best
end

function S.bestOwnedToolScore(kind)
    local best = -1
    local function scan(container)
        if not container then
            return
        end
        for _, child in ipairs(container:GetChildren()) do
            if not child:IsA("Tool") then
                continue
            end
            local match = (kind == "Pickaxe" and S.isPickaxeWorldItem(child))
                or (kind == "Sword" and S.isSwordWorldItem(child))
            if match then
                best = math.max(best, S.getWorldGearScore(child))
            end
        end
    end
    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    return best
end

function S.getCurrentGearScore(category, worldItem)
    if category == "Pickaxe" or category == "Sword" then return S.bestOwnedToolScore(category) end
    if category ~= "Armor" then return -1 end
    local slot = S.getArmorSlotKey(worldItem)
    local piece = S.getEquippedArmorPiece(slot)
    local score = piece and S.getWorldGearScore(piece) or -1
    local confirmed = S._confirmedArmor and S._confirmedArmor[slot]
    if confirmed and confirmed.character == LocalPlayer.Character and confirmed.generation == CoreFarm._finishGen
        and os.clock() - confirmed.at < 3 then score = math.max(score, confirmed.score) end
    return score
end

function S.isDecorativeOrShopChest(inst)
    if not inst then
        return true
    end

    if S.coreStorageObject(inst) then return true end
    local cur = inst
    while cur and cur ~= Workspace do
        local n = string.lower(cur.Name or "")
        if n == "coinshop"
            or n == "shop"
            or n == "sell_table"
            or n == "bountysell"
            or n == "sellparts"
            or n:find("coinshop", 1, true)
            or n:find("armory", 1, true)
            or n:find("blacksmith", 1, true)
        then
            return true
        end
        cur = cur.Parent
    end

    return false
end

function S.isChestInDungeonWave(inst)
    local cur = inst
    while cur and cur ~= Workspace do
        local n = tostring(cur.Name or "")
        if n == "Wave" or n:match("^Wave%d+$") then
            return true
        end
        cur = cur.Parent
    end
    return false
end

function S.isChestStepJunk(inst)
    if not inst then
        return true
    end
    local cur = inst
    while cur and cur ~= Workspace do
        if cur.Name == "ChestStep" then
            return true
        end
        cur = cur.Parent
    end
    return false
end

function S.resolveDungeonChestModel(inst)
    if not inst then
        return nil
    end

    if inst:IsA("ProximityPrompt") then
        local parent = inst.Parent
        if parent then
            local model = parent:FindFirstAncestorOfClass("Model") or parent.Parent
            if model and model:IsA("Model") then
                inst = model
            end
        end
    elseif inst:IsA("BasePart") then
        
        local model = inst.Parent
        if model and model:IsA("Model") and string.lower(model.Name):find("chest", 1, true) then
            inst = model
        else
            inst = inst:FindFirstAncestorOfClass("Model") or inst
        end
    end

    if not inst or not inst.Parent then
        return nil
    end

    local n = string.lower(inst.Name or "")
    if n == "chest" and inst.Parent and inst.Parent:IsA("Model") then
        local pn = string.lower(inst.Parent.Name or "")
        if pn:find("chest", 1, true) then
            inst = inst.Parent
        end
    end

    return inst
end

function S.markChestLocked(inst)
    if not inst then
        return
    end
    Autofarm.lockedChestSkip = Autofarm.lockedChestSkip or {}
    local untilTick = tick() + 120 
    Autofarm.lockedChestSkip[inst] = untilTick
    local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
    if model then
        Autofarm.lockedChestSkip[model] = untilTick
    end
end

function S.isChestMarkedLocked(inst)
    if not inst then
        return false
    end
    Autofarm.lockedChestSkip = Autofarm.lockedChestSkip or {}
    local function check(obj)
        local untilTick = Autofarm.lockedChestSkip[obj]
        if not untilTick then
            return false
        end
        if tick() < untilTick then
            return true
        end
        Autofarm.lockedChestSkip[obj] = nil
        return false
    end
    if check(inst) then
        return true
    end
    local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
    return model ~= nil and check(model)
end

function S.playerGuiSaysChestLocked()
    local cache, now = S.gameGuiCache(), os.clock()
    if cache.lockAt and now - cache.lockAt < 0.75 then return cache.locked == true end
    cache.lockAt, cache.locked = now, false
    for label in pairs(cache.labels) do
        if not label.Parent then cache.labels[label] = nil
        elseif S.gameGuiVisible(label) then
            local text = string.lower(label.Text or "")
            if text:find("chest", 1, true) and S.chestTextLocked(text) then cache.locked = true; break end
        end
    end
    return cache.locked
end

function S.isChestPadlocked(inst)
    if not inst then return false end
    if S.isChestMarkedLocked(inst) then return true end
    local function state(object)
        local function yes(v) return v == true or v == 1 or (type(v) == "string" and v:lower() == "true") end
        local function no(v) return v == false or v == 0 or (type(v) == "string" and v:lower() == "false") end
        for _, key in ipairs({"Locked", "IsLocked", "Padlocked", "BossLocked", "DungeonLocked"}) do
            if yes(object:GetAttribute(key)) then return true end
        end
        if yes(object:GetAttribute("Unlocked")) or yes(object:GetAttribute("CanOpen")) then return false end
        for _, key in ipairs({"Unlocked", "CanOpen"}) do
            if no(object:GetAttribute(key)) then return true end
        end
        for _, key in ipairs({"RequiresKey", "KeyRequired", "NeedsKey"}) do
            if yes(object:GetAttribute(key)) then return true end
        end
        for _, key in ipairs({"LockState", "Status", "State"}) do
            if S.chestTextLocked(object:GetAttribute(key)) then return true end
        end
        if no(object:GetAttribute("Locked")) or no(object:GetAttribute("IsLocked")) then return false end
        return nil
    end
    local ownState = state(inst)
    if ownState == true then return true end
    local gated = false
    local node = inst
    while node and node ~= Workspace do
        if state(node) == true then return true end
        local name = string.lower(node.Name or ""):gsub("[^%w]", "")
        if S.chestTextLocked(node.Name) then return true end
        if name:find("dungeon", 1, true) or name:find("spider", 1, true)
            or name == "wave" or name:match("^wave%d+$") then gated = true end
        for _, tag in ipairs({"LockedChest", "DungeonChest", "SpiderChest", "BossChest"}) do
            if CollectionService:HasTag(node, tag) then
                if tag == "LockedChest" then return true end
                gated = true
            end
        end
        node = node.Parent
    end
    for _, desc in ipairs(inst:GetDescendants()) do
        if state(desc) == true then return true end
        if desc:IsA("BoolValue") and desc.Value == true then
            local name = string.lower(desc.Name or "")
            if name == "locked" or name == "islocked" or name == "requireskey" then return true end
        end
        if desc:IsA("ProximityPrompt")
            and (S.chestTextLocked(desc.ActionText) or S.chestTextLocked(desc.ObjectText)) then return true end
    end
    -- Gated rewards need an explicit open state; an ordinary Open prompt is insufficient.
    -- Cosmetic padlock meshes alone do not make normal world chests locked.
    return gated and ownState ~= false
end

function S.safeLookAt(from, lookAt)
    if typeof(from) ~= "Vector3" then
        return nil
    end
    if typeof(lookAt) ~= "Vector3" then
        lookAt = from + Vector3.new(0, 1, 0)
    end
    if (lookAt - from).Magnitude < 0.08 then
        lookAt = from + Vector3.new(0, 1, 0)
    end
    local ok, cf = pcall(CFrame.lookAt, from, lookAt)
    if ok and typeof(cf) == "CFrame" then
        local p = cf.Position
        if p.X == p.X and p.Y == p.Y and p.Z == p.Z then
            return cf
        end
    end
    return CFrame.new(from)
end

function S.autofarmCycleShouldAbort()
    return Autofarm._cycleAbort == true or Autofarm.enabled ~= true or Autofarm._farmShuttingDown == true
end

function S.releaseStuckFarmHold()
    Autofarm._cycleAbort = true
    Autofarm._cycleGen = (Autofarm._cycleGen or 0) + 1
    Autofarm._returnGen = (Autofarm._returnGen or 0) + 1
    Autofarm._activeMine = nil
    Autofarm._gatePinY = nil
    Autofarm.miningBusy = false
    Autofarm._miningBusySince = nil
    Autofarm._oreHuntMode = false
    Autofarm.moving = false
    Autofarm.busy = false
    Autofarm._cycleRunning = false
    Autofarm._scrapProcessing = false
    S.cancelAutofarmTween()
    S.clearMineHoldPin()
    S.disconnectAll("autofarmHover")
    S.disconnectAll("autofarmAntiFall")
    Autofarm.hoverLocked = false
    pcall(S.releaseAutofarmSeat)
    local humanoid = S.getHumanoid()
    if humanoid then
        pcall(function()
            humanoid.Sit = false
            humanoid.PlatformStand = false
        end)
    end
    local root = S.getRoot()
    if root then
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

function S.releaseCharacterHold()
    Autofarm._holdPos = nil
    Autofarm._holdLook = nil
    Autofarm._holdOre = nil
    Autofarm._holdCruise = nil
    S.disconnectAll("oreUnderHold")
end

function S.findAutofarmTrackPart()
    local chunks = Workspace:FindFirstChild("Chunks")
    local layers = chunks and chunks:FindFirstChild("Layers")
    if not layers then
        return nil
    end

    local root = S.getRoot()
    local origin = root and root.Position
    local best, bestDist = nil, math.huge

    for _, layer in ipairs(layers:GetChildren()) do
        local track = layer:FindFirstChild("Track") or layer:FindFirstChild("Track", true)
        if track then
            local cf = S.getTrackInstanceCFrame(track)
            if cf then
                if not origin then
                    return track
                end
                local dist = (Vector3.new(cf.Position.X, 0, cf.Position.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    best = track
                end
            end
        end
    end

    return best
end

function S.getTrackInstanceCFrame(track)
    if not track then
        return nil
    end
    if track:IsA("BasePart") then
        return track.CFrame
    end
    if track:IsA("Model") then
        local ok, pivot = pcall(function()
            return track:GetPivot()
        end)
        if ok and pivot then
            return pivot
        end
        local pp = track.PrimaryPart or track:FindFirstChildWhichIsA("BasePart", true)
        return pp and pp.CFrame or nil
    end
    local part = track:FindFirstChildWhichIsA("BasePart", true)
    return part and part.CFrame or nil
end

function S.getAutofarmAxisVectorFromString()
    local axis = Autofarm.axis or "+Z"
    if axis == "+X" then
        return Vector3.new(1, 0, 0)
    elseif axis == "-X" then
        return Vector3.new(-1, 0, 0)
    elseif axis == "-Z" then
        return Vector3.new(0, 0, -1)
    end
    return Vector3.new(0, 0, 1)
end

function S.getDrillRouteAxis()
    local startPos = Workspace:GetAttribute("Start_Position")
    local endPos = Workspace:GetAttribute("End_Position")
    if typeof(startPos) ~= "Vector3" or typeof(endPos) ~= "Vector3" then
        return nil
    end
    local flat = Vector3.new(endPos.X - startPos.X, 0, endPos.Z - startPos.Z)
    if flat.Magnitude < 1 then
        return nil
    end
    return flat.Unit
end

function S.refreshAutofarmRouteDir()
    local drillAxis = S.getDrillRouteAxis()
    if drillAxis then
        Autofarm.routeDirBase = drillAxis
        return S.getAutofarmAxisVector()
    end

    local track = S.findAutofarmTrackPart()
    if track then
        local cf = S.getTrackInstanceCFrame(track)
        if cf then
            local look = cf.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.05 then
                Autofarm.routeDirBase = flat.Unit
                return S.getAutofarmAxisVector()
            end
        end
    end

    if Autofarm.routeDirBase and Autofarm.routeDirBase.Magnitude > 0.05 then
        return S.getAutofarmAxisVector()
    end

    return S.snapAutofarmAxisFromLook()
end

function S.getAutofarmAxisVector()
    local base = Autofarm.routeDirBase
    if base and base.Magnitude > 0.05 then
        local dir = base.Unit
        if Autofarm.trackForward == false then
            dir = -dir
        end
        Autofarm.routeDir = dir
        return dir
    end
    if Autofarm.routeDir and Autofarm.routeDir.Magnitude > 0.05 then
        return Autofarm.routeDir.Unit
    end
    return S.getAutofarmAxisVectorFromString()
end

function S.getAutofarmFlyY()
    return Autofarm.flyY or 70
end

function S.getAutofarmWorldPosition(distance)
    local origin = Autofarm.origin
    if not origin then
        local root = S.getRoot()
        if not root then
            return nil
        end
        origin = root.Position
    end

    local dir = S.getAutofarmAxisVector()
    local flat = Vector3.new(origin.X, 0, origin.Z) + dir * (distance or 0)
    return Vector3.new(flat.X, S.getAutofarmFlyY(), flat.Z)
end

function S.getAutofarmCFrame(distance)
    local pos = S.getAutofarmWorldPosition(distance)
    if not pos then
        return nil
    end
    local dir = S.getAutofarmAxisVector()
    return S.safeLookAt(pos, pos + dir)
end

function S.cancelAutofarmTween()
    Autofarm.moving = false
    if Autofarm.activeTween then
        pcall(function()
            Autofarm.activeTween:Cancel()
        end)
        Autofarm.activeTween = nil
    end
end

function S.setAutofarmPlatformStand(enabled)

    if Autofarm.enabled and not Autofarm._farmShuttingDown then
        enabled = true
    end
    local humanoid = S.getHumanoid()
    if not humanoid then
        return
    end
    pcall(function()
        humanoid.PlatformStand = enabled == true
    end)
end

function S.clearDragTarget()
    local knit = S.getKnit()
    if not knit then
        return
    end
    pcall(function()
        local drag = knit.GetController("DragController")
        if drag then
            drag.Target = nil
            if drag.TargetChanged then
                drag.TargetChanged:Fire(nil)
            end
        end
    end)
end

function S.requestStreamAround(position, timeout)
    local root = S.getRoot()
    position = position or (root and root.Position)
    if not position then
        return false
    end

    timeout = timeout or 1.5
    local ok = pcall(function()
        if typeof(LocalPlayer.RequestStreamAroundAsync) == "function" then
            LocalPlayer:RequestStreamAroundAsync(position, timeout)
        end
    end)
    return ok
end

function S.getAutofarmSpeed()
    return math.clamp(Autofarm.tweenSpeed or 1500, 80, 4000)
end

function S.farmHoldReason()
    if Autofarm._farmShuttingDown then
        return "shutting down"
    end
    if Autofarm._scrapFlushing then
        return "scrap flush"
    end
    if Autofarm._scrapProcessing then
        return "scrap process"
    end
    if Autofarm.miningBusy then
        if Autofarm._activeMine then
            return "mine dig"
        end
        return "ore dig"
    end
    if Autofarm._oreHuntMode then
        return "ore hunt"
    end
    if Autofarm.moving then
        return "tween"
    end
    if Autofarm.busy then
        return Autofarm._holdReason or "busy"
    end
    return "none"
end

function S.farmLog(action, detail)
    if action == "glide" or action == "held" or action == "grace" or action == "cycle" then return end
    local line = tostring(action) .. (detail and (" · " .. tostring(detail)) or "")
    Autofarm._dbgAction = line
    S.interactionNote("farm", line)
end

function S.farmErr(action, err)
    pcall(function()
        Autofarm._dbgErr = tostring(err)
        warn("[NA FARM]", action, err)
        S.farmLog(action, err)
    end)
end

function S.autofarmInStartupGrace()
    local untilT = Autofarm._cruiseReadyAt
    return typeof(untilT) == "number" and tick() < untilT
end

function S.holdAutofarmCruise(reason)
    Autofarm.busy = true
    Autofarm._busySince = tick()
    Autofarm._holdReason = reason or "busy"
    S.farmLog("HOLD", Autofarm._holdReason)
end

function S.isAutofarmCruiseHeld()
    return S._activity~=nil or (S._finishSettings and S._finishSettings.busy == true) or S._chestInteraction ~= nil
        or Autofarm.busy == true
        or Autofarm.moving == true
        or Autofarm.miningBusy == true
        or Autofarm._oreHuntMode == true
        or Autofarm._scrapProcessing == true
        or Autofarm._scrapFlushing == true
end

function S.stopAlkalineRouteGlide()
    S.disconnectAll("autofarmGlide")
end

function S.startAlkalineRouteGlide()
    S.stopAlkalineRouteGlide()
    S.farmLog("glide start", string.format("spd=%d y=%.1f", S.getAutofarmSpeed(), S.getAutofarmFlyY()))
    local lastHud = 0
    State.connections.autofarmGlide = RunService.RenderStepped:Connect(function(dt)
        if not Autofarm.enabled then
            return
        end
        if S.isAutofarmCruiseHeld() then
            if os.clock() - lastHud > 0.25 then
                lastHud = os.clock()
                S.farmLog("held", S.farmHoldReason())
            end
            return
        end
        dt = math.min(math.max(dt or 0, 0), 0.05)
        local speed = S.getAutofarmSpeed()
        local mapEnd = Autofarm.mapEndStuds or 100000
        local nextD = (Autofarm.distance or 0) + speed * dt
        if nextD >= mapEnd then
            if CoreFarm.openAll or CoreFarm._ownedRun then
                S.coreNoteLap()
                if CoreFarm._drainingChests or CoreFarm._leaving then return end
            end
            Autofarm._pendingMapWrap = true
            local ok, err = pcall(S.setAutofarmPose, 0)
            if not ok then
                S.farmErr("wrap pose", err)
            else
                S.farmLog("wrap", "map end → 0")
            end
            return
        end
        local ok, err = pcall(S.setAutofarmPose, nextD)
        if not ok then
            S.farmErr("pose", err)
            return
        end
        if os.clock() - lastHud > 0.35 then
            lastHud = os.clock()
            S.farmLog("glide", string.format("d=%.0f", nextD))
        end
    end)
end

function S.resetAutofarmCharacterState()
    S.cancelAutofarmTween()
    S.lockAutofarmHover(false)
    S.clearDragTarget()
    S.setAutofarmPlatformStand(false)

    local root = S.getRoot()
    if root then
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

function S.clearMineHoldPin()
    Autofarm._mineHoldPos = nil
    Autofarm._mineLookAt = nil
end

function S.pinBusyFarmHold(root)
    if not root then
        return
    end
    S.setAutofarmPlatformStand(true)
    root.Anchored = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    local pos = root.Position
    local pin = Autofarm._mineHoldPos
    local pinY = Autofarm._gatePinY
    if typeof(pinY) ~= "number" then
        pinY = (typeof(pin) == "Vector3" and pin.Y) or nil
    end
    
    if typeof(pinY) ~= "number" then
        pinY = S.getAutofarmFlyY()
    end

    local x, z = pos.X, pos.Z
    if typeof(pin) == "Vector3" then
        x, z = pin.X, pin.Z
    end

    local driftedY = pos.Y ~= pos.Y or math.abs(pos.Y - pinY) > 0.4
    local driftedXZ = typeof(pin) == "Vector3"
        and Vector3.new(pos.X - x, 0, pos.Z - z).Magnitude > 1.5
    if not driftedY and not driftedXZ then
        return
    end

    local stand = Vector3.new(x, pinY, z)
    local look = Autofarm._mineLookAt
    local cf
    if typeof(look) == "Vector3" and (look - stand).Magnitude > 0.1 then
        cf = S.safeLookAt(stand, look)
    else
        cf = S.safeLookAt(stand, stand + S.getAutofarmAxisVector())
    end
    if cf then
        root.CFrame = cf
    end
end

function S.hardRecoverAutofarmCruise(reason)
    warn("[naturally alkaline] hard recover cruise" .. (reason and (" — " .. tostring(reason)) or ""))
    S.farmLog("recover", reason)
    Autofarm._cycleAbort = true
    Autofarm._cycleRunning = false
    Autofarm.miningBusy = false
    Autofarm._miningBusySince = nil
    Autofarm._oreHuntMode = false
    Autofarm.moving = false
    Autofarm._gatePinY = nil
    S.clearMineHoldPin()
    pcall(S.releaseCharacterHold)
    pcall(S.cancelAutofarmTween)
    if not Autofarm.enabled then
        return
    end
    local dist = Autofarm.distance or 0
    pcall(function()
        S.setAutofarmPose(dist)
        S.setAutofarmPlatformStand(true)
        S.ensureAutofarmAntiFall(true)
        S.lockAutofarmHover(true)
        
        task.defer(function()
            if Autofarm.enabled and not Autofarm.miningBusy then
                S.setAutofarmPose(Autofarm.distance or dist)
            end
        end)
    end)
    pcall(S.startAlkalineRouteGlide)
end

function S.ensureAutofarmAntiFall(on)
    S.disconnectAll("autofarmAntiFall")
    if not on then
        Autofarm._gatePinY = nil
        return
    end

    State.connections.autofarmAntiFall = RunService.Heartbeat:Connect(function()
        if not Autofarm.enabled then
            return
        end

        local root = S.getRoot()
        if not root then
            return
        end

        if Autofarm.miningBusy or Autofarm._oreHuntMode or Autofarm._scrapProcessing then
            S.pinBusyFarmHold(root)
            return
        end

        S.setAutofarmPlatformStand(true)
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        local flyY = S.getAutofarmFlyY()
        local targetY = Autofarm._gatePinY
        if typeof(targetY) ~= "number" then
            targetY = flyY
        end

        local pos = root.Position
        local dir = S.getAutofarmAxisVector()

        if Autofarm.moving then
            if pos.Y ~= pos.Y or pos.Y < targetY - 1.5 then
                local cf = S.safeLookAt(Vector3.new(pos.X, targetY, pos.Z), Vector3.new(pos.X, targetY, pos.Z) + dir)
                if cf then
                    root.CFrame = cf
                end
            end
            return
        end

        local pin = Autofarm._mineHoldPos
        local x, z = pos.X, pos.Z
        if typeof(pin) == "Vector3" then
            x, z = pin.X, pin.Z
        end
        local hold = Vector3.new(x, targetY, z)
        local cf = S.safeLookAt(hold, hold + dir)
        if cf then
            root.CFrame = cf
        end
    end)
end

function S.lockAutofarmHover(enabled)
    Autofarm.hoverLocked = enabled == true
    S.disconnectAll("autofarmHover")

    if Autofarm.enabled then
        S.ensureAutofarmAntiFall(true)
        S.setAutofarmPlatformStand(true)
    end

    if not Autofarm.hoverLocked then
        if not Autofarm.enabled then
            S.ensureAutofarmAntiFall(false)
            S.setAutofarmPlatformStand(false)
            local root = S.getRoot()
            if root then
                root.Anchored = false
            end
        end
        return
    end

    S.setAutofarmPlatformStand(true)
    State.connections.autofarmHover = RunService.Heartbeat:Connect(function()
        if not Autofarm.enabled or not Autofarm.hoverLocked then
            return
        end
        if Autofarm.moving then
            return
        end
        local root = S.getRoot()
        if not root then
            return
        end

        if Autofarm.miningBusy or Autofarm._oreHuntMode or Autofarm._scrapProcessing then
            S.pinBusyFarmHold(root)
            return
        end

        local dir = S.getAutofarmAxisVector()
        local flyY = Autofarm._gatePinY or S.getAutofarmFlyY()
        local pos = root.Position
        local pin = Autofarm._mineHoldPos
        local x, z = pos.X, pos.Z
        if typeof(pin) == "Vector3" then
            x, z = pin.X, pin.Z
        end
        local hold = Vector3.new(x, flyY, z)
        root.Anchored = false
        local cf = S.safeLookAt(hold, hold + dir)
        if cf then
            root.CFrame = cf
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        S.setAutofarmPlatformStand(true)
    end)
end

function S.setAutofarmPose(distance)
    local root = S.getRoot()
    local cf = S.getAutofarmCFrame(distance)
    if not root or not cf then
        return false
    end

    root.Anchored = false
    if Autofarm.enabled then
        S.setAutofarmPlatformStand(true)
    end
    root.CFrame = cf
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    Autofarm.distance = distance or 0
    return true
end

function S.syncAutofarmDistanceFromRoot()
    local root = S.getRoot()
    local origin = Autofarm.origin
    if not root or not origin then
        return Autofarm.distance or 0
    end

    local dir = S.getAutofarmAxisVector()
    local rel = root.Position - origin
    local flat = Vector3.new(rel.X, 0, rel.Z)
    local dist = math.max(0, flat:Dot(dir))
    local mapEnd = Autofarm.mapEndStuds or (DEPTH_TARGET_END_METERS * S.getAutofarmStudsPerMeter())
    Autofarm.distance = math.clamp(dist, 0, mapEnd)
    return Autofarm.distance
end

function S.snapAutofarmAxisFromLook()
    local root = S.getRoot()
    if not root then
        return Autofarm.routeDir or S.getAutofarmAxisVectorFromString()
    end

    local look = root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.05 then
        flat = Vector3.new(0, 0, 1)
    else
        flat = flat.Unit
    end

    Autofarm.routeDirBase = flat
    return S.getAutofarmAxisVector()
end

function S.ensureAutofarmOrigin(force)
    local root = S.getRoot()
    if not root then
        return false
    end

    if force or not Autofarm.origin then
        Autofarm.origin = Vector3.new(root.Position.X, S.getAutofarmFlyY(), root.Position.Z)
    end
    return true
end

function S.resetAutofarmStart()
    local root = S.getRoot()
    if not root then
        return false
    end

    S.cancelAutofarmTween()
    Autofarm.miningBusy = false
    Autofarm.suppressChestOreStopUntil = 0
    Autofarm.origin = Vector3.new(root.Position.X, S.getAutofarmFlyY(), root.Position.Z)
    Autofarm.distance = 0
    S.refreshAutofarmRouteDir()

    if Autofarm.enabled then
        S.setAutofarmPose(0)
        S.setAutofarmPlatformStand(true)
    end

    return true
end

function S.setAutofarmCameraAssist(enabled)
    if enabled then
        if Autofarm.ownedCamAssist then
            return
        end
        Autofarm.camBackup = {
            maxZoom = LocalPlayer.CameraMaxZoomDistance,
            minZoom = LocalPlayer.CameraMinZoomDistance,
        }
        pcall(function()
            LocalPlayer.CameraMaxZoomDistance = math.max(tonumber(Autofarm.camBackup.maxZoom) or 128, 500)
            LocalPlayer.CameraMinZoomDistance = math.min(tonumber(Autofarm.camBackup.minZoom) or 0.5, 0.5)
        end)
        Autofarm.ownedCamAssist = true
        return
    end

    if not Autofarm.ownedCamAssist then
        return
    end
    local bak = Autofarm.camBackup
    pcall(function()
        if bak then
            LocalPlayer.CameraMaxZoomDistance = bak.maxZoom or 128
            LocalPlayer.CameraMinZoomDistance = bak.minZoom or 0.5
        end
    end)
    Autofarm.camBackup = nil
    Autofarm.ownedCamAssist = false
end

function S.runAutofarmCycle()
    if S._v3AuraBusy or S._chestInteraction or S.autofarmCycleShouldAbort() or CoreFarm._leaving then return end
    if not Services.ToolService or not Services.InteractionService then return end
    if S.autofarmInStartupGrace() then S.ensureAutofarmOrigin(false); return end
    if S._activity then return end
    if S._v3 and not CoreFarm._drainingChests and os.clock()>=(S._v3NextJobAt or 0) then
        if S.v3RunNextJob() then S._v3NextJobAt=os.clock()+2;return end
    end
    S.coreHoldChestRun()
    S.ensureAutofarmOrigin(false)
    S.syncAutofarmWindowFromDrill()
    if not Autofarm.enabled then return end
    S.ensureAutofarmAntiFall(true)
    S.lockAutofarmHover(true)
    local chest = S.findChestForAutofarm()
    if chest then
        S.holdAutofarmCruise("chest")
        S.autofarmVisitChest(chest)
    elseif CoreFarm._drainingChests then
        S.coreDrainChestsTick()
    end
    Autofarm._pendingMapWrap = false
end

function S.setAutofarm(enabled, opts)
    enabled = enabled == true
    opts = type(opts) == "table" and opts or {}
    if enabled and type(CoreFarm) == "table" and CoreFarm._leaving then return end
    if enabled and game.PlaceId ~= NA.placeId then
        return
    end

    if not enabled then

        Autofarm._farmShuttingDown = true
        S.disconnectAll("autofarm")
        S.disconnectAll("autofarmGlide")
        S.cancelAutofarmTween()
        S.lockAutofarmHover(false)
    end

    Autofarm.enabled = enabled
    S.disconnectAll("autofarm")
    S.disconnectAll("autofarmGlide")
    S.cancelAutofarmTween()

    if not enabled then
        S.farmLog("disable", "off")
        pcall(S.releaseStuckFarmHold)
        S.stopFarmLoopsSoft()
        if opts.skipReturn then
            pcall(S.forceReleaseFarmCharacter)
            return
        end
        S.returnToDrillAfterFarmStop({ keepEngine = false, force = true })
        return
    end

    Autofarm._returnGen = (Autofarm._returnGen or 0) + 1
    Autofarm._returningToDrill = false
    Autofarm._farmShuttingDown = false
    Autofarm.busy = false
    Autofarm._cycleRunning = false
    Autofarm.moving = false
    Autofarm.miningBusy = false
    Autofarm._oreHuntMode = false
    Autofarm._scrapProcessing = false
    Autofarm._scrapFlushing = false

    S.syncAutofarmMapEndFromMeters()

    Autofarm._holdReason = nil
    Autofarm._dbgErr = nil
    Autofarm._cruiseReadyAt = tick() + 2.5
    Autofarm.debugHud = false
    S.farmLog("enable", "run / tween only — filters stay as set")

    S.releaseAutofarmSeat()
    S.resetAutofarmStart()
    if not Autofarm.origin then
        Autofarm.enabled = false
        return
    end

    if not State.noclip then
        S.setNoclip(true)
        Autofarm.ownedNoclip = true
    end
    pcall(S.setAutofarmCameraAssist, true)

    S.setAutofarmPose(Autofarm.distance or 0)
    S.setAutofarmPlatformStand(true)
    S.ensureAutofarmAntiFall(true)
    S.lockAutofarmHover(true)

    State.connections.autofarm = RunService.Heartbeat:Connect(function()
        if S._activity or S._chestInteraction or (S._finishSettings and S._finishSettings.busy) then return end
        if not Autofarm.enabled then
            return
        end

        if Autofarm.miningBusy then
            local mineSince = Autofarm._miningBusySince
            if typeof(mineSince) == "number" and (tick() - mineSince) > 70 then
                S.hardRecoverAutofarmCruise("miningBusy watchdog")
            end
        end

        local rootCheck = S.getRoot()
        if rootCheck
            and not Autofarm.moving
            and not Autofarm.miningBusy
            and not Autofarm._oreHuntMode
            and not Autofarm._scrapProcessing
        then
            local flyY = S.getAutofarmFlyY()
            local pinY = Autofarm._gatePinY
            local expectY = typeof(pinY) == "number" and pinY or flyY
            if rootCheck.Position.Y < expectY - 20 or rootCheck.Position.Y ~= rootCheck.Position.Y then
                S.hardRecoverAutofarmCruise("void sink")
            end
        end

        if Autofarm.busy or Autofarm._cycleRunning then

            local since = Autofarm._busySince
            local maxBusy = 45
            if Autofarm.busy and typeof(since) == "number" and (tick() - since) > maxBusy then
                Autofarm._cycleGen = (Autofarm._cycleGen or 0) + 1
                Autofarm.busy = false
                Autofarm._busySince = nil
                Autofarm._cycleRunning = false
                S.farmLog("watchdog", string.format("%.0fs %s", tick() - since, Autofarm._holdReason or "busy"))
                S.hardRecoverAutofarmCruise("busy watchdog")
            end
            return
        end
        if (tick() - (State.lastAutofarmTick or 0)) < 0.2 then
            return
        end
        State.lastAutofarmTick = tick()
        Autofarm._cycleAbort = false
        Autofarm._cycleGen = (Autofarm._cycleGen or 0) + 1
        local gen = Autofarm._cycleGen
        Autofarm._cycleRunning = true
        task.spawn(function()
            local ok, err = pcall(S.runAutofarmCycle)
            if not ok then
                pcall(S.farmErr, "cycle ERR", err)
                pcall(S.hardRecoverAutofarmCruise, "cycle error")
            end
            
            if gen == Autofarm._cycleGen then
                Autofarm._cycleRunning = false
                Autofarm.busy = false
                Autofarm._busySince = nil
                Autofarm._cycleAbort = false
            end
        end)
    end)

    S.startAlkalineRouteGlide()
end

function S.getToolDamage(tool)
    if not tool then
        return 0
    end

    local damage = 0
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local damageModule = shared and shared:FindFirstChild("ToolDamage")
        if damageModule then
            local ToolDamage = require(damageModule)
            local total = ToolDamage.GetTotalDamage(tool)
            if typeof(total) == "number" then
                damage = total
                return
            end
        end

        local raw = tool:GetAttribute("Damage")
        if typeof(raw) == "number" then
            damage = raw
        end
    end)

    return damage
end

function S.getFlatDistanceToPlayer(inst)
    local root = S.getRoot()
    local pos = S.getInstancePosition(inst)
    if not root or not pos then
        return math.huge
    end
    return (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
end

function S.normalizeChestTypeToken(name)
    local key = tostring(name or "")
    key = key:gsub("_Chest$", ""):gsub("_chest$", "")
    key = key:gsub("Chest$", ""):gsub("chest$", "")
    key = key:gsub("^_+", ""):gsub("_+$", "")
    key = key:gsub("^%s+", ""):gsub("%s+$", "")
    if key == "" then
        key = "Chest"
    end
    return key
end

function S.getChestTypeKey(chest)
    return S.normalizeChestTypeToken(chest and chest.Name or "Chest")
end

function S.chestTypeStrings(chest)
    local out = {}
    local function add(value)
        if type(value) == "string" and value ~= "" then
            out[#out + 1] = value
        end
    end
    if not chest then
        return out
    end
    add(chest.Name)
    local parent = chest.Parent
    if parent and parent.Name ~= "ChestNode" and parent.Name ~= "ChestNodes" then
        add(parent.Name)
    end
    for _, attr in ipairs({ "Type", "ChestType", "Rarity", "Category", "ChestId", "Id", "Name", "DisplayName", "Tier" }) do
        pcall(function()
            add(chest:GetAttribute(attr))
        end)
    end
    local prompts = S.collectProximityPrompts(chest)
    local prompt = prompts[1]
    if prompt then
        add(prompt.ObjectText)
        if prompt.Parent then
            add(prompt.Parent.Name)
        end
    end
    for _, child in ipairs(chest:GetChildren()) do
        local n = string.lower(child.Name)
        if n:find("chest", 1, true) or n:find("core", 1, true) then
            add(child.Name)
        end
    end
    return out
end

function S.chestCanon(chest)
    for _, raw in ipairs(S.chestTypeStrings(chest)) do
        local canon = S.canonChestKey(S.normalizeChestTypeToken(raw))
        local rawCanon = S.canonChestKey(raw)
        for _, entry in ipairs(CHEST_CATALOG) do
            if canon == entry.canon or rawCanon == entry.canon then
                return entry.canon
            end
        end
    end
    return S.canonChestKey(S.getChestTypeKey(chest))
end

function S.canonChestKey(text)
    local token = string.lower(tostring(text or "")):gsub("[^%a%d]", "")
    return CHEST_ALIAS[token] or token
end

function S.chestLabelsFromSaved(list)
    local out = {}
    local seen = {}
    for _, opt in ipairs(list or {}) do
        local canon = S.canonChestKey(opt)
        for _, entry in ipairs(CHEST_CATALOG) do
            if entry.canon == canon and not seen[entry.label] then
                seen[entry.label] = true
                table.insert(out, entry.label)
                break
            end
        end
    end
    return out
end

function S.chestSelectionList(value)
    local list = dropdownList(value)
    if type(list) ~= "table" then
        return {}
    end
    local out = {}
    for _, opt in ipairs(list) do
        if type(opt) == "string" and opt ~= "" then
            out[#out + 1] = opt
        end
    end
    return out
end

function S.chestWhitelistWants(canon)
    for _, opt in ipairs(S.chestSelectionList(Autofarm.chestTypes)) do
        if S.canonChestKey(opt) == canon then
            return true
        end
    end
    return false
end

function S.chestTextHasCore(chest)
    for _, raw in ipairs(S.chestTypeStrings(chest)) do
        local token = string.lower(raw)
        if token:find("core", 1, true) and not token:find("score", 1, true) then
            return true
        end
    end
    return false
end

function S.chestMatchesAutofarmWhitelist(chest)
    local selected = S.chestSelectionList(Autofarm.chestTypes)
    if #selected == 0 then
        return false
    end
    local key = S.chestCanon(chest)
    for _, opt in ipairs(selected) do
        if S.canonChestKey(opt) == key then
            return true
        end
    end
    if S.chestWhitelistWants("core") and S.chestTextHasCore(chest) then
        return true
    end
    local selectedKeys = {}
    for _, option in ipairs(selected) do selectedKeys[S.canonChestKey(option)] = true end
    for _, entry in ipairs(CHEST_CATALOG) do
        if not selectedKeys[entry.canon] then return false end
    end
    return true -- "All types" includes new ChestNode tiers added by the game.
end

function S.findChestForAutofarm()
    if not Autofarm.openChests or #S.chestSelectionList(Autofarm.chestTypes) == 0 then return nil end
    local best, distance = nil, math.huge
    local reach = CoreFarm._drainingChests and math.huge or 15000
    S.forEachWorldChestNode(function(chest)
        S.rememberFarmChest(chest)
        if not chest.Parent or S.coreStorageObject(chest) or S.isDecorativeOrShopChest(chest)
            or CollectionService:HasTag(chest, "ShopItem") or CollectionService:HasTag(chest, "SupplyCrate") then return end
        local record = S.chestAttemptRecord(chest)
        if record.done or record.blocked or os.clock() < (record.retryAt or 0)
            or not S.chestMatchesAutofarmWhitelist(chest) or S.chestLockStatus(chest) then return end
        local d = S.getFlatDistanceToPlayer(chest)
        if d <= reach and d < distance then best, distance = chest, d end
    end)
    return best
end

function S.autofarmVisitChest(chest)
    if not chest or not chest.Parent or not Autofarm.enabled or not Autofarm.openChests
        or S._chestInteraction or CoreFarm._leaving then return false end
    chest = S.resolveDungeonChestModel(chest) or chest
    if S.coreStorageObject(chest) or S.isDecorativeOrShopChest(chest)
        or not S.chestMatchesAutofarmWhitelist(chest) then return false end
    local record = S.chestAttemptRecord(chest)
    local remembered = S.rememberFarmChest(chest)
    if record.done or record.blocked or os.clock() < (record.retryAt or 0) or S.isChestPadlocked(chest) then return false end
    if S.chestOpened(chest) then record.done = true; return true end
    local root = S.getRoot()
    if not root then return false end
    local prompt = S.chestPrompt(chest)
    if not prompt then
        record.missingPrompt = (record.missingPrompt or 0) + 1
        record.retryAt = os.clock() + 2
        if record.missingPrompt >= 4 then record.blocked = true end
        local pos = S.getInstancePosition(chest)
        if pos and record.missingPrompt <= 2 then pcall(S.requestStreamAround, pos, 0.8) end
        S.interactionNote("chest", chest.Name .. ": waiting for an opening prompt")
        return false
    end
    local context = { chest = chest, root = root, character = LocalPlayer.Character,
        cycle = Autofarm._cycleGen, farm = true }
    S._chestInteraction = context
    local savedDistance = Autofarm.distance
    local opened = false
    local ok, err = pcall(function()
        S.cancelAutofarmTween()
        S.ensureAutofarmAntiFall(true)
        S.lockAutofarmHover(true)
        if Services.ToolService then pcall(function() Services.ToolService:UnequipTool() end) end
        for _ = 1, 2 do
            if not S.chestInteractionActive(context) or not chest.Parent or record.tries >= 6 then break end
            if S.isChestPadlocked(chest) then break end
            prompt = S.chestPrompt(chest)
            if not prompt then break end
            record.tries += 1
            context.attempt = record.tries
            context.coresBefore = tonumber(LocalPlayer:GetAttribute("Cores")) or 0
            S.coreSetStatus("Opening " .. chest.Name .. " · attempt " .. record.tries .. "/6")
            local held = S.holdChestInteract(chest, nil, context)
            if not S.chestInteractionActive(context) then break end
            if not S.isChestPadlocked(chest) and (held or context.inputStarted or not chest.Parent) then
                local nativeWait = os.clock() + 0.8
                repeat
                    if S.chestOpened(chest, context.coresBefore) then opened = true; break end
                    task.wait(0.08)
                until not S.chestInteractionActive(context) or os.clock() >= nativeWait
                if not opened and S.chestInteractionActive(context) then
                    if held then S.chestServerInteract(context, prompt) end
                    local deadline = os.clock() + 6
                    repeat
                        if not S.chestInteractionActive(context) or S.chestLockStatus(chest) then break end
                        if S.chestOpened(chest, context.coresBefore) then opened = true; break end
                        if prompt.Parent then S.pinChestInteraction(context, prompt) end
                        task.wait(0.1)
                    until os.clock() >= deadline
                end
            end
            if opened or S.isChestPadlocked(chest) then break end
            if S.chestInteractionActive(context) then task.wait(0.35) end
        end
    end)
    local sameRun = LocalPlayer.Character == context.character and S.getRoot() == root
        and context.cycle == Autofarm._cycleGen
    if opened then
        record.done, record.blocked, record.retryAt = true, false, 0
        if remembered then remembered.done = true end
    elseif sameRun and not S._unloaded then
        record.retryAt = os.clock() + math.min(8, 1 + record.tries)
        record.blocked = record.tries >= 6
    end
    pcall(S.restoreCameraAim, context.camera)
    if S._chestInteraction == context then S._chestInteraction = nil end
    if sameRun and Autofarm.enabled and not CoreFarm._leaving then
        S.clearMineHoldPin()
        Autofarm._gatePinY = nil
        if savedDistance ~= nil then Autofarm.distance = savedDistance; S.setAutofarmPose(savedDistance) end
        S.lockAutofarmHover(true)
    end
    S.clearDragTarget()
    if not ok then S.interactionNote("chest error", tostring(err):sub(1, 120)) end
    S.interactionNote("chest", chest.Name .. (opened and ": opening confirmed"
        or record.blocked and ": unconfirmed after 6 attempts; finish paused"
        or ": unconfirmed; queued for retry"))
    return opened
end

function S.isPhoenixLootChest(inst)
    if not inst or not inst.Parent or not (inst:IsA("Model") or inst:IsA("BasePart")) then
        return false
    end
    local name = string.lower(inst.Name or "")
    local hint = name:find("chest", 1, true) or name == "phoenix"
    for _, attr in ipairs({"ChestType", "Type", "ChestId", "DisplayName", "Tier"}) do
        local value = inst:GetAttribute(attr)
        if type(value) == "string" and S.canonChestKey(value) == "phoenix" then hint = true end
    end
    if not hint then return false end
    if inst:GetAttribute("Armor") ~= nil or inst:GetAttribute("ArmorType") ~= nil
        or string.lower(tostring(inst:GetAttribute("Class") or "")) == "armor"
        or string.lower(tostring(inst:GetAttribute("Category") or "")) == "armor"
        or string.lower(tostring(inst:GetAttribute("DisplayCategory") or "")) == "armor" then
        return false
    end
    local cur = inst
    while cur and cur ~= Workspace do
        local ancestorName = string.lower(cur.Name or "")
        if cur:IsA("Tool") or CollectionService:HasTag(cur, "ShopItem")
            or CollectionService:HasTag(cur, "SupplyCrate")
            or ancestorName:find("loadout", 1, true)
            or ancestorName:find("shop", 1, true) then return false end
        cur = cur.Parent
    end
    if S.isDecorativeOrShopChest(inst) or S.isChestInDungeonWave(inst) or S.isChestStepJunk(inst)
        or S.chestCanon(inst) ~= "phoenix" then return false end
    for _, prompt in ipairs(S.collectProximityPrompts(inst)) do
        local action = string.lower(prompt.ActionText or "")
        if prompt.Enabled and (action == "interact" or action:find("open", 1, true)) then
            return true
        end
    end
    return false
end

function S.isChestEspTarget(inst)
    if not inst or not inst.Parent then
        return false
    end
    
    if S.isChestInDungeonWave(inst) or S.isChestStepJunk(inst) then
        return false
    end

    local lower = string.lower(inst.Name or "")
    if lower == "chestnode"
        or lower == "chestnodes"
        or lower == "cheststep"
        or lower:find("cheststep", 1, true)
        or lower:find("supply", 1, true)
    then
        return false
    end
    if CollectionService:HasTag(inst, "SupplyCrate") then
        return false
    end

    if S.chestCanon(inst) == "phoenix" then
        return S.isPhoenixLootChest(inst)
    end
    local underSocket = false
    local walk = inst.Parent
    for _ = 1, 6 do
        if not walk then
            break
        end
        if walk.Name == "ChestNode" or walk.Name == "ChestNodes" then
            underSocket = true
            break
        end
        walk = walk.Parent
    end
    if not underSocket then
        return S.isPhoenixLootChest(inst)
    end

    if lower:find("chest", 1, true) or inst:FindFirstChild("Chest") or CollectionService:HasTag(inst, "Interactive") then
        return true
    end
    if inst:FindFirstChildWhichIsA("ProximityPrompt", true) then
        return true
    end
    local canon = S.canonChestKey(S.normalizeChestTypeToken(inst.Name))
    for _, entry in ipairs(CHEST_CATALOG) do
        if entry.canon == canon then
            return true
        end
    end
    return false
end

function S.ensureChestIndex()
    if S._unloaded then return nil end
    local existing = S._chestIndex
    if existing then return existing end
    local cache = { entries = setmetatable({}, { __mode = "k" }), pending = setmetatable({}, { __mode = "k" }),
        queue = {}, head = 1, tail = 0, running = false, inspected = 0 }
    S._chestIndex = cache
    local function active() return not S._unloaded and S._chestIndex == cache end
    local function record(inst)
        local node = inst
        for _ = 1, 8 do
            if not node or node == Workspace then break end
            if node.Name == "Items" or node == LocalPlayer.Character then return end
            if (node:IsA("Model") or node:IsA("BasePart")) and not cache.entries[node] then
                local name = string.lower(node.Name or "")
                local parent = node.Parent
                local socket = parent and (parent.Name == "ChestNode" or parent.Name == "ChestNodes")
                local core = name:find("core", 1, true) and name:find("chest", 1, true)
                local phoenix = S.canonChestKey(node:GetAttribute("ChestType")) == "phoenix"
                    or ((name:find("chest", 1, true) or name == "phoenix") and S.chestCanon(node) == "phoenix")
                if (socket or core or phoenix) and not S.coreStorageObject(node) and not S.isChestInDungeonWave(node) then
                    local model = S.resolveDungeonChestModel(node) or node
                    if S.isChestEspTarget(model) or core then cache.entries[model] = true; S.rememberFarmChest(model) end
                end
            end
            node = node.Parent
        end
    end
    local enqueue, start
    start = function()
        if cache.running or not active() then return end
        cache.running = true
        task.spawn(function()
            while active() and cache.head <= cache.tail do
                local began, count = os.clock(), 0
                repeat
                    local inst = cache.queue[cache.head]
                    cache.queue[cache.head], cache.head = nil, cache.head + 1
                    cache.pending[inst] = nil
                    local ok, err = pcall(function()
                    if inst == Workspace or (inst.Parent and inst:IsDescendantOf(Workspace)) then
                        record(inst)
                        local name = inst.Name
                        local skip = name == "Items" or name == "Wave" or name:match("^Wave%d+$") or inst == LocalPlayer.Character
                            or (inst:IsA("Model") and Players:GetPlayerFromCharacter(inst))
                        if not skip and (inst == Workspace or inst:IsA("Model") or inst:IsA("Folder")) then
                            for _, child in ipairs(inst:GetChildren()) do
                                if child:IsA("Model") or child:IsA("Folder")
                                    or (child:IsA("BasePart") and ((name == "ChestNode" or name == "ChestNodes")
                                        or string.lower(child.Name):find("phoenix", 1, true))) then enqueue(child, true) end
                            end
                        end
                    end
                    end)
                    if not ok then S.interactionNote("chest index", tostring(err):sub(1, 100)) end
                    count, cache.inspected = count + 1, cache.inspected + 1
                until cache.head > cache.tail or count >= 48 or os.clock() - began >= 0.0015 or not active()
                if cache.head <= cache.tail and active() then task.wait(0.03) end
            end
            if cache.head > cache.tail then cache.queue, cache.head, cache.tail = {}, 1, 0 end
            cache.running = false
        end)
    end
    enqueue = function(inst, insideWorker)
        if not active() or not inst or cache.pending[inst] then return end
        cache.pending[inst] = true
        cache.tail = cache.tail + 1; cache.queue[cache.tail] = inst
        if not insideWorker then start() end
    end
    State.connections.chestIndexAdded = Workspace.DescendantAdded:Connect(function(inst)
        local parent = inst.Parent
        if inst:IsA("Model") or inst:IsA("Folder") or inst:IsA("ProximityPrompt")
            or (inst:IsA("BasePart") and ((parent and (parent.Name == "ChestNode" or parent.Name == "ChestNodes"))
                or string.lower(inst.Name):find("phoenix", 1, true))) then enqueue(inst) end
    end)
    State.connections.chestIndexRemoved = Workspace.DescendantRemoving:Connect(function(inst) cache.entries[inst] = nil end)
    State.connections.chestIndexTagged = CollectionService:GetInstanceAddedSignal("Interactive"):Connect(function(inst) enqueue(inst) end)
    enqueue(Workspace)
    return cache
end

function S.chestLockStatus(chest)
    S._chestLockCache = S._chestLockCache or setmetatable({}, { __mode = "k" })
    local now, cached = os.clock(), S._chestLockCache[chest]
    if cached and now - cached.at < 0.75 then return cached.locked end
    local locked = S.isChestPadlocked(chest)
    S._chestLockCache[chest] = { at = now, locked = locked }
    return locked
end

function S.forEachWorldChestNode(callback)
    local cache = S.ensureChestIndex()
    if not cache then return end
    for model in pairs(cache.entries) do
        if not model.Parent or not model:IsDescendantOf(Workspace) then cache.entries[model] = nil
        elseif not S.coreStorageObject(model) and not S.isChestInDungeonWave(model) then S.rememberFarmChest(model); callback(model) end
    end
end

function S.setNoclip(enabled)
    State.noclip = enabled == true
    for _, key in ipairs({ "noclip", "noclipAdded", "noclipRemoved", "noclipCharacter" }) do S.disconnectAll(key) end
    for part, original in pairs(State._noclipParts or {}) do
        if part.Parent and part.CanCollide ~= original then part.CanCollide = original end
    end
    State._noclipParts = setmetatable({}, { __mode = "k" })
    if not enabled then return end
    local function attach(char)
        if S._unloaded or not State.noclip then return end
        S.disconnectAll("noclipAdded"); S.disconnectAll("noclipRemoved")
        local parts = setmetatable({}, { __mode = "k" }); State._noclipParts = parts
        local function add(part)
            if part:IsA("BasePart") and parts[part] == nil then parts[part] = part.CanCollide end
        end
        State.connections.noclipAdded = char.DescendantAdded:Connect(add)
        State.connections.noclipRemoved = char.DescendantRemoving:Connect(function(part) parts[part] = nil end)
        for _, part in ipairs(char:GetDescendants()) do add(part) end
    end
    if LocalPlayer.Character then attach(LocalPlayer.Character) end
    State.connections.noclipCharacter = LocalPlayer.CharacterAdded:Connect(attach)
    State.connections.noclip = RunService.Stepped:Connect(function()
        if S._unloaded or not State.noclip then return end
        for part in pairs(State._noclipParts) do
            if part.Parent and part.CanCollide then part.CanCollide = false end
        end
    end)
end

function S.bindServices()
    local knit = S.getKnit()
    if not knit then return false, "Knit module not found" end
    
    for _, name in ipairs({ "ToolService", "InteractionService", "TeleportManagerService", "CutSceneService", "ShopService", "DragService", "CurrencyService" }) do
        if not Services[name] then
            local ok, service = pcall(function() return knit.GetService(name) end)
            if ok and service then Services[name] = service end
        end
    end
    if game.PlaceId == 101906032112547 then
        return Services.TeleportManagerService ~= nil, "Waiting for lobby service"
    end
    return Services.ToolService ~= nil and Services.InteractionService ~= nil, "Waiting for chest services"
end

function S.waitForKnit(maxSeconds)
    maxSeconds = maxSeconds or 90
    S.hubLog("Waiting for PlayerScripts...")

    local player = LocalPlayer or Players.LocalPlayer
    if not player then
        return false, "LocalPlayer not ready"
    end
    local playerScripts = player:WaitForChild("PlayerScripts", maxSeconds)
    if not playerScripts then
        return false, "PlayerScripts not found"
    end

    local controllers = playerScripts:WaitForChild("Controllers", math.min(30, maxSeconds))
    if controllers then
        S.hubLog("Controllers found")
    else
        S.hubLog("Controllers not found yet")
    end

    local knit = S.getKnit()
    if not knit then
        return false, "Knit module not found"
    end

    S.hubLog("Waiting for Knit.OnStart...")
    local finished = false
    local knitError = nil

    task.spawn(function()
        local ok, err = pcall(function()
            knit.OnStart():await()
        end)
        if not ok then
            knitError = err
        end
        finished = true
    end)

    local started = os.clock()
    while not finished and os.clock() - started < maxSeconds do
        task.wait(0.25)
    end

    if not finished then
        return false, "Knit timeout"
    end

    if knitError then
        return false, tostring(knitError)
    end

    S.hubLog("Knit ready")
    return true
end

function S.waitForGameReady()
    if not game:IsLoaded() then
        S.hubLog("Waiting for game load...")
        game.Loaded:Wait()
    end
    local player = Players.LocalPlayer or LocalPlayer
    if not player then
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        player = Players.LocalPlayer
    end
    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 30)
    if not root then
        return false, "no root"
    end
    local shieldDeadline = os.clock() + 20
    while char.Parent and char:FindFirstChildOfClass("ForceField") and os.clock() < shieldDeadline do
        task.wait(0.2)
    end
    task.wait(0.4)
    return S.waitForKnit(45)
end

function S.connectServicesAsync()
    if S._unloaded or S._bindingServices or os.clock() < (S._nextServiceBindAt or 0) then return end
    S._bindingServices = true
    S._nextServiceBindAt = os.clock() + 5
    task.spawn(function()
        local lastError
        for attempt = 1, 3 do
            if S._unloaded then return end
            local ok, bound, err = pcall(S.bindServices)
            local usable = game.PlaceId == 101906032112547 and Services.TeleportManagerService ~= nil
                or game.PlaceId ~= 101906032112547 and Services.ToolService ~= nil and Services.InteractionService ~= nil
            if usable then
                S._servicesReady, S._knitReady = true, true
                break
            end
            lastError = ok and err or bound
            if attempt < 3 then task.wait(1.5) end
        end
        S._bindingServices = false
        if not S._servicesReady then
            S._nextServiceBindAt = os.clock() + 5
            S.hubLog("Core services retry: " .. tostring(lastError))
            return
        end
        S.hubLog("Core services connected")
        task.defer(function() if not S._unloaded then pcall(S.coreRequestRun) end end)
    end)
end

local LOBBY_PLACE = 101906032112547

local coreChestDefaults = {}
for _, label in ipairs(CHEST_TYPE_OPTIONS) do
    coreChestDefaults[#coreChestDefaults + 1] = label
end

CoreFarm = {
    enabled = true,
    mode = "Unranked",
    partySize = 1,
    openAll = true,
    _queuedRun = true,
    rescans = 2,
    joinDungeon = false,
    joinMines = false,
    chestTypes = coreChestDefaults,
    laps = 0,
}

function S.coreTeleportService()
    local knit = S.getKnit()
    if not knit then
        return nil
    end
    local ok, svc = pcall(function()
        return knit.GetService("TeleportManagerService")
    end)
    if ok then
        return svc
    end
    return nil
end

function S.coreAwait(promise)
    if type(promise) ~= "table" then
        return promise
    end
    if type(promise.expect) == "function" then
        local ok, value = pcall(function()
            return promise:expect()
        end)
        if ok then
            return value
        end
    end
    if type(promise.await) == "function" then
        local ok, a, b = pcall(function()
            return promise:await()
        end)
        if ok then
            return b ~= nil and b or a
        end
    end
    return nil
end

function S.coreSaveQueue()
    if S._v3 then S.v3SaveConfig() end
end

function S.coreLoadQueue()
    S.v3LoadConfig()
    S._v3Running=S._v3.autoStart
    S._v3SafeCFrame=S.getRoot() and S.getRoot().CFrame
    S.trySetControlsFlag("dtec_core_chest_types",CoreFarm.chestTypes)
end

function S.coreZoneEmpty(zone)
    if typeof(zone) ~= "Instance" then
        return false
    end
    local count = tonumber(zone:GetAttribute("PlayerCount")) or 0
    local state = tonumber(zone:GetAttribute("State")) or 0
    return count < 1 and state <= 1
end

function S.coreFindZone()
    for _, inst in ipairs(CollectionService:GetTagged("PartyZone")) do
        if S.coreZoneEmpty(inst) then
            return inst
        end
    end
    return nil
end

function S.coreStandOn(zone)
    local root = S.getRoot()
    if not root or not zone then
        return
    end
    local cf = zone:IsA("BasePart") and zone.CFrame or zone:GetPivot()
    local lift = 4
    if zone:IsA("BasePart") then
        lift = zone.Size.Y * 0.5 + 2
    end
    root.CFrame = cf + Vector3.new(0, lift, 0)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

function S.corePartyIsLeaving()
    if game.PlaceId ~= LOBBY_PLACE then
        return false
    end
    local knit = S.getKnit()
    if not knit then
        return false
    end
    local ctrl
    pcall(function()
        ctrl = knit.GetController("PartyCreateController")
    end)
    local zone = ctrl and ctrl.Zone
    if not zone then
        return false
    end
    local state = tonumber(zone:GetAttribute("State")) or 0
    local teleportTime = tonumber(zone:GetAttribute("TeleportTime")) or 0
    return state > 1 or teleportTime ~= 0
end

function S.coreFinishStart(ok)
    CoreFarm._starting = false
    CoreFarm._partyStarted = ok == true
    if ok then CoreFarm._partyRequestAt = os.clock() end
    return ok == true
end

function S.coreStartLobby()
    if S._unloaded or CoreFarm._userStop then return false end
    S.coreSetStatus("Lobby: joining " .. tostring(CoreFarm.mode))
    if CoreFarm._starting then
        return false
    end
    CoreFarm._starting = true
    if game.PlaceId ~= LOBBY_PLACE then
        S.notify("Lobby", "This only runs in the lobby", 4)
        return S.coreFinishStart(false)
    end
    local rootDeadline = os.clock() + 15
    while not S.getRoot() and os.clock() < rootDeadline do
        task.wait(0.25)
    end
    if not S.getRoot() then
        return S.coreFinishStart(false)
    end
    local svc = S.coreTeleportService()
    local tagged = CollectionService:GetTagged("PartyZone")
    if not svc or #tagged == 0 then
        S.coreSetStatus("Lobby: wait for pads")
        if os.clock() - (CoreFarm._waitNote or 0) > 8 then
            CoreFarm._waitNote = os.clock()
            S.notify("Lobby", "Waiting for party pads to load.", 4)
        end
        return S.coreFinishStart(false)
    end
    local zone = S.coreFindZone()
    if not zone or not S.coreZoneEmpty(zone) then
        S.coreSetStatus("Lobby: pads full")
        if os.clock() - (CoreFarm._waitNote or 0) > 8 then
            CoreFarm._waitNote = os.clock()
            S.notify("Lobby", "Pads are full. Waiting for an empty one.", 4)
        end
        return S.coreFinishStart(false)
    end
    local knit = S.getKnit()
    local ctrl = nil
    if knit then
        pcall(function()
            ctrl = knit.GetController("PartyCreateController")
        end)
    end
    local claimed = false
    for _ = 1, 5 do
        if not S.coreZoneEmpty(zone) and (tonumber(zone:GetAttribute("PlayerCount")) or 0) > 1 then
            break
        end
        if S._unloaded or CoreFarm._userStop then return S.coreFinishStart(false) end
        S.coreStandOn(zone)
        task.wait(0.2)
        if S._unloaded or CoreFarm._userStop then return S.coreFinishStart(false) end
        pcall(function()
            S.coreAwait(svc:TouchedZone(zone))
        end)
        task.wait(0.35)
        local count = tonumber(zone:GetAttribute("PlayerCount")) or 0
        if ctrl and ctrl.Zone == zone then
            claimed = true
            break
        end
        if count == 1 then
            claimed = true
            break
        end
        if count > 1 then
            break
        end
    end
    if not claimed or (ctrl and ctrl.Zone and ctrl.Zone ~= zone) then
        if ctrl and ctrl.Zone and ctrl.Zone ~= zone then
            pcall(function()
                svc:ExitZone(ctrl.Zone)
            end)
        end
        return S.coreFinishStart(false)
    end
    local countNow = tonumber(zone:GetAttribute("PlayerCount")) or 0
    if countNow > 1 then
        pcall(function()
            svc:ExitZone(zone)
        end)
        return S.coreFinishStart(false)
    end
    if S._unloaded or CoreFarm._userStop then
        pcall(function() svc:ExitZone(zone) end)
        return S.coreFinishStart(false)
    end
    local modeName = CoreFarm.mode == "Ranked" and "Ranked" or "Unranked"
    local size = math.clamp(math.floor(tonumber(CoreFarm.partySize) or 1), 1, 8)
    S.coreSaveQueue()
    local started = false
    if ctrl and ctrl.Zone == zone and ctrl.CreateUI and ctrl.CreateUI.MapSelect then
        local button = ctrl.CreateUI.MapSelect:FindFirstChild(modeName)
        if button then
            local countOk = pcall(function() ctrl:UpdatePlayerCount(size) end)
            ctrl.SelectedMapButton = button
            local modeOk = pcall(function() ctrl:UpdateMapSelection() end)
            if countOk and modeOk then
                local startOk, promise = pcall(function() return ctrl:StartParty() end)
                started = startOk and S.coreAwait(promise) ~= false
            end
        end
    end
    if not started then
        local ranked = modeName == "Ranked"
        local ok, promise = pcall(function()
            return svc:CreatedZone(zone, size, "Earth", ranked)
        end)
        if not ok or S.coreAwait(promise) == false then
            pcall(function()
                svc:ExitZone(zone)
            end)
            return S.coreFinishStart(false)
        end
    end
    S.notify("Lobby", modeName .. " · party " .. size, 4)
    return S.coreFinishStart(true)
end

function S.coreAutoChestOn()
    return Autofarm.openChests == true or (type(CoreFarm) == "table" and (CoreFarm.openAll == true or CoreFarm._ownedRun == true))
end

function S.coreSkipCutscene()
    if S._unloaded then return end
    if not S.coreAutoChestOn() then
        return
    end
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    local skip = gui and gui:FindFirstChild("CutSceneUI") and gui.CutSceneUI:FindFirstChild("Skip")
    local showing = skip and skip.Visible == true
    if workspace:GetAttribute("InCutScene") ~= true and not showing then
        return
    end
    local knit = S.getKnit()
    if not knit then
        return
    end
    local ctrl, svc
    pcall(function()
        ctrl = knit.GetController("CutSceneController")
    end)
    pcall(function()
        svc = knit.GetService("CutSceneService")
    end)
    local scene = ctrl and ctrl.CurrentCutScene
    if not scene then
        return
    end
    local now = os.clock()
    if CoreFarm._skippedScene == scene and now - (CoreFarm._skippedAt or 0) < 0.4 then
        return
    end
    if CoreFarm._skippedScene == scene and workspace:GetAttribute("InCutScene") == true and now - (CoreFarm._skippedAt or 0) >= 0.45 then
        if ctrl.AbortCutScene then
            pcall(function()
                ctrl:AbortCutScene()
            end)
        end
        CoreFarm._skippedAt = now
        return
    end
    CoreFarm._skippedScene = scene
    CoreFarm._skippedAt = now
    local ctx = ctrl.CurrentCutSceneContext
    if svc then
        if ctx and ctx.Private and ctx.RuntimeId ~= nil then
            pcall(function()
                svc:VoteSkipPrivate(ctx.RuntimeId, scene)
            end)
        else
            pcall(function()
                svc:VoteSkip(scene)
            end)
        end
    end
end

function S.coreRefreshChestPick()
    local flags = Controls and Controls.Flags
    local types = flags and flags.dtec_core_chest_types
    local raw = types and ((types._value and types._value.Value) or types.CurrentValue)
    local picked = S.chestLabelsFromSaved(S.chestSelectionList(raw))
    if #picked == 0 then
        picked = S.chestLabelsFromSaved(S.chestSelectionList(CoreFarm._chestPick))
    end
    if #picked == 0 then
        picked = S.chestLabelsFromSaved(S.chestSelectionList(CoreFarm.chestTypes))
    end
    if #picked > 0 then
        CoreFarm._chestPick = picked
    end
    return picked
end

function S.coreHoldChestRun()
    if S._v3 and not S._v3.chests then return end
    if not (CoreFarm.openAll or CoreFarm._ownedRun) or CoreFarm._leaving then
        return
    end
    local picked = S.coreRefreshChestPick()
    if #picked == 0 then
        return
    end
    CoreFarm.chestTypes = picked
    CoreFarm._chestPick = picked
    Autofarm.chestTypes = picked
    Autofarm.openChests = true
    Autofarm.enterMines = false
    Autofarm.enterDungeons = false
    Autofarm.oreUnderEnabled = false
    Autofarm.autoSell = false
end

function S.coreSetStatus(message)
    message = tostring(message or "Waiting")
    if CoreFarm._statusText == message then return end
    CoreFarm._statusText = message
    local label = CoreFarm._statusLabel
    if label and label.Set then pcall(function() label:Set(message) end) end
end

function S.coreWantRun()
    return not CoreFarm._userStop and (CoreFarm.openAll == true or CoreFarm._queuedRun == true
        or S.coreToggleOn("dtec_core_open"))
end

function S.corePlayerReady()
    if S._unloaded then return false end
    if S._finishSettings and S._finishSettings.busy then return false end
    if not Services.ToolService or not Services.InteractionService then
        CoreFarm._rootSeenAt = nil
        S.coreSetStatus(not Services.ToolService and "Wait: ToolService" or "Wait: InteractionService")
        return false
    end
    S._servicesReady = true 
    if workspace:GetAttribute("InCutScene") == true then
        CoreFarm._rootSeenAt = nil
        S.coreSetStatus("Wait: cutscene")
        return false
    end
    local player = LocalPlayer or Players.LocalPlayer
    local char = player and player.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        CoreFarm._rootSeenAt = nil
        S.coreSetStatus("Wait: character")
        return false
    end
    if CoreFarm._rootSeenCharacter ~= char then
        CoreFarm._rootSeenCharacter, CoreFarm._rootSeenAt = char, nil
    end
    CoreFarm._rootSeenAt = CoreFarm._rootSeenAt or os.clock()
    local age = os.clock() - CoreFarm._rootSeenAt
    
    local settle = char:FindFirstChildOfClass("ForceField") and 2 or 1
    if age < settle then S.coreSetStatus("Wait: spawn settling"); return false end
    return true
end

function S.coreCycleError(stage, err)
    local message = tostring(err)
    CoreFarm._lastCycleError = stage .. ": " .. message
    S.interactionNote("cycle error", CoreFarm._lastCycleError)
    pcall(S.hubLog, CoreFarm._lastCycleError)
    local first = message:match("[^\n]+") or message
    S.coreSetStatus("Retry " .. stage .. ": " .. first:sub(1, 90))
end

function S.coreResumeChurch()
    if CoreFarm._teleportPending or CoreFarm._teleportStarted then return true end
    if CoreFarm._runStarted or CoreFarm._ownedRun then return false end
    local _, buttons = S.coreChurchConfirmButtons()
    local button = S.coreFindSaveButton(buttons)
    if button then
        CoreFarm._bootChurchWait = true
        S.coreFireChurchButton(button)
        return true
    end
    if CoreFarm._bootChurchWait then
        S.coreSetStatus("Church: waiting for teleport acknowledgement")
        return true
    end
    return false
end

function S.coreCycleTick()
    if not S._unloaded and S.coreProcessSaveRequest() then return end
    if not S._unloaded and S._uiReady then S.coreMenuRefresh() end
    if S._unloaded or not S._uiReady or S._configLoading or CoreFarm._leaving then return end
    if S.v3Tick() then return end
    if CoreFarm._userStop then S.coreSetStatus("Stopped"); return end
    if not S.coreWantRun() and not CoreFarm.enabled then return end
    if game.PlaceId == NA.placeId then
        if S.coreResumeChurch() then return end
        return S.coreCycleRun()
    end
    if game.PlaceId ~= LOBBY_PLACE or CoreFarm._starting then return end
    if S.corePartyIsLeaving() then CoreFarm._partyStarted = true; return end
    if CoreFarm._partyStarted then
        local knit, ctrl = S.getKnit(), nil
        if knit then pcall(function() ctrl = knit.GetController("PartyCreateController") end) end
        if ctrl and ctrl.Zone and os.clock() - (CoreFarm._partyRequestAt or os.clock()) < 12 then return end
        if ctrl and ctrl.Zone then
            local service = S.coreTeleportService()
            if service then pcall(function() service:ExitZone(ctrl.Zone) end) end
        end
        CoreFarm._partyStarted = false
    end
    if os.clock() < (CoreFarm._nextLobbyAt or 0) then return end
    CoreFarm._nextLobbyAt = os.clock() + 4
    local ok, err = xpcall(S.coreStartLobby, function(e) return debug.traceback(tostring(e), 2) end)
    if not ok then
        CoreFarm._starting, CoreFarm._partyStarted = false, false
        S.coreCycleError("lobby", err)
    end
end

function S.coreChurchReady()
    if CoreFarm._teleportPending or CoreFarm._teleportStarted then return true end
    local _, buttons = S.coreChurchConfirmButtons()
    if S.coreFindSaveButton(buttons) then
        CoreFarm._churchMenuSeen = true
        return true
    end
    return false
end

function S.coreCycleRun()
    if S._unloaded then return false end
    if S._activity then return true end
    if S._configLoading or not S._uiReady then S.coreSetStatus("Wait: settings"); return false end
    if CoreFarm._leaving then return false end
    if not S.coreWantRun() then S.coreSetStatus(CoreFarm._userStop and "Stopped" or "Off"); return false end
    CoreFarm.openAll = true
    if game.PlaceId == LOBBY_PLACE then
        S.coreSetStatus("Lobby: queued")
        return false
    end
    if game.PlaceId ~= NA.placeId then S.coreSetStatus("Wait: match place"); return false end
    if CoreFarm._applying or CoreFarm._startPending then S.coreSetStatus("Starting farm"); return false end
    if not Services.ToolService or not Services.InteractionService then S.connectServicesAsync() end
    if not S.corePlayerReady() then return false end
    local farmOn = Autofarm.enabled == true and typeof(Autofarm.origin) == "Vector3"
    if CoreFarm._runStarted and CoreFarm._ownedRun and farmOn then
        if S._chestInteraction then return true end
        if CoreFarm._drainingChests then S.coreDrainChestsTick(); return true end
        S.coreSetStatus("Running · lap " .. tostring((CoreFarm.laps or 0) + 1) .. "/" .. tostring(CoreFarm.rescans or 2))
        S.coreHoldChestRun()
        S.coreUnstickRun()
        return true
    end
    if os.clock() < (CoreFarm._nextStartAt or 0) then return false end
    if not S.coreToggleOn("dtec_core_open") then S.trySetControlsFlag("dtec_core_open", true) end
    local gen = CoreFarm._applyGen or 0
    CoreFarm._startPending = true
    S.coreSetStatus("Starting farm")
    task.spawn(function()
        local ok, err = xpcall(function()
            if S._unloaded or CoreFarm._userStop or CoreFarm._leaving
                or gen ~= (CoreFarm._applyGen or 0) or not CoreFarm.openAll then return end
            S.coreApplyRun()
        end, function(e) return debug.traceback(tostring(e), 2) end)
        if S._unloaded or gen ~= (CoreFarm._applyGen or 0) then return end
        CoreFarm._startPending, CoreFarm._applying = false, false
        CoreFarm._nextStartAt = os.clock() + 2
        if ok and CoreFarm._runStarted then
            CoreFarm._queuedRun, CoreFarm._startFailures = false, 0
            S.coreSetStatus("Running · lap 1/" .. tostring(CoreFarm.rescans or 2))
            S.coreSaveQueue()
        elseif not ok then
            CoreFarm._runStarted, CoreFarm._ownedRun = false, false
            CoreFarm._startFailures = (CoreFarm._startFailures or 0) + 1
            CoreFarm._nextStartAt = os.clock() + math.min(15, 2 ^ math.min(CoreFarm._startFailures, 4))
            pcall(S.coreStopLootWatch)
            if Autofarm.enabled then pcall(S.setAutofarm, false, { skipReturn = true }) end
            S.coreCycleError(CoreFarm._startStage or "farm", err)
        else
            S.coreSetStatus("Retry: route not ready")
        end
    end)
    return true
end

function S.coreRequestRun()
    
    if S._unloaded or CoreFarm._userStop or CoreFarm._leaving then return false end
    if not S.coreWantRun() and not CoreFarm.enabled then return false end
    CoreFarm.openAll = true
    if not CoreFarm._runStarted then CoreFarm._queuedRun = true end
    return true
end

function S.stopCoreChestRun()
    if CoreFarm._stopping then
        return
    end
    CoreFarm._stopping = true
    S.v3CancelActivity()
    CoreFarm._drainingChests, CoreFarm._chestQuietSince = false, nil
    CoreFarm._userStop = true
    CoreFarm.enabled, CoreFarm._bootChurchWait = false, false
    CoreFarm._startPending = false
    CoreFarm._queuedRun = false
    CoreFarm._nextStartAt = 0
    CoreFarm._rootSeenAt = nil
    CoreFarm._saveNowRequested = nil
    CoreFarm._churchReturning, CoreFarm._churchPaused = false, true
    CoreFarm._finishGen = (CoreFarm._finishGen or 0) + 1
    S.coreStopLootWatch()
    S.disconnectAll("coreReturnTeleport")
    CoreFarm._lootSeen = nil
    CoreFarm._church = nil
    CoreFarm._applyGen = (CoreFarm._applyGen or 0) + 1
    CoreFarm.openAll = false
    CoreFarm._ownedRun = false
    CoreFarm._runStarted = false
    CoreFarm._applying = false
    CoreFarm._leaving = false
    Autofarm.openChests = false
    if game.PlaceId == NA.placeId then
        S.setAutofarm(false)
        S.trySetControlsFlag("na_autofarm", false)
    end
    S.trySetControlsFlag("dtec_core_open", false)
    S.trySetControlsFlag("dtec_lobby_auto", false)
    S.coreSetStatus("Stopped")
    S.coreSaveQueue()
    CoreFarm._stopping = false
end

function S.coreApplyRun()
    if S._unloaded or CoreFarm._userStop or CoreFarm._applying or CoreFarm._leaving then
        return
    end
    if not CoreFarm.openAll or not S.corePlayerReady() then return end
    CoreFarm._applying = true
    CoreFarm._applySince = os.clock()
    local gen = CoreFarm._applyGen or 0
    local function stillThisRun()
        return not S._unloaded and not CoreFarm._userStop and not CoreFarm._leaving
            and gen == (CoreFarm._applyGen or 0) and CoreFarm.openAll == true
    end
    local rootDeadline = os.clock() + 20
    while not S.getRoot() and os.clock() < rootDeadline do
        if not stillThisRun() then
            CoreFarm._applying = false
            return
        end
        task.wait(0.5)
    end
    if not stillThisRun() then
        CoreFarm._applying = false
        return
    end
    if not S.getRoot() then
        CoreFarm._applying = false
        CoreFarm._runStarted = false
        return
    end
    local picked = S.coreRefreshChestPick()
    if #picked == 0 then
        picked = {}
        for _, label in ipairs(CHEST_TYPE_OPTIONS) do
            picked[#picked + 1] = label
        end
    end
    CoreFarm.chestTypes = picked
    CoreFarm._chestPick = picked
    CoreFarm._ownedRun = true
    S._v3Visited=setmetatable({},{__mode="k"})
    CoreFarm._finishGen = (CoreFarm._finishGen or 0) + 1
    CoreFarm._keptCount, CoreFarm._missedCount = 0, 0
    CoreFarm._drainingChests, CoreFarm._chestQuietSince, CoreFarm._chestSummary = false, nil, nil
    S._confirmedArmor = {}
    S._knownFarmChests, S._farmChestInstances = {}, setmetatable({}, {__mode = "k"})
    S.ensureChestIndex()
    CoreFarm._startStage = "loot tracker"
    S.coreStartLootWatch()
    Autofarm.chestTypes = picked
    Autofarm.openChests = true
    Autofarm.enterMines = false
    Autofarm.enterDungeons = false
    Autofarm.oreUnderEnabled = false
    Autofarm.autoSell = false
    S.trySetControlsFlag("na_auto_loot", false)
    S.trySetControlsFlag("na_af_auto_ores", false)
    S.trySetControlsFlag("na_af_auto_chests", true)
    S.trySetControlsFlag("na_af_chest_types", S.chestLabelsFromSaved(Autofarm.chestTypes))
    CoreFarm.laps = 0
    CoreFarm._leaving = false
    CoreFarm._lapLock = 0
    CoreFarm._coresBefore = tonumber(LocalPlayer:GetAttribute("Cores")) or 0
    if not stillThisRun() then
        CoreFarm._applying = false
        return
    end
    CoreFarm._startStage = "farm engine"
    S.setAutofarm(true)
    if not Autofarm.enabled or not Autofarm.origin then
        CoreFarm._runStarted = false
        CoreFarm._applying = false
        Autofarm._dbgErr = "no root"
        return
    end
    Autofarm._dbgErr = nil
    CoreFarm._runStarted, CoreFarm._startStage = true, nil
    CoreFarm._stuckAt = nil
    S.trySetControlsFlag("na_autofarm", true)
    local need = math.clamp(math.floor(tonumber(CoreFarm.rescans) or 2), 1, 10)
    S.notify("Core", "Run on · auto chests · " .. need .. " map ends", 4)
    CoreFarm._applying = false
end

function S.coreUnstickRun()
    if S._activity or CoreFarm._drainingChests then return end
    if S._chestInteraction or (S._finishSettings and S._finishSettings.busy) then return end
    if not (CoreFarm.openAll and CoreFarm._ownedRun) or CoreFarm._leaving or CoreFarm._applying then
        return
    end
    if workspace:GetAttribute("InCutScene") == true then
        return
    end
    local root = S.getRoot()
    if not root then
        return
    end
    if not Autofarm.enabled or not State.connections.autofarm or not State.connections.autofarmGlide then
        CoreFarm._stuckAt = nil
        if not Autofarm.enabled or not State.connections.autofarm then
            S.setAutofarm(true)
        else
            S.ensureAutofarmOrigin(true)
            S.startAlkalineRouteGlide()
            S.lockAutofarmHover(true)
        end
        return
    end
    if Autofarm.moving or (Autofarm.busy and Autofarm._holdReason == "chest") then
        CoreFarm._stuckAt = nil
        return
    end
    local pos = root.Position
    local stamp = CoreFarm._stuckAt
    if type(stamp) ~= "table" then
        CoreFarm._stuckAt = { x = pos.X, z = pos.Z, at = os.clock() }
        return
    end
    local moved = (Vector3.new(pos.X - stamp.x, 0, pos.Z - stamp.z)).Magnitude
    if moved > 12 then
        CoreFarm._stuckAt = { x = pos.X, z = pos.Z, at = os.clock() }
        return
    end
    if os.clock() - (stamp.at or 0) < 4 then
        return
    end
    CoreFarm._stuckAt = { x = pos.X, z = pos.Z, at = os.clock() }
    S.clearMineHoldPin()
    Autofarm._gatePinY = nil
    Autofarm.busy = false
    Autofarm.moving = false
    Autofarm._cycleRunning = false
    if (Autofarm.distance or 0) < 40 then
        S.setAutofarm(true)
        return
    end
    S.ensureAutofarmOrigin(not Autofarm.origin)
    S.startAlkalineRouteGlide()
    S.setAutofarmPose(Autofarm.distance or 0)
    S.lockAutofarmHover(true)
end

function S.coreFinishActive(gen)
    if type(gen)=="table" and gen.kind then return S.v3JobActive(gen) end
    return not S._unloading and not S._unloaded and not CoreFarm._userStop
        and CoreFarm._leaving == true and gen == CoreFarm._finishGen
end

function S.chestOpened(chest, coresBefore)
    if type(coresBefore) == "number" and (tonumber(LocalPlayer:GetAttribute("Cores")) or 0) > coresBefore then return true end
    if not chest then return false end
    local opened = false
    for _, name in ipairs({"Opened", "IsOpened", "Looted"}) do
        if chest:GetAttribute(name) == true then opened = true; break end
    end
    if not opened then return false end
    for _, prompt in ipairs(S.collectProximityPrompts(chest)) do
        local action = string.lower(prompt.ActionText or "")
        if prompt.Enabled and (action == "interact" or action:find("open", 1, true)) then return false end
    end
    return true
    -- A streamed-out model, disabled prompt or local lid tween proves no reward.
end

function S.chestAttemptRecord(chest)
    S._chestAttempts = S._chestAttempts or setmetatable({}, { __mode = "k" })
    local generation = type(CoreFarm) == "table" and CoreFarm._finishGen or 0
    local record = S._chestAttempts[chest]
    if not record or record.generation ~= generation then
        record = { generation = generation, tries = 0, done = false }; S._chestAttempts[chest] = record
    end
    return record
end

function S.hotbarTools()
    local tools, seen = {}, {}
    for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack") }) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and not seen[tool] then tools[#tools + 1] = tool; seen[tool] = true end
            end
        end
    end
    return tools
end

function S.hotbarLimit()
    for _, container in ipairs({ LocalPlayer, LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character }) do
        if container then
            for _, key in ipairs({ "MaxTools", "MaxHotbarSlots", "HotbarSize", "ToolCapacity" }) do
                local value = tonumber(container:GetAttribute(key))
                if value and value >= 1 and value <= 100 then return math.floor(value) end
            end
        end
    end

    return math.huge
end

function S.hotbarFullHint()
    local cache = S.gameGuiCache()
    for label in pairs(cache.labels) do
        if label.Parent and S.gameGuiVisible(label) then
            local text = string.lower(label.Text or "")
            if ((text:find("hotbar", 1, true) or text:find("inventory", 1, true) or text:find("backpack", 1, true))
                and text:find("full", 1, true)) or text:find("too many tools", 1, true)
                or (text:find("can only carry", 1, true) and text:find("tool", 1, true)) then return true end
        end
    end
    return false
end

function S.hotbarProtected(tool)
    local token = S.normalizeGearToken(S.armorLabel(tool))
    if S.coreKeepKind(tool) or (S.isItemBagTool and S.isItemBagTool(tool))
        or token:find("itembag", 1, true) or token:find("revive", 1, true)
        or token:find("medkit", 1, true) or token:find("bandage", 1, true)
        or tool:GetAttribute("QuestItem") or tool:GetAttribute("NoDrop") then return true end
    return false
end

function S.hotbarToolGroup(tool)
    if S.isPickaxeWorldItem(tool) then return "Pickaxe" end
    if S.isSwordWorldItem(tool) then return "Sword" end
    local token = S.normalizeGearToken(S.coreLootIdentity(tool))
    local category = S.itemCategoryKey(tool)
    if token:find("rifle", 1, true) or token:find("shotgun", 1, true) or token:find("revolver", 1, true)
        or token:find("blackhole", 1, true) or category:find("weapon", 1, true)
        or category == "gun" or tool:GetAttribute("Ammo") ~= nil then return "Weapon" end
    if S.isArmorWorldItem(tool) then return "Armor" end
    return "Other"
end

function S.hotbarToolScore(tool)
    local score = S.getWorldGearScore(tool)
    if score and score >= 0 then return score end
    return (tonumber(tool:GetAttribute("Value")) or 0) + (tonumber(tool:GetAttribute("Damage")) or 0)
end

function S.hotbarMayReplace(tool, incoming)
    if not incoming or S.isItemBagTool(tool) or tool:GetAttribute("QuestItem") or tool:GetAttribute("NoDrop") then return false end
    local oldKind, oldTier = S.coreKeepKind(tool)
    local newKind, newTier = S.coreKeepKind(incoming)
    if oldKind ~= "Tool" or oldTier >= 110 then return false end
    if newKind == "Shard" then return true end
    if newKind ~= "Tool" or S.hotbarToolGroup(tool) ~= S.hotbarToolGroup(incoming) then return false end
    local oldPriority, newPriority = S.coreLootPriority(tool, oldKind, oldTier), S.coreLootPriority(incoming, newKind, newTier)
    return newPriority > oldPriority or (newPriority == oldPriority and S.hotbarToolScore(incoming) > S.hotbarToolScore(tool))
end

function S.hotbarDropCandidate(incoming)
    local tools, best, bestScore = S.hotbarTools(), nil, math.huge
    local incomingGroup = S.hotbarToolGroup(incoming)
    local incomingScore = S.hotbarToolScore(incoming)
    local newKind, newTier = S.coreKeepKind(incoming)
    local newPriority = S.coreLootPriority(incoming, newKind, newTier)
    local pickaxes = 0
    for _, tool in ipairs(tools) do if S.isPickaxeWorldItem(tool) then pickaxes += 1 end end
    for _, tool in ipairs(tools) do
        local group, score = S.hotbarToolGroup(tool), S.hotbarToolScore(tool)
        local kind, tier = S.coreKeepKind(tool)
        local priority = kind and S.coreLootPriority(tool, kind, tier) or 0
        local canDrop = true
        pcall(function() canDrop = tool.CanBeDropped ~= false end)
        if canDrop and (not S.hotbarProtected(tool) or S.hotbarMayReplace(tool, incoming)) then
            local upgrade = incomingGroup == group and (incomingScore > score or S.hotbarMayReplace(tool, incoming))
            local sparePickaxe = group ~= "Pickaxe" or pickaxes > 1 or (incomingGroup == "Pickaxe" and upgrade)
            local candidateScore = priority * 100000000 + math.max(0, score)
            if sparePickaxe and newPriority > priority and candidateScore < bestScore then
                best, bestScore = tool, candidateScore
            elseif sparePickaxe and upgrade and newPriority == priority and candidateScore < bestScore then
                best, bestScore = tool, candidateScore
            end
        end
    end
    return best
end

function S.hotbarDropTool(tool, context, incoming)
    if not tool or (S.hotbarProtected(tool) and not S.hotbarMayReplace(tool, incoming))
        or not S.coreFinishActive(context) or not Services.ToolService then return false end
    local character, before = LocalPlayer.Character, #S.hotbarTools()
    local canDrop = true
    pcall(function() canDrop = tool.CanBeDropped ~= false end)
    if not canDrop then return false end
    local ok, promise = pcall(function() return Services.ToolService:EquipTool(tool) end)
    if not ok then return false end
    S.coreFinishAwait(promise, 1, context)
    local deadline = os.clock() + 1
    while S.coreFinishActive(context) and tool.Parent ~= character and os.clock() < deadline do task.wait(0.05) end

    if not S.coreFinishActive(context) or LocalPlayer.Character ~= character or tool.Parent ~= character then return false end
    local focused
    pcall(function() focused = UserInputService:GetFocusedTextBox() end)
    if focused then return false end
    local sent = S.sendNativeKey(Enum.KeyCode.Backspace, true)
    if sent then task.wait(0.06) end
    S.sendNativeKey(Enum.KeyCode.Backspace, false)
    deadline = os.clock() + 1.2
    while S.coreFinishActive(context) and os.clock() < deadline do
        if tool.Parent ~= character and not tool:IsDescendantOf(LocalPlayer) and #S.hotbarTools() < before then
            S._discardedLoot = S._discardedLoot or {}
            S._discardedLoot[S.normalizeGearToken(tool.Name)] = { at = os.clock(), score = S.hotbarToolScore(tool) }
            S.interactionNote("hotbar", "Dropped " .. tool.Name .. "; slot confirmed free")
            return true
        end
        task.wait(0.1)
    end
    S.interactionNote("hotbar", "Game did not confirm dropping " .. tool.Name)
    return false
end

function S.isDiscardedLoot(item)
    local discarded = S._discardedLoot and S._discardedLoot[S.normalizeGearToken(item.Name)]
    if not discarded then return false end
    if os.clock() - discarded.at > 180 then S._discardedLoot[S.normalizeGearToken(item.Name)] = nil; return false end
    return S.hotbarToolScore(item) <= discarded.score
end

function S.hotbarMakeRoom(entry, context, force)
    if entry.kind == "Armor" then return true end
    if not force and #S.hotbarTools() < S.hotbarLimit() then return true end
    local candidate = S.hotbarDropCandidate(entry.item)
    if candidate and S.hotbarDropTool(candidate, context, entry.item) then return true end
    S.interactionNote("hotbar", "No confirmed free slot for " .. entry.name)
    S.coreSetStatus("Hotbar: no free slot · keeping protected gear")
    return false
end

function S.gameGuiCache()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    local cache = S._gameGui
    if cache and cache.gui == gui then return cache end
    S.disconnectAll("gameGuiAdded"); S.disconnectAll("gameGuiRemoved")
    cache = { gui = gui, buttons = {}, labels = {} }; S._gameGui = cache
    if not gui then return cache end
    local function record(inst)
        if inst:IsA("GuiButton") then cache.buttons[inst] = true end
        if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then cache.labels[inst] = true end
    end
    State.connections.gameGuiAdded = gui.DescendantAdded:Connect(record)
    State.connections.gameGuiRemoved = gui.DescendantRemoving:Connect(function(inst)
        cache.buttons[inst], cache.labels[inst] = nil, nil
    end)
    local n = 0
    for _, inst in ipairs(gui:GetDescendants()) do
        record(inst); n = n + 1
        if n % 128 == 0 then task.wait() end
    end
    return cache
end

function S.coreStorageObject(inst)
    local cur = inst
    for _ = 1, 14 do
        if not cur or cur == Workspace then break end
        local name = string.lower(cur.Name or "")
        local token = S.normalizeGearToken(name)
        if token:find("loadout", 1, true) or token:find("playercrate", 1, true)
            or token:find("personalcrate", 1, true) or token:find("equipmentcrate", 1, true)
            or token:find("storagecrate", 1, true) or token:find("spawncrate", 1, true) then return true end
        if token:find("crate", 1, true) then
            if name:find("'s", 1, true) or name:find("’s", 1, true) then return true end
            for _, key in ipairs({ "Owner", "OwnerId", "OwnerUserId", "PlayerUserId", "PlayerName" }) do
                if cur:GetAttribute(key) ~= nil then return true end
            end
        end
        cur = cur.Parent
    end
    return false
end

function S.coreChurchContext(inst)
    local cur, church = inst, nil
    for _ = 1, 16 do
        if not cur or cur == Workspace then break end
        local token = S.normalizeGearToken(cur.Name)

        if token:find("crate", 1, true) or token:find("loadout", 1, true)
            or token:find("storage", 1, true) or token:find("shop", 1, true) then return nil end
        if (cur:IsA("Model") or cur:IsA("BasePart") or cur:IsA("Folder"))
            and (token:find("church", 1, true) or token:find("chapel", 1, true)) then church = church or cur end
        cur = cur.Parent
    end
    return church
end

function S.coreSaveReturnNow()
    if S._unloaded or CoreFarm._teleportPending then return false end
    if game.PlaceId ~= NA.placeId then S.notify("Return", "Join a match first.", 3); return false end
    if CoreFarm._leaving then return S.coreRetryChurchReturn() end
    CoreFarm._saveNowRequested = true
    S.coreSetStatus("Return queued")
    return true
end

function S.coreProcessSaveRequest()
    if not CoreFarm._saveNowRequested then return false end
    if S._unloaded or game.PlaceId ~= NA.placeId then CoreFarm._saveNowRequested = nil; return false end
    if S._chestInteraction or (S._finishSettings and S._finishSettings.busy) then return true end
    CoreFarm._saveNowRequested = nil
    if CoreFarm._leaving or CoreFarm._teleportPending then return true end
    CoreFarm._userStop, CoreFarm._leaving, CoreFarm.openAll, CoreFarm._ownedRun = false, true, false, false
    CoreFarm._runStarted = false
    CoreFarm._finishGen = (CoreFarm._finishGen or 0) + 1
    local gen, before = CoreFarm._finishGen, CoreFarm._coresBefore
    S.disconnectAll("autofarmGlide"); S.disconnectAll("autofarm")
    task.spawn(function()
        local ok, err = pcall(S.coreFinishRun, before, gen)
        if not ok and S.coreFinishActive(gen) then
            S.coreSetStatus("Return paused")
            S.interactionNote("return", tostring(err))
        end
    end)
    return true
end

function S.coreStatusCaption(value)
    value = tostring(value or "Starting")
    if value:find("opening save dialog", 1, true) then return "Opening church" end
    if value:find("teleport accepted", 1, true) then return "Returning to lobby" end
    if value:find("altar not loaded", 1, true) then return "Church altar not loaded" end
    if value:find("Church: Teleport", 1, true) then return "Confirming return" end
    return value
end

function S.coreLootIdentity(item)
    local parts = {tostring(item.Name or "")}
    for _, attr in ipairs({"DisplayName", "ItemId", "ArmorName", "Material", "ArmorMaterial", "ArmorSet"}) do
        local value = item:GetAttribute(attr)
        if type(value) == "string" then parts[#parts + 1] = value end
    end
    return table.concat(parts, " ")
end

function S.coreLootValue(item)
    for _, attribute in ipairs({"SellValue", "SellPrice", "CoinValue", "Value", "Worth", "Price"}) do
        local raw = item:GetAttribute(attribute)
        if type(raw) == "string" then raw = raw:gsub("[,%s$]", "") end
        local value = tonumber(raw)
        if value and value == value and value >= 0 and value < math.huge then return value end
    end
    return 0
end

function S.coreLootPriority(item, kind, tier)
    local name = S.normalizeGearToken(S.coreLootIdentity(item))
    if kind == "Shard" then
        local rarity = S.normalizeGearToken(item:GetAttribute("Rarity")) .. name
        return 10000 + (rarity:find("legendary", 1, true) and 100 or rarity:find("rare", 1, true) and 50 or 0)
    end
    if name:find("blackhole", 1, true) then return 9000 end
    if kind == "Armor" then return 7000 + math.min(120, tier or 0) * 10 end
    if kind == "Tool" then
        if tier and tier >= 110 then return 8500 end
        return 6000 + math.min(100, tier or 0) * 10
    end
    return 1000
end

function S.coreSackCount()
    local label = S._sackQuantityLabel
    if not label or not label.Parent then
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        local sack = gui and gui:FindFirstChild("SackUI", true)
        label = sack and sack:FindFirstChild("Quantity", true)
        S._sackQuantityLabel = label
    end
    if not label or not (label:IsA("TextLabel") or label:IsA("TextButton")) then return nil, nil end
    local current, capacity = tostring(label.Text or ""):match("(%d+)%s*/%s*(%d+)")
    return tonumber(current), tonumber(capacity)
end

function S.coreSackValuable(item, gen)
    if not S.coreFinishActive(gen) or not item.Parent or not Services.ToolService then return false end
    local character = LocalPlayer.Character
    local function active() return S.coreFinishActive(gen) and LocalPlayer.Character == character end
    local before, capacity = S.coreSackCount()
    if before == nil or (capacity and before >= capacity) then return false end
    local bag
    for _, container in ipairs({LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack")}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if S.isItemBagTool(tool) then bag = tool; break end
            end
        end
        if bag then break end
    end
    if not bag then return false end
    local ok, promise = pcall(function() return Services.ToolService:EquipTool(bag) end)
    if not ok then return false end
    S.coreFinishAwait(promise, 1, gen)
    local deadline = os.clock() + 0.8
    while active() and bag.Parent ~= character and os.clock() < deadline do task.wait(0.08) end
    if not active() or bag.Parent ~= character or not item.Parent then return false end
    ok = pcall(function() Services.ToolService.Update:Fire({"Pickup", item}) end)
    if not ok then return false end
    deadline = os.clock() + 1.2
    while active() and os.clock() < deadline do
        local current = S.coreSackCount()
        if current and current > before then return true end
        task.wait(0.1)
    end
    return false
end

function S.coreEquipOwnedArmor(gen)
    local best = {}
    for _, container in ipairs({LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack")}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and S.isArmorWorldItem(tool) then
                    local slot, score = S.getArmorSlotKey(tool), S.getWorldGearScore(tool)
                    if not best[slot] or score > best[slot].score then best[slot] = {item = tool, score = score} end
                end
            end
        end
    end
    for slot, entry in pairs(best) do
        if not S.coreFinishActive(gen) then return end
        if Services.ToolService and entry.score > S.getCurrentGearScore("Armor", entry.item) then
            local ok, promise = pcall(function() return Services.ToolService:EquipTool(entry.item) end)
            if ok then S.coreFinishAwait(promise, 1.2, gen) end
            local deadline = os.clock() + 1.2
            while ok and S.coreFinishActive(gen) and os.clock() < deadline do
                local equipped = S.getEquippedArmorPiece(slot)
                if equipped and S.getWorldGearScore(equipped) >= entry.score then
                    S._confirmedArmor = S._confirmedArmor or {}
                    S._confirmedArmor[slot] = {score = S.getWorldGearScore(equipped), character = LocalPlayer.Character,
                        generation = CoreFarm._finishGen, at = os.clock()}
                    break
                end
                task.wait(0.1)
            end
        end
    end
end

function S.coreKeepKind(item)
    if not item then return nil end
    local label = S.coreLootIdentity(item)
    local name = S.normalizeGearToken(label .. " " .. tostring(item:GetAttribute("ItemId") or ""))
    if name:find("shard", 1, true) then return "Shard", 0 end
    local category = S.itemCategoryKey(item)
    local class = S.normalizeGearToken(item:GetAttribute("Class"))
    if category == "ammo" or category == "ammunition" or class == "ammo" or class == "ammunition"
        or name:find("ammunition", 1, true) or name:find("bullets", 1, true)
        or name:find("shotgunammo", 1, true) or name:find("rifleammo", 1, true) then return nil end
    local rarity = S.normalizeGearToken(item:GetAttribute("Rarity"))
    local tier = 0
    if name:find("blackhole", 1, true) or name:find("mythic", 1, true) or rarity:find("mythic", 1, true) then tier = 110 end
    if name:find("phoenix", 1, true) then tier = math.max(tier, 90) end
    if name:find("king", 1, true) and not name:find("goblin", 1, true) then tier = math.max(tier, 100) end
    if name:find("void", 1, true) then tier = math.max(tier, 80) end
    if rarity:find("legendary", 1, true) or name:find("legendary", 1, true) then tier = math.max(tier, 95)
    elseif rarity == "epic" then tier = math.max(tier, 80) end
    local value = S.coreLootValue(item)
    if S.isArmorWorldItem(item) then
        local material = S.getArmorMaterialRank(label)
        tier = math.max(tier, material)
        if tier >= 80 or value >= 1000 then return "Armor", tier end
        return nil
    end
    local tool = item:IsA("Tool") or S.isPickaxeWorldItem(item) or S.isSwordWorldItem(item)
        or category:find("weapon", 1, true) or category == "tool" or category == "gun" or category == "consumable"
        or name:find("rifle", 1, true) or name:find("shotgun", 1, true)
        or name:find("revolver", 1, true) or name:find("blackhole", 1, true)
    if tool then
        tier = math.max(tier, S.getPickaxeRank(label), S.getSwordRank(label))
        if tier >= 80 or value >= 1000 then return "Tool", tier end
        return nil
    end
    if value >= 1000 then return "Valuable", 0 end
    return nil
end

function S.coreItemKeys(item)
    local keys = {}
    for _, value in ipairs({ item.Name, item:GetAttribute("ItemId") or "", item:GetAttribute("DisplayName") or "" }) do
        local key = S.normalizeGearToken(value)
        if key ~= "" then keys[key] = true end
    end
    return keys
end

function S.coreKeysMatch(item, keys)
    for key in pairs(S.coreItemKeys(item)) do
        if keys[key] then return true end
    end
    return false
end

function S.coreOwnedCount(keys)
    local count = 0
    local function scan(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and S.coreKeysMatch(item, keys) then
                count = count + math.max(1, tonumber(item:GetAttribute("Amount"))
                    or tonumber(item:GetAttribute("Count")) or tonumber(item:GetAttribute("Quantity")) or 1)
            end
        end
    end
    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    return count
end

function S.coreRecordLoot(item)
    if not CoreFarm._lootSeen or not S.coreInventoryLocked() or not item then return end
    item = S.resolveWorldItem(item)
    if not item or not item.Parent or CoreFarm._lootSeen[item] or S.isHardExcluded(item) then return end
    local kind, tier = S.coreKeepKind(item)
    if not kind or S.isDiscardedLoot(item) or S.coreStorageObject(item) then return end
    local pos = S.getItemPosition(item)
    if pos then
        CoreFarm._lootSeen[item] = { item = item, name = item.Name, keys = S.coreItemKeys(item),
            kind = kind, tier = tier, pos = pos, value = S.coreLootValue(item) }
    end
end

function S.coreSavePromptScore(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Parent or not prompt.Enabled
        or S.coreStorageObject(prompt) or not S.coreChurchContext(prompt) then return 0 end
    local label = S.coreChurchText(prompt) .. " " .. S.coreChurchText(prompt.Parent)
    local score = S.coreChurchActionScore(label)
    if score <= 0 then return 0 end
    local token = S.normalizeGearToken(label)
    local gear = token:find("gear", 1, true) or token:find("equipment", 1, true) or token:find("items", 1, true)
    local save = token:find("save", 1, true) or token:find("bank", 1, true) or token:find("extract", 1, true)
    return score + (save and gear and 150 or 0)
end

function S.coreChurchRoot(inst)
    return S.coreChurchContext(inst)
end

function S.coreStandAtAltar(prompt, gen, attempt)
    if not S.coreFinishActive(gen) then return false end
    local pos, root = S.getPromptWorldPosition(prompt), S.getRoot()
    if not pos or not root or not prompt.Enabled then return false end
    local range = tonumber(prompt.MaxActivationDistance) or 10
    if range <= 0 then return false end
    local directions = { Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) }
    local side = directions[((tonumber(attempt) or 1) - 1) % #directions + 1]
    local distance = math.min(3, range * 0.4)
    local candidate = pos + side * distance + Vector3.new(0, math.min(0.8, range * 0.15), 0)
    local humanoid = S.getHumanoid()
    local hip = humanoid and tonumber(humanoid.HipHeight) or 2
    local half = root.Size and root.Size.Y * 0.5 or 1
    local leg = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Left Leg")
    if leg and leg:IsA("BasePart") then half = half + leg.Size.Y end
    pcall(function()
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = { LocalPlayer.Character }
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.RespectCanCollide = true
        local hit = Workspace:Raycast(candidate + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
        if hit and hit.Normal.Y > 0.6 and hit.Position.Y <= pos.Y + 1.5 and hit.Position.Y >= pos.Y - 8 then
            local grounded = Vector3.new(candidate.X, hit.Position.Y + (hip or 2) + half, candidate.Z)
            if (grounded - pos).Magnitude < range * 0.85 then candidate = grounded end
        end
    end)
    root.Anchored = false
    if humanoid then humanoid.Sit, humanoid.PlatformStand = false, false end
    local cf = CFrame.new(candidate)
    pcall(function() cf = CFrame.lookAt(candidate, Vector3.new(pos.X, candidate.Y, pos.Z)) end)
    root.CFrame, root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = cf, Vector3.zero, Vector3.zero
    task.wait(0.2)
    if not S.coreFinishActive(gen) then return false end
    local livePos = S.getPromptWorldPosition(prompt)
    local inRange = livePos and (root.Position - livePos).Magnitude < range * 0.95
    S.interactionNote("altar position", inRange and "In prompt range · approach " .. tostring(attempt or 1) or "Position changed before interaction")
    CoreFarm._altarInRange = inRange == true
    return inRange == true
end

function S.coreRetryChurchReturn()
    if S._unloaded or CoreFarm._churchRecoveryBusy or CoreFarm._churchReturning or CoreFarm._teleportPending then return false end
    local _, buttons = S.coreChurchConfirmButtons()
    if S.coreFindSaveButton(buttons) then return S.coreConfirmChurchNow(true) end
    if not S.coreFinishActive(CoreFarm._finishGen) then
        S.notify("Church", "Return recovery is available after the chest laps finish.", 4)
        return false
    end
    local gen = CoreFarm._finishGen
    CoreFarm._churchRecoveryBusy = true
    task.spawn(function()
        local ok, err = pcall(function()
            S.coreSetStatus("Church: finding the save altar")
            local church = S.coreFindChurch(gen, true)
            if church and S.coreFinishActive(gen) then S.coreReturnLobby(CoreFarm._coresBefore, gen, church)
            elseif S.coreFinishActive(gen) then S.coreSetStatus("Church: altar not loaded · retry return") end
        end)
        CoreFarm._churchRecoveryBusy = false
        if not ok then S.interactionNote("church recovery", tostring(err)) end
    end)
    return true
end

function S.coreRememberChurch(inst)
    if not inst then return end
    local isPrompt = inst:IsA("ProximityPrompt")
    if isPrompt then
        if S.coreSavePromptScore(inst) <= 0 then return end
        inst = S.coreChurchRoot(inst)
    elseif not (inst:IsA("Model") or inst:IsA("BasePart")) or not (string.lower(inst.Name):find("church", 1, true) or string.lower(inst.Name):find("chapel", 1, true)) then return end
    if not inst or S.coreStorageObject(inst) then return end
    local pos = S.getInstancePosition(inst)
    if not pos then return end
    CoreFarm._churchCandidates = CoreFarm._churchCandidates or setmetatable({}, { __mode = "k" })
    CoreFarm._churchCandidates[inst] = pos

    if not CoreFarm._church then CoreFarm._church = { inst = inst, pos = pos } end
end

function S.coreStopLootWatch()
    CoreFarm._lootWatchToken = nil
    for _, key in ipairs({ "coreLootAdded", "coreLootTagged", "coreChurchAdded", "coreChurchGuiAdded", "coreItemsFolderAdded" }) do S.disconnectAll(key) end
end

function S.coreSnapshotLoot()
    local n = 0
    S.forEachWorldLootItem(function(item)
        S.coreRecordLoot(item)
        n = n + 1
        if n % 64 == 0 then task.wait() end
    end)
end

function S.coreStartLootWatch()
    S.coreStopLootWatch()
    CoreFarm._lootSeen, CoreFarm._church, CoreFarm._churchCandidates = {}, nil, setmetatable({}, { __mode = "k" })
    local token = {}
    CoreFarm._lootWatchToken = token
    local function active() return CoreFarm._lootWatchToken == token and S.coreInventoryLocked() end
    local function attach(items)
        if not active() then return end
        S.disconnectAll("coreLootAdded")
        State.connections.coreLootAdded = items.ChildAdded:Connect(function(item)
            task.defer(function() if active() then S.coreRecordLoot(item) end end)
        end)
    end
    local items = Workspace:FindFirstChild("Items")
    if items then attach(items) end
    State.connections.coreItemsFolderAdded = Workspace.ChildAdded:Connect(function(folder)
        if folder.Name == "Items" and active() then attach(folder); S.coreSnapshotLoot() end
    end)
    State.connections.coreLootTagged = CollectionService:GetInstanceAddedSignal("DungeonLootHighlightTarget"):Connect(S.coreRecordLoot)
    State.connections.coreChurchAdded = Workspace.DescendantAdded:Connect(function(inst)
        if active() and (inst:IsA("ProximityPrompt") or (string.lower(inst.Name):find("church", 1, true) or string.lower(inst.Name):find("chapel", 1, true))) then S.coreRememberChurch(inst) end
    end)
    S.coreSnapshotLoot()
end

function S.coreFinishAwait(promise, seconds, gen)
    if type(promise) ~= "table" or type(promise.andThen) ~= "function" then return promise ~= false, promise end
    local done, success, result = false, false, nil
    local observer = promise:andThen(function(value)
        done, success, result = true, value ~= false, value
    end)
    if observer and type(observer.catch) == "function" then
        observer:catch(function(err) done, success, result = true, false, err end)
    end
    local deadline = os.clock() + seconds
    while not done and os.clock() < deadline and S.coreFinishActive(gen) do task.wait(0.1) end
    return done and success, result
end

function S.coreStandNear(pos, gen)
    if type(gen)=="table" and gen.kind then return S.v3Move(gen,pos+Vector3.new(0,2.5,3)) end
    if not S.coreFinishActive(gen) then return false end
    local root = S.getRoot()
    if not root then return false end
    if type(gen) == "table" and gen.farm then
        local stand = pos + Vector3.new(0, 2.5, 3)
        Autofarm._mineHoldPos, Autofarm._gatePinY = stand, stand.Y
    end
    root.Anchored = false
    root.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 3))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    local humanoid = S.getHumanoid()
    if humanoid then humanoid.Sit, humanoid.PlatformStand = false, false end
    return true
end

function S.coreResolveKeptItem(entry, gen)
    local item = entry.item
    local items = Workspace:FindFirstChild("Items")
    if items and item.Parent and item:IsDescendantOf(items) then return item end
    if not S.coreFinishActive(gen) or not S.coreStandNear(entry.pos, gen) then return nil end
    S.requestStreamAround(entry.pos, 0.8)
    task.wait(0.2)
    if not S.coreFinishActive(gen) then return nil end
    items = Workspace:FindFirstChild("Items")
    if items then
        for _, candidate in ipairs(items:GetChildren()) do
            if S.coreKeysMatch(candidate, entry.keys) then
                local pos = S.getItemPosition(candidate)
                if pos and (pos - entry.pos).Magnitude < 16 and not S.isHardExcluded(candidate) then return candidate end
            end
        end
    end
    return nil
end

function S.coreCollectKeptItem(entry, gen)
    if entry.kind == "Armor" and S.getCurrentGearScore("Armor", entry.item) >= S.getWorldGearScore(entry.item) then
        return true, "covered"
    end
    if entry.kind == "Valuable" then
        local current, capacity = S.coreSackCount()
        if current and capacity and current >= capacity then return false, "capacity" end
    end
    local item = S.coreResolveKeptItem(entry, gen)
    if not item or not Services.InteractionService or S.isHardExcluded(item) then return false end
    local before = S.coreOwnedCount(entry.keys)
    local slot = entry.kind == "Armor" and S.getArmorSlotKey(item) or nil
    local score = slot and S.getWorldGearScore(item) or nil
    if slot and S.getCurrentGearScore("Armor", item) >= score then return true, "covered" end
    local bagBefore = entry.kind == "Valuable" and S.coreSackCount() or nil
    local function collected()
        if slot then
            local piece = S.getEquippedArmorPiece(slot)
            local confirmed = piece ~= nil and S.getWorldGearScore(piece) >= score
            if confirmed then
                S._confirmedArmor = S._confirmedArmor or {}
                S._confirmedArmor[slot] = {score = S.getWorldGearScore(piece), character = LocalPlayer.Character,
                    generation = CoreFarm._finishGen, at = os.clock()}
            end
            return confirmed
        end
        
        if S.coreOwnedCount(entry.keys) > before then return true end
        local current = entry.kind == "Valuable" and S.coreSackCount() or nil
        return bagBefore ~= nil and current ~= nil and current > bagBefore
    end
    local roomTried = false
    for attempt = 1, 2 do
        if not S.coreFinishActive(gen) then return false end
        if attempt == 2 and entry.kind ~= "Valuable" and not slot and not collected() and (#S.hotbarTools() >= S.hotbarLimit() or S.hotbarFullHint()) and not roomTried then
            roomTried = true
            if S._finishSettings.freeSlots == false or not S.hotbarMakeRoom(entry, gen, true) then return false end
        end
        if collected() then return true end
        if not item.Parent then return false end
        local pos = S.getItemPosition(item) or entry.pos
        if not S.coreStandNear(pos, gen) then return false end
        S.requestStreamAround(pos, 0.5)
        task.wait(0.15)
        if not S.coreFinishActive(gen) then return false end
        if entry.kind == "Valuable" and attempt == 2 and S.coreSackValuable(item, gen) then
            S.clearDragTarget()
            return true
        end
        if not S.coreFinishActive(gen) then return false end
        S.setDragTarget(item)
        local ok, promise = pcall(function() return Services.InteractionService:Interact(item) end)
        if ok then S.coreFinishAwait(promise, 1.2, gen) end
        local deadline = os.clock() + 0.8
        while S.coreFinishActive(gen) and os.clock() < deadline do
            if collected() then
                S.clearDragTarget()
                return true
            end
            task.wait(0.1)
        end
    end
    S.clearDragTarget()
    return false
end

function S.coreCollectKeptLoot(gen)
    task.wait(0.35)
    if not S.coreFinishActive(gen) then return end
    local outcomes, armorChecked = {}, false
    local function pass(shardsOnly)
        S.coreSnapshotLoot()
        local list = {}
        for _, entry in pairs(CoreFarm._lootSeen or {}) do
            local state = outcomes[entry] or {tries = 0}
            outcomes[entry] = state
            if not state.collected and not state.covered and not state.capacity and state.tries < 2 and (not shardsOnly or entry.kind == "Shard") then
                list[#list + 1] = entry
            end
        end
        table.sort(list, function(a, b)
            local ap, bp = S.coreLootPriority(a.item, a.kind, a.tier), S.coreLootPriority(b.item, b.kind, b.tier)
            if ap ~= bp then return ap > bp end
            if a.kind == "Armor" and b.kind == "Armor" then
                local as, bs = S.getWorldGearScore(a.item), S.getWorldGearScore(b.item)
                if as ~= bs then return as > bs end
            end
            local av, bv = S.coreLootValue(a.item), S.coreLootValue(b.item)
            if av ~= bv then return av > bv end
            return a.name < b.name
        end)
        for _, entry in ipairs(list) do
            if not S.coreFinishActive(gen) then return end
            if entry.kind == "Armor" and not armorChecked then
                S.coreEquipOwnedArmor(gen)
                armorChecked = true
            end
            local state = outcomes[entry]
            state.tries += 1
            local ok, kept, reason = pcall(S.coreCollectKeptItem, entry, gen)
            state.covered = ok and reason == "covered"
            state.capacity = ok and reason == "capacity"
            state.collected = ok and kept == true and not state.covered
            task.wait((state.covered or state.capacity) and 0.01 or 0.12)
        end
    end
    -- Two shard sweeps happen before equipment or sack valuables can take space.
    pass(true)
    if not S.coreFinishActive(gen) then return end
    task.wait(0.3)
    pass(true)
    if not S.coreFinishActive(gen) then return end
    pass(false)
    if not S.coreFinishActive(gen) then return end
    task.wait(0.25)
    pass(false) -- catches delayed drops and gives failed equipment one final retry
    local collected, missed, covered = 0, 0, 0
    for _, state in pairs(outcomes) do
        if state.collected then collected += 1
        elseif state.covered then covered += 1
        elseif state.tries > 0 then missed += 1 end
    end
    CoreFarm._keptCount, CoreFarm._missedCount, CoreFarm._coveredCount = collected, missed, covered
    if missed > 0 then S.notify("Core", missed .. " selected drops could not be confirmed in inventory.", 6) end
end

function S.coreEquipKeptTools(gen)
    if S._finishSettings.equip == false then return end
    S.coreEquipOwnedArmor(gen)
    if not S.coreFinishActive(gen) then return end
    local tools, seen = {}, {}
    local function scan(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            local kind = S.coreKeepKind(item)
            if item:IsA("Tool") and (kind == "Shard" or kind == "Tool" or S.isPickaxeTool(item)) and not seen[item] then
                seen[item] = true
                tools[#tools + 1] = item
            end
        end
    end
    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    local best, bestScore = nil, -1
    for _, item in ipairs(tools) do
        if not S.coreFinishActive(gen) then return end
        if Services.ToolService and item.Parent then
            local ok, promise = pcall(function() return Services.ToolService:EquipTool(item) end)
            if ok then S.coreFinishAwait(promise, 1, gen) end
            if S.isPickaxeTool(item) then
                local score = S.getWorldGearScore(item)
                if score > bestScore then best, bestScore = item, score end
            end
            task.wait(0.15)
        end
    end
    if best and best.Parent and Services.ToolService and S.coreFinishActive(gen) then
        local ok, promise = pcall(function() return Services.ToolService:EquipTool(best) end)
        if ok then S.coreFinishAwait(promise, 1, gen) end
    end
    
end

function S.coreFindChurch(gen, force)
    if not S.coreFinishActive(gen) then return nil end
    local visited, candidates, best, bestScore = {}, {}, nil, 0
    local function consider(inst, refresh)
        if not inst or (visited[inst] and not refresh) or not inst:IsDescendantOf(Workspace) then return end
        visited[inst] = true
        local prompt, target, pad, score = S.coreChurchTargets(inst)
        score = prompt and score or (target and 20 or pad and 15 or 0)
        if score > bestScore then
            local pos = prompt and S.getPromptWorldPosition(prompt) or S.getInstancePosition(target or pad)
            if pos then
                best, bestScore = { inst = inst, pos = pos, prompt = prompt, target = target, pad = pad }, score
            end
        end
    end
    local cached = CoreFarm._church
    if cached and not force then consider(cached.inst) end
    if bestScore >= 150 then CoreFarm._church = best; return best.inst end
    for inst in pairs(CoreFarm._churchCandidates or {}) do candidates[#candidates + 1] = inst end
    for _, inst in ipairs(candidates) do consider(inst) end
    if bestScore >= 150 then CoreFarm._church = best; return best.inst end
    if cached and cached.pos then
        
        S.requestStreamAround(cached.pos, 1)
        task.wait(0.2)
        if not S.coreFinishActive(gen) then return nil end
        visited[cached.inst] = nil; consider(cached.inst)
    end
    local queue, head, inspected = { Workspace }, 1, 0
    local deadline = os.clock() + 8
    while head <= #queue and os.clock() < deadline and S.coreFinishActive(gen) do
        local parent = queue[head]; queue[head], head = false, head + 1
        for _, child in ipairs(parent:GetChildren()) do
            inspected = inspected + 1
            if child:IsA("ProximityPrompt") and S.coreSavePromptScore(child) > 0 then
                consider(S.coreChurchRoot(child), true)
            elseif (child:IsA("Model") or child:IsA("BasePart")) and (string.lower(child.Name):find("church", 1, true) or string.lower(child.Name):find("chapel", 1, true)) then
                S.coreRememberChurch(child); consider(child)
            end
            if bestScore >= 150 then CoreFarm._church = best; return best.inst end
            if child.Name ~= "Items" and child ~= LocalPlayer.Character
                and (child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart") or child:IsA("Attachment"))
                and not (child:IsA("Model") and Players:GetPlayerFromCharacter(child)) then queue[#queue + 1] = child end
            if inspected % 96 == 0 then
                task.wait()
                if not S.coreFinishActive(gen) or os.clock() >= deadline then break end
            end
        end
    end
    if best and S.coreFinishActive(gen) then
        CoreFarm._church = best
        S.interactionNote("altar target", best.inst:GetFullName())
        return best.inst
    end
    S.interactionNote("altar target", "No loaded save interaction found")
    return nil
end

function S.coreChurchText(inst)
    if not inst then return "" end
    local text = tostring(inst.Name or "")
    for _, key in ipairs({ "ActionText", "ObjectText", "Text" }) do
        pcall(function() text = text .. " " .. tostring(inst[key] or "") end)
    end
    return string.lower(text)
end

function S.coreChurchActionScore(text)
    local token = S.normalizeGearToken(text)
    if token:find("withoutsav", 1, true) or token:find("dontsave", 1, true)
        or token:find("donotsave", 1, true) or token:find("nosave", 1, true)
        or token:find("abandon", 1, true) or token:find("cancel", 1, true)
        or token:find("purchase", 1, true) or token:find("buy", 1, true) then return -1 end
    local score = 0
    if token:find("save", 1, true) or token:find("bank", 1, true) then score = 60 end
    if token:find("extract", 1, true) or token:find("store", 1, true) then score = math.max(score, 50) end
    if token:find("lobby", 1, true) then score = score + 20 end
    if token:find("equipment", 1, true) or token:find("items", 1, true) or token:find("gear", 1, true) then score = score + 10 end
    if score == 0 and (token:find("return", 1, true) or token:find("teleport", 1, true)
        or token:find("portal", 1, true) or token:find("church", 1, true)) then score = 5 end
    return score
end

function S.coreChurchTargets(church)
    if not church or not church:IsDescendantOf(Workspace) or not S.coreChurchContext(church)
        or S.coreStorageObject(church) then return nil end
    local prompt, target, pad, best = nil, nil, nil, 0
    for _, candidate in ipairs(S.collectProximityPrompts(church)) do
        local score = S.coreSavePromptScore(candidate)
        if score > best and S.getPromptWorldPosition(candidate) then prompt, best = candidate, score end
    end
    local ancestor = prompt and prompt.Parent
    while ancestor and ancestor ~= Workspace do
        if CollectionService:HasTag(ancestor, "Interactive") and not S.coreStorageObject(ancestor) then target = ancestor; break end
        if ancestor == church then break end
        ancestor = ancestor.Parent
    end
    if not target then
        local targetScore = 0
        for _, candidate in ipairs(CollectionService:GetTagged("Interactive")) do
            if (candidate == church or candidate:IsDescendantOf(church)) and S.coreChurchContext(candidate)
                and not S.coreStorageObject(candidate) then
                local score = S.coreChurchActionScore(S.coreChurchText(candidate))
                if score > targetScore then target, targetScore = candidate, score end
            end
        end
    end
    if not prompt and not target then
        for _, child in ipairs(church:GetDescendants()) do
            if child:IsA("TouchTransmitter") and child.Parent and child.Parent:IsA("BasePart")
                and S.coreChurchContext(child.Parent) and S.coreChurchActionScore(S.coreChurchText(child.Parent)) > 0 then
                pad = child.Parent; break
            end
        end
    end
    return prompt, target, pad, best
end

function S.interactionNote(stage, message)
    S._interactionLog = S._interactionLog or {}
    local line = stage .. ": " .. tostring(message)
    if S._interactionLog[#S._interactionLog] == line then return end
    S._interactionLog[#S._interactionLog + 1] = line
    if #S._interactionLog > 40 then table.remove(S._interactionLog, 1) end
end

function S.nativeInput()
    if S._nativeInput then return S._nativeInput end
    local input
    pcall(function() input = UserInputService:CreateVirtualInput() end)
    if input then S._nativeInput = { object = input, modern = true }; return S._nativeInput end
    pcall(function() input = game:GetService("VirtualInputManager") end)
    if input then S._nativeInput = { object = input, modern = false }; return S._nativeInput end
end

function S.sendNativeKey(key, down)
    local input = S.nativeInput()
    if not input then return false end
    return pcall(function()
        if input.modern then input.object:SendKey(down, key, false)
        else input.object:SendKeyEvent(down, key, false, game) end
    end)
end

function S.gameGuiVisible(gui)
    local node = gui
    local own = S._alkalineLibrary and S._alkalineLibrary.ScreenGui
    while node do
        if node == own or ((node:IsA("GuiObject") or node:IsA("ScreenGui")) and string.lower(node.Name):find("alkaline", 1, true)) then return false end
        if node:IsA("GuiObject") and node.Visible == false then return false end
        if node:IsA("ScreenGui") and node.Enabled == false then return false end
        node = node.Parent
    end
    return gui ~= nil and gui.Parent ~= nil
end

function S.churchInputBackends()
    local list = {}
    local preferred = S.nativeInput()
    if preferred then list[#list + 1] = preferred end
    if not S._churchLegacyInput then
        local legacy
        pcall(function() legacy = game:GetService("VirtualInputManager") end)
        if legacy then S._churchLegacyInput = { object = legacy, modern = false } end
    end
    local legacy = S._churchLegacyInput
    if legacy and (not preferred or preferred.object ~= legacy.object) then list[#list + 1] = legacy end
    return list
end

function S.churchClickPoint(button, alternate)
    local position, size = button.AbsolutePosition, button.AbsoluteSize
    if not position or not size or size.X < 2 or size.Y < 2 then return nil end
    local x, y = position.X + size.X * 0.5, position.Y + size.Y * 0.5
    local inset = Vector2.new(0, 0)
    pcall(function() inset = game:GetService("GuiService"):GetGuiInset() end)

    if not alternate then x, y = x + inset.X, y + inset.Y end
    return Vector2.new(x, y), inset
end

function S.churchSignalInput(button, state)
    if S._churchLastInput and (not state or S._churchLastInput.UserInputState == state) then return S._churchLastInput end
    local position, size = button.AbsolutePosition, button.AbsoluteSize
    return {
        UserInputType = Enum.UserInputType.MouseButton1,
        UserInputState = state,
        KeyCode = Enum.KeyCode.Unknown,
        Position = Vector3.new(position and position.X + size.X * 0.5 or 0, position and position.Y + size.Y * 0.5 or 0, 0),
    }
end

function S.churchInvokeSignal(button, signalName)
    local targets, node = {}, button
    for _ = 1, 3 do
        if not node or not node:IsA("GuiObject") or S.coreChurchConfirmScore(node) <= 0 then break end
        targets[#targets + 1] = node
        node = node.Parent
    end
    local function invoke(target, name, object)
        local signal
        pcall(function() signal = target[name] end)
        if not signal then return false end
        local args = name == "Activated" and { object, 0 } or name == "MouseButton1Click" and {} or { object }
        local fired, enumerated, hasConnections = false, false, false
        if typeof(getconnections) == "function" then
            local ok, connections = pcall(getconnections, signal)
            if ok and type(connections) == "table" then
                enumerated, hasConnections = true, #connections > 0
                for _, connection in ipairs(connections) do
                    if connection.Enabled ~= false then
                        local callOk, err = pcall(function()
                            if type(connection.Function) == "function" then connection.Function(table.unpack(args))
                            elseif type(connection.Fire) == "function" then connection:Fire(table.unpack(args))
                            else error("No callable handler") end
                        end)
                        fired = callOk or fired
                        if not callOk then S.interactionNote("church handler " .. name, tostring(err):sub(1, 160)) end
                    end
                end
            end
        end
        if not fired and (not enumerated or hasConnections) and typeof(firesignal) == "function" then
            fired = pcall(firesignal, signal, table.unpack(args))
        end
        return fired
    end
    local ending = Enum.UserInputState and Enum.UserInputState.End
    for _, target in ipairs(targets) do
        if invoke(target, signalName, S.churchSignalInput(target, ending)) then
            S.interactionNote("church handler", signalName .. " on " .. target.Name); return true
        end
    end

    for _, target in ipairs(targets) do
        if not target:IsA("GuiButton") then
            local begun = invoke(target, "InputBegan", S.churchSignalInput(target, Enum.UserInputState and Enum.UserInputState.Begin))
            if begun then task.wait(0.08) end
            local ended = invoke(target, "InputEnded", S.churchSignalInput(target, ending))
            if begun or ended then return true end
        end
    end
    return false
end

function S.nativeButtonClick(button, attempt)
    if not S.coreChurchButtonVisible(button) then return false end
    local backends = S.churchInputBackends()
    attempt = tonumber(attempt) or 1
    local input = backends[(attempt == 2 or attempt == 6) and 2 or 1] or backends[1]
    if not input then S.interactionNote("church input", "No native input backend available"); return false end
    local point = S.churchClickPoint(button, attempt >= 5)
    if not point then return false end
    local own = S._alkalineLibrary and S._alkalineLibrary.ScreenGui
    local wasEnabled = own and own.Enabled
    local mouse, focused
    pcall(function() mouse = UserInputService:GetMouseLocation(); focused = UserInputService:GetFocusedTextBox() end)
    if focused then
        if own and focused:IsDescendantOf(own) then pcall(function() focused:ReleaseFocus(false) end)
        else S.interactionNote("church input", "Waiting for text input to lose focus"); return false end
    end
    local observed, listeners = false, {}
    local function capture(object)
        if object and object.UserInputType == Enum.UserInputType.MouseButton1 then S._churchLastInput = object end
    end
    pcall(function() listeners[#listeners + 1] = UserInputService.InputEnded:Connect(capture) end)
    pcall(function() listeners[#listeners + 1] = button.InputBegan:Connect(function(object)
        if object.UserInputType == Enum.UserInputType.MouseButton1 then observed = true; capture(object) end
    end) end)
    if own and own.Parent then own.Enabled = false end
    pcall(function()
        if input.modern then input.object:SendKey(false, Enum.KeyCode.E, false)
        else input.object:SendKeyEvent(false, Enum.KeyCode.E, false, game) end
    end)
    local pressed = false
    local ok, err = pcall(function()
        if input.modern then
            input.object:SendMousePosition(point)
            input.object:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
        else
            
            pcall(function() input.object:SendMouseMoveEvent(point.X, point.Y, game) end)
            input.object:SendMouseButtonEvent(point.X, point.Y, 0, true, game, 0)
        end
        pressed = true
        task.wait(0.1)
    end)
    local released, releaseError = pcall(function()
        if input.modern then input.object:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
        else input.object:SendMouseButtonEvent(point.X, point.Y, 0, false, game, 0) end
    end)

    task.wait(0.16)
    for _, connection in ipairs(listeners) do pcall(function() connection:Disconnect() end) end
    if own and own.Parent and not S._unloaded then own.Enabled = wasEnabled end
    if mouse then pcall(function()
        if input.modern then input.object:SendMousePosition(mouse)
        else input.object:SendMouseMoveEvent(mouse.X, mouse.Y, game) end
    end) end
    S.interactionNote("church input", (input.modern and "VirtualInput" or "VirtualInputManager")
        .. " at " .. math.floor(point.X) .. "," .. math.floor(point.Y)
        .. (observed and " · button received mouse-down" or " · awaiting game acknowledgement"))
    if not ok then S.interactionNote("church input error", tostring(err):sub(1, 160)) end
    if not released then S.interactionNote("church release error", tostring(releaseError):sub(1, 160)) end
    return ok and pressed and released
end

function S.coreTrackChurchTeleport()
    if State.connections.churchActionTeleport then return end
    State.connections.churchActionTeleport = LocalPlayer.OnTeleport:Connect(function(state)
        if S._unloaded then return end
        CoreFarm._teleportFailed = state == Enum.TeleportState.Failed
        CoreFarm._teleportPending = not CoreFarm._teleportFailed
        CoreFarm._teleportStarted = state == Enum.TeleportState.InProgress
    end)
end

function S.coreFindSaveButton(buttons)
    local best, score = nil, 0
    for button in pairs(buttons or {}) do
        local value = S.coreChurchConfirmScore(button)
        if value > score then best, score = button, value end
    end
    if best and S._churchLastTarget ~= best then
        S._churchLastTarget = best
        S.interactionNote("church target", best.ClassName .. " " .. best.Name)
    end
    return best
end

function S.coreFireChurchButton(button, force)
    if S._unloaded or (S._finishSettings and S._finishSettings.busy) or S._chestInteraction or CoreFarm._teleportPending or S._churchClickBusy or S.coreChurchConfirmScore(button) <= 0 then return false end
    if CoreFarm._churchPaused and not force then return false end
    S._churchClicks = S._churchClicks or setmetatable({}, { __mode = "k" })
    local now, last = os.clock(), S._churchClicks[button]
    if force then last = nil; CoreFarm._churchPaused = false end
    if last and (last.count >= 6 or now - last.at < 2) then return false end
    local count = last and last.count + 1 or 1
    S._churchClicks[button] = { count = count, at = now }
    S._churchClickBusy, S._churchClickAt = true, now
    S.coreTrackChurchTeleport()
    local ok, dispatched = pcall(function()
        if count == 1 or count == 2 or count >= 5 then
            if S.nativeButtonClick(button, count) then return true end
        end
        return S.churchInvokeSignal(button, (count == 1 or count == 4) and "MouseButton1Click" or "Activated")
    end)
    S._churchClickBusy = false
    S.interactionNote("church", "Attempt " .. count .. "/6 " .. (ok and dispatched and "sent; awaiting teleport" or "input unavailable"))
    if CoreFarm._teleportStarted then S.coreSetStatus("Church: teleport accepted")
    else S.coreSetStatus("Church: Teleport · attempt " .. count .. "/6") end
    if ok and dispatched then CoreFarm._churchSaveRequested = true end
    return ok and dispatched == true
end

function S.coreConfirmChurchNow(force)
    local _, buttons = S.coreChurchConfirmButtons()
    local button = S.coreFindSaveButton(buttons)
    if not button then S.notify("Church", "The save-and-return dialog is not open.", 4); return false end
    return S.coreFireChurchButton(button, force == true)
end

function S.coreChurchAutoConfirmTick()
    if S._unloaded or not S._uiReady or S._configLoading or game.PlaceId ~= NA.placeId then return end

    if (S._finishSettings and S._finishSettings.busy) or S._chestInteraction or CoreFarm._churchReturning or CoreFarm._churchPaused or CoreFarm._teleportPending
        or S._churchClickBusy or CoreFarm._ownedRun or Autofarm.enabled then return end
    local _, buttons = S.coreChurchConfirmButtons()
    local button = S.coreFindSaveButton(buttons)
    if button then S.coreFireChurchButton(button) end
end

function S.coreChurchButtonVisible(button)
    return button ~= nil and button:IsA("GuiObject") and S.gameGuiVisible(button)
end

function S.coreChurchConfirmScore(button)
    if not S.coreChurchButtonVisible(button) then return 0 end
    local label = S.coreChurchText(button)
    local teleportCaption = false
    pcall(function() teleportCaption = S.normalizeGearToken(tostring(button.Text or ""):gsub("<.->", "")) == "teleport" end)
    for _, child in ipairs(button:GetDescendants()) do
        if child:IsA("TextLabel") then
            label = label .. " " .. S.coreChurchText(child)
            if child.Visible ~= false and S.normalizeGearToken(tostring(child.Text or ""):gsub("<.->", "")) == "teleport" then teleportCaption = true end
        end
    end
    if not button:IsA("GuiButton") and not teleportCaption then return 0 end
    local token = S.normalizeGearToken(label)
    if S.coreChurchActionScore(label) < 0 or label:match("%f[%a]no%f[%A]")
        or token:find("close", 1, true) or token:find("decline", 1, true)
        or token:find("discard", 1, true) then return 0 end
    if not (token:find("teleport", 1, true) or token:find("save", 1, true)
        or token:find("confirm", 1, true) or token:find("yes", 1, true)
        or token:find("extract", 1, true) or token:find("return", 1, true)
        or token:find("continue", 1, true)) then return 0 end
    local now = os.clock()
    S._churchConfirmCache = S._churchConfirmCache or setmetatable({}, { __mode = "k" })
    local cached = S._churchConfirmCache[button]
    if cached and cached.parent == button.Parent and cached.label == label and now - cached.at < 0.8 then return cached.score end
    local context, scope = label, button.Parent
    for _ = 1, 6 do
        if not scope or scope:IsA("PlayerGui") then break end
        context = context .. " " .. S.coreChurchText(scope)
        
        local queue, head, visited = { scope }, 1, 0
        while head <= #queue and visited < 160 do
            local node = queue[head]; head = head + 1
            for _, child in ipairs(node:GetChildren()) do
                visited = visited + 1
                if child:IsA("TextLabel") and child.Visible ~= false then
                    context = context .. " " .. S.coreChurchText(child)
                elseif child:IsA("Frame") and child.Visible ~= false then queue[#queue + 1] = child end
            end
        end
        local proof = S.normalizeGearToken(context)
        if (proof:find("save", 1, true) or proof:find("bank", 1, true) or proof:find("store", 1, true))
            and (proof:find("gear", 1, true) or proof:find("items", 1, true) or proof:find("equipment", 1, true)) then break end
        if scope:IsA("ScreenGui") then break end
        scope = scope.Parent
    end
    context = S.normalizeGearToken(context)
    local saved = context:find("save", 1, true) or context:find("bank", 1, true) or context:find("store", 1, true)
    local gear = context:find("items", 1, true) or context:find("gear", 1, true)
        or context:find("equipment", 1, true) or context:find("loadout", 1, true) or context:find("inventory", 1, true)
    local church = context:find("church", 1, true) or context:find("extract", 1, true)
    local lobby = context:find("lobby", 1, true) or context:find("returntohub", 1, true)
    if context:find("loadout", 1, true) or context:find("crate", 1, true) then return 0 end
    if not church and not (saved and gear and lobby) then return 0 end
    if context:find("notbesaved", 1, true) or context:find("withoutsav", 1, true) then return 0 end
    local score = (token:find("teleport", 1, true) and 120 or token:find("save", 1, true) and 100 or 40) + (gear and 10 or 0)
    score = score + (teleportCaption and 25 or 0) + (button:IsA("GuiButton") and 10 or button:IsA("Frame") and 5 or 0)
    S._churchConfirmCache[button] = { parent = button.Parent, label = label, at = now, score = score }
    return score
end

function S.coreChurchConfirmButtons()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    local cache = S._churchGuiCache
    if cache and cache.gui == gui then return gui, cache.buttons end
    S.disconnectAll("churchButtonsAdded"); S.disconnectAll("churchButtonsRemoved")
    cache = { gui = gui, buttons = {} }; S._churchGuiCache = cache
    if not gui then return nil, cache.buttons end
    local own = S._alkalineLibrary and S._alkalineLibrary.ScreenGui
    local function record(inst)
        local namedFrame = inst:IsA("Frame") and S.normalizeGearToken(inst.Name):find("teleport", 1, true)
        if (inst:IsA("GuiButton") or inst:IsA("TextLabel") or namedFrame) and (not own or not inst:IsDescendantOf(own)) then cache.buttons[inst] = true end
    end
    State.connections.churchButtonsAdded = gui.DescendantAdded:Connect(record)
    State.connections.churchButtonsRemoved = gui.DescendantRemoving:Connect(function(inst) cache.buttons[inst] = nil end)
    local queue, head, visited = { gui }, 1, 0
    while head <= #queue and not S._unloaded do
        local parent = queue[head]; head = head + 1
        if parent ~= own then
            for _, child in ipairs(parent:GetChildren()) do
                if child ~= own then record(child); queue[#queue + 1] = child end
            end
        end
        visited = visited + 1
        if visited % 96 == 0 then task.wait() end
    end
    return gui, cache.buttons
end

function S.coreChurchExit(church, gen, attempt)
    if not church or not S.coreFinishActive(gen) or not S.coreChurchContext(church) then return false end
    if S.coreChurchReady() then return true end
    attempt = tonumber(attempt) or 1
    if CoreFarm._teleportFailed and CoreFarm._churchOpenLastMethod then
        attempt = CoreFarm._churchOpenLastMethod
        CoreFarm._teleportFailed = false
    end
    local prompt, target, pad = S.coreChurchTargets(church)
    local pos = (prompt and S.getPromptWorldPosition(prompt)) or S.getInstancePosition(target or pad)
    if not pos then S.interactionNote("altar target", "No valid save interaction at this church"); return false end
    S.requestStreamAround(pos, 1)
    task.wait(0.3)
    if not S.coreFinishActive(gen) then return false end
    if S.coreChurchReady() then return true end
    prompt, target, pad = S.coreChurchTargets(church)
    local issued = false
    if prompt and prompt.Parent and prompt.Enabled then
        local promptPos = S.getPromptWorldPosition(prompt)
        if not promptPos or not S.coreStandAtAltar(prompt, gen, attempt) then return false end
        local hold = math.max(0, tonumber(prompt.HoldDuration) or 0)
        local camera, backup, triggerConnection, backend, key, holding, own, wasEnabled
        local triggered = false
        pcall(function() camera = S.aimCameraAtWorld(promptPos, nil); S.faceCharacterToward(promptPos) end)
        pcall(function() backup = S.preparePromptsForHold({ prompt }) end)
        pcall(function() triggerConnection = prompt.Triggered:Connect(function(player)
            if not player or player == LocalPlayer then triggered = true end
        end) end)
        local ok, err = pcall(function()
            if attempt >= 3 then
                local backends = S.churchInputBackends()
                backend = backends[attempt == 4 and 2 or 1] or backends[1]
            end
            if attempt == 1 and typeof(fireproximityprompt) == "function" then
                issued = pcall(fireproximityprompt, prompt, hold)
                S.interactionNote("church open", "Prompt helper · attempt " .. attempt)
            elseif backend then
                key = prompt.KeyboardKeyCode or Enum.KeyCode.E
                own = S._alkalineLibrary and S._alkalineLibrary.ScreenGui
                wasEnabled = own and own.Enabled
                local focused = UserInputService:GetFocusedTextBox()
                if focused then
                    if own and focused:IsDescendantOf(own) then focused:ReleaseFocus(false)
                    else return end
                end
                if own and own.Parent then own.Enabled = false end
                holding = "key"
                if backend.modern then backend.object:SendKey(false, key, false); backend.object:SendKey(true, key, false)
                else backend.object:SendKeyEvent(false, key, false, game); backend.object:SendKeyEvent(true, key, false, game) end
                issued = true
                S.interactionNote("church open", (backend.modern and "VirtualInput" or "VirtualInputManager") .. " key · attempt " .. attempt)
            else
                holding = "prompt"
                prompt:InputHoldBegin()
                issued = true
                S.interactionNote("church open", "Prompt press/release · attempt " .. attempt)
            end
            local deadline = os.clock() + hold + 0.25
            while issued and S.coreFinishActive(gen) and os.clock() < deadline do
                if S.coreChurchReady() or triggered then break end
                task.wait(0.1)
            end
        end)
        
        if holding == "key" and backend then
            pcall(function()
                if backend.modern then backend.object:SendKey(false, key, false)
                else backend.object:SendKeyEvent(false, key, false, game) end
            end)
        elseif holding == "prompt" then pcall(function() prompt:InputHoldEnd() end) end
        task.wait(0.16)
        if triggerConnection then pcall(function() triggerConnection:Disconnect() end) end
        if own and own.Parent and not S._unloaded then own.Enabled = wasEnabled end
        pcall(S.restorePromptsAfterHold, backup)
        pcall(S.restoreCameraAim, camera)
        if not ok then S.interactionNote("church open error", tostring(err)) end
        if issued and S.coreFinishActive(gen) then
            local deadline = os.clock() + 1.2
            repeat
                if S.coreChurchReady() then break end
                task.wait(0.1)
            until not S.coreFinishActive(gen) or os.clock() >= deadline
        end
    elseif target and Services.InteractionService then
        
        local targetPos = S.getInstancePosition(target)
        if targetPos then S.coreStandNear(targetPos, gen) end
        local ok, promise = pcall(function() return Services.InteractionService:Interact(target) end)
        issued = ok
        if ok then S.coreFinishAwait(promise, 2, gen) end
    elseif pad then
        local padPos = S.getInstancePosition(pad)
        if not padPos or not S.coreStandNear(padPos, gen) then return false end
        local root = S.getRoot()
        if root then
            if typeof(firetouchinterest) == "function" then
                issued = pcall(firetouchinterest, root, pad, 0)
                task.wait(0.15)
                pcall(firetouchinterest, root, pad, 1)
            else root.CFrame = pad.CFrame; root.AssemblyLinearVelocity = Vector3.zero; issued = true end
        end
    end
    if issued and S.coreFinishActive(gen) then
        CoreFarm._churchSaveRequested, CoreFarm._churchOpenLastMethod = true, attempt
    end
    return issued and S.coreFinishActive(gen)
end

function S.coreFinishRun(before, gen)
    if not S.coreFinishActive(gen) then return end
    
    Autofarm._returnGen = (Autofarm._returnGen or 0) + 1
    Autofarm._cycleGen = (Autofarm._cycleGen or 0) + 1
    Autofarm._skipNextEndGame = true
    S.setAutofarm(false, { skipReturn = true })
    Autofarm.openChests = false
    S.notify("Core", "Chest laps done · collecting shards and King's/Phoenix gear", 5)
    S.coreCollectKeptLoot(gen)
    if not S.coreFinishActive(gen) then return end
    S.coreEquipKeptTools(gen)
    S.coreStopLootWatch()
    pcall(S.forceReleaseFarmCharacter)
    if not S.coreFinishActive(gen) then return end
    if S._v3 and not S._v3.church then
        S.v3Park("Chest farm complete · items collected")
        return
    end
    S.notify("Core", "Selected items ready · going to church", 4)
    local church = S.coreFindChurch(gen)
    if not church and S.coreFinishActive(gen) then
        S.coreSetStatus("Church: waiting for the save altar to load")
        task.wait(1)
        if S.coreFinishActive(gen) then church = S.coreFindChurch(gen, true) end
    end
    if not S.coreFinishActive(gen) then return end
    if not church then
        CoreFarm._churchPaused = true
        S.coreSetStatus("Church: save altar not loaded · retry return")
        S.notify("Church", "Save altar not loaded. Your items are kept here. Use Retry church return.", 8)
        return
    end
    S.disconnectAll("coreReturnTeleport")
    CoreFarm._churchSaveRequested = false
    CoreFarm._teleportStarted = false
    CoreFarm._teleportPending = false
    CoreFarm._teleportFailed = false
    State.connections.coreReturnTeleport = LocalPlayer.OnTeleport:Connect(function(state)
        if not S.coreFinishActive(gen) then return end
        CoreFarm._teleportFailed = state == Enum.TeleportState.Failed
        CoreFarm._teleportPending = not CoreFarm._teleportFailed
        CoreFarm._teleportStarted = state == Enum.TeleportState.InProgress
    end)
    S.coreReturnLobby(before, gen, church)
end

function S.coreNoteLap()
    if not (CoreFarm.openAll or CoreFarm._ownedRun) or CoreFarm._leaving or CoreFarm._drainingChests then
        return
    end
    local now = os.clock()
    if now - (CoreFarm._lapLock or 0) < 3 then
        return
    end
    CoreFarm._lapLock = now
    CoreFarm.laps = (CoreFarm.laps or 0) + 1
    local need = math.clamp(math.floor(tonumber(CoreFarm.rescans) or 2), 1, 10)
    S.notify("Core", "Lap " .. CoreFarm.laps .. "/" .. need, 4)
    if CoreFarm.laps < need then
        return
    end
    CoreFarm.laps = need
    CoreFarm._drainingChests, CoreFarm._chestQuietSince = true, nil
    S.disconnectAll("autofarmGlide")
    S.coreSetStatus("Finishing remaining chests")
end

function S.coreReturnLobby(before, gen, church)
    if not church or not S.coreFinishActive(gen) or CoreFarm._churchReturning then return false end
    local session = {}
    CoreFarm._churchReturning, CoreFarm._churchPaused, CoreFarm._churchMenuSeen = session, false, false
    CoreFarm._churchOpenLastMethod, CoreFarm._churchNeedsResolve = nil, false
    S.coreTrackChurchTeleport(); S.coreSaveQueue()
    local ok, result = pcall(function()
        local _, buttons = S.coreChurchConfirmButtons()
        local requests, seen, openAt, missingAt = 0, false, -math.huge, nil
        local deadline = os.clock() + 35
        while S.coreFinishActive(gen) and os.clock() < deadline do
            if CoreFarm._teleportStarted then S.coreSetStatus("Church: teleport accepted"); return true end
            local button = S.coreFindSaveButton(buttons)
            if button then
                seen, missingAt = true, nil
                CoreFarm._churchSaveRequested = true
                if not CoreFarm._teleportPending and (not S._finishSettings or S._finishSettings.autoChurch) then S.coreFireChurchButton(button) end
            elseif seen or CoreFarm._churchMenuSeen then

                missingAt = missingAt or os.clock()
                if not CoreFarm._teleportPending and os.clock() - missingAt > 8 then return false end
            elseif not CoreFarm._teleportPending and os.clock() - openAt >= 8 then
                if requests >= 4 then return false end
                requests, openAt = requests + 1, os.clock()
                if CoreFarm._churchNeedsResolve or not church:IsDescendantOf(Workspace) then
                    local resolved = S.coreFindChurch(gen, true)
                    if resolved then church = resolved end
                    CoreFarm._churchNeedsResolve = false
                end
                S.coreSetStatus("Church: opening save dialog")
                local issued = S.coreChurchExit(church, gen, requests)
                if not S.coreFinishActive(gen) then return false end
                CoreFarm._churchNeedsResolve = not S.coreChurchReady()
                if not issued then
                    S.interactionNote("church open", "No confirmed menu yet · attempt " .. requests .. "/4")
                end
            end
            task.wait(0.2)
        end
        return CoreFarm._teleportStarted == true
    end)
    if CoreFarm._churchReturning == session then CoreFarm._churchReturning = false end
    if not S.coreFinishActive(gen) then return false end
    if not ok then S.interactionNote("church error", tostring(result):sub(1, 160)) end
    if not (ok and result) then
        CoreFarm._churchPaused = not CoreFarm._teleportPending
        S.coreSetStatus(CoreFarm._teleportPending and "Church: teleport pending at server" or "Church: return paused · Retry church return")
        S.notify("Church", "Save return is not confirmed. Keeping your items here; use Retry church return, or Copy Debug for details.", 8)
    end
    if not CoreFarm._teleportPending and not CoreFarm._teleportStarted then
        pcall(S.forceReleaseFarmCharacter)
        local root=S.getRoot();local cf=S.getDrillReturnCFrame() or S._v3SafeCFrame
        if root and cf then root.CFrame=cf;root.AssemblyLinearVelocity=Vector3.zero end
    end
    return ok and result == true
end

function S.coreMenuRefresh()
    if S._farmUi then S._farmUi:refresh(); return end
    local labels = CoreFarm._menuLabels
    if not labels then return end
    local need = math.max(1, tonumber(CoreFarm.rescans) or 2)
    local laps = math.min(need, tonumber(CoreFarm.laps) or 0)
    local values = {
        progress = tostring(laps) .. " / " .. tostring(need) .. " complete",
        loot = tostring(CoreFarm._keptCount or 0) .. " collected · " .. tostring(CoreFarm._missedCount or 0) .. " missed",
    }
    CoreFarm._menuValues = CoreFarm._menuValues or {}
    for key, text in pairs(values) do
        if labels[key] and CoreFarm._menuValues[key] ~= text then
            CoreFarm._menuValues[key] = text
            pcall(function() labels[key]:Set(text) end)
        end
    end
end

function S.coreMenuSetEnabled(value)
    if S._configLoading then return end
    if value then S.v3Start() else S.v3Park("Stopped") end
end

function S.coreCopyDebug()
    local text = "naturally alkaline v" .. NA.version .. "\nPlace: " .. tostring(game.PlaceId)
        .. "\nStatus: " .. tostring(CoreFarm._statusText or "Starting")
        .. "\nActivity: " .. tostring(S._activity and S._activity.kind or "idle")
        .. "\nConfig: " .. tostring(S._configStatus) .. " | " .. tostring(S._queueStatus)
        .. "\nKills / ores / ammo claims: " .. tostring(S._v3Kills or 0) .. "/" .. tostring(S._v3Mined or 0) .. "/" .. tostring(S._v3AmmoBought or 0)
        .. "\nShop / drag / currency services: " .. tostring(Services.ShopService~=nil) .. "/" .. tostring(Services.DragService~=nil) .. "/" .. tostring(Services.CurrencyService~=nil)
        .. "\nLaps: " .. tostring(CoreFarm.laps or 0) .. "/" .. tostring(CoreFarm.rescans or 2)
        .. "\nLoot: " .. tostring(CoreFarm._keptCount or 0) .. " collected, " .. tostring(CoreFarm._missedCount or 0) .. " missed"
        .. "\nChests: " .. (CoreFarm._chestSummary and (tostring(CoreFarm._chestSummary.opened) .. " opened, "
            .. tostring(CoreFarm._chestSummary.pending) .. " pending, " .. tostring(CoreFarm._chestSummary.locked) .. " locked") or "scanning")
        .. "\nAltar in range: " .. tostring(CoreFarm._altarInRange == true)
        .. "\n" .. tostring(CoreFarm._lastCycleError or "No startup error")
        .. "\n" .. table.concat(S._interactionLog or {}, "\n")
    if S.copyToClipboard(text) then S.notify("Autofarm", "Debug copied", 3)
    else S.notify("Autofarm", "Clipboard is unavailable", 4) end
end

function S.buildAutofarmTab()
    local ui = S._farmUi
    ui:mount()
    
    CoreFarm._statusLabel = { Set = function() ui:refresh() end }
    CoreFarm._menuLabels, CoreFarm._menuValues = nil, nil
    ui:refresh()
end

function S.v3Defaults()
    return {schema=3, autoStart=true, autoQueue=true, queueMode="Unranked", chests=true, laps=2,
        chestTypes=table.clone(CHEST_TYPE_OPTIONS), church=true, hunt=false, aura=false, mobs={All=true},
        mine=false, mines=false, ores={Gold=true,Iron=true}, collect=false, corpses=false, bounties=false,
        loot={Shards=true,Gear=true,Valuables=true,Ores=true,Scrap=true,Consumables=true},
        ammoBuy=false, ammo={Pistol=true,Rifle=true,Special=true,Shotgun=true}, stock=true,
        executeOnTeleport=true, reserveCoins=0, spendLimit=5000, auraRange=24, speed=700}
end

function S.v3CleanConfig(raw)
    local cfg=S.v3Defaults()
    if type(raw)~="table" then return cfg end
    for key,value in pairs(cfg) do
        if type(value)=="boolean" and type(raw[key])=="boolean" then cfg[key]=raw[key] end
    end
    for key,limits in pairs({laps={1,10},reserveCoins={0,100000000},spendLimit={0,100000000},auraRange={6,60},speed={100,1500}}) do
        local n=tonumber(raw[key]);if n and n==n and math.abs(n)<math.huge then cfg[key]=math.clamp(math.floor(n),limits[1],limits[2]) end
    end
    cfg.queueMode=raw.queueMode=="Ranked" and "Ranked" or "Unranked"
    for _,key in ipairs({"mobs","ores","loot","ammo"}) do
        if type(raw[key])=="table" then
            cfg[key]={};local count=0
            for name,on in pairs(raw[key]) do
                if type(name)=="string" and #name<=80 and on==true and count<100 then cfg[key][name]=true;count+=1 end
            end
        end
    end
    if type(raw.chestTypes)=="table" then
        local labels=S.chestLabelsFromSaved(raw.chestTypes)
        if #labels>0 then cfg.chestTypes=labels end
    end
    return cfg
end

function S.v3SaveConfig()
    if not S._v3 then return false end
    local cfg=S._v3
    cfg.laps, cfg.queueMode=CoreFarm.rescans,CoreFarm.mode
    cfg.chestTypes=S.chestLabelsFromSaved(CoreFarm.chestTypes)
    if typeof(getgenv)=="function" then getgenv().NATURALLY_ALKALINE_SETTINGS=cfg end
    if typeof(writefile)~="function" then S._configStatus="Session only · file API unavailable";return false end
    local ok,err=pcall(function()
        local json=game:GetService("HttpService"):JSONEncode(cfg)
        writefile("naturally_alkaline_v3.json",json)
    end)
    S._configStatus=ok and "Saved · loads on execution" or "Save failed"
    if not ok then S.interactionNote("config",tostring(err):sub(1,120)) end
    return ok
end

function S.v3LoadConfig()
    local raw
    if typeof(readfile)=="function" then
        local ok,result=pcall(function()return game:GetService("HttpService"):JSONDecode(readfile("naturally_alkaline_v3.json"))end)
        if ok and type(result)=="table" then raw=result end
    end
    if not raw and typeof(getgenv)=="function" then raw=getgenv().NATURALLY_ALKALINE_SETTINGS end
    S._v3=S.v3CleanConfig(raw)
    S._configStatus=raw and "Settings loaded" or "Defaults · save to keep changes"
    CoreFarm.mode,CoreFarm.partySize,CoreFarm.rescans=S._v3.queueMode,1,S._v3.laps
    CoreFarm.chestTypes=S._v3.chestTypes;CoreFarm._chestPick=table.clone(CoreFarm.chestTypes)
    CoreFarm.enabled=S._v3.autoStart;CoreFarm._userStop=not S._v3.autoStart
    CoreFarm.openAll=S._v3.autoStart and S._v3.chests;CoreFarm._queuedRun=CoreFarm.openAll
    S._finishSettings.autoChurch=S._v3.church
    Autofarm.tweenSpeed=S._v3.speed
end

function S.v3QueueLoader()
    if not S._v3 or not S._v3.executeOnTeleport or S._v3LoaderQueued then return end
    local queue=queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if typeof(queue)~="function" then S._queueStatus="Auto execute unsupported by executor";return end
    local loader=[[local run=true
if type(readfile)=="function" then
    pcall(function()
        local cfg=game:GetService("HttpService"):JSONDecode(readfile("naturally_alkaline_v3.json"))
        if type(cfg)=="table" and cfg.executeOnTeleport==false then run=false end
    end)
end
if run then loadstring(game:HttpGet("https://raw.githubusercontent.com/naturallyalkaline/autofarm-everything/main/main.lua"))() end]]
    local ok=pcall(queue,loader)
    S._v3LoaderQueued=ok;S._queueStatus=ok and "Auto execute queued" or "Auto execute failed"
end

function S.v3Set(key,value)
    local cfg=S._v3;if not cfg then return end
    cfg[key]=value
    if key=="queueMode" then CoreFarm.mode=value end
    if key=="laps" then CoreFarm.rescans=value end
    if key=="church" then S._finishSettings.autoChurch=value end
    if key=="speed" then Autofarm.tweenSpeed=value end
    if key=="chestTypes" then
        CoreFarm.chestTypes,CoreFarm._chestPick=value,value;Autofarm.chestTypes=value
        S.trySetControlsFlag("dtec_core_chest_types",value)
    end
    -- A movement setting change cancels the old owner before the next scheduler tick.
    if key=="chests" then
        S.v3CancelActivity();S.stopCoreChestRun()
        if S._v3Running then S.v3Start() end
    elseif key=="hunt" or key=="mine" or key=="mines" or key=="ammoBuy" or key=="collect" then
        S.v3CancelActivity()
    end
    S.v3SaveConfig();S.v3QueueLoader()
    if S._farmUi then S._farmUi:refresh() end
end

function S.v3Start()
    if S._unloaded then return end
    S._v3Running=true;S._v3Completed=false;CoreFarm._userStop=false;CoreFarm.enabled=true
    CoreFarm.openAll=S._v3.chests;CoreFarm._queuedRun=S._v3.chests
    CoreFarm.mode,CoreFarm.partySize=S._v3.queueMode,1
    S.trySetControlsFlag("dtec_core_open",true)
    S._v3Generation=(S._v3Generation or 0)+1
    S.v3QueueLoader();S.coreSetStatus("Starting")
end

function S.v3CancelActivity()
    S._v3Generation=(S._v3Generation or 0)+1
    local job=S._activity
    if job then job.cancelled=true;S.v3EndJob(job,S._v3Running and not CoreFarm._userStop and not S._unloaded) end
end

function S.v3Park(message)
    S.v3CancelActivity()
    S._v3Running=false;S._v3Completed=true
    S.stopCoreChestRun()
    pcall(S.forceReleaseFarmCharacter)
    local root=S.getRoot();local cf=S.getDrillReturnCFrame() or S._v3SafeCFrame
    if root and cf then root.CFrame=cf;root.AssemblyLinearVelocity=Vector3.zero end
    S.coreSetStatus(message or "Stopped")
end

function S.v3Token(text)
    return tostring(text or ""):lower():gsub("[^%w]","")
end

function S.v3AliveMob(mob)
    if not mob or not mob.Parent or not mob:IsA("Model") or Players:GetPlayerFromCharacter(mob) then return false end
    local faction=S.v3Token(mob:GetAttribute("NpcFaction"))
    if faction:find("friendly",1,true) or faction=="villager" then return false end
    if mob==LocalPlayer.Character or mob:GetAttribute("NpcFaction")=="FriendlyCompanion"
        or mob:GetAttribute("Friendly")==true or mob:GetAttribute("Hostile")==false then return false end
    local h=mob:FindFirstChildOfClass("Humanoid")
    return h~=nil and h.Health>0
end

function S.v3MobName(mob)
    return tostring(mob:GetAttribute("RealName") or mob:GetAttribute("NpcType") or mob.Name)
end

function S.v3SelectedMob(mob)
    local selected=S._v3.mobs
    return selected.All==true or selected[S.v3MobName(mob)]==true
end

function S.v3OreType(ore)
    local value=ore:GetAttribute("SessionOreType") or ore:GetAttribute("SessionOreModel") or ore:GetAttribute("Ore_Model") or ore.Name
    local token=S.v3Token(value)
    for _,name in ipairs({"HeartGem","Emerald","Diamond","Ruby","Gold","Iron","Copper","Coal"}) do
        if token:find(S.v3Token(name),1,true) then return name end
    end
    return tostring(value)
end

function S.v3OreHealth(ore)
    local h=ore and ore:FindFirstChild("Health")
    if h and (h:IsA("NumberValue") or h:IsA("IntValue")) then return tonumber(h.Value) end
    return ore and tonumber(ore:GetAttribute("Health"))
end

function S.v3OreAlive(ore)
    if not ore or not ore.Parent or ore:GetAttribute("OreLoaded")==false then return false end
    local hp=S.v3OreHealth(ore);if hp then return hp>0 end
    local rock=ore:FindFirstChild("Rock") or ore:FindFirstChild("Ore")
    return rock~=nil and rock:IsA("BasePart") and rock.Transparency<0.98
end

function S.v3IndexRecord(inst,index)
    if not inst or not inst.Parent or not inst:IsDescendantOf(Workspace) then return end
    local node=inst
    if inst:IsA("Humanoid") then node=inst.Parent end
    if CollectionService:HasTag(inst,"NpcManager") and not inst:IsA("Model") then node=inst:FindFirstAncestorOfClass("Model") end
    if not node then return end
    if node:IsA("Model") then
        local parent=node.Parent
        local npcParent=parent and (parent.Name=="Npc" or parent.Name=="NPC" or parent.Name=="Mobs")
        if (npcParent or CollectionService:HasTag(node,"NpcManager") or CollectionService:HasTag(inst,"NpcManager"))
            and S.v3AliveMob(node) then index.mobs[node]=true end
        if node.Name=="Mineshaft" or node.Name=="VoidMineshaft" or (node.Name=="Cave" and node:FindFirstChild("Gate_Cave"))
            or CollectionService:HasTag(node,"Mineshaft") then index.mines[node]=true end
        local n=node.Name
        if n=="MinerTown" or n=="BountyCamp" or n=="TradingCampTutorial" or n:match("^CampTier")
            or n:find("Fortress",1,true) or CollectionService:HasTag(node,"Village") then index.villages[node]=true end
    end
    if node:IsA("Model") or node:IsA("BasePart") then
        if node:GetAttribute("SessionOreType") or node:GetAttribute("SessionOreModel") or node:GetAttribute("Ore_Model")
            or CollectionService:HasTag(node,"Ore")
            or ((node.Name:match("^OreNode") or node.Name:match("^WormNode")) and node:FindFirstChild("Health")) then index.ores[node]=true end
        local items=Workspace:FindFirstChild("Items")
        local item=node
        while item.Parent and item.Parent~=items and item.Parent~=Workspace and item.Parent:IsA("Model") do item=item.Parent end
        if items and item.Parent==items then index.loot[item]=true end
        if CollectionService:HasTag(node,"ShopItem") then index.stock[node]=true end
        if CollectionService:HasTag(node,"Corpse") or CollectionService:HasTag(node,"Bounty") then index.loot[node]=true end
    end
    if node:IsA("BasePart") and CollectionService:HasTag(node,"BuyPart") then index.buy[node]=true end
end

function S.v3EnsureIndex()
    if S._v3Index then return S._v3Index end
    local index={queue={},head=1,tail=0,pending=setmetatable({},{__mode="k"}),running=false,ready=false}
    for _,key in ipairs({"mobs","ores","mines","villages","stock","loot","buy"}) do index[key]=setmetatable({},{__mode="k"}) end
    S._v3Index=index
    local enqueue
    enqueue=function(inst,expand)
        if S._unloaded or not inst or index.pending[inst] then return end
        index.pending[inst]=true;index.tail+=1;index.queue[index.tail]={inst,expand}
        if index.running then return end
        index.running=true
        task.defer(function()
            while not S._unloaded and index.head<=index.tail do
                local began,count=os.clock(),0
                repeat
                    local entry=index.queue[index.head];index.queue[index.head]=nil;index.head+=1
                    local obj=entry[1];index.pending[obj]=nil
                    if obj==Workspace or (obj.Parent and obj:IsDescendantOf(Workspace)) then
                        pcall(S.v3IndexRecord,obj,index)
                        local parent=obj.Parent
                        if parent and parent~=Workspace then pcall(S.v3IndexRecord,parent,index) end
                        if entry[2] and not (obj:IsA("Model") and Players:GetPlayerFromCharacter(obj))
                            and (obj==Workspace or obj:IsA("Model") or obj:IsA("Folder")) then
                            for _,child in ipairs(obj:GetChildren()) do
                                if child:IsA("Model") or child:IsA("Folder") or child:IsA("Humanoid")
                                    or (child:IsA("BasePart") and (obj.Name=="Items" or child.Name:find("Ore",1,true)
                                    or CollectionService:HasTag(child,"Ore") or CollectionService:HasTag(child,"BuyPart"))) then enqueue(child,true) end
                            end
                        end
                    end
                    count+=1
                until index.head>index.tail or count>=40 or os.clock()-began>=0.002
                if index.head<=index.tail then task.wait(0.04) end
            end
            index.running=false;index.ready=true
            if index.head>index.tail then index.queue={};index.head=1;index.tail=0 end
        end)
    end
    State.connections.v3Added=Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Model") or obj:IsA("Humanoid") or obj:IsA("Folder") or obj:IsA("ProximityPrompt")
            or (obj:IsA("BasePart") and obj.Parent and obj.Parent.Name=="Items") then enqueue(obj,false) end
    end)
    State.connections.v3Removed=Workspace.DescendantRemoving:Connect(function(obj)
        for _,key in ipairs({"mobs","ores","mines","villages","stock","loot","buy"}) do index[key][obj]=nil end
    end)
    for _,tag in ipairs({"NpcManager","Ore","Mineshaft","Village","ShopItem","Corpse","Bounty","BuyPart"}) do
        State.connections["v3Tag"..tag]=CollectionService:GetInstanceAddedSignal(tag):Connect(function(obj)
            if tag=="ShopItem" and S._v3PurchaseSent then S._v3PurchaseSent[obj]=nil end
            enqueue(obj,false)
        end)
        for _,obj in ipairs(CollectionService:GetTagged(tag)) do enqueue(obj,false) end
    end
    enqueue(Workspace,true)
    return index
end

function S.v3JobActive(job)
    return job~=nil and S._activity==job and not job.cancelled and not S._unloaded and not CoreFarm._userStop
        and job.generation==(S._v3Generation or 0) and job.character==LocalPlayer.Character
        and S.getRoot()==job.root and job.root.Parent~=nil and (not S.getHumanoid() or S.getHumanoid().Health>0)
end

function S.v3BeginJob(kind,target)
    if S._activity or S._v3AuraBusy or S._chestInteraction or CoreFarm._leaving or S._unloaded or CoreFarm._userStop then return nil end
    local root=S.getRoot();if not root then return nil end
    local job={kind=kind,target=target,root=root,character=LocalPlayer.Character,generation=S._v3Generation or 0,
        saved=root.CFrame,noclip=State.noclip,humanoid=S.getHumanoid()}
    job.platform=job.humanoid and job.humanoid.PlatformStand
    root.Anchored=false
    S._activity=job
    job.hold=root.CFrame
    S.disconnectAll("v3Hold")
    State.connections.v3Hold=RunService.Heartbeat:Connect(function()
        if S.v3JobActive(job) and job.hold then
            if job.allowTransition and (root.Position-job.hold.Position).Magnitude>20 then job.hold=nil;return end
            root.CFrame=job.hold;root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
        end
    end)
    S.lockAutofarmHover(false);S.ensureAutofarmAntiFall(false)
    if not State.noclip then S.setNoclip(true) end
    if job.humanoid then job.humanoid.Sit=false;job.humanoid.PlatformStand=true end
    return job
end

function S.v3Move(job,pos)
    if not S.v3JobActive(job) or typeof(pos)~="Vector3" or pos.X~=pos.X or pos.Y~=pos.Y or pos.Z~=pos.Z then return false end
    job.hold=nil
    local delta=pos-job.root.Position
    local distance=delta.Magnitude
    local deadline=os.clock()+math.min(14,distance/math.max(100,S._v3.speed)+3)
    while S.v3JobActive(job) and distance>3 and os.clock()<deadline do
        local step=math.min(distance,math.max(100,S._v3.speed)*0.05)
        local nextPos=job.root.Position+delta.Unit*step
        job.root.CFrame=S.safeLookAt(nextPos,pos) or CFrame.new(nextPos)
        job.root.AssemblyLinearVelocity=Vector3.zero;job.root.AssemblyAngularVelocity=Vector3.zero
        task.wait(0.05)
        delta=pos-job.root.Position;distance=delta.Magnitude
    end
    if S.v3JobActive(job) then job.hold=job.root.CFrame end
    return S.v3JobActive(job) and distance<=5
end

function S.v3EndJob(job,resume)
    if S._activity~=job then return end
    S._activity=nil
    S.disconnectAll("v3Hold")
    S.clearDragTarget();S.clearMineHoldPin();Autofarm._gatePinY=nil
    if job.prompt then pcall(function()job.prompt:InputHoldEnd()end);job.prompt=nil end
    if job.character~=LocalPlayer.Character or job.root~=S.getRoot() then return end
    if job.root.Parent then
        job.root.AssemblyLinearVelocity=Vector3.zero;job.root.AssemblyAngularVelocity=Vector3.zero
        if resume and not S._unloaded and not CoreFarm._userStop and Autofarm.enabled then
            S.setAutofarmPose(Autofarm.distance or 0)
            S.ensureAutofarmAntiFall(true);S.lockAutofarmHover(true)
        elseif not CoreFarm._teleportPending then
            job.root.CFrame=S.getDrillReturnCFrame() or job.saved
        end
    end
    if job.humanoid and job.humanoid.Parent then job.humanoid.PlatformStand=(resume and Autofarm.enabled) or job.platform or false end
    if not job.noclip and not Autofarm.enabled then S.setNoclip(false) end
end

function S.v3Tool(kind)
    local best,score=nil,-math.huge
    for _,tool in ipairs(S.hotbarTools()) do
        local cat=S.v3Token(S.itemCategoryKey(tool));local n=S.v3Token(tool.Name)
        local pick=cat=="pickaxe" or n:find("pickaxe",1,true)~=nil
        local sword=cat=="sword" or n:find("sword",1,true)~=nil
        local gun=cat=="gun" or cat=="primaryweapon" or cat=="secondaryweapon" or tool:GetAttribute("Ammo")~=nil
        local ammo=tonumber(tool:GetAttribute("Ammo"))
        if (kind=="mine" and pick) or (kind=="combat" and (sword or (gun and (ammo==nil or ammo>0)))) then
            local damage=(kind=="mine" and S.getWorldGearScore(tool) or S.getToolDamage(tool))
            if damage>score then best,score=tool,damage end
        end
    end
    return best
end

function S.v3Equip(tool,job)
    if not tool or not Services.ToolService or (job and not S.v3JobActive(job)) then return false end
    if tool.Parent==LocalPlayer.Character then return true end
    local ok=pcall(function()Services.ToolService:EquipTool(tool)end)
    if not ok then return false end
    local deadline=os.clock()+0.9
    while not S._unloaded and (not job or S.v3JobActive(job)) and os.clock()<deadline do
        if tool.Parent==LocalPlayer.Character then return true end
        task.wait(0.06)
    end
    return false
end

function S.v3Attack(targets,job)
    if #targets==0 or not Services.ToolService or not Services.ToolService.Update then return false end
    if S._chestInteraction or CoreFarm._leaving or (S._activity and S._activity~=job) then return false end
    local tool=S.v3Tool("combat");if not S.v3Equip(tool,job) then return false end
    if (job and not S.v3JobActive(job)) or S._chestInteraction or CoreFarm._leaving or (S._activity and S._activity~=job) then return false end
    local now=os.clock();local delay=math.clamp(tonumber(tool:GetAttribute("AttackCooldown")) or tonumber(tool:GetAttribute("Cooldown")) or 0.5,0.2,3)
    if now<(S._v3AttackAt or 0) then return false end
    S._v3AttackAt=now+delay
    local name=S.v3Token(tool.Name);local category=S.v3Token(S.itemCategoryKey(tool));local gun=tool:GetAttribute("Ammo")~=nil or category=="gun" or category=="primaryweapon" or category=="secondaryweapon"
    local valid={};local root=S.getRoot();if not root then return false end
    local range=gun and 100 or S._v3.auraRange
    for _,mob in ipairs(targets) do
        local pos=S.getInstancePosition(mob)
        if #valid<8 and S.v3AliveMob(mob) and S.v3SelectedMob(mob) and pos and (pos-root.Position).Magnitude<=range then valid[#valid+1]=mob end
    end
    if #valid==0 then return false end
    return pcall(function()
        if not gun then Services.ToolService.Update:Fire({"Swing",valid});return end
        local mob=valid[1];local part=mob.PrimaryPart or mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart",true)
        if not part then return end
        local start=root.Position+Vector3.new(0,1.5,0);local finish=part.Position
        if name:find("shotgun",1,true) then Services.ToolService.Update:Fire({"Shoot",{{Start=start,EndPos=finish,HeadShot=false}}})
        else Services.ToolService.Update:Fire({"Shoot",part,false,start,finish,(finish-start).Magnitude}) end
    end)
end

function S.v3Hunt(job,mob)
    local humanoid=mob:FindFirstChildOfClass("Humanoid");if not humanoid then return end
    local hp,lastChange=humanoid.Health,os.clock();local deadline=os.clock()+35
    while S.v3JobActive(job) and S._v3.hunt and S.v3AliveMob(mob) and os.clock()<deadline do
        local pos=S.getInstancePosition(mob);if not pos or not S.v3Move(job,pos+Vector3.new(0,5,0)) then break end
        S.coreSetStatus("Hunt · "..S.v3MobName(mob))
        if not S.v3Tool("combat") then S.coreSetStatus("Hunt · equip a sword or loaded gun");break end
        S.v3Attack({mob},job);task.wait(0.2)
        if humanoid.Health~=hp then hp,lastChange=humanoid.Health,os.clock() end
        if os.clock()-lastChange>8 then break end
    end
    if humanoid.Health<=0 then S._v3Kills=(S._v3Kills or 0)+1 end
end

function S.v3MineOre(job,ore)
    if not Services.ToolService or not Services.ToolService.Update then S.coreSetStatus("Mining · waiting for tool service");return end
    if not S.v3OreAlive(ore) or not S._v3.ores[S.v3OreType(ore)] then return end
    local pos=S.getInstancePosition(ore);if not pos then return end
    if not S.v3Move(job,pos+Vector3.new(0,3,0)) then return end
    local tool=S.v3Tool("mine");if not S.v3Equip(tool,job) then S.coreSetStatus("Mining · pickaxe required");return end
    local hp,lastChange=S.v3OreHealth(ore),os.clock();local deadline=os.clock()+30
    while S.v3JobActive(job) and S._v3.mine and S.v3OreAlive(ore) and os.clock()<deadline do
        S.coreSetStatus("Mining · "..S.v3OreType(ore))
        if tool.Parent~=job.character and not S.v3Equip(tool,job) then break end
        Services.ToolService.Update:Fire({"Swing",{ore}});task.wait(0.5)
        local current=S.v3OreHealth(ore)
        if current~=hp then hp,lastChange=current,os.clock() end
        if os.clock()-lastChange>8 then break end
    end
    if S.v3JobActive(job) and not S.v3OreAlive(ore) then
        S._v3Mined=(S._v3Mined or 0)+1
        task.wait(0.35)
        S.v3CollectNearby(job,pos,32,true)
    end
end

function S.v3MineVisit(job,mine)
    local hit=mine:FindFirstChild("EntranceHitbox",true)
    if not hit or not hit:IsA("BasePart") then S.coreSetStatus("Mine · entrance not loaded");return end
    if not S.v3Move(job,hit.Position+hit.CFrame.LookVector*6) then return end
    pcall(S.requestStreamAround,hit.Position,1)
    if not S.v3JobActive(job) then return end
    local entered=false;local before=job.root.Position
    job.allowTransition=true
    for _,prompt in ipairs(S.collectProximityPrompts(mine)) do
        local text=S.v3Token(prompt.ActionText)
        if prompt.Enabled and text:find("enter",1,true) and not text:find("exit",1,true) then
            local pos=S.getPromptWorldPosition(prompt)
            if pos and S.v3Move(job,pos+Vector3.new(0,2,0)) then
                local deadline=os.clock()+math.min(30,(tonumber(prompt.HoldDuration) or 0)+0.3)
                job.prompt=prompt
                prompt:InputHoldBegin()
                while S.v3JobActive(job) and os.clock()<deadline do task.wait(0.08) end
                pcall(function()prompt:InputHoldEnd()end)
                job.prompt=nil
            end
            break
        end
    end
    job.hold=nil
    for step=0,12 do
        if not S.v3JobActive(job) then return end
        if (job.root.Position-before).Magnitude>25 then entered=true;break end
        local pos=hit.Position+hit.CFrame.LookVector*(6-step)
        job.root.CFrame=CFrame.new(pos);job.root.AssemblyLinearVelocity=Vector3.zero
        task.wait(0.1)
    end
    if not S.v3JobActive(job) then return end
    pcall(S.requestStreamAround,job.root.Position,1)
    job.allowTransition=false
    job.hold=job.root.CFrame
    local index=S.v3EnsureIndex();local origin=job.root.Position
    local attempted={};local deadline=os.clock()+90;local quiet=0
    while S.v3JobActive(job) and S._v3.mines and os.clock()<deadline do
        local best,distance=nil,math.huge
        for ore in pairs(index.ores) do
            local pos=S.getInstancePosition(ore)
            if not attempted[ore] and S.v3OreAlive(ore) and S._v3.ores[S.v3OreType(ore)] and pos
                and (ore:IsDescendantOf(mine) or (entered and (pos-origin).Magnitude<1200)) then
                local d=(pos-job.root.Position).Magnitude;if d<distance then best,distance=ore,d end
            end
        end
        if not best then
            quiet+=1
            if quiet>=4 then break end
            pcall(S.requestStreamAround,origin-hit.CFrame.LookVector*(quiet*100),0.8)
            task.wait(0.4)
        else
            quiet=0
            attempted[best]=true;S.v3MineOre(job,best)
        end
    end
    -- Job cleanup returns to the farm route; no stale interior pin is retained.
end

function S.v3LootKind(item)
    if not item or not item.Parent or S.isHardExcluded(item) or S.isDiscardedLoot(item)
        or CollectionService:HasTag(item,"ShopItem") then return nil end
    local name=S.v3Token(item.Name);local category=S.v3Token(S.itemCategoryKey(item))
    if name:find("ammo",1,true) or category=="ammo" or category=="ammunition" then return nil end
    if item:GetAttribute("Bounty")==true or (tonumber(item:GetAttribute("BountyValue")) or 0)>0 or CollectionService:HasTag(item,"Bounty") then return "Bounties" end
    if category=="corpse" or name:find("corpse",1,true) or CollectionService:HasTag(item,"Corpse") then return "Corpses" end
    if category=="ore" or category=="bar" then return "Ores" end
    local kind=S.coreKeepKind(item)
    if kind=="Shard" then return "Shards" end
    if kind=="Armor" or kind=="Tool" then return "Gear" end
    if kind=="Valuable" then return "Valuables" end
    if category=="ore" or category=="bar" or name:find("ore",1,true) then return "Ores" end
    if category=="consumable" or name:find("potion",1,true) or name:find("medkit",1,true) then return "Consumables" end
    if category=="scrap" or name:find("scrap",1,true) then return "Scrap" end
    return "Other"
end

function S.v3SackPickup(job,item)
    local before,capacity=S.coreSackCount()
    if before==nil then S.coreSetStatus("Collection · waiting for sack counter");return false end
    if capacity and before>=capacity then S.coreSetStatus("Sack full · "..before.." / "..capacity);return false end
    local bag
    for _,tool in ipairs(S.hotbarTools()) do if S.isItemBagTool(tool) then bag=tool;break end end
    if not S.v3Equip(bag,job) or not S.v3JobActive(job) or not item.Parent then return false end
    for _=1,2 do
        if not S.v3JobActive(job) or not item.Parent then return false end
        Services.ToolService.Update:Fire({"Pickup",item})
        local deadline=os.clock()+1.1
        while S.v3JobActive(job) and os.clock()<deadline do
            local count=S.coreSackCount();if count and count>before then return true end
            task.wait(0.1)
        end
    end
    return false
end

function S.v3CollectOne(job,item)
    local kind=S.v3LootKind(item);if not kind then return false end
    local pos=S.getItemPosition(item) or S.getInstancePosition(item)
    if not pos or not S.v3Move(job,pos+Vector3.new(0,3,0)) then return false end
    if kind=="Gear" or kind=="Shards" then
        local keepKind,tier=S.coreKeepKind(item)
        local entry={item=item,name=item.Name,kind=keepKind,tier=tier,pos=pos,keys=S.coreItemKeys(item)}
        if not entry.kind then return false end
        -- Reuse the tested armor/hotbar verification without creating a church finish.
        return S.coreCollectKeptItem(entry,job)
    end
    return S.v3SackPickup(job,item)
end

function S.v3CollectNearby(job,pos,range,oresOnly)
    local current,capacity=S.coreSackCount();if current and capacity and current>=capacity then return end
    local index=S.v3EnsureIndex();local list={}
    for item in pairs(index.loot) do
        local point=S.getItemPosition(item);local kind=S.v3LootKind(item)
        if kind and point and (point-pos).Magnitude<=range and (not oresOnly or kind=="Ores") then list[#list+1]=item end
    end
    for i=1,math.min(16,#list) do if not S.v3JobActive(job) then return end;S.v3CollectOne(job,list[i]);task.wait(0.15) end
end

function S.v3AmmoType(item)
    local name=S.v3Token(item:GetAttribute("AmmoType") or item.Name)
    if name:find("revolver",1,true) and name:find("ammo",1,true) then return "Pistol" end
    if not name:find("ammo",1,true) and not name:find("shell",1,true) and item:GetAttribute("AmmoType")==nil then return nil end
    for _,kind in ipairs({"Pistol","Rifle","Special","Shotgun"}) do if name:find(kind:lower(),1,true) then return kind end end
    return nil
end

function S.v3StockQuality(item)
    local n=S.v3Token(tostring(item:GetAttribute("DisplayName") or item.Name)..tostring(item:GetAttribute("Rarity") or ""))
    if n:find("blackhole",1,true) then return 3 end
    if n:find("phoenix",1,true) or n:find("mythic",1,true) or n:find("king",1,true) then return 2 end
    if n:find("void",1,true) or n:find("legendary",1,true) then return 1 end
    return 0
end

function S.v3StockRows()
    local rows={};local index=S.v3EnsureIndex()
    S.v3RestockText()
    S._v3StockSeen=S._v3StockSeen or setmetatable({},{__mode="k"})
    for item in pairs(index.stock) do
        if item.Parent and CollectionService:HasTag(item,"ShopItem") and item:IsDescendantOf(Workspace) then
            local quality=S.v3StockQuality(item)
            local place=item:FindFirstAncestor("Shop")
            local village=item.Parent
            while village and village~=Workspace and not index.villages[village] do village=village.Parent end
            local location=village and village~=Workspace and village.Name or (place and place.Parent and place.Parent.Name) or "Village"
            rows[#rows+1]={item=item,name=tostring(item:GetAttribute("DisplayName") or item.Name),location=location,quality=quality}
            if S._v3.stock and quality>=2 and S._v3StockSeen[item]~=(tostring(item.Name)..tostring(S._v3RestockEnd or "")) then
                S._v3StockSeen[item]=tostring(item.Name)..tostring(S._v3RestockEnd or "");S.notify("Village stock",location.." · "..rows[#rows].name,7)
            end
        end
    end
    table.sort(rows,function(a,b)if a.quality~=b.quality then return a.quality>b.quality end;return a.location..a.name<b.location..b.name end)
    return rows
end

function S.v3BuyPart(item)
    local pos=S.getItemPosition(item);if not pos then return nil end
    local best,distance=nil,120
    for part in pairs(S.v3EnsureIndex().buy) do
        if part.Parent and part:IsDescendantOf(Workspace) then
            local d=(part.Position-pos).Magnitude
            if d<distance then best,distance=part,d end
        end
    end
    return best
end

function S.v3Wallet()
    for _,name in ipairs({"Coins","Money","Cash"}) do local n=tonumber(LocalPlayer:GetAttribute(name));if n then return n end end
    if Services.CurrencyService and os.clock()>=(S._v3WalletAt or 0) then
        S._v3WalletAt=os.clock()+1.5
        local ok,reply=pcall(function()return Services.CurrencyService:GetCurrency()end)
        if ok then
            local done,value=S.v3Await(reply,1.2,S._activity)
            if done and tonumber(value) then S._v3Wallet=tonumber(value);S._v3WalletSeen=os.clock() end
        end
    end
    if S._v3WalletSeen and os.clock()-S._v3WalletSeen<4 then return S._v3Wallet end
    return nil
end

function S.v3AmmoCount(kind)
    for _,name in ipairs({kind.."Ammo",kind.."Ammunition","Ammo"..kind}) do
        local n=tonumber(LocalPlayer:GetAttribute(name));if n then return n end
    end
    local total=0;local found=false
    for _,tool in ipairs(S.hotbarTools()) do
        if S.v3AmmoType(tool)==kind then total+=tonumber(tool:GetAttribute("ReserveAmmo")) or tonumber(tool:GetAttribute("Amount")) or tonumber(tool:GetAttribute("Count")) or tonumber(tool:GetAttribute("Ammo")) or 1;found=true end
    end
    return found and total or nil
end

function S.v3BuyAmmo(job,item)
    local kind=S.v3AmmoType(item);if not kind or not S._v3.ammo[kind] or not S._v3.ammoBuy then return end
    local buy=S.v3BuyPart(item);if not buy then S.coreSetStatus("Ammo · register not loaded");return end
    local price=tonumber(item:GetAttribute("Price")) or tonumber(item:GetAttribute("Cost")) or tonumber(item:GetAttribute("Value"))
    local wallet=S.v3Wallet();local spent=S._v3Spent or 0
    if not price or price<0 or not wallet then S.coreSetStatus("Ammo · waiting for price / balance");return end
    if wallet-price<S._v3.reserveCoins or spent+price>S._v3.spendLimit then S.coreSetStatus("Ammo · spending limit / coin reserve");return end
    local pos=S.getItemPosition(item);if not pos or not S.v3Move(job,pos+Vector3.new(0,3,0)) then return end
    if not Services.DragService or not Services.ShopService then S.connectServicesAsync();S.coreSetStatus("Ammo · waiting for shop / drag service");return end
    local knit=S.getKnit();local drag
    if knit then pcall(function()drag=knit.GetController("DragController")end) end
    if not drag then return end
    local beforeAmmo=S.v3AmmoCount(kind)
    local ok,result=pcall(function()
        Services.ToolService:UnequipTool()
        Services.DragService:Request(item)
        if drag.TryLockTarget then drag:TryLockTarget(item) end
        local deadline=os.clock()+1.4
        while S.v3JobActive(job) and os.clock()<deadline and drag.LockedTarget~=item do task.wait(0.08) end
        if not S.v3JobActive(job) or drag.LockedTarget~=item then return false end
        if not S.v3Move(job,buy.Position+Vector3.new(0,4,3)) then return false end
        local cf=buy.CFrame*CFrame.new(0,buy.Size.Y*0.5+0.7,0)
        if not drag.MainAttach then return false end
        drag.MainAttach.WorldCFrame=cf
        if item:IsA("Model") then item:PivotTo(cf) elseif item:IsA("BasePart") then item.CFrame=cf end
        task.wait(0.2)
        if not S.v3JobActive(job) then return false end
        Services.DragService:Weld(item)
        task.wait(0.3)
        if not S.v3JobActive(job) then return false end
        local point=S.getItemPosition(item)
        if not point or (point-buy.Position).Magnitude>10 then return false end
        if drag.ReleaseLockedTarget then drag:ReleaseLockedTarget() end
        Services.DragService:Cancel()
        if not S.v3JobActive(job) then return false end
        -- Exactly one purchase request. A timeout never automatically repeats a debit.
        S._v3PurchaseSent=S._v3PurchaseSent or setmetatable({},{__mode="k"})
        S._v3PurchaseSent[item]=true
        S._v3Spent=spent+price
        local reply=Services.ShopService:Buy(buy)
        local acknowledged,value=S.v3Await(reply,2,job)
        local purchaseOK=acknowledged and value==true
        local deadline=os.clock()+3
        while S.v3JobActive(job) and os.clock()<deadline do
            local afterAmmo=S.v3AmmoCount(kind)
            if afterAmmo and beforeAmmo and afterAmmo>beforeAmmo then return true end
            local money=S.v3Wallet()
            if item.Parent and (purchaseOK or not CollectionService:HasTag(item,"ShopItem")) then
                if purchaseOK or (money and money<wallet) then
                    local claimed,claimReply=S.v3Await(Services.InteractionService:Interact(item),1,job)
                    if claimed and claimReply==true and S.v3JobActive(job) then return true end
                    local claimUntil=os.clock()+2
                    while S.v3JobActive(job) and os.clock()<claimUntil do
                        local count=S.v3AmmoCount(kind)
                        if count and (beforeAmmo==nil or count>beforeAmmo) then return true end
                        task.wait(0.1)
                    end
                    S.coreSetStatus("Ammo purchased · claim not confirmed");return false
                end
            end
            task.wait(0.1)
        end
        S.coreSetStatus("Ammo · purchase not confirmed; no automatic rebuy")
        return false
    end)
    pcall(function()if drag.ReleaseLockedTarget then drag:ReleaseLockedTarget() end;Services.DragService:Cancel()end)
    if ok and result then S._v3AmmoBought=(S._v3AmmoBought or 0)+1 end
    if not ok then S.interactionNote("ammo purchase",tostring(result):sub(1,140)) end
end

function S.v3ChooseJob()
    local index=S.v3EnsureIndex();local root=S.getRoot();if not root then return nil end
    S._v3Visited=S._v3Visited or setmetatable({},{__mode="k"})
    local candidates={}
    local function add(kind,item,delay)
        if not item.Parent or os.clock()<(S._v3Visited[item] or 0) then return end
        local pos=S.getInstancePosition(item);if not pos then return end
        if (pos-root.Position).Magnitude>8000 then return end
        candidates[#candidates+1]={kind=kind,target=item,distance=(pos-root.Position).Magnitude,delay=delay,
            priority=kind=="collect" and (S.v3LootKind(item)=="Shards" and 2 or S.v3LootKind(item)=="Gear" and 1 or 0) or 0}
    end
    if S._v3.hunt then for mob in pairs(index.mobs) do if S.v3AliveMob(mob) and S.v3SelectedMob(mob) then add("hunt",mob,12) end end end
    if S._v3.mine then
        for ore in pairs(index.ores) do
            local inside=false;local ancestor=ore.Parent
            while ancestor and ancestor~=Workspace do
                if index.mines[ancestor] then inside=true;break end
                ancestor=ancestor.Parent
            end
            if not inside and S.v3OreAlive(ore) and S._v3.ores[S.v3OreType(ore)] then add("mine",ore,20) end
        end
        if S._v3.mines then for mine in pairs(index.mines) do add("mines",mine,120) end end
    end
    if S._v3.ammoBuy then
        for item in pairs(index.stock) do
            local kind=S.v3AmmoType(item)
            if CollectionService:HasTag(item,"ShopItem") and kind and S._v3.ammo[kind] and not (S._v3PurchaseSent and S._v3PurchaseSent[item]) then add("ammo",item,15) end
        end
        -- Visit unloaded settlements to stream stock. The live index receives it.
        for village in pairs(index.villages) do add("village",village,300) end
    end
    if S._v3.collect or S._v3.corpses or S._v3.bounties then
        local count,capacity=S.coreSackCount();local full=count and capacity and count>=capacity
        for item in pairs(index.loot) do
            local kind=S.v3LootKind(item)
            if kind and ((S._v3.collect and S._v3.loot[kind]) or (kind=="Corpses" and S._v3.corpses) or (kind=="Bounties" and S._v3.bounties))
                and (not full or kind=="Shards" or kind=="Gear") then add("collect",item,15) end
        end
    end
    -- Round-robin job types, then nearest target: a respawning mob cannot starve mines/shops.
    local order={"hunt","mine","mines","ammo","village","collect"}
    for offset=1,#order do
        local slot=((S._v3JobCursor or 0)+offset-1)%#order+1
        local best
        for _,entry in ipairs(candidates) do if entry.kind==order[slot] and (not best or entry.priority>best.priority or (entry.priority==best.priority and entry.distance<best.distance)) then best=entry end end
        if best then S._v3JobCursor=slot;return best end
    end
    return nil
end

function S.v3RunNextJob()
    if S._activity or S._chestInteraction or CoreFarm._leaving or CoreFarm._drainingChests
        or CoreFarm._userStop or S._unloaded then return false end
    local entry=S.v3ChooseJob();if not entry then return false end
    local job=S.v3BeginJob(entry.kind,entry.target);if not job then return false end
    S._v3Visited[entry.target]=os.clock()+entry.delay
    local ok,err=pcall(function()
        if entry.kind=="hunt" then S.v3Hunt(job,entry.target)
        elseif entry.kind=="mine" then S.v3MineOre(job,entry.target)
        elseif entry.kind=="mines" then S.v3MineVisit(job,entry.target)
        elseif entry.kind=="ammo" then S.v3BuyAmmo(job,entry.target)
        elseif entry.kind=="collect" then S.v3CollectOne(job,entry.target)
        elseif entry.kind=="village" then
            local pos=S.getInstancePosition(entry.target)
            if pos and S.v3Move(job,pos+Vector3.new(0,10,0)) then pcall(S.requestStreamAround,pos,1);task.wait(0.5) end
        end
    end)
    S.v3EndJob(job,true)
    if not ok then S.interactionNote("activity "..entry.kind,tostring(err):sub(1,140)) end
    return true
end

function S.v3Tick()
    if not S._v3 or S._unloaded or not S._uiReady then return true end
    if S._v3.stock or S._v3Running then S.v3EnsureIndex() end
    if not S._v3Running or S._v3Completed or CoreFarm._userStop or CoreFarm._leaving then return true end
    if game.PlaceId==LOBBY_PLACE then
        if not S._v3.autoQueue then S.coreSetStatus("Lobby · auto queue off");return true end
        CoreFarm.enabled=true
        return false
    end
    if game.PlaceId~=NA.placeId then return true end
    if S._v3.chests then return false end
    if not S.corePlayerReady() or S._activity then return true end
    local movement=S._v3.hunt or S._v3.mine or S._v3.ammoBuy or S._v3.collect or S._v3.corpses or S._v3.bounties
    if not movement then
        if Autofarm.enabled then S.setAutofarm(false) end
        S.coreSetStatus(S._v3.aura and "Kill aura · nearby targets" or "Ready · choose a farm")
        return true
    end
    CoreFarm.openAll,CoreFarm._ownedRun=false,false
    if not Autofarm.enabled then Autofarm.openChests=false;S.setAutofarm(true) end
    return true
end

function S.v3AuraTick()
    if not S._v3 or not S._v3Running or not S._v3.aura or CoreFarm._userStop or CoreFarm._leaving
        or S._unloaded or game.PlaceId~=NA.placeId or S._chestInteraction or S._activity then return end
    if os.clock()<(S._v3AttackAt or 0) then return end
    local root=S.getRoot();if not root then return end
    local targets={}
    for mob in pairs(S.v3EnsureIndex().mobs) do
        local pos=S.getInstancePosition(mob)
        if S.v3AliveMob(mob) and S.v3SelectedMob(mob) and pos and (pos-root.Position).Magnitude<=S._v3.auraRange then targets[#targets+1]=mob end
        if #targets>=8 then break end
    end
    S._v3AuraBusy=true
    local ok,err=pcall(S.v3Attack,targets,nil)
    S._v3AuraBusy=false
    if not ok then error(err) end
end

function S.v3Await(reply,seconds,job)
    if type(reply)~="table" or type(reply.andThen)~="function" then return true,reply end
    local done,value=false,nil
    local observer=reply:andThen(function(result)done,value=true,result end)
    if observer and type(observer.catch)=="function" then observer:catch(function()done,value=true,false end)end
    local deadline=os.clock()+seconds
    while not done and not S._unloaded and (not job or S.v3JobActive(job)) and os.clock()<deadline do task.wait(0.06)end
    return done,value
end

function S.v3RestockText()
    if os.clock()>=(S._v3TimerAt or 0) then
        S._v3TimerAt=os.clock()+5
        local best
        for _,timer in ipairs(CollectionService:GetTagged("TimerText")) do
            local et=tonumber(timer:GetAttribute("EndTime"))
            if et and (not best or et>best) then best=et end
        end
        if best then S._v3RestockEnd=best end
    end
    local et=S._v3RestockEnd
    if not et then return "Restock timer not loaded" end
    local remaining=math.max(0,math.floor(et-Workspace:GetServerTimeNow()))
    return string.format("Restock %02d:%02d",math.floor(remaining/60),remaining%60)
end

function S.coreBootAutoload()
    if S._unloaded or CoreFarm._leaving or CoreFarm._userStop then return end
    if S._v3 then S.v3QueueLoader() end
    S.corePullLoadedFlags()
    S.coreRequestRun()
end

function S.buildUI()
    S._configLoading = true
    Autofarm.depthHudVisible, Autofarm.debugHud = false, false
    local ok, err = pcall(S.buildAutofarmTab)
    S._configLoading = false
    if not ok then error(err) end
    S.setAntiAfk(true)
    S._uiReady = true
    S.hubLog("Autofarm ready")
    S.coreBootAutoload()
end

task.spawn(function()
    S.hubLog("Waiting for the match...")
    local readyOk, readyErr = S.waitForGameReady()
    if S._unloaded then return end
    S._knitReady = readyOk == true
    if not readyOk then
        S.hubLog("Match wait: " .. tostring(readyErr))
    end
    S.hubLog("Building UI...")
    pcall(S.coreLoadQueue)

    local buildOk, buildErr = pcall(S.buildUI)
    if not buildOk then
        S._configLoading = false
        S.hubLog("UI ERROR: " .. tostring(buildErr))
        S.notify(HUB_NAME, "UI error: " .. tostring(buildErr), 10)
        S._uiReady = true
        return
    end

    S.connectServicesAsync()
end)

local respawnPlayer = LocalPlayer or Players.LocalPlayer
if respawnPlayer then
State.connections.coreRespawn = respawnPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if S._unloaded then return end

    if Autofarm.enabled then
        S.setAutofarmPlatformStand(true)
        S.ensureAutofarmAntiFall(true)
        S.lockAutofarmHover(true)
        S.setAutofarmPose(Autofarm.distance or 0)
    elseif game.PlaceId == NA.placeId and type(CoreFarm) == "table" and CoreFarm.openAll then
        CoreFarm._rootSeenAt = nil
        CoreFarm._runStarted = false
        S.coreRequestRun()
    end
end)
end

S.hubLog(HUB_NAME .. " started | PlaceId " .. game.PlaceId)

State.connections.coreCutscene = workspace:GetAttributeChangedSignal("InCutScene"):Connect(function()
    if S._unloaded then return end
    if workspace:GetAttribute("InCutScene") == true then
        task.defer(function()
            pcall(S.coreSkipCutscene)
        end)
    end
end)

task.spawn(function()
    while not S._unloaded do
        task.wait(0.25)
        pcall(S.coreSkipCutscene)
    end
end)

function S.coreToggleOn(flagName)
    local flags = Controls and Controls.Flags
    local flag = flags and flags[flagName]
    if flag and flag._value and flag._value.Value ~= nil then
        return flag._value.Value == true
    end
    if flag and flag.CurrentValue == true then
        return true
    end
    local lib = S._alkalineLibrary
    local toggle = lib and lib.Toggles and lib.Toggles[flagName]
    return toggle ~= nil and toggle.Value == true
end

function S.corePullLoadedFlags() end

task.spawn(function()
    while not S._uiReady and not S._unloaded do task.wait(0.2) end
    while not S._unloaded do
        local ok, err = xpcall(S.coreCycleTick, function(e) return debug.traceback(tostring(e), 2) end)
        if not ok then pcall(S.coreCycleError, "cycle", err) end
        task.wait(1.5)
    end
end)

task.spawn(function()
    while not S._unloaded do
        task.wait(1)
        if S._unloaded then return end
        local ok, err = pcall(S.coreChurchAutoConfirmTick)
        if not ok then S.interactionNote("church watcher", tostring(err):sub(1, 120)) end
    end
end)

function S.setAntiAfk(enabled)
    S.disconnectAll("antiAfk")
    if not enabled or S._unloaded then return end
    State.connections.antiAfk = LocalPlayer.Idled:Connect(function()
        if S._unloaded then return end
        pcall(function()
            local user = game:GetService("VirtualUser")
            user:CaptureController()
            user:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end



task.spawn(function()
    while not S._unloaded do
        task.wait(0.2)
        if S._uiReady then
            local ok,err=pcall(S.v3AuraTick)
            if not ok and os.clock()>=(S._v3AuraErrorAt or 0) then
                S._v3AuraErrorAt=os.clock()+10
                S.interactionNote("aura",tostring(err):sub(1,120))
            end
        end
    end
end)
