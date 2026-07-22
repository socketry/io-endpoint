# Getting Started

This guide explains how to get started with `io-endpoint`, a library that provides a separation of concerns interface for network I/O endpoints.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add io-endpoint
~~~

## Core Concepts

`io-endpoint` provides a unified interface for working with network endpoints, allowing you to write code that is agnostic to the underlying transport mechanism (TCP, UDP, UNIX sockets, SSL/TLS). This separation of concerns makes it easier to:

- **Write transport-agnostic code**: Your application logic doesn't need to know whether it's using TCP, UDP, or UNIX sockets.
- **Test with different transports**: Easily swap between transports during testing.
- **Handle multiple addresses**: Automatically handle IPv4 and IPv6 addresses.
- **Compose endpoints**: Combine multiple endpoints for failover or load distribution.

The library centers around the {ruby IO::Endpoint::Generic} class, which represents a network endpoint that can be bound (for servers) or connected to (for clients). Different endpoint types handle different scenarios:

- {ruby IO::Endpoint::HostEndpoint} - Resolves hostnames to addresses (e.g., "localhost:8080")
- {ruby IO::Endpoint::AddressEndpoint} - Works with specific network addresses
- {ruby IO::Endpoint::UNIXEndpoint} - Handles UNIX domain sockets
- {ruby IO::Endpoint::ExclusiveUNIXEndpoint} - Owns and cleans up UNIX domain socket paths
- {ruby IO::Endpoint::SSLEndpoint} - Wraps endpoints with SSL/TLS encryption
- {ruby IO::Endpoint::CompositeEndpoint} - Combines multiple endpoints

## Usage

### Creating a TCP Server

When you need to create a server that listens on a specific port, you can use {ruby IO::Endpoint.tcp} to create a TCP endpoint:

```ruby
require "io/endpoint"

# Create a TCP endpoint listening on localhost port 8080:
endpoint = IO::Endpoint.tcp("localhost", 8080)

# Bind to the endpoint and accept connections:
endpoint.bind do |server|
	# The server socket is automatically closed when the block exits
	server.listen(10)
	
	loop do
		client, address = server.accept
		# Handle the client connection
		client.close
	end
end
```

### Creating a TCP Client

To connect to a remote server, use the `connect` method:

```ruby
require "io/endpoint"

# Create a TCP endpoint for the remote server:
endpoint = IO::Endpoint.tcp("example.com", 80)

# Connect to the server:
endpoint.connect do |socket|
	# The socket is automatically closed when the block exits
	socket.write("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n")
	response = socket.read
	puts response
end
```

### Using UNIX Domain Sockets

For inter-process communication on the same machine, UNIX domain sockets provide better performance than TCP:

```ruby
require "io/endpoint"

# Create a UNIX socket endpoint:
endpoint = IO::Endpoint.unix("/tmp/myapp.sock")

# Bind to the socket:
endpoint.bind do |server|
	server.listen(10)
	
	loop do
		client, address = server.accept
		# Handle the client connection
		client.close
	end
end
```

When a bound endpoint exclusively owns its socket path, use `IO::Endpoint.exclusive_unix`. Closing the bound endpoint removes the socket path. An adjacent lock file serializes ownership and allows a new process to recover a stale socket after the previous owner crashes:

```ruby
endpoint = IO::Endpoint.exclusive_unix("/tmp/myapp.sock")
bound_endpoint = endpoint.bound

begin
	# Run a server using bound_endpoint.
ensure
	bound_endpoint.close
end
```

Exclusive ownership applies to sockets created with `#bind` or `#bound`. An orderly close removes both the socket and lock paths. After a crash, the lock file can remain and is reused by subsequent owners.

To generate a unique socket path for a worker, pass an existing directory and a prefix using `unique:`. The concrete path is generated immediately and is available through `#path`, so it can be registered with a service discovery mechanism before the worker starts serving:

```ruby
endpoint = IO::Endpoint.exclusive_unix("/tmp/workers", unique: "worker")
endpoint.path # => "/tmp/workers/worker-12345-a4c091b25e2f6408.ipc"
```

The directory must already exist. Generated paths include the process identifier and random entropy. Crashed processes can leave stale socket and lock paths, so consumers should use stable names, tolerate failed connections, or obtain the viable paths from a service discovery mechanism.

### Using SSL/TLS

To add encryption to your connections, wrap a TCP endpoint with SSL:

```ruby
require "io/endpoint"

# Create an SSL endpoint:
endpoint = IO::Endpoint.ssl("example.com", 443, hostname: "example.com")

# Connect with SSL encryption:
endpoint.connect do |socket|
	# The socket is automatically encrypted
	socket.write("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n")
	response = socket.read
	puts response
end
```
