--!strict
local RunService = game:GetService("RunService")

local Packages = script.Parent.Parent
local Signal = require(Packages.Signal)
local NetworkerUtils = require(script.Parent.NetworkerUtils)

type NetworkTag = NetworkerUtils.NetworkTag
type RemotesContainer = NetworkerUtils.RemotesContainer

--[=[
	NetworkerClient facilitates the communication of client-sided networking and handles server networking instructions  
	@class NetworkerClient  
	@client
]=]
local NetworkerClient = {}
NetworkerClient.__index = NetworkerClient

export type NetworkerClient = typeof(setmetatable(
	{} :: {
		networkTag: NetworkTag,
		remotes: RemotesContainer,
		instanceConn: RBXScriptConnection?,
		changedSignals: { [string]: Signal.Signal<any> },
	},
	NetworkerClient
))

--[=[
	Constructs a new NetworkerClient
	@param networkTag NetworkTag -- The unique tag of the networker
	@param module {} -- The class or service the networker will be communicating with  
	@return NetworkerClient  
]=]
function NetworkerClient.new(networkTag: NetworkTag, module: {}): NetworkerClient
	assert(RunService:IsClient(), "NetworkerClient can only be created on the client")

	local self = {
		networkTag = networkTag,
		changedSignals = {},
	}

	setmetatable(self, NetworkerClient)

	if not RunService:IsRunning() then
		return self :: any
	end

	if typeof(networkTag) == "Instance" then
		local attributeTag = networkTag:GetAttribute(NetworkerUtils.INSTANCE_ATTRIBUTE) :: string?
		if not attributeTag then
			networkTag:GetAttributeChangedSignal(NetworkerUtils.INSTANCE_ATTRIBUTE):Wait()
			attributeTag = networkTag:GetAttribute(NetworkerUtils.INSTANCE_ATTRIBUTE) :: string?
		end

		assert(attributeTag, "NetworkerClient instance does not have a networkTag attribute")
		self.networkTag = attributeTag
	end

	local remotes = script.Parent:WaitForChild("_remotes"):WaitForChild(self.networkTag) :: RemotesContainer
	self.remotes = remotes

	remotes.Destroying:Once(function()
		self:destroy()
	end)

	remotes.RemoteEvent.OnClientEvent:Connect(function(method: string, key: string, ...: any?)
		if method == NetworkerUtils.SET_TAG then
			module[key] = ...
			if self.changedSignals[key] then
				self.changedSignals[key]:Fire(module[key])
			end
			return
		end

		assert(module[method], "Method " .. method .. " does not exist on networkTag " .. remotes.Name)
		module[method](module, key, ...)
	end)

	return self
end

--[=[
	Gets the Signal for the given key. Changed signals are used to notify the client when a value has been changed on the server using the set methods.  
	@param key string -- The key of the signal  
	@return Signal -- Returns the Signal  
]=]
function NetworkerClient.getServerChangedSignal<T>(self: NetworkerClient, key: string): Signal.Signal<T>
	if not self.changedSignals[key] then
		self.changedSignals[key] = Signal.new()
	end

	return self.changedSignals[key]
end

--[=[
	calls a method on the server.  
	@param method string -- The method to fire  
	@param ... any -- The arguments to pass to the method  
	@return ()  
]=]
function NetworkerClient.fire(self: NetworkerClient, method: string, ...: any?): ()
	if RunService:IsRunning() then
		self.remotes.RemoteEvent:FireServer(method, ...)
	end
end

--[=[
	calls a method on the server, and returns its result. 
	@param method string -- The method to fire  
	@param ... any -- The arguments to pass to the method  
	@return any? -- The result of the method
	@yields
]=]
function NetworkerClient.fetch(self: NetworkerClient, method: string, ...: any): ...any
	if not RunService:IsRunning() then
		return nil
	end

	return self.remotes.RemoteFunction:InvokeServer(method, ...)
end

--[=[
	Destroys the NetworkerClient and cleans up all connections  
	@return ()  
]=]
function NetworkerClient.destroy(self: NetworkerClient): ()
	if self.remotes then
		self.remotes:Destroy()
	end
	for _, signal in self.changedSignals do
		signal:Destroy()
	end
	if self.instanceConn then
		self.instanceConn:Disconnect()
	end
end

NetworkerClient.Destroy = NetworkerClient.destroy

return NetworkerClient
