# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require "io/endpoint"
require "io/endpoint/host_endpoint"

describe IO::Endpoint::Generic do
	let(:options) {Hash.new}
	let(:endpoint) {subject.new(**options)}
	
	with options: {linger: 10} do
		it "has linger" do
			expect(endpoint.linger).to be == 10
		end
	end
	
	with options: {timeout: 10} do
		it "has timeout" do
			expect(endpoint.timeout).to be == 10
		end
	end
	
	with options: {local_address: Addrinfo.tcp("localhost", 0)} do
		it "has local_address" do
			expect(endpoint.local_address).to be_equal options[:local_address]
		end
	end
	
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
	
	with ".parse" do
		let(:url) {"tcp://localhost:1234"}
		let(:endpoint) {subject.parse(url, **options)}
		
		it "can convert URL to endpoint" do
			expect(endpoint).to be_a(IO::Endpoint::HostEndpoint)
			expect(endpoint.hostname).to be == "localhost"
			expect(endpoint.service).to be == 1234
		end
	end
end
