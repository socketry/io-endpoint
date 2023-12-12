# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require_relative 'address_endpoint'

module IO::Endpoint
	class HostEndpoint < Generic
		def initialize(specification, **options)
			super(**options)
			
			@specification = specification
		end
		
		def to_s
			nodename, service, family, socktype, protocol, flags = @specification
			
			"\#<#{self.class} name=#{nodename.inspect} service=#{service.inspect} family=#{family.inspect} type=#{socktype.inspect} protocol=#{protocol.inspect} flags=#{flags.inspect}>"
		end
		
		def address
			@specification
		end
		
		def hostname
			@specification.first
		end
		
		# Try to connect to the given host by connecting to each address in sequence until a connection is made.
		# @yield [Socket] the socket which is being connected, may be invoked more than once
		# @return [Socket] the connected socket
		# @raise if no connection could complete successfully
		def connect
			last_error = nil
			
			Addrinfo.foreach(*@specification) do |address|
				begin
					socket = Socket.connect(address, **@options)
				rescue Errno::ECONNREFUSED, Errno::ENETUNREACH, Errno::EAGAIN => last_error
				else
					return socket unless block_given?
					
					begin
						return yield(socket)
					ensure
						socket.close
					end
				end
			end
			
			raise last_error
		end
		
		# Invokes the given block for every address which can be bound to.
		# @yield [Socket] the bound socket
		# @return [Array<Socket>] an array of bound sockets
		def bind(&block)
			Addrinfo.foreach(*@specification).map do |address|
				Socket.bind(address, **@options, &block)
			end
		end
		
		# @yield [AddressEndpoint] address endpoints by resolving the given host specification
		def each
			return to_enum unless block_given?
			
			Addrinfo.foreach(*@specification) do |address|
				yield AddressEndpoint.new(address, **@options)
			end
		end
	end
	
	# @param arguments nodename, service, family, socktype, protocol, flags. `socktype` will be set to Socket::SOCK_STREAM.
	# @param options keyword arguments passed on to {HostEndpoint#initialize}
	#
	# @return [HostEndpoint]
	def self.tcp(*arguments, **options)
		arguments[3] = ::Socket::SOCK_STREAM
		
		HostEndpoint.new(arguments, **options)
	end

	# @param arguments nodename, service, family, socktype, protocol, flags. `socktype` will be set to Socket::SOCK_DGRAM.
	# @param options keyword arguments passed on to {HostEndpoint#initialize}
	#
	# @return [HostEndpoint]
	def self.udp(*arguments, **options)
		arguments[3] = ::Socket::SOCK_DGRAM
		
		HostEndpoint.new(arguments, **options)
	end
end
