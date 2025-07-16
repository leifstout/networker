--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NetworkerUtils = require(script.Parent.NetworkerUtils)

local RemoteContainter: Folder
if RunService:IsRunning() and RunService:IsServer() then
	RemoteContainter = Instance.new("Folder")
	RemoteContainter.Name = "_remotes"
	RemoteContainter.Parent = script.Parent
end

type NetworkTag = NetworkerUtils.NetworkTag
type ClientAccess = NetworkerUtils.ClientAccess
type RemotesContainer = NetworkerUtils.RemotesContainer

--[=[
	NetworkerServer facilitates the communication of server-sided networking and handles client networking requests  
	@class NetworkerServer  
]=]
local NetworkerServer = {}
NetworkerServer.__index = NetworkerServer

--[=[
	@within NetworkerServer  
	@type PlayerGroup Player | { Player }  
]=]
type PlayerGroup = Player | { Player }

export type NetworkerServer = typeof(setmetatable(
	{} :: {
		networkTag: NetworkTag,
		event: RemoteEvent,
		func: RemoteFunction,
		remotes: RemotesContainer,
		instance: Instance?,
		instanceConn: RBXScriptConnection?,
		recipients: { Player }?,
		_accessLookup: { [string]: { module: any, method: (...any?) -> ...any? } },
	},
	NetworkerServer
))

--[=[
	Constructs a new NetworkerServer  
	@param networkTag NetworkTag -- The unqiue tag of the networker  
	@param module table? -- The class or service the client will be communicating with  
	@param clientAccess ClientAccess? -- The methods that the client is allowed to call  
	@return NetworkerServer  
]=]
function NetworkerServer.new(networkTag: NetworkTag, module: {}?, clientAccess: ClientAccess?): NetworkerServer
	assert(RunService:IsServer(), "NetworkerServer can only be created on the server")

	local self = setmetatable({
		networkTag = networkTag,
		_accessLookup = {},
	}, NetworkerServer)

	local remotes = Instance.new("Folder")
	local event = Instance.new("RemoteEvent")
	local func = Instance.new("RemoteFunction")
	event.Parent = remotes
	func.Parent = remotes

	self.remotes = remotes :: RemotesContainer
	self.event = event
	self.func = func

	if typeof(networkTag) == "Instance" then
		local instance = networkTag :: Instance
		assert(
			instance:GetAttribute(NetworkerUtils.INSTANCE_ATTRIBUTE) == nil,
			"NetworkerServer instance already has a networkTag attribute"
		)

		local newTag = HttpService:GenerateGUID(false):sub(1, 13)
		self.instance = instance
		self.networkTag = newTag
		instance:SetAttribute(NetworkerUtils.INSTANCE_ATTRIBUTE, newTag)

		self.instanceConn = instance.Destroying:Once(function()
			self:destroy()
		end)
	end

	remotes.Name = self.networkTag :: string
	assert(RemoteContainter:FindFirstChild(remotes.Name) == nil, "NetworkerServer with the same name already exists")
	remotes.Parent = RemoteContainter

	if clientAccess then
		assert(module, "Module must be provided if clientAccess is specified")
		self:addClientAccess(module, clientAccess)
	end

	local function callback(player: Player, method: string, ...: any?): ...any?
		local access = self._accessLookup[method]
		if not access then
			warn(method .. " does not exist or is restricted for ", networkTag)
			return
		end

		return access.method(access.module, player, ...)
	end

	event.OnServerEvent:Connect(callback)
	func.OnServerInvoke = callback

	return self
end

--[=[
	Adds a client access method(s) to the NetworkerServer
	@param module any -- The class or service the client will be communicating with  
	@param methods ClientAccess -- The methods that the client is allowed to call
	@return ()  
]=]
function NetworkerServer.addClientAccess(self: NetworkerServer, module: any, methods: { any }): ()
	for _, method in methods do
		for funcName, func in module do
			if func ~= method then
				continue
			end

			assert(self._accessLookup[funcName] == nil, "Client access method already exists: " .. funcName)
			assert(type(func) == "function", "Client access method must be a function: " .. funcName)

			self._accessLookup[funcName] = {
				module = module,
				method = method,
			}
		end
	end
end

--[=[
	Adds a player to the list of recipients  
	@param player Player -- The player to add to the list of recipients  
	@return ()  
]=]
function NetworkerServer.addRecipient(self: NetworkerServer, player: Player): ()
	if not self.recipients then
		self.recipients = {}
	end

	assert(self.recipients, "Recipients list is nil")
	table.insert(self.recipients, player)
