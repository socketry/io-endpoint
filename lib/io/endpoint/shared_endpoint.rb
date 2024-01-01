# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require_relative 'generic'
require_relative 'composite_endpoint'
require_relative 'socket_endpoint'

require 'openssl'

module IO::Endpoint
	# Pre-connect and pre-bind sockets so that it can be used between processes.
	class SharedEndpoint < Generic
		# Create a new `SharedEndpoint` by binding to the given endpoint.
		def self.bound(endpoint, backlog: Socket::SOMAXCONN, close_on_exec: false, **options)
			sockets = endpoint.bind(**options)
			
			sockets.each do |server|
				# This is somewhat optional. We want to have a generic interface as much as possible so that users of this interface can just call it without knowing a lot of internal details. Therefore, we ignore errors here if it's because the underlying socket does not support the operation.
				begin
					server.listen(backlog)
				rescue Errno::EOPNOTSUPP
					# Ignore.
				end
				
				server.close_on_exec = close_on_exec
			end
			
			return self.new(endpoint, sockets)
		end
		
		# Create a new `SharedEndpoint` by connecting to the given endpoint.
		def self.connected(endpoint, close_on_exec: false)
			socket = endpoint.connect
			
			socket.close_on_exec = close_on_exec
			
			return self.new(endpoint, [socket])
		end
		
		def initialize(endpoint, sockets, **options)
			super(**options)
			
			raise TypeError, "sockets must be an Array" unless sockets.is_a?(Array)
			
			@endpoint = endpoint
			@sockets = sockets
		end
		
		attr :endpoint
		attr :sockets
		
		def local_address_endpoint(**options)
			endpoints = @sockets.map do |wrapper|
				AddressEndpoint.new(wrapper.to_io.local_address, **options)
			end
			
			return CompositeEndpoint.new(endpoints)
		end
		
		def remote_address_endpoint(**options)
			endpoints = @sockets.map do |wrapper|
				AddressEndpoint.new(wrapper.to_io.remote_address, **options)
			end
			
			return CompositeEndpoint.new(endpoints)
		end
		
		# Close all the internal sockets.
		def close
			@sockets.each(&:close)
			@sockets.clear
		end
		
		def each(&block)
			return to_enum unless block_given?
			
			@sockets.each do |socket|
				yield SocketEndpoint.new(socket.dup)
			end
		end
		
		def bind(wrapper = Wrapper.default, &block)
			@sockets.each.map do |server|
				server = server.dup
				
				if block_given?
					wrapper.async do
						begin
							yield server
						ensure
							server.close
						end
					end
				else
					server
				end
			end
		end
		
		def connect(wrapper = Wrapper.default, &block)
			@sockets.each do |socket|
				socket = socket.dup
				
				return socket unless block_given?
				
				begin
					return yield(socket)
				ensure
					socket.close
				end
			end
		end
		
		def accept(wrapper = Wrapper.default, &block)
			bind(wrapper) do |server|
				wrapper.accept(server, &block)
			end
		end
		
		def to_s
			"\#<#{self.class} #{@sockets.size} descriptors for #{@endpoint}>"
		end
	end
	
	class Generic
		def bound(**options)
			SharedEndpoint.bound(self, **options)
		end
		
		def connected(**options)
			SharedEndpoint.connected(self, **options)
		end
	end
end
