# Named Endpoints

This guide explains how to use `IO::Endpoint::NamedEndpoints` to manage multiple endpoints by name, enabling scenarios like running the same application on different protocols or ports.

## Overview

`NamedEndpoints` is a collection of endpoints that can be accessed by symbolic names. Unlike {ruby IO::Endpoint::CompositeEndpoint}, which treats endpoints as an ordered list for failover, `NamedEndpoints` allows you to:

- **Access endpoints by name**: Use symbolic keys like `:http1` or `:http2` instead of array indices.
- **Run multiple configurations**: Serve the same application on different protocols, ports, or transports simultaneously.
- **Iterate over endpoints**: Process all endpoints while maintaining their names for configuration lookup.

## When to Use NamedEndpoints

Use `NamedEndpoints` when you need to:

- Run the same server application on multiple endpoints with different configurations (e.g., HTTP/1 and HTTP/2).
- Access endpoints by symbolic names rather than position.
- Bind multiple endpoints and create servers for each one.
- Manage a collection of endpoints where each has a specific role or configuration.

If you need failover behavior (trying endpoints in order until one succeeds), use {ruby IO::Endpoint::CompositeEndpoint} instead.

## Creating Named Endpoints

### Using the Constructor

Create a `NamedEndpoints` instance by passing a hash of endpoints:

```ruby
require "io/endpoint"

http1_endpoint = IO::Endpoint.tcp("localhost", 8080)
http2_endpoint = IO::Endpoint.tcp("localhost", 8090)

named = IO::Endpoint::NamedEndpoints.new(
	http1: http1_endpoint,
	http2: http2_endpoint
)
```

### Using the Factory Method

The `IO::Endpoint.named` factory method provides a convenient way to create named endpoints:

```ruby
require "io/endpoint"

named = IO::Endpoint.named(
	http1: IO::Endpoint.tcp("localhost", 8080),
	http2: IO::Endpoint.tcp("localhost", 8090),
	https: IO::Endpoint.ssl("localhost", 8443)
)
```

## Accessing Endpoints

Access endpoints by their names using the `[]` operator:

```ruby
named = IO::Endpoint.named(
	http1: IO::Endpoint.tcp("localhost", 8080),
	http2: IO::Endpoint.tcp("localhost", 8090)
)

# Access by name
http1 = named[:http1]
http2 = named[:http2]

# Returns nil if not found
missing = named[:nonexistent]  # => nil
```

## Iterating Over Endpoints

### Using `each`

The `each` method yields both the name and endpoint:

```ruby
named = IO::Endpoint.named(
	http1: IO::Endpoint.tcp("localhost", 8080),
	http2: IO::Endpoint.tcp("localhost", 8090)
)

named.each do |name, endpoint|
	puts "Endpoint #{name} is bound to #{endpoint}"
end
```

To map over endpoint values, use `endpoints.values.map`:

```ruby
protocols = named.endpoints.values.map do |endpoint|
	endpoint.protocol.to_s
end

# => ["HTTP1", "HTTP2"]
```

## Binding Endpoints

To bind endpoints, iterate over the collection and bind each endpoint individually, or use the `bound` method to create a new collection with all endpoints bound.

The `bound` method creates a new `NamedEndpoints` instance where all endpoints are bound:

```ruby
named = IO::Endpoint.named(
	http1: IO::Endpoint.tcp("localhost", 8080),
	http2: IO::Endpoint.tcp("localhost", 8090)
)

bound_named = named.bound(reuse_address: true)

# All endpoints are now bound
bound_named.each do |name, bound_endpoint|
	server = bound_endpoint.sockets.first
	server.listen(10)
end
```

## Connecting to Endpoints

To connect to a specific endpoint, access it by name and call `connect` on that endpoint:

```ruby
named = IO::Endpoint.named(
	primary: IO::Endpoint.tcp("server1.example.com", 80),
	secondary: IO::Endpoint.tcp("server2.example.com", 80)
)

# Connect to a specific endpoint by name
named[:primary].connect do |socket|
	socket.write("GET / HTTP/1.1\r\n\r\n")
	response = socket.read
	puts response
end
```

If you need failover behavior (trying endpoints in order until one succeeds), use {ruby IO::Endpoint::CompositeEndpoint} instead.

## Real-World Example: Multi-Protocol Server

Here's a complete example of using `NamedEndpoints` with Falcon to run the same application on HTTP/1 and HTTP/2:

```ruby
#!/usr/bin/env falcon-host
require "falcon/environment/server"
require "falcon/environment/rack"
require "falcon/composite_server"
require "io/endpoint"
require "io/endpoint/named_endpoints"

# Define HTTP/1 endpoint configuration
http1 = environment do
	include Falcon::Environment::Server
	scheme "http"
	protocol {Async::HTTP::Protocol::HTTP1}
	
	endpoint do
		Async::HTTP::Endpoint.for(scheme, "localhost", port: 8080, protocol: protocol)
	end
end

# Define HTTP/2 endpoint configuration
http2 = environment do
	include Falcon::Environment::Server
	scheme "http"
	protocol {Async::HTTP::Protocol::HTTP2}
	
	endpoint do
		Async::HTTP::Endpoint.for(scheme, "localhost", port: 8090, protocol: protocol)
	end
end

# Main service
service "multi-protocol" do
	include Falcon::Environment::Rack
	
	protocol_http1 {http1.with(middleware: self.middleware).evaluator}
	protocol_http2 {http2.with(middleware: self.middleware).evaluator}
	
	# Combine endpoints using NamedEndpoints
	endpoint do
		IO::Endpoint::NamedEndpoints.new(
			protocol_http1: protocol_http1.endpoint,
			protocol_http2: protocol_http2.endpoint
		)
	end
	
	# Create servers for each named endpoint
	make_server do |bound_endpoint|
		servers = {}
		
		bound_endpoint.each do |name, endpoint|
			servers[name.to_s] = self[name].make_server(endpoint)
		end
		
		Falcon::CompositeServer.new(servers)
	end
end
```

This configuration allows the same Rack application to be served on both HTTP/1 (port 8080) and HTTP/2 (port 8090) simultaneously.

## Closing Endpoints

The `close` method closes all endpoints in the collection:

```ruby
named = IO::Endpoint.named(
	http1: IO::Endpoint.tcp("localhost", 8080),
	http2: IO::Endpoint.tcp("localhost", 8090)
)

# ... use endpoints ...

named.close  # Closes all endpoints
```

## Comparison with CompositeEndpoint

| Feature | NamedEndpoints | CompositeEndpoint |
|---------|---------------|-------------------|
| **Access** | By symbolic name (`[:http1]`) | By index (`[0]`) |
| **Use Case** | Multiple configurations | Failover/load balancing |
| **Iteration** | Yields name and endpoint | Yields endpoint only |
| **Connect Behavior** | Tries all until success | Tries in order until success |

Choose `NamedEndpoints` when you need to identify endpoints by name and manage different configurations. Choose `CompositeEndpoint` when you need failover behavior with endpoints tried in order.
