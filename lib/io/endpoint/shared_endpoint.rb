# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require_relative 'generic'
require_relative 'composite_endpoint'

module IO::Endpoint
	# Pre-connect and pre-bind sockets so that it can be used between processes.
	class SharedEndpoint < Generic
		# Create a new `SharedEndpoint` by binding to the given endpoint.
		def self.bound(endpoint, backlog: Socket::SOMAXCONN, close_on_exec: false, **options)
			sockets = []
			
			endpoint.each do |server_endpoint|
				server = server_endpoint.bind(**options)
				
				# This is somewhat optional. We want to have a generic interface as much as possible so that users of this interface can just call it without knowing a lot of internal details. Therefore, we ignore errors here if it's because the underlying socket does not support the operation.
				begin
					server.listen(backlog)
				rescue Errno::EOPNOTSUPP
					# Ignore.
				end
				
				server.close_on_exec = close_on_exec
				
				sockets << server
			end
			
			return self.new(endpoint, sockets)
		end
		
		# Create a new `SharedEndpoint` by connecting to the given endpoint.
		def self.connected(endpoint, close_on_exec: false)
			wrapper = endpoint.connect
			
			wrapper.close_on_exec = close_on_exec
			
			return self.new(endpoint, [wrapper])
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
				AddressEndpoint.new(wrapper.to_io.local_address)
			end
			
			return CompositeEndpoint.new(endpoints, **options)
		end
		
		def remote_address_endpoint(**options)
			endpoints = @sockets.map do |wrapper|
				AddressEndpoint.new(wrapper.to_io.remote_address)
			end
			
			return CompositeEndpoint.new(endpoints, **options)
		end
		
		# Close all the internal sockets.
		def close
			@sockets.each(&:close)
			@sockets.clear
		end
		
		def bind
			@sockets.each do |server|
				server = server.dup
				
				begin
					yield server
				ensure
					server.close
				end
			end
		end
		
		def connect
			@sockets.each do |peer|
				peer = peer.dup
				
				begin
					yield peer
				ensure
					peer.close
				end
			end
		end
		
		def accept(backlog = nil, &block)
			bind do |server|
				server.accept(&block)
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
