# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/wrapper'

describe IO::Endpoint::Wrapper do
	it "implements a default schedule method" do
		queue = ::Thread::Queue.new
		
		subject.new.schedule do
			queue << :scheduled
		end
		
		expect(queue.pop).to be == :scheduled
	end
end
