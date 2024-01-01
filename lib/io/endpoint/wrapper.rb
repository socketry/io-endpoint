# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'socket'

module IO::Endpoint
	class Wrapper
		include ::Socket::Constants
		
		if IO.method_defined?(:timeout=)
			def set_timeout(io, timeout)
				io.timeout = timeout
			end
		else
			def set_timeout(io, timeout)
				warn "IO#timeout= not supported on this platform."
			end
		end
		
		def set_buffered(socket, buffered)
			case buffered
			when true
				socket.setsockopt(IPPROTO_TCP, TCP_NODELAY, 0)
			when false
				socket.setsockopt(IPPROTO_TCP, TCP_NODELAY, 1)
			end
		rescue Errno::EINVAL
			# On Darwin, sometimes occurs when the connection is not yet fully formed. Empirically, TCP_NODELAY is enabled despite this result.
		rescue Errno::EOPNOTSUPP
			# Some platforms may simply not support the operation.
		rescue Errno::ENOPROTOOPT
			# It may not be supported by the protocol (e.g. UDP). ¯\_(ツ)_/¯
		end
		
		def async
			raise NotImplementedError
		end
		
		# Build and wrap the underlying io.
		# @option reuse_port [Boolean] Allow this port to be bound in multiple processes.
		# @option reuse_address [Boolean] Allow this port to be bound in multiple processes.
		# @option linger [Boolean] Wait for data to be sent before closing the socket.
		# @option buffered [Boolean] Enable or disable Nagle's algorithm for TCP sockets.
		def build(*arguments, timeout: nil, reuse_address: true, reuse_port: nil, linger: nil, buffered: false)
			socket = ::Socket.new(*arguments)
			
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
				socket.setsockopt(SOL_SOCKET, SO_LINGER, 1)
			end
			
			if buffered == false
				set_buffered(socket, buffered)
			end
			
			yield socket if block_given?
			
			return socket
		rescue
			socket&.close
			raise
		end
		
		# Establish a connection to a given `remote_address`.
		# @example
		#  socket = Async::IO::Socket.connect(Async::IO::Address.tcp("8.8.8.8", 53))
		# @param remote_address [Address] The remote address to connect to.
		# @option local_address [Address] The local address to bind to before connecting.
		def connect(remote_address, local_address: nil, **options)
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
		def bind(local_address, protocol: 0, **options, &block)
			socket = build(local_address.afamily, local_address.socktype, protocol, **options) do |socket|
				socket.bind(local_address.to_sockaddr)
			end
			
			return socket unless block_given?
			
			async do
				begin
					yield socket
				ensure
					socket.close
				end
			end
		end
		
		# Bind to a local address and accept connections in a loop.
		def accept(server, timeout: server.timeout, &block)
			while true
				socket, address = server.accept
				
				socket.timeout = timeout if timeout != false
				
				async do
					yield socket, address
				end
			end
		end
	end
	
	class ThreadWrapper < Wrapper
		def async(&block)
			Thread.new(&block)
		end
	end
	
	class FiberWrapper < Wrapper
		def async(&block)
			Fiber.schedule(&block)
		end
	end
	
	def Wrapper.default
		if Fiber.scheduler
			FiberWrapper.new
		else
			ThreadWrapper.new
		end
	end
end
