---
sidebar_position: 1
---

# Installation

## Wally

Add [leifstout/networker](https://wally.run/package/leifstout/networker?version=0.3.0) to your Wally configuration file.

<sub>wally.toml</sub>
```toml
[package]
name = "username/game"
description = "An awesome game!"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"

[dependencies]
networker = "leifstout/networker@0.3.0"
```