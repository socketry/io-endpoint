# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'tmpdir'

module WithTemporaryDirectory
	attr :temporary_directory
	
	def around
		Dir.mktmpdir do |temporary_directory|
			@temporary_directory = temporary_directory
			yield
		end
	end
end
