# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

require "digest"
require "fileutils"
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
		def self.temporary_socket_path_for(raw_path)
			checksum = Digest::SHA1.hexdigest(raw_path)
			filename = "#{checksum}.ipc"
			
			socket_path = File.join(Dir.tmpdir, filename)
			return socket_path if socket_path.bytesize <= MAX_UNIX_PATH_BYTES
			
			raise ArgumentError, "Unable to construct a UNIX socket path within #{MAX_UNIX_PATH_BYTES} bytes for #{raw_path.inspect}"
		end
		
		# Initialize a new UNIX domain socket endpoint.
		# @parameter path [String] The path to the UNIX socket.
		# @parameter type [Integer] The socket type (defaults to Socket::SOCK_STREAM).
		# @parameter options [Hash] Additional options to pass to the parent class.
		def initialize(path, type = Socket::SOCK_STREAM, **options)
			@raw_path = path
			@path = if path.bytesize <= MAX_UNIX_PATH_BYTES
				path
			else
				self.class.temporary_socket_path_for(@raw_path)
			end
			
			super(Address.unix(@path, type), **options)
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
		
		# @attribute [String] The original path.
		# This may differ from {#path} when the original path is too long for a UNIX socket address.
		attr :raw_path
		
		def symlink?
			@raw_path != @path
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
		
		private def create_symlink_if_required!
			return unless symlink?
			
			if File.symlink?(@raw_path) && File.readlink(@raw_path) == @path
				return
			end
			
			FileUtils.mkdir_p(File.dirname(@raw_path))
			File.symlink(@path, @raw_path)
		end
		
		private def unlink_stale_paths!
			File.unlink(@raw_path) rescue nil
			if symlink?
				File.unlink(@path) rescue nil
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
