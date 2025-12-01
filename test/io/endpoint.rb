# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "io/endpoint"

describe IO::Endpoint do
	with ".file_descriptor_limit" do
		it "has a file descriptor limit" do
			expect(IO::Endpoint.file_descriptor_limit).to be_a Integer
		end
	end
end
