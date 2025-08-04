local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Channel = TextChatService.TextChannels.RBXGeneral

local Prefix = "ERX"
local Handlers = {}
local Pending = {}

local Lib = {}

function Lib:Send(Name, Args)
	local Encoded = ""
	if Args ~= nil then
		local Ok, Result = pcall(HttpService.JSONEncode, HttpService, Args)
		if Ok then
			Encoded = "|" .. Result
		end
	end
	Channel:SendAsync("", Prefix .. Name .. Encoded)
end

function Lib:Reply(Name, Args)
	self:Send("Response:" .. Name, Args)
end

function Lib:On(Name, Callback)
	Handlers[Name] = Callback
end

function Lib:SendAndWait(Name, Subject, Timeout)
	Timeout = Timeout or 10
	local Id = Name .. "_" .. Subject .. "_" .. tick()
	local Bind = Instance.new("BindableEvent")
	Pending[Id] = Bind

	self:Send(Name, { Subject = Subject })

	local Result
	local Done = false

	local Conn
	Conn = TextChatService.MessageReceived:Connect(function(Msg)
		local Md = Msg.Metadata
		local From = Msg.TextSource and Players:GetPlayerByUserId(Msg.TextSource.UserId)
		if not Md or not From or From == LocalPlayer then return end
		if Md:sub(1, #Prefix) ~= Prefix then return end
		local Data = Md:sub(#Prefix + 1)
		local Raw, Json = Data:match("^Response:" .. Name .. "|(.+)$")
		if Raw then
			local Ok, Args = pcall(HttpService.JSONDecode, HttpService, Raw)
			if Ok and Args.Subject == Subject then
				Done = true
				Result = { Args, From }
				Bind:Fire()
			end
		end
	end)

	task.delay(Timeout, function()
		if not Done then
			Bind:Fire()
		end
	end)

	Bind.Event:Wait()
	Pending[Id] = nil
	Conn:Disconnect()

	if Result then
		return table.unpack(Result)
	end
end

function Lib:Get(Timeout)
	local Bind = Instance.new("BindableEvent")
	local Done = false
	local Result

	local Conn
	Conn = TextChatService.MessageReceived:Connect(function(Msg)
		local Md = Msg.Metadata
		local From = Msg.TextSource and Players:GetPlayerByUserId(Msg.TextSource.UserId)
		if not Md or not From or From == LocalPlayer then return end
		if Md:sub(1, #Prefix) ~= Prefix then return end
		local Data = Md:sub(#Prefix + 1)
		local Name, Json = Data:match("([^|]+)|?(.*)")
		local Args = nil
		if Json and Json ~= "" then
			local Ok, Result = pcall(HttpService.JSONDecode, HttpService, Json)
			if Ok then Args = Result end
		end
		Result = { Name, Args, From }
		Bind:Fire()
	end)

	task.delay(Timeout or 10, function()
		if not Done then
			Bind:Fire()
		end
	end)

	Bind.Event:Wait()
	Conn:Disconnect()

	if Result then
		return table.unpack(Result)
	end
end

TextChatService.MessageReceived:Connect(function(Msg)
	local Md = Msg.Metadata
	local From = Msg.TextSource and Players:GetPlayerByUserId(Msg.TextSource.UserId)
	if not Md or not From or From == LocalPlayer then return end
	if Md:sub(1, #Prefix) ~= Prefix then return end

	local Data = Md:sub(#Prefix + 1)
	local Name, Json = Data:match("([^|]+)|?(.*)")
	local Args = nil
	if Json and Json ~= "" then
		local Ok, Result = pcall(HttpService.JSONDecode, HttpService, Json)
		if Ok then Args = Result end
	end

	local Handler = Handlers[Name]
	if Handler then
		task.spawn(Handler, Args, From)
	end
end)

return Lib
