# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.
# Copyright, 2026, by Delton Ding.

require "securerandom"

require_relative "unix_endpoint"

module IO::Endpoint
	# Represents an exclusively owned endpoint for a UNIX domain socket.
	class ExclusiveUNIXEndpoint < UNIXEndpoint
		# Represents the ownership lifecycle for an exclusive UNIX socket.
		class Ownership
			# Initialize an exclusive ownership lifecycle.
			# @parameter lock [File] The exclusive ownership lock.
			# @parameter paths [Array(String)] The owned filesystem paths.
			def initialize(lock, paths)
				@lock = lock
				@released = false
				@lock_identity = [lock.path, lock.stat]
				
				@path_identities = paths.filter_map do |path|
					[path, File.lstat(path)]
				rescue Errno::ENOENT
					# The path was removed before ownership could be recorded:
				end
			end
			
			# Set whether the ownership lock should close on exec.
			# @parameter value [Boolean] Whether to close the lock on exec.
			def close_on_exec=(value)
				@lock.close_on_exec = value
			end
			
			# Release ownership and remove the exclusively owned paths.
			def release
				return if @released
				@released = true
				
				@path_identities.each do |path_identity|
					unlink_if_owned(*path_identity)
				end
				
				unlink_if_owned(*@lock_identity)
			ensure
				@lock.close unless @lock.closed?
			end
			
			# Unlink a path if it still refers to the owned filesystem entry.
			private def unlink_if_owned(path, identity)
				current = File.lstat(path)
				
				if current.dev == identity.dev && current.ino == identity.ino
					File.unlink(path)
				end
			rescue Errno::ENOENT
				# The path was already removed:
			end
		end
		
		# Adds exclusive ownership behavior to a bound UNIX socket.
		module OwnedSocket
			# Set whether the socket and its ownership lock should close on exec.
			# @parameter value [Boolean] Whether to close on exec.
			def close_on_exec=(value)
				@exclusive_ownership.close_on_exec = value
				super
			end
			
			# Close the socket and release its filesystem paths.
			def close
				super
			ensure
				@exclusive_ownership.release
			end
		end
		
		# Bind and exclusively own the UNIX socket paths.
		# @yields {|socket| ...} If a block is given, yields the bound socket.
		# 	@parameter socket [Socket] The bound socket.
		# @returns [Array(Socket)] The bound socket.
		# @raises [Errno::EADDRINUSE] If another exclusive endpoint owns the path.
		def bind(wrapper = self.wrapper, &block)
			lock = acquire_exclusive_lock
			
			begin
				# The ownership lifecycle must be attached before a bind block can run:
				result = super(wrapper, &nil)
				ownership = Ownership.new(lock, paths)
				
				result.each do |socket|
					socket.instance_variable_set(:@exclusive_ownership, ownership)
					socket.extend(OwnedSocket)
				end
				
				lock = nil
				
				if block
					return result.map do |socket|
						wrapper.schedule do
							begin
								block.call(socket)
							ensure
								socket.close
							end
						end
					end
				else
					return result
				end
			rescue
				if ownership || lock
					result&.each(&:close)
					Ownership.new(lock, []).release if lock && !lock.closed?
				end
				
				raise
			end
		end
		
		# Acquire the lock which serializes exclusive ownership and stale path recovery.
		# @returns [File] The locked file.
		# @raises [Errno::EADDRINUSE] If another exclusive endpoint owns the path.
		private def acquire_exclusive_lock
			lock_path = @address.unix_path + ".lock"
			lock = File.open(lock_path, File::RDWR | File::CREAT, 0o600)
			
			unless lock.flock(File::LOCK_EX | File::LOCK_NB)
				lock.close
				raise Errno::EADDRINUSE, @path
			end
			
			return lock
		rescue
			lock&.close unless lock&.closed?
			raise
		end
	end
	
	# @parameter path [String]
	# @parameter type Socket type
	# @parameter unique [String | Nil] An optional prefix for a unique socket path generated within `path`.
	# @parameter options keyword arguments passed through to {ExclusiveUNIXEndpoint#initialize}
	#
	# @returns [ExclusiveUNIXEndpoint]
	def self.exclusive_unix(path = "", type = ::Socket::SOCK_STREAM, unique: nil, **options)
		unless unique.nil?
			unless unique.is_a?(String) && !unique.empty? && File.basename(unique) == unique && unique != "." && unique != ".."
				raise ArgumentError, "Unique prefix must be a non-empty basename!"
			end
			
			unless File.stat(path).directory?
				raise Errno::ENOTDIR, path
			end
			
			path = File.join(path, "#{unique}-#{Process.pid}-#{SecureRandom.hex(8)}.ipc")
		end
		
		ExclusiveUNIXEndpoint.new(path, type, **options)
	end
end
