--[[
    @author depso (depthso)
    @description Grow a Garden stock bot script for Telegram
    https://www.roblox.com/games/126884695634066
]]


type table = {
    [any]: any
}


_G.Configuration = {
    --// Reporting
    ["Enabled"] = true,
    ["BotToken"] = “7639130235:AAHMCA49n9Zn-wiO0jLjeV9qDF81yTZoOsI”, -- Replace with your Telegram bot token
    ["ChatID"] = "-1002738709062", -- Replace with your Telegram chat ID
    ["Weather Reporting"] = true,
    
    --// User
    ["Anti-AFK"] = true,
    ["Auto-Reconnect"] = true,
    ["Rendering Enabled"] = false,


    --// Message Layouts
    ["AlertLayouts"] = {
        ["Weather"] = {
            Emoji = "⛅",
        },
        ["SeedsAndGears"] = {
            Emoji = "🌱⚙️",
            Layout = {
                ["ROOT/SeedStock/Stocks"] = "SEEDS STOCK",
                ["ROOT/GearStock/Stocks"] = "GEAR STOCK"
            }
        },
        ["EventShop"] = {
            Emoji = "🎪",
            Layout = {
                ["ROOT/EventShopStock/Stocks"] = "EVENT STOCK"
            }
        },
        ["Eggs"] = {
            Emoji = "🥚",
            Layout = {
                ["ROOT/PetEggStock/Stocks"] = "EGG STOCK"
            }
        },
        ["CosmeticStock"] = {
            Emoji = "💄",
            Layout = {
                ["ROOT/CosmeticStock/ItemStocks"] = "COSMETIC ITEMS STOCK"
            }
        }
    }
}


--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")


--// Remotes
local DataStream = ReplicatedStorage.GameEvents.DataStream -- RemoteEvent 
local WeatherEventStarted = ReplicatedStorage.GameEvents.WeatherEventStarted -- RemoteEvent 


local LocalPlayer = Players.LocalPlayer


local function GetConfigValue(Key: string)
    return _G.Configuration[Key]
end


--// Set rendering enabled
local Rendering = GetConfigValue("Rendering Enabled")
RunService:Set3dRenderingEnabled(Rendering)


--// Check if the script is already running
if _G.StockBot then return end 
_G.StockBot = true


local function GetDataPacket(Data, Target: string)
    for _, Packet in Data do
        local Name = Packet[1]
        local Content = Packet[2]


        if Name == Target then
            return Content
        end
    end


    return 
end


local function GetLayout(Type: string)
    local Layouts = GetConfigValue("AlertLayouts")
    return Layouts[Type]
end


local function TelegramSend(Type: string, Message: string)
    local Enabled = GetConfigValue("Enabled")
    local BotToken = GetConfigValue("BotToken")
    local ChatID = GetConfigValue("ChatID")


    --// Check if reports are enabled
    if not Enabled or not BotToken or not ChatID then return end


    local Layout = GetLayout(Type)
    local Emoji = Layout.Emoji or "ℹ️"
    
    local FinalMessage = string.format("%s %s\n%s", Emoji, Type:upper(), Message)
    
    local Url = string.format("https://api.telegram.org/bot%s/sendMessage", BotToken)
    
    local RequestData = {
        Url = Url,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode({
            chat_id = ChatID,
            text = FinalMessage,
            disable_notification = false
        })
    }


    --// Send POST request to Telegram API
    task.spawn(request, RequestData)
end


local function MakeStockString(Stock: table): string
    local String = ""
    for Name, Data in Stock do 
        local Amount = Data.Stock
        local EggName = Data.EggName 


        Name = EggName or Name
        String ..= string.format("%s x%d\n", Name, Amount)
    end


    return String
end


local function ProcessPacket(Data, Type: string, Layout)
    local Message = ""
    
    local FieldsLayout = Layout.Layout
    if not FieldsLayout then return end


    for Packet, Title in FieldsLayout do 
        local Stock = GetDataPacket(Data, Packet)
        if not Stock then return end


        local StockString = MakeStockString(Stock)
        Message ..= string.format("%s:\n%s\n", Title, StockString)
    end


    TelegramSend(Type, Message)
end


DataStream.OnClientEvent:Connect(function(Type: string, Profile: string, Data: table)
    if Type ~= "UpdateData" then return end
    if not Profile:find(LocalPlayer.Name) then return end


    local Layouts = GetConfigValue("AlertLayouts")
    for Name, Layout in Layouts do
        ProcessPacket(Data, Name, Layout)
    end
end)


WeatherEventStarted.OnClientEvent:Connect(function(Event: string, Length: number)
    --// Check if Weather reports are enabled
    local WeatherReporting = GetConfigValue("Weather Reporting")
    if not WeatherReporting then return end


    --// Calculate end time
    local ServerTime = math.round(workspace:GetServerTimeNow())
    local EndTime = os.date("%H:%M:%S", ServerTime + Length)


    local Message = string.format("%s\nEnds at: %s", Event, EndTime)
    TelegramSend("Weather", Message)
end)


--// Anti idle
LocalPlayer.Idled:Connect(function()
    --// Check if Anti-AFK is enabled
    local AntiAFK = GetConfigValue("Anti-AFK")
    if not AntiAFK then return end


    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)


--// Auto reconnect
GuiService.ErrorMessageChanged:Connect(function()
    local IsSingle = #Players:GetPlayers() <= 1
    local PlaceId = game.PlaceId
    local JobId = game.JobId


    --// Check if Auto-Reconnect is enabled
    local AutoReconnect = GetConfigValue("Auto-Reconnect")
    if not AutoReconnect then return end


    queue_on_teleport("https://gist.githubusercontent.com/depthso/7d9ec71436ccad0b4663c3baaba34f66/raw/5d7717a8da5590994bae698e0cef03fdb8bf42e5/Stockbot.lua")


    --// Join a different server if the player is solo
    if IsSingle then
        TeleportService:Teleport(PlaceId, LocalPlayer)
        return
    end


    TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer)
end)
