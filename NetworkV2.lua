-- PacketLib Module
local PacketLib = {}
PacketLib.__index = PacketLib

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

function PacketLib.new(packetPrefix: string, communicationChannel)
    local self = setmetatable({}, PacketLib)
    self.PacketPrefix = packetPrefix or "Packet_"
    self.Communication = communicationChannel or TextChatService.TextChannels.RBXGeneral
    self.LocalPlayer = Players.LocalPlayer
    self._handlers = {}

    -- Connect message receive event
    self._connection = self.Communication.MessageReceived:Connect(function(message)
        local packetData = message.Metadata
        local textSource = message.TextSource
        if not packetData or not textSource then return end
        if packetData:sub(1, #self.PacketPrefix) ~= self.PacketPrefix then return end
        if textSource.UserId == self.LocalPlayer.UserId then return end

        local packetName = packetData:sub(#self.PacketPrefix + 1)
        self:_handlePacket(packetName, textSource, message)
    end)

    return self
end

function PacketLib:_handlePacket(packetName, textSource, message)
    local handler = self._handlers[packetName]
    if handler then
        handler(textSource, message)
    end
end

-- Register handler function for a packet name
function PacketLib:On(packetName: string, callback: (TextSource, TextChatMessage) -> ())
    assert(type(callback) == "function", "Callback must be a function")
    self._handlers[packetName] = callback
end

-- Send a packet with just the name (can extend later for data)
function PacketLib:Send(packetName: string)
    assert(type(packetName) == "string", "packetName must be string")
    local packetData = self.PacketPrefix .. packetName
    self.Communication:SendAsync("", packetData)
    return packetData
end

-- Cleanup the connection when done
function PacketLib:Destroy()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self._handlers = {}
end

return PacketLib
