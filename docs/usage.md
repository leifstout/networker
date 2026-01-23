---
sidebar_position: 2
---

# Basic Usage
Networker allows you to call certain select server functions on the client. To start, you must create a *Networker.server* object

<sub>main.server.luau</sub>

```lua
local Networker = require("path/to/networker")

local module = {}

local function module.printSomething(
    self: typeof(module) -- networker always returns the module itself as the first parameter
    player: Player, -- always the second parameter, the player who fired the function
    ... -- arguments that the player sent
)
    print(`{player.Name} said "{...}"!`)
end

-- create a server networker object
local networker = Networker.server.new(
    "myScript", -- unique identifier
    module, -- the module that the client will communicate with
    { -- functions from the module which the client can access
        printSomething,
    }
)


-- tell all clients to call the setValue function with a 50 parameter
networker:fireAll("setValue", 50)

-- OR

networker:setAll("myValue", 50)
```
You must then create a *Networker.client* object

<sub>main.client.luau</sub>

```lua
local Networker = require("path/to/networker")

local myClientModule = {
    myValue = 0
}

function myClientModule.setValue(self: typeof(myClientModule), value: number)
    self.myValue = value
end

-- create a client networker object
local networker = Networker.client.new(
    "myScript", -- same identifier we used on the server
    myClientModule -- module that the server can communicate with
)

-- check when the server sets a value using :set or :setAll
networker:getServerChangedSignal(
    "myValue" -- key name
):Connect(function(newVal)
    print(`server set myValue to: {newVal}!`)
end)

-- tell the server to call the printSomething function with a "Hello there!" parameter
networker:fire(
    "printSomething", -- function name
    "Hello there!"
)
```