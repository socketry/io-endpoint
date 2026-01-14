# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

require "digest"
require "tmpdir"

require_relative "address_endpoint"

module IO::Endpoint
	# This class doesn't exert ownership over the specified unix socket and ensures exclusive access by using `flock` where possible.
	class UNIXEndpoint < AddressEndpoint
		# The maximum safe UNIX socket path length in bytes (not including the null terminator).
		MAX_UNIX_PATH_BYTES = 103
		
		# Compute a stable temporary UNIX socket path for an overlong path.
		# @parameter path [String] The original (possibly overlong) path.
		# @returns [String] A short, stable path suitable for {Address.unix}.
		def self.temporary_socket_path_for(path)
			checksum = Digest::SHA256.hexdigest(path)
			filename = "#{checksum}.ipc"
			
			socket_path = File.join(Dir.tmpdir, filename)
			return socket_path if socket_path.bytesize <= MAX_UNIX_PATH_BYTES

			raise ArgumentError, "Unable to construct a UNIX socket path within #{MAX_UNIX_PATH_BYTES} bytes for #{path.inspect}"
		end
		
		# Initialize a new UNIX domain socket endpoint.
		# @parameter path [String] The path to the UNIX socket.
		# @parameter type [Integer] The socket type (defaults to Socket::SOCK_STREAM).
		# @parameter options [Hash] Additional options to pass to the parent class.
		def initialize(path, type = Socket::SOCK_STREAM, **options)
			@path = path
			@socket_path = if path.bytesize <= MAX_UNIX_PATH_BYTES
				path
			else
				self.class.temporary_socket_path_for(path)
			end
			
			super(Address.unix(@socket_path, type), **options)
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
		
		# @attribute [String] The effective path used for binding/connecting.
		# This may differ from {#path} when the original path is too long for a UNIX socket address.
		attr :socket_path
		
		def symlink?
			@socket_path != @path
		end
		
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
			result = super
			create_symlink_if_required!
			return result
		rescue Errno::EADDRINUSE
			# If you encounter EADDRINUSE from `bind()`, you can check if the socket is actually accepting connections by attempting to `connect()` to it. If the socket is still bound by an active process, the connection will succeed. Otherwise, it should be safe to `unlink()` the path and try again.
			if !bound?
				unlink_stale_paths!
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

			
	private def create_symlink_if_required!
		return unless symlink?
		
		if File.symlink?(@path) && File.readlink(@path) == @socket_path
			return
		end
		
		File.symlink(@socket_path, @path)
	end
	
	private def unlink_stale_paths!
		File.unlink(@socket_path) rescue nil
		if symlink?
			File.unlink(@path) rescue nil
		end
	end
end
