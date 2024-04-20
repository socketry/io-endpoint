# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require_relative 'host_endpoint'
require_relative 'generic'

require 'openssl'

module OpenSSL
	module SSL
		module SocketForwarder
			unless method_defined?(:close_on_exec=)
				def close_on_exec=(value)
					to_io.close_on_exec = value
				end
			end
			
			unless method_defined?(:local_address)
				def local_address
					to_io.local_address
				end
			end
			
			unless method_defined?(:wait)
				def wait(*arguments)
					to_io.wait(*arguments)
				end
			end
			
			unless method_defined?(:wait_readable)
				def wait_readable(*arguments)
					to_io.wait_readable(*arguments)
				end
			end
			
			unless method_defined?(:wait_writable)
				def wait_writable(*arguments)
					to_io.wait_writable(*arguments)
				end
			end
			
			if IO.method_defined?(:timeout)
				unless method_defined?(:timeout)
					def timeout
						to_io.timeout
					end
				end
				
				unless method_defined?(:timeout=)
					def timeout=(value)
						to_io.timeout = value
					end
				end
			end
		end
	end
end

module IO::Endpoint
	class SSLEndpoint < Generic
		def initialize(endpoint, **options)
			super(**options)
			
			@endpoint = endpoint
			
			if ssl_context = options[:ssl_context]
				@context = build_context(ssl_context)
			else
				@context = nil
			end
		end
		
		def to_s
			"\#<#{self.class} #{@endpoint}>"
		end
		
		def address
			@endpoint.address
		end
		
		def hostname
			@options[:hostname] || @endpoint.hostname
		end
		
		attr :endpoint
		attr :options
		
		def params
			@options[:ssl_params]
		end
		
		def build_context(context = ::OpenSSL::SSL::SSLContext.new)
			if params = self.params
				context.set_params(params)
			end
			
			# context.setup
			# context.freeze
			
			return context
		end
		
		def context
			@context ||= build_context
		end
		
		# Connect to the underlying endpoint and establish a SSL connection.
		# @yield [Socket] the socket which is being connected
		# @return [Socket] the connected socket
		def bind(*arguments, **options, &block)
			if block_given?
				@endpoint.bind(*arguments, **options) do |server|
					yield ::OpenSSL::SSL::SSLServer.new(server, self.context)
				end
			else
				@endpoint.bind(*arguments, **options).map do |server|
					::OpenSSL::SSL::SSLServer.new(server, self.context)
				end
			end
		end
		
		# Connect to the underlying endpoint and establish a SSL connection.
		# @yield [Socket] the socket which is being connected
		# @return [Socket] the connected socket
		def connect(&block)
			socket = ::OpenSSL::SSL::SSLSocket.new(@endpoint.connect, self.context)
			
			if hostname = self.hostname
				socket.hostname = hostname
			end
			
			begin
				socket.connect
			rescue
				socket.close
				raise
			end
			
			return socket unless block_given?
				
			begin
				yield socket
			ensure
				socket.close
			end
		end
		
		def each
			return to_enum unless block_given?
			
			@endpoint.each do |endpoint|
				yield self.class.new(endpoint, **@options)
			end
		end
	end

	# @param arguments
	# @param ssl_context [OpenSSL::SSL::SSLContext, nil]
	# @param hostname [String, nil]
	# @param options keyword arguments passed through to {Endpoint.tcp}
	#
	# @return [SSLEndpoint]
	def self.ssl(*arguments, ssl_context: nil, hostname: nil, **options)
		SSLEndpoint.new(self.tcp(*arguments, **options), ssl_context: ssl_context, hostname: hostname)
	end
end
