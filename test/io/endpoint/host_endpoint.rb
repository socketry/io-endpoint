# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2025, by Samuel Williams.

require "io/endpoint/host_endpoint"
require "io/endpoint/shared_endpoint"

describe IO::Endpoint::HostEndpoint do
	let(:specification) {["localhost", 0, nil, ::Socket::SOCK_STREAM]}
	let(:endpoint) {subject.new(specification)}
	
	it "can bind to address" do
		endpoint.bind do |socket|
			expect(socket).to be_a(Socket)
		end
	end
	
	it "can connect to bound address" do
		bound = endpoint.bound
		
		bound.bind do |server|
			expect(server).to be_a(Socket)
			
			peer, address = server.accept
			peer.close
		end
		
		bound.sockets.each do |server|
			# server_endpoint = IO::Endpoint::AddressEndpoint.new(server.local_address)
			server_endpoint = subject.new(["localhost", server.local_address.ip_port, nil, ::Socket::SOCK_STREAM])
			
			client = server_endpoint.connect
			expect(client).to be_a(Socket)
			
			# Wait for the connection to be closed.
			client.wait_readable
			
			client.close
		end
	ensure
		bound&.close
	end
	
	with "#inspect" do
		it "can generate a string representation" do
			expect(endpoint.inspect).to be == "#<IO::Endpoint::HostEndpoint name=\"localhost\" service=0 family=nil type=1 protocol=nil flags=nil>"
		end
	end
end

describe IO::Endpoint do
	with ".udp" do
		let(:endpoint) {subject.udp("localhost", 0)}
		
		it "can construct endpoint from path" do
			expect(endpoint).to be_a(IO::Endpoint::HostEndpoint)
			expect(endpoint).to have_attributes(specification: be == ["localhost", 0, nil, ::Socket::SOCK_DGRAM])
		end
	end
	
	with ".tcp" do
		let(:endpoint) {subject.tcp("localhost", 0)}
		
		it "can construct endpoint from path" do
			expect(endpoint).to be_a(IO::Endpoint::HostEndpoint)
			expect(endpoint).to have_attributes(specification: be == ["localhost", 0, nil, ::Socket::SOCK_STREAM])
		end
	end
end
