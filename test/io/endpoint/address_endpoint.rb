# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/address_endpoint'

describe IO::Endpoint::AddressEndpoint do
	let(:options) {Hash.new}
	let(:address) {Addrinfo.tcp('localhost', 0)}
	let(:endpoint) {subject.new(address)}
	
	it "can bind to address" do
		endpoint.bind do |socket|
			expect(socket).to be_a(Socket)
		end
	end
	
	it "can connect to address" do
		server = endpoint.bind
		expect(server).to be_a(Socket)
		
		server.listen(1)
		
		thread = Thread.new do
			peer, address = server.accept
			peer.close
		end
		
		subject.new(server.local_address).connect do |socket|
			expect(socket).to be_a(Socket)
			
			# Wait for the connection to be closed.
			socket.wait_readable
			
			socket.close
		end
	ensure
		server&.close
		thread&.join
	end
	
	with "#to_s" do
		it "can generate a string representation" do
			expect(endpoint.to_s).to be =~ /#<IO::Endpoint::AddressEndpoint address=/
		end
	end
end
