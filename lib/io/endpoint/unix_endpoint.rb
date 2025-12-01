# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

require_relative "address_endpoint"

module IO::Endpoint
	# This class doesn't exert ownership over the specified unix socket and ensures exclusive access by using `flock` where possible.
	class UNIXEndpoint < AddressEndpoint
		# Initialize a new UNIX domain socket endpoint.
		# @parameter path [String] The path to the UNIX socket.
		# @parameter type [Integer] The socket type (defaults to Socket::SOCK_STREAM).
		# @parameter options [Hash] Additional options to pass to the parent class.
		def initialize(path, type = Socket::SOCK_STREAM, **options)
			# I wonder if we should implement chdir behaviour in here if path is longer than 104 characters.
			super(Address.unix(path, type), **options)
			
			@path = path
		end
		
		# Get a string representation of the UNIX endpoint.
		# @returns [String] A string representation showing the socket path.
		def to_s
			"unix:#{@path}"
		end
		
		# Get a detailed string representation of the UNIX endpoint.
		# @returns [String] A detailed string representation including the path.
		def inspect
			"\#<#{self.class} path=#{@path.inspect}>"
		end
		
		# @attribute [String] The path to the UNIX socket.
		attr :path
		
		# Check if the socket is currently bound and accepting connections.
		# @returns [Boolean] True if the socket is bound and accepting connections, false otherwise.
		def bound?
			self.connect do
				return true
			end
		rescue Errno::ECONNREFUSED
			return false
		rescue Errno::ENOENT
			return false
		end
		
		# Bind the UNIX socket, handling stale socket files.
		# @yields {|socket| ...} If a block is given, yields the bound socket.
		# 	@parameter socket [Socket] The bound socket.
		# @returns [Array(Socket)] The bound socket.
		# @raises [Errno::EADDRINUSE] If the socket is still in use by another process.
		def bind(...)
			super
		rescue Errno::EADDRINUSE
			# If you encounter EADDRINUSE from `bind()`, you can check if the socket is actually accepting connections by attempting to `connect()` to it. If the socket is still bound by an active process, the connection will succeed. Otherwise, it should be safe to `unlink()` the path and try again.
			if !bound?
				File.unlink(@path) rescue nil
				retry
			else
				raise
			end
		end
	end
	
	# @parameter path [String]
	# @parameter type Socket type
	# @parameter options keyword arguments passed through to {UNIXEndpoint#initialize}
	#
	# @returns [UNIXEndpoint]
	def self.unix(path = "", type = ::Socket::SOCK_STREAM, **options)
		UNIXEndpoint.new(path, type, **options)
	end
end
