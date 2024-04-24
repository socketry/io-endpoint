# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/unix_endpoint'
require 'with_temporary_directory'
require 'sus/fixtures/async/reactor_context'

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
		thread&.kill
		sockets&.each(&:close)
	end
end

describe IO::Endpoint do
	let(:endpoint) {subject.unix("/tmp/test.ipc", Socket::SOCK_DGRAM)}
	
	with '.unix' do
		it "can construct endpoint from path" do
			expect(endpoint).to be_a(IO::Endpoint::UNIXEndpoint)
			expect(endpoint).to have_attributes(path: be == "/tmp/test.ipc")
		end

		with "a simple UDP server" do
			include Sus::Fixtures::Async::ReactorContext
			
			it "can send and receive UDP messages" do
				server_task = Async do
					endpoint.bind do |server|
						expect(server).to be_a(Socket)
						packet, address = server.recvfrom(512)
						
						expect(packet).to be == "Hello World!"
					end
				end
				
				endpoint.connect do |peer|
					peer.sendmsg("Hello World!")
				end
				
				server_task.wait
			end
		end
	end
end
