# Esdenera API

The Esdenera API is a stateful JSON-over-HTTPS-based protocol to run
CLI commands on the appliance.  It is currently used by the
JavaScript-based GUI/R web interface as a middleware.

The goal of this API is to provide native language bindings for a
number of common programming languages and frameworks.  This will make
it easier to integrate TNOS into existing platforms, such as:

* Cloud management stacks.
* Automation, deployment and configuration management frameworks.
* Network management applications.
* API-based SDN frameworks.
* 3rd party security solutions (that attempt to insert firewall rules etc.).

## Version and license

* TNOS WEBAPI2 Version 3.0

See [LICENSE.md](LICENSE.md) for more details.

## Languages

### Currently released

* [Lua](lua/)

### Not yet released

The following language binding have been implemented and will be
released under the ISC license *soon*:

* JavaScript (jQuery plugin, as used by Esdenera's web interface).
* Java
* Python
* Ruby

### Future implementations

* Go
* Swift
* C/C++
* Perl
* ...more?

## API primitives

### Constructor

Optional language-specific constructor initializing defaults and
returning a new session context.

* api:		"3.0" (API version)
* user:		"admin" (default admin user)
* pass:		"" (password not provided)
* path:		"/tornado/api2/" (API path, will be changed to "/tnos/api/")
* name:		"tornado" (or the system hostname)
* mode:		"default" (default mode, instead of "monitor")
* timeout:	10000 (timeout in milliseconds for requests)
* debug:	false (API debugging)
* host:		"127.0.0.1" (remote host)
* port:		8443 (remote port)
* jsonp:	false (use JSONP, only need for JavaScript)
* text-only:	"false" (get JSON-embedded arrays of text instead of objects)
* limit:	0 (limit returned number of entries in the largest JSON array)
* offset:	0 (offset in the largest JSON array)
* post:		null (optional post data)

### init OPTIONS

Provide a hash table / option array to overwrite the defaults.

### OPTIONS get

Get the current configuration of the API.

### command CLI-COMMAND [OPTIONS]

Request to execute a single CLI command on the TNOS system and return
the result as a JSON object.  The implementation should consider
non-blocking and a deferrable callback for the result.

### commands CLI-COMMANDS [OPTIONS]

Like `command`, but used to execute multiple commands and to return
the results in a single `multiple-response` JSON object.

Depending on the language, the commands can be provided as a
comma-separated list, as an array, or similar.

### cache ID [OPTIONS]

Request the result of a previous command via cache ID.

### delete [OBJECT] [OPTIONS]

Post and remove the specified JSON object from the running configuration.
This command adds the object in a json.document container to the post option.

### load [OBJECT] [OPTIONS]

Post and append the specified JSON object to the running configuration.
Like `delete`, this command adds the object in a json.document
container to the post option.

### login [OPTIONS]

Login to the TNOS system and start a new session.  The username and
password have to be set with init previously, or by passing an
additional OPTIONS argument to the login function.

### logout

Terminate the session remotely and reset the internal state.

### ping

Simple protocol-based keepalive of the remote peer.

### PRIVATE jsonp_callback

Only used by optional JSONP support.

### PRIVATE request

Used internally by the login, logout, command, commands and all
functions executing commands through the TNOS API.

Caveats and security considerations
-----------------------------------

TNOS uses self-signed TLS certificates for WEBAPI2.  While this is a
very common practice in the appliance world, it causes difficulties
and bad useability with most client-side SSL/TLS implementations.
Vendors seem to demand that you either *buy* a certificate for each
private appliance, or that you create and install your own CA.  The
follwing thoughts should be considered when implementing the API for a
new language or framework:

* Don't ignore certificate errors, the API should provide a
callback/feedback mechanism to ask the user if the certificate should
be accepted.  In the Java world, most examples advise to simply ignore
validation errors to use self-signed certificates ... don't do that!
The SelfSignedTrustManager.java implementation provides a naive
feedback mechanism to ask for and store the user's decision.

* The current authentication is based on username and password.
Future versions of the CLI backend will optionally support client
certificates.  Work to support client certificates in OpenBSD's httpd
and libtls has been started.

Another note about threads:

* Avoid to implement threading in the API directly.  The
implementation (API user) is responsible to decide if the API should
be called within a thread context.
