# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/shared_endpoint'
require 'with_temporary_directory'

describe IO::Endpoint::SharedEndpoint do
	include WithTemporaryDirectory
	
	let(:path) {File.join(temporary_directory, "test.ipc")}
	let(:internal_endpoint) {IO::Endpoint::UNIXEndpoint.new(path)}
	
	it "can bind to address" do
		endpoint = subject.bound(internal_endpoint)
		
		endpoint.bind do |socket|
			expect(socket).to be_a(Socket)
		end
	end
	
	it "can connect to address" do
		server = internal_endpoint.bind
		
		server.listen(1)
		
		thread = Thread.new do
			peer, address = server.accept
			peer.close
		end
		
		endpoint = subject.connected(internal_endpoint)
		
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
