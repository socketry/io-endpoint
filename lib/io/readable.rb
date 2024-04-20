class IO
	unless method_defined?(:readable?)
		def readable?
			if self.wait_readable(0).nil?
				# timeout means it is not eof
				return true
			else
				!self.eof?
			end
		end
	end
end

require 'socket'

class BasicSocket
	unless method_defined?(:readable?)
		def readable?
			# Is it likely that the socket is still connected?
			# May return false positive, but won't return false negative.
			return false unless super
			
			# If we can wait for the socket to become readable, we know that the socket may still be open.
			result = to_io.recv_nonblock(1, MSG_PEEK, exception: false)
			
			# No data was available - newer Ruby can return nil instead of empty string:
			return false if result.nil?
			
			# Either there was some data available, or we can wait to see if there is data avaialble.
			return !result.empty? || result == :wait_readable
		rescue Errno::ECONNRESET
			# This might be thrown by recv_nonblock.
			return false
		end
	end
end

require 'stringio'

class StringIO
	unless method_defined?(:readable?)
		def readable?
			!eof?
		end
	end
end

require 'openssl'

class OpenSSL::SSL::SSLSocket
	unless method_defined?(:readable?)
		def readable?
			to_io.readable?
		end
	end
end
