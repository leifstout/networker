# Networker
A complete replacement for RemoteEvents allowing you to modify tables and call functions on a different run context effortlessly

## Examples

### Server

```lua
local myService = {}

function myService:init()
	-- initialize networker to the service/object
	self.networker = Networker.server.new("myService", self, {
		self.printTest,
	})
end

-- client has access to call this because it's included in the client access table
function myService:printTest(player: Player)
	print(`{player.Name} called the print test`)
end

function myService:addPoints(player: Player, points: number)
	...
end

return myService
```

### Client

```lua
local serviceClient = {}

local networker = Networker.client.new("myService", serviceClient)
networker:fire("printTest") -- tell the server to call the printTest function

```
