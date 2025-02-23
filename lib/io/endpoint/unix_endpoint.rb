# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require_relative "address_endpoint"

module IO::Endpoint
	# This class doesn't exert ownership over the specified unix socket and ensures exclusive access by using `flock` where possible.
	class UNIXEndpoint < AddressEndpoint
		def initialize(path, type = Socket::SOCK_STREAM, **options)
			# I wonder if we should implement chdir behaviour in here if path is longer than 104 characters.
			super(Address.unix(path, type), **options)
			
			@path = path
		end
		
		def to_s
			"unix:#{@path}"
		end
		
		def inspect
			"\#<#{self.class} path=#{@path.inspect}>"
		end
		
		attr :path
		
		def bound?
			self.connect do
				return true
			end
		rescue Errno::ECONNREFUSED
			return false
		rescue Errno::ENOENT
			return false
		end
		
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
	
	# @param path [String]
	# @param type Socket type
	# @param options keyword arguments passed through to {UNIXEndpoint#initialize}
	#
	# @return [UNIXEndpoint]
	def self.unix(path = "", type = ::Socket::SOCK_STREAM, **options)
		UNIXEndpoint.new(path, type, **options)
	end
end
