# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/wrapper'

describe IO::Endpoint::Wrapper do
	it "does not implement a default async method" do
		expect do
			subject.new.async{}
		end.to raise_exception(NotImplementedError)
	end
end
