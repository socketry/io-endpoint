# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint'

describe IO::Endpoint::Generic do
	let(:options) {Hash.new}
	let(:endpoint) {subject.new(**options)}
	
	with options: {hostname: "localhost"} do
		it "has a hostname" do
			expect(endpoint.hostname).to be == "localhost"
		end
	end
	
	with options: {reuse_port: true} do
		it "has reuse_port?" do
			expect(endpoint.reuse_port?).to be == true
		end
	end
	
	with options: {reuse_address: true} do
		it "has reuse_address?" do
			expect(endpoint.reuse_address?).to be == true
		end
	end	
end
