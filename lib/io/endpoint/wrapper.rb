# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require 'socket'

module IO::Endpoint
	class Wrapper
		include ::Socket::Constants
		
		def set_timeout(io, timeout)
			if io.respond_to?(:timeout=)
				io.timeout = timeout
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
		
		# Establish a connection to a given `remote_address`.
		# @example
		#  socket = Async::IO::Socket.connect(Async::IO::Address.tcp("8.8.8.8", 53))
		# @parameter remote_address [Address] The remote address to connect to.
		# @parameter linger [Boolean] Wait for data to be sent before closing the socket.
		# @parameter local_address [Address] The local address to bind to before connecting.
		def connect(remote_address, local_address: nil, linger: nil, timeout: nil, buffered: false, **options)
			socket = nil
			
			begin
				socket = ::Socket.new(remote_address.afamily, remote_address.socktype, remote_address.protocol)
				
				if linger
					socket.setsockopt(SOL_SOCKET, SO_LINGER, 1)
				end
				
				if buffered == false
					set_buffered(socket, buffered)
				end
				
				if timeout
					set_timeout(socket, timeout)
				end
				
				if local_address
					if defined?(IP_BIND_ADDRESS_NO_PORT)
						# Inform the kernel (Linux 4.2+) to not reserve an ephemeral port when using bind(2) with a port number of 0. The port will later be automatically chosen at connect(2) time, in a way that allows sharing a source port as long as the 4-tuple is unique.
						socket.setsockopt(SOL_IP, IP_BIND_ADDRESS_NO_PORT, 1)
					end
					
					socket.bind(local_address.to_sockaddr)
				end
			rescue
				socket&.close
				raise
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
		
		# JRuby requires ServerSocket
		if defined?(::ServerSocket)
			ServerSocket = ::ServerSocket
		else
			ServerSocket = ::Socket
		end
		
		# Bind to a local address.
		# @example
		#  socket = Async::IO::Socket.bind(Async::IO::Address.tcp("0.0.0.0", 9090))
		# @parameter local_address [Address] The local address to bind to.
		# @parameter reuse_port [Boolean] Allow this port to be bound in multiple processes.
		# @parameter reuse_address [Boolean] Allow this port to be bound in multiple processes.
		# @parameter linger [Boolean] Wait for data to be sent before closing the socket.
		# @parameter protocol [Integer] The socket protocol to use.
		def bind(local_address, protocol: 0, reuse_address: true, reuse_port: nil, linger: nil, bound_timeout: nil, backlog: Socket::SOMAXCONN, **options, &block)
			socket = nil
			
			begin
				socket = ServerSocket.new(local_address.afamily, local_address.socktype, protocol)
				
				if reuse_address
					socket.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
				end
				
				if reuse_port
					socket.setsockopt(SOL_SOCKET, SO_REUSEPORT, 1)
				end
				
				if linger
					socket.setsockopt(SOL_SOCKET, SO_LINGER, 1)
				end
				
				# Set the timeout:
				if bound_timeout
					set_timeout(socket, bound_timeout)
				end
				
				socket.bind(local_address.to_sockaddr)
				
				if backlog
					begin
						# Generally speaking, bind/listen is a common pattern, but it's not applicable to all socket types. We ignore the error if it's not supported as the alternative is exposing this upstream, which seems less desirable than handling it here. In other words, `bind` in this context means "prepare it to accept connections", whatever that means for the given socket type.
						socket.listen(backlog)
					rescue Errno::EOPNOTSUPP
						# Ignore.
					end
				end
			rescue
				socket&.close
				raise
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
		def accept(server, timeout: nil, linger: nil, **options, &block)
			while true
				socket, address = server.accept
				
				if linger
					socket.setsockopt(SOL_SOCKET, SO_LINGER, 1)
				end
				
				if timeout
					set_timeout(socket, timeout)
				end
				
				async do
					# Some sockets, notably SSL sockets, need application level negotiation before they are ready:
					if socket.respond_to?(:start)
						begin
							socket.start
						rescue
							socket.close
							raise
						end
					end
					
					yield socket, address
				end
			end
		end
	end
	
	class ThreadWrapper < Wrapper
		def async(&block)
			::Thread.new(&block)
		end
	end
	
	class FiberWrapper < Wrapper
		def async(&block)
			::Fiber.schedule(&block)
		end
	end
	
	if Fiber.respond_to?(:scheduler)
		def Wrapper.default
			if Fiber.scheduler
				FiberWrapper.new
			else
				ThreadWrapper.new
			end
		end
	else
		def Wrapper.default
			ThreadWrapper.new
		end
	end
end
