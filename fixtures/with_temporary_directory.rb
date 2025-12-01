# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

require "tmpdir"

module WithTemporaryDirectory
	attr :temporary_directory
	
	def around(&block)
		Dir.mktmpdir do |temporary_directory|
			@temporary_directory = temporary_directory
			super(&block)
		ensure
			@temporary_directory = nil
		end
	end
end
