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

local json = require("cjson")
local http = require("socket.http")
local https = require("ssl.https")
local ltn12 = require("ltn12")

local tnos = {
	opts = {
		api =	"3.0",
		user =	"admin",
		pass =	"",
		path =	"/tornado/api2/",
		name =	"tornado",
		mode = 	"default",
		timeout = 10000,
		debug =	false,
		host =	"127.0.0.1",
		port =	8443,
		jsonp =	false,
		['text-only'] = nil,
		limit =	nil,
		offset = nil,
		post =	nil,
		seq = -1,
		token = "",
		cookie = nil
	}
}

function tnos:extend(a, b)
	if not b then
		return
	end
	for k, v in pairs(b) do
		a[k] = v
	end
	return a
end

function tnos:init(options)
	self:extend(self.opts, options)
	self.opts.pass = nil
end

function tnos:get()
	return (self.opts)
end

function tnos:command(command, options, post)
	local req = {
		tornado = {
			type = "command-request",
			command = command
		}
	}
	self:extend(self.opts, options)
	if post then
		self:extend(req, post)
	end

	return self:request(req)
end

function tnos:commands(arr, options)
	local req = {
		tornado = {
			type = "multiple-request",
			multiple = arr
		}
	}
	self:extend(self.opts, options)

	return self:request(req)
end

function tnos:load(object)
	local post = {
		json = {
			document = object
		}
	}

	return self:command("load", nil, post)
end

function tnos:delete(object)
	local post = {
		json = {
			document = object
		}
	}

	return self:command("no", nil, post)
end

function tnos:cache(id, options)
	local req = {
		tornado = {
			type = "cache-request",
			id = id
		}
	}
	self:extend(self.opts, options)

	return self:request(req)
end

function tnos:login(options)
	local req, resp, headers, err

	self:extend(self.opts, options)

	req = {
		tornado = {
			type = "auth-request",
			user = self.opts.user,
			pass = self.opts.pass,
			name = self.opts.name,
			mode = self.opts.mode
		}
	}

	self.opts.pass = nil

	resp, headers, err = self:request(req)
	if not (resp and resp.tornado.auth == "OK" and
	    resp.tornado.token and headers['set-cookie']) then
		if resp and resp.tornado and resp.tornado.auth then
			err = resp.tornado.auth
		end
		return nil, headers, err
	end

	self.opts.seq = 0
	self.opts.token = resp.tornado.token
	self.opts.cookie = headers['set-cookie']:match("tornado=[^; ]+")

	return true
end

function tnos:logout(options)
	local req = {
		tornado = {
			type = "logout",
		}
	}

	self:request(req)

	self.opts.seq = -1
	self.opts.token = ""
end

function tnos:ping()
	local req = {
		tornado = {
			type = "ping",
		}
	}

	return self:request(req)
end

function tnos:request(request)
	local req, resp, url, code, headers, status, ret, err

	self.opts.seq = self.opts.seq + 1
	self:extend(request.tornado, {
		version = 2,
		token = self.opts.token,
		seq = self.opts.seq
	})

	request.tornado['text-only'] = self.opts['text-only']
	request.tornado.limit = self.opts.limit
	request.tornado.offset = self.opts.offset

	url = string.format("https://%s:%d%s",
	    tnos.opts.host, tnos.opts.port, tnos.opts.path);

	req = json.encode(request)
	if not req then
		return nil, "api-error", "unexpected request"
	end

	if self.opts.debug then
		print(">>> request = " .. json.encode(req))
		if self.opts.cookie then
			print("cookie = " .. self.opts.cookie)
		end
	end

	-- timeout has to be set in the http layer (not https)
	http.TIMEOUT = self.opts.timeout / 1000

	resp = {}
	ret, code, headers, status = https.request({
		url = url,
		method = "POST",
		headers = {
			['content-type'] = "application/json",
			['content-length'] = tostring(#req),
			['Cookie'] = self.opts.cookie
		},
		source = ltn12.source.string(req),
		sink = ltn12.sink.table(resp)
	})

	if not ret or code ~= 200 then
		return nil, "api-error", "missing response"
	end

	if self.opts.debug then
		print("<<< response = " .. json.encode(resp))
		print("headers = " .. json.encode(headers))
	end

	ret = json.decode(table.concat(resp))
	if not (ret and ret.tornado and ret.tornado.version == 2) then
		return nil, "api-error", "unexpected response"
	end

	-- hard error
	if ret.tornado.type == "session-error" then
		return nil, ret.tornado.type, ret.text
	end

	-- soft error
	if ret.tornado.type == "request-error" or
	    ret.tornado.type == "response-error" then
		err = ret.text
	end

	return ret, headers, err
end

return tnos
