# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'socket'

module IO::Endpoint
	module Wrapper
		include Socket::Constants
		
		if $stdin.respond_to?(:timeout=)
			def self.set_timeout(io, timeout)
				io.timeout = timeout
			end
		else
			def self.set_timeout(io, timeout)
				warn "IO#timeout= not supported on this platform."
			end
		end
		
		# Build and wrap the underlying io.
		# @option reuse_port [Boolean] Allow this port to be bound in multiple processes.
		# @option reuse_address [Boolean] Allow this port to be bound in multiple processes.
		def self.build(*arguments, timeout: nil, reuse_address: true, reuse_port: nil, linger: nil)
			socket = Socket.new(*arguments)
			
			# Set the timeout:
			if timeout
				set_timeout(socket, timeout)
			end
			
			if reuse_address
				socket.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
			end
			
			if reuse_port
				socket.setsockopt(SOL_SOCKET, SO_REUSEPORT, 1)
			end
			
			if linger
				socket.setsockopt(SOL_SOCKET, SO_LINGER, linger)
			end
			
			yield socket if block_given?
			
			return socket
		rescue
			socket&.close
		end
		
		# Establish a connection to a given `remote_address`.
		# @example
		#  socket = Async::IO::Socket.connect(Async::IO::Address.tcp("8.8.8.8", 53))
		# @param remote_address [Address] The remote address to connect to.
		# @option local_address [Address] The local address to bind to before connecting.
		def self.connect(remote_address, local_address: nil, **options)
			socket = build(remote_address.afamily, remote_address.socktype, remote_address.protocol, **options) do |socket|
				if local_address
					if defined?(IP_BIND_ADDRESS_NO_PORT)
						# Inform the kernel (Linux 4.2+) to not reserve an ephemeral port when using bind(2) with a port number of 0. The port will later be automatically chosen at connect(2) time, in a way that allows sharing a source port as long as the 4-tuple is unique.
						socket.setsockopt(SOL_IP, IP_BIND_ADDRESS_NO_PORT, 1)
					end
					
					socket.bind(local_address.to_sockaddr)
				end
			end
			
			begin
				socket.connect(remote_address.to_sockaddr)
			rescue Exception
				socket.close
				raise
			end
			
			return socket unless block_given?
			
			begin
				yield socket
			ensure
				socket.close
			end
		end
		
		# Bind to a local address.
		# @example
		#  socket = Async::IO::Socket.bind(Async::IO::Address.tcp("0.0.0.0", 9090))
		# @param local_address [Address] The local address to bind to.
		# @option protocol [Integer] The socket protocol to use.
		def self.bind(local_address, protocol: 0, **options, &block)
			socket = build(local_address.afamily, local_address.socktype, protocol, **options) do |socket|
				socket.bind(local_address.to_sockaddr)
			end
			
			return socket unless block_given?
			
			begin
				yield socket
			ensure
				socket.close
			end
		end
		
		# Bind to a local address and accept connections in a loop.
		def self.accept(*arguments, backlog: SOMAXCONN, **options, &block)
			bind(*arguments, **options) do |server|
				server.listen(backlog) if backlog
				
				Fiber.schedule do
					while true
						server.accept(&block)
					end
				end
			end
		end
	end
end
