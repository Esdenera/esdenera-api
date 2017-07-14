#!/usr/local/bin/luajit51

-- Copyright (c) 2017 Esdenera Networks GmbH
--
-- Permission to use, copy, modify, and distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
-- WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
-- ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
-- WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
-- ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
-- OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

local tnos = require("tnos")
local json = require("cjson")
local getopt = require("posix.getopt").getopt
local unistd = require("posix.unistd")
local posix = require("posix")

local host, user, cfg, pass, fp, cmd, last_idx, opts, ret, debug
local textonly = "true"
local home = nil
local schema = nil

local function usage()
	print("usage: " .. arg[0] ..
	    " [-dj] [-c config] [-u user] [-p pass] [-h host]")
	os.exit(1)
end

local function log_print(resp)
	local t = { tornado = { type = "api-error", class = "text" }}

	if type(resp) == "string" then
		t.text = { resp }
	elseif type(resp) == "table" and not resp.tornado then
		t.text = resp
	elseif type(resp) == "table" then
		t = resp
	else
		return
	end

	if textonly == "true" then
		if not t.text then
			log_print("Invalid response.")
			os.exit(1)
		end
		for _, v in ipairs(t.text) do
			print(v)
		end
	else
		print(json.encode(t))
	end
end

local function log_err(code, ...)
	log_print(...)
	os.exit(code)
end

local function sortedpairs(t)
	local keys, i = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return function()
		i = next(keys, i)
		if i then
			return keys[i], t[keys[i]]
		end
	end
end

local function logout()
	tnos:logout()
	unistd.unlink(cfg)
end

local function save_config()
	fp = io.open(cfg, "w")
	if fp then
		opts = tnos:get()
		opts.pass = ""
		ret = fp:write(json.encode(opts))
		fp:close()
	end
end

local function get_schema()
	local resp, err, text, fp
	local path = home .. "/schema-" .. tnos.opts.host .. ".json"

	fp = io.open(path, "r")
	if fp then
		text = fp:read("*a")
		fp:close()
		if text then
			resp = json.decode(text)
		end
	end

	if not resp then
		resp, err, text =
		    tnos:command("show commands schema", {
		    ['text-only'] = "false"
		})
		if not resp then
			log_err(1, err .. ": " .. text)
		end

		fp = io.open(path, "w")
		if fp then
			fp:write(json.encode(resp))
			fp:close()
		end
	end

	if not (resp and
	    resp.json and
	    resp.json.document and
	    resp.json.document.commands) then
		log_err(1, "invalid schema")
	end

	return resp.json.document.commands
end

local function open_config()
	local fp = io.open(cfg, "r")
	if fp then
		ret = fp:read("*a")
		if ret then
			opts = json.decode(ret)
		end
		fp:close()
	end
end

