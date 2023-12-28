# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require_relative 'generic'

module IO::Endpoint
	class CompositeEndpoint < Generic
		def initialize(endpoints, **options)
			super(**options)
			@endpoints = endpoints
		end
		
		def each(&block)
			@endpoints.each do |endpoint|
				endpoint.each(&block)
			end
		end
		
		def connect(&block)
			last_error = nil
			
			@endpoints.each do |endpoint|
				begin
					return endpoint.connect(&block)
				rescue => last_error
				end
			end
			
			raise last_error
		end
		
		def bind(&block)
			if block_given?
				@endpoints.each do |endpoint|
					endpoint.bind(&block)
				end
			else
				@endpoints.map(&:bind).flatten.compact
			end
		end
	end
	
	def self.composite(*endpoints, **options)
		CompositeEndpoint.new(endpoints, **options)
	end
end
