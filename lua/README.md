# The Esdenera TNOS API for Lua

## Install

Install Lua, `luasec`, `luasocket`, `lua-cjson`, and `luaposix`.

On OpenBSD, you can install the related packages:

	pkg_add luajit luasec luasocket

## CLI

The `cli.lua` module currently implements a simple non-interactive
cloud-CLI-style command line tool (like awscli or Azure CLI 2.0).

For example:

	$ en show ip
	$ en -j show version
	$ en logout

### TODO

- Access API port over SSH forwarding to gain secure authentication.
- Parse loaded schema to provide context-sensitive help.

## Example

1. Create an API session

        $ lua
        > tnos = require("tnos")

2. Initialize the session

        > tnos.init({ host = "firewall.example.com", "user" = "admin" })

3. Login

        > tnos.login({ pass = "SECRET" })

4. Commands

    - Enable debug

            > tnos.init({ debug = true })

    - Single command

            > = tnos.command("show version")

    - Multiple commands

            > = tnos.commands({ "system resolver host-database www 192.168.0.80", "get system resolver host-database" })

    - Load command

            > tnos.load({ system = { hostname = "test" }})

    - Delete command

            > tnos.delete({ system = { hostname = {}}})

5. Logout

        > tnos.logout()

6. Close the session

        > tnos = nil
