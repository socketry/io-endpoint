# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'socket'

require_relative 'generic'
require_relative 'wrapper'

module IO::Endpoint
	class AddressEndpoint < Generic
		def initialize(address, **options)
			super(**options)
			
			@address = address
		end
		
		def to_s
			"\#<#{self.class} #{@address.inspect}>"
		end
		
		attr :address
		
		# Bind a socket to the given address. If a block is given, the socket will be automatically closed when the block exits.
		# @yield [Socket] the bound socket
		# @return [Socket] the bound socket
		def bind(&block)
			Wrapper.bind(@address, **@options, &block)
		end
		
		# Connects a socket to the given address. If a block is given, the socket will be automatically closed when the block exits.
		# @return [Socket] the connected socket
		def connect(&block)
			Wrapper.connect(@address, **@options, &block)
		end
	end
end
