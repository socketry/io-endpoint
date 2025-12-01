# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

require_relative "address_endpoint"

module IO::Endpoint
	# Represents an endpoint for a hostname and service that resolves to multiple addresses.
	class HostEndpoint < Generic
		# Initialize a new host endpoint.
		# @parameter specification [Array] The host specification array containing nodename, service, family, socktype, protocol, and flags.
		# @parameter options [Hash] Additional options to pass to the parent class.
		def initialize(specification, **options)
			super(**options)
			
			@specification = specification
		end
		
		# Get a string representation of the host endpoint.
		# @returns [String] A string representation showing hostname and service.
		def to_s
			"host:#{@specification[0]}:#{@specification[1]}"
		end
		
		# Get a detailed string representation of the host endpoint.
		# @returns [String] A detailed string representation including all specification parameters.
		def inspect
			nodename, service, family, socktype, protocol, flags = @specification
			
			"\#<#{self.class} name=#{nodename.inspect} service=#{service.inspect} family=#{family.inspect} type=#{socktype.inspect} protocol=#{protocol.inspect} flags=#{flags.inspect}>"
		end
		
		# @attribute [Array] The host specification array.
		attr :specification
		
		# Get the hostname from the specification.
		# @returns [String, nil] The hostname (nodename) from the specification.
		def hostname
			@specification[0]
		end
		
		# Get the service from the specification.
		# @returns [String, Integer, nil] The service (port) from the specification.
		def service
			@specification[1]
		end
		
		# Try to connect ot the given host using the given wrapper.
		#
		# The implementation uses Happy Eyeballs (RFC 8305) algorithm if it makes sense to do so. This attempts IPv6 and IPv4 connections in parallel, preferring IPv6 but starting IPv4 attempts after a short delay to improve connection speed.
		#
		# @parameter happy_eyeballs_delay [Float] Delay in seconds before starting IPv4 connections (defaults to @options[:happy_eyeballs_delay] or 0.05)
		# @yields {|socket| ...} the socket which is being connected, may be invoked more than once.
		# @returns [Socket] the connected socket.
		# @raises if no connection could complete successfully.
		def connect(wrapper = self.wrapper, happy_eyeballs_delay: nil, &block)
			happy_eyeballs_delay ||= @options.fetch(:happy_eyeballs_delay, 0.05)
			
			# Collect all addresses first:
			addresses = Addrinfo.foreach(*@specification).to_a
			
			# If only one address, use simple sequential connection:
			return connect_sequential(addresses, wrapper, &block) if addresses.size <= 1
			
			# Separate IPv6 and fallback addresses:
			ipv6_addresses, fallback_addresses = addresses.partition(&:ipv6?)
			
			# If we only have one protocol family, use sequential connection:
			if ipv6_addresses.empty? || fallback_addresses.empty?
				return connect_sequential(addresses, wrapper, &block)
			end
			
			# Happy Eyeballs: try IPv6 immediately, fallback addresses after delay:
			connected_socket = nil
			connection_errors = []
			pending_count = 0
			ipv4_started = false
			mutex = Mutex.new
			condition_variable = ConditionVariable.new
			
			# Helper to attempt a connection:
			attempt_connection = proc do |address|
				should_continue = mutex.synchronize do
					if connected_socket
						false
					else
						pending_count += 1
						true
					end
				end
				next unless should_continue
				
				begin
					socket = wrapper.connect(address, **@options)
					mutex.synchronize do
						if connected_socket
							# Another connection succeeded first, close this one:
							socket.close
						else
							connected_socket = socket
							condition_variable.broadcast
						end
					end
				rescue => error
					mutex.synchronize do
						connection_errors << error
						pending_count -= 1
						condition_variable.broadcast
					end
				end
			end
			
			# Start IPv6 connections immediately:
			ipv6_addresses.each do |address|
				wrapper.schedule do
					attempt_connection.call(address)
				end
			end
			
			# Start fallback connections after delay:
			fallback_delayed = wrapper.schedule do
				sleep(happy_eyeballs_delay)
				should_start = mutex.synchronize do
					if connected_socket
						false
					else
						ipv4_started = true
						true
					end
				end
				
				if should_start
					fallback_addresses.each do |address|
						wrapper.schedule do
							attempt_connection.call(address)
						end
					end
				end
			end
			
			# Wait for a successful connection or all failures
			mutex.synchronize do
				loop do
					break if connected_socket
					# All connections have completed if:
					# - IPv4 connections have started (or were skipped)
					# - No pending connections remain
					break if ipv4_started && pending_count == 0
					condition_variable.wait(mutex)
				end
			end
			
			# Ensure fallback scheduling completes:
			fallback_delayed.join if fallback_delayed.alive?
			
			if connected_socket
				return connected_socket unless block_given?
				
				begin
					return yield(connected_socket)
				ensure
					connected_socket.close
				end
			else
				# All connections failed, raise the last error
				raise connection_errors.last || IOError.new("Connection failed!")
			end
		end
		
		# Invokes the given block for every address which can be bound to.
		# @yields {|socket| ...} For each address that can be bound, yields the bound socket.
		# 	@parameter socket [Socket] The bound socket.
		# @returns [Array<Socket>] an array of bound sockets
		def bind(wrapper = self.wrapper, &block)
			Addrinfo.foreach(*@specification).map do |address|
				wrapper.bind(address, **@options, &block)
			end
		end
		
		# @yields {|endpoint| ...} For each resolved address, yields an address endpoint.
		# 	@parameter endpoint [AddressEndpoint] An address endpoint.
		def each
			return to_enum unless block_given?
			
			Addrinfo.foreach(*@specification) do |address|
				yield AddressEndpoint.new(address, **@options)
			end
		end
		
		private
		
		# Sequential connection fallback for single address or single protocol family
		def connect_sequential(addresses, wrapper, &block)
			last_error = nil
			
			addresses.each do |address|
				begin
					socket = wrapper.connect(address, **@options)
				rescue Errno::ECONNREFUSED, Errno::ENETUNREACH, Errno::EAGAIN => last_error
					# Try next address
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
	end
	
	# @parameter arguments nodename, service, family, socktype, protocol, flags. `socktype` will be set to Socket::SOCK_STREAM.
	# @parameter options keyword arguments passed on to {HostEndpoint#initialize}
	#
	# @returns [HostEndpoint]
	def self.tcp(*arguments, **options)
		arguments[3] = ::Socket::SOCK_STREAM
		
		HostEndpoint.new(arguments, **options)
	end
	
	# @parameter arguments nodename, service, family, socktype, protocol, flags. `socktype` will be set to Socket::SOCK_DGRAM.
	# @parameter options keyword arguments passed on to {HostEndpoint#initialize}
	#
	# @returns [HostEndpoint]
	def self.udp(*arguments, **options)
		arguments[3] = ::Socket::SOCK_DGRAM
		
		HostEndpoint.new(arguments, **options)
	end
end
