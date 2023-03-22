# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/socket_endpoint'
require 'with_temporary_directory'

describe IO::Endpoint::SocketEndpoint do
	include WithTemporaryDirectory
	
	let(:path) {File.join(temporary_directory, "test.ipc")}
	let(:internal_endpoint) {IO::Endpoint::UNIXEndpoint.new(path)}
	
	it "can bind to address" do
		internal_endpoint.bind do |internal_socket|
			endpoint = subject.new(internal_socket)
			
			endpoint.bind do |socket|
				expect(socket).to be_equal(internal_socket)
			end
		end
	end
	
	it "can connect to address" do
		server = internal_endpoint.bind
		expect(server).to be_a(Socket)
		
		server.listen(1)
		
		thread = Thread.new do
			peer, address = server.accept
			peer.close
		end
		
		internal_endpoint.connect do |internal_socket|
			endpoint = subject.new(internal_socket)
			
			endpoint.connect do |socket|
				expect(socket).to be_a(Socket)
				
				# Wait for the connection to be closed.
				socket.wait_readable
				
				socket.close
			end
		end
	ensure
		server&.close
		thread&.join
	end
end
