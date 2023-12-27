# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/unix_endpoint'
require 'with_temporary_directory'

describe IO::Endpoint::UNIXEndpoint do
	include WithTemporaryDirectory
	
	let(:path) {File.join(temporary_directory, "test.ipc")}
	let(:endpoint) {subject.new(path)}
	
	it "can bind to address" do
		expect(endpoint).not.to be(:bound?)
		
		endpoint.bind do |socket|
			expect(socket).to be_a(Socket)
		end
	end
	
	it "can connect to address" do
		sockets = endpoint.bind
		server = sockets.first
		
		expect(server).to be_a(Socket)
		
		server.listen(1)
		
		thread = Thread.new do
			while true
				peer, address = server.accept
				peer.close
			end
		ensure
			server&.close
		end
		
		expect(endpoint).to be(:bound?)
		
		endpoint.connect do |socket|
			expect(socket).to be_a(Socket)
			
			# Wait for the connection to be closed.
			socket.wait_readable
			
			socket.close
		end
	ensure
		sockets&.each(&:close)
		thread&.kill
	end
end

describe IO::Endpoint do
	let(:endpoint) {subject.unix("/tmp/test.ipc")}
	
	with '.unix' do
		it "can construct endpoint from path" do
			expect(endpoint).to be_a(IO::Endpoint::UNIXEndpoint)
			expect(endpoint).to have_attributes(path: be == "/tmp/test.ipc")
		end
	end
end
