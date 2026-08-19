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

### Configuring TLS Certificate Material

Use {ruby IO::Endpoint::TLS::Configuration} to provide certificate and private key material without coupling application configuration to OpenSSL. Certificate material is supplied as PEM content rather than file paths, so it can be loaded from files, environment variables, or secret stores:

```ruby
trust_store = IO::Endpoint::TLS::TrustStore.parse(root_certificates)
certificate_chain = IO::Endpoint::TLS::Certificates.parse(certificate_chain_bundle)

tls_configuration = IO::Endpoint::TLS::Configuration.new(
	trust_store: trust_store,
	certificate_chain: certificate_chain,
	private_key: private_key,
)

endpoint = IO::Endpoint.ssl(
	"example.com",
	443,
	hostname: "example.com",
	tls_configuration: tls_configuration,
)
```

Use `TrustStore.new(certificates: certificates)` when certificates are already represented as an array of individual PEM strings. Use `TrustStore.parse(certificate_bundle)` to split a concatenated PEM bundle into that canonical representation, or `TrustStore.load("/path/to/certificates.pem")` to load and parse a bundle from a file. Options such as `system_certificates: true` are forwarded from `load` to `parse`.

The local certificate chain is an ordered array of individual PEM strings, with the leaf certificate first. Use `Certificates.parse(certificate_bundle)` to split a concatenated bundle while preserving that order.

Set `system_certificates: true` to include system-provided trusted certificates. System and custom certificates can be combined in the same trust store.

The SSL endpoint converts the trust store into an OpenSSL certificate store and the complete configuration into an OpenSSL context. Other endpoint implementations can consume the same trust, identity, and verification configuration using their native TLS implementation.

The OpenSSL conversion is also available directly using `IO::Endpoint::TLS::OpenSSL.build_certificate_store(trust_store)`.

For a server which requires clients to provide a trusted certificate, set `verification: :required`. Use `:peer` to verify a certificate when the peer provides one, and `:none` to explicitly disable peer verification. When a trust store is supplied and no policy is specified, peer verification is enabled by default. On client connections with a hostname, peer verification also checks that the certificate identifies that hostname.