end

--[=[
	Removes a player from the list of recipients  
	@param player Player -- The player to remove from the list of recipients  
	@return ()  
]=]
function NetworkerServer.removeRecipient(self: NetworkerServer, player: Player): ()
	if not self.recipients then
		return
	end

	local index = table.find(self.recipients, player)
	if index then
		table.remove(self.recipients, index)
	end
end

--[=[
	Clears the list of recipients  
	@return ()  
]=]
function NetworkerServer.clearRecipients(self: NetworkerServer): ()
	self.recipients = nil
end

--[=[
	Fires a method to the given players  
	@param players PlayerGroup -- The players to fire the method to  
	@param method string -- The name of the method to fire  
	@param ... any? -- The arguments to pass to the method  
	@return ()  
]=]
function NetworkerServer.fire(self: NetworkerServer, players: PlayerGroup, method: string, ...: any?): ()
	if typeof(players) == "Instance" then
		self.event:FireClient(players, method, ...)
		return
	end

	for _, player in players :: { Player } do
		self.event:FireClient(player, method, ...)
	end
end

--[=[
	Fires a method to all players  
	@param method string -- The name of the method to fire  
	@param ... any? -- The arguments to pass to the method  
	@return ()  
]=]
function NetworkerServer.fireAll(self: NetworkerServer, method: string, ...: any?): ()
	self.event:FireAllClients(method, ...)
end

--[=[
	Fires a method to all players except the given players  
	@param players PlayerGroup -- The players to exclude from the firing  
	@param method string -- The name of the method to fire  
	@param ... any? -- The arguments to pass to the method  
	@return ()  
]=]
function NetworkerServer.fireAllExcept(self: NetworkerServer, players: PlayerGroup, method: string, ...: any?): ()
	if typeof(players) == "Instance" then
		players = { players }
	end

	for _, player in Players:GetPlayers() do
		if not table.find(players :: { Player }, player) then
			self.event:FireClient(player, method, ...)
		end
	end
end

--[=[
	Fires a method to the list of recipients  
	@param method string -- The name of the method to fire  
	@param ... any? -- The arguments to pass to the method  
	@return ()  
]=]
function NetworkerServer.fireRecipients(self: NetworkerServer, method: string, ...: any?): ()
	if not self.recipients then
		warn("No recipients set for service ", self.networkTag)
		return
	end

	self:fire(self.recipients, method, ...)
end

--[=[
	Sets a value to the given players  
	@param players PlayerGroup -- The players to set the value to  
	@param index string -- The name of the value being set  
	@param value any? -- The value being set  
	@return ()  
]=]
function NetworkerServer.set(self: NetworkerServer, players: PlayerGroup, index: string, value: any?)
	self:fire(players, NetworkerUtils.SET_TAG, index, value)
end

--[=[
	Sets a value to all players  
	@param index string -- The name of the value being set  
	@param value any? -- The value being set  
	@return ()  
]=]
function NetworkerServer.setAll(self: NetworkerServer, index: string, value: any?)
	self:fireAll(NetworkerUtils.SET_TAG, index, value)
end

--[=[
	Sets a value to all players except the given players  
	@param players PlayerGroup -- The players to exclude from the setting  
	@param index string -- The name of the value being set  
	@param value any? -- The value being set  
	@return ()  
]=]
function NetworkerServer.setAllExcept(self: NetworkerServer, players: PlayerGroup, index: string, value: any?)
	self:fireAllExcept(players, NetworkerUtils.SET_TAG, index, value)
end

--[=[
	Sets a value to the list of recipients  
	@param index string -- The name of the value being set  
	@param value any? -- The value being set  
	@return ()  
]=]
function NetworkerServer.setRecipients(self: NetworkerServer, index: string, value: any?): ()
	self:fireRecipients(NetworkerUtils.SET_TAG, index, value)
end

--[=[
	Destroys the NetworkerServer  
	@return ()  
]=]
function NetworkerServer.destroy(self: NetworkerServer): ()
	self.remotes:Destroy()
	self:clearRecipients()
	if self.instanceConn then
		self.instanceConn:Disconnect()
	end
	if self.instance then
		self.instance:SetAttribute(NetworkerUtils.INSTANCE_ATTRIBUTE, nil)
		self.instance = nil
	end
end

return NetworkerServer
