# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require_relative "endpoint/version"
require_relative "endpoint/generic"
require_relative "endpoint/shared_endpoint"

require_relative 'readable'

module IO::Endpoint
	def self.file_descriptor_limit
		Process.getrlimit(Process::RLIMIT_NOFILE).first
	end
end
