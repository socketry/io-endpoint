# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require 'io/endpoint/unix_endpoint'
require 'with_temporary_directory'
require 'sus/fixtures/async/reactor_context'
require 'async/variable'

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
		
		# Wait for the server to start accepting connections:
		# I noticed on slow CI, that the connect would fail because the server has not called `#accept` yet, even if it's bound and listening!
		Thread.pass until thread.status == "sleep"
		
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
	
	with "#to_s" do
		it "can generate a string representation" do
			expect(endpoint.to_s).to be =~ /unix:.*test\.ipc/
		end
	end

	with "#inspect" do
		it "can generate a string representation" do
			expect(endpoint.inspect).to be =~ /#<IO::Endpoint::UNIXEndpoint path=.*test\.ipc/
		end
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
				bound = Async::Variable.new
				
				server_task = Async do
					endpoint.bind do |server|
						bound.resolve(true)
						
						expect(server).to be_a(Socket)
						packet, address = server.recvfrom(512)
						
						expect(packet).to be == "Hello World!"
					end
				end
				
				bound.wait
				
				endpoint.connect do |peer|
					peer.sendmsg("Hello World!")
				end
				
				server_task.wait
			end
		end
	end
end