local function parse_command(command)
	local arr = {}
	local schemav

	-- strip whitespace
	command = command:gsub("^%s*(.-)%s*$", "%1")

	-- strip help character "?"
	cmd = command:gsub("(.-)%s*%?$", "%1")

	local token = ''
	-- are we currently inside a parenthesis section?
	local double_parens = false
	local single_parens = false
	for c in cmd:gmatch(".") do
		-- single and double parenthesis sections exclude each other
		if c == '"' and not single_parens then
			double_parens = not double_parens
		end
		if c == "'" and not double_parens then
			single_parens = not single_parens
		end

		-- a token can only end when we are not inside a parenthesis
		-- section
		if not double_parens and not single_parens
		    and c:match('%s') and token ~= '' then
			table.insert(arr, token)
			token = ''
		else
			token = token..c
		end
	end
	if token ~= '' then
		table.insert(arr, token)
	end

	local function show_valid_args(t, match, errv)
		local parent = "  "
		local arg

		if not errv then
			errv = {}
		end
		table.insert(errv, "valid commands/arguments:")

		if (t.__parent and t.__parent._guide) then
			table.insert(errv, t.__parent._guide)
		end

		for k, v in sortedpairs(t) do
			local p
			if match then
				if k:match("^" .. match) then
					p = ("  %-15s"):format(k)
				end
			elseif k:match("^%w") then
				p = ("  %-15s"):format(k)
			end
			if p then
				if v._help then
					p = p .. " " .. v._help
				end
				table.insert(errv, p)
			end
		end
		table.insert(errv, "  <cr>")

		return errv
	end

	local function match_token(token, word)
		local match, key, t, action, type, guide, isparent = 0
		local errv = {}

		action = token._action
		type = token._type
		guide = token._guide
		if not guide then
			guide = ("<x%s>"):format(type)
		end

		if token[word] then
			-- exact match
			match = 1
			key = word
			t = token[word]
		else
			-- find possible matches
			for k, v in pairs(token) do
				if k:match("^%w") then
					isparent = true
					if k:match("^" .. word) then
						match = match + 1
						key = k
						t = v
					end
				end
			end
		end

		if match == 0 and type then
			return token, guide
		elseif match == 0 then
			table.insert(errv, ("unknown argument: %s"):format(word))
			return nil, nil, errv
		elseif match > 1 then
			table.insert(errv, ("unknown argument: %s"):format(word))
			return nil, word, errv
		elseif not key then
			return nil, nil, errv
		end

		return t, key
	end

	-- print results
	schemav = schema
	for _,v in ipairs(arr) do
		local t, match, errv = match_token(schemav, v)
		if not t then
			return nil, show_valid_args(schemav, match, errv)
		end
		t.__parent = { _schema = schemav, _guide = match }
		schemav = t
	end

	-- Must end with a question mark
	if command:match("(.*)%?$") then
		return nil, show_valid_args(schemav)
	end

	-- Return nomalized command string
	return table.concat(arr, " ")
end

local function run_command(command)
	local cmd, errv

	-- parse and normalize command
	cmd, errv = parse_command(command)
	if not cmd then
		log_err(0, errv)
	end

	if cmd == "exit" or cmd == "end" or cmd == "logout" then
		if cmd == "logout" then
			logout()
		else
			save_config()
		end
		log_err(0, "Connection closed.");
	end
	local resp, err, text = tnos:command(cmd, { ['text-only'] = textonly })
	if not resp then
		log_err(1, text)
	end
	log_print(resp)
end

for r, optarg, optind, _ in getopt(arg, "c:dh:jp:u:") do
	if (r == 'c') then
		cfg = optarg
	elseif (r == 'd') then
		debug = true
	elseif (r == 'h') then
		host = optarg
	elseif (r == 'j') then
		textonly = "false"
	elseif (r == 'p') then
		pass = optarg
	elseif (r == 'u') then
		user = optarg
	else
		usage()
	end
	last_idx = optind
end

if not home then
	home = os.getenv("HOME") .. "/.esdenera"
	posix.mkdir(home)
	posix.chmod(home, "rwx------")
end

if not cfg then
	cfg = home .. "/config.json"
end

open_config()

tnos:init(opts)
if debug then
	tnos:init({ debug = true })
else
	tnos:init({ debug = false })
end

if not opts then
	if not host then
		io.write("Host: ")
		host = io.stdin:read("*l")
	end

	if not user then
		local u, h = host:match("([^@]+)@(.*)")
		if not u then
			user = os.getenv("USER")
		else
			user = u
			host = h
		end
	end

	if not pass then
		io.stdout:write("Password: ")
		pass = io.stdin:read("*l")
	end

	if not tnos:login({ user = user, pass = pass, host = host }) then
		log_err(1, "Login failed.")
	end
	pass = nil
end

if not schema then
	schema = get_schema()
	if not schema then
		log_err(1, "failed to get schema")
	end
end

-- First check if a command was specified on the command line
cmd = table.concat(arg, " ", last_idx)
if #cmd > 0 then
	run_command(cmd)
	save_config()
	os.exit(0)
end

-- don't enter interactive mode if terminal is a tty
if unistd.isatty(0) then
	parse_command("?")
	os.exit(0)
end

-- read commands from pipe
fp = io.stdin
for line in fp:lines() do
	run_command(line)
end
