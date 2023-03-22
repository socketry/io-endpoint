# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/composite_endpoint'
require 'with_temporary_directory'

describe IO::Endpoint::CompositeEndpoint do
	include WithTemporaryDirectory
	
	let(:path) {File.join(temporary_directory, "test.ipc")}
	let(:internal_endpoint) {IO::Endpoint::UNIXEndpoint.new(path)}
 	let(:endpoint) {subject.new([internal_endpoint])}
	
	it "can bind to address" do
		endpoint.bind do |socket|
			expect(socket).to be_a(Socket)
		end
	end
	
	it "can connect to address" do
		servers = endpoint.bind
		expect(servers).to be_a(Array)
		expect(servers).to have_attributes(size: be == 1)
		server = servers.first
		
		server.listen(1)
		
		thread = Thread.new do
			peer, address = server.accept
			peer.close
		end
		
		endpoint.connect do |socket|
			expect(socket).to be_a(Socket)
			
			# Wait for the connection to be closed.
			socket.wait_readable
			
			socket.close
		end
	ensure
		server&.close
		thread&.join
	end
end
