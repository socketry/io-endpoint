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
	
	with "Happy Eyeballs" do
		it "can connect using Happy Eyeballs algorithm" do
			bound = endpoint.bound
			
			bound.bind do |server|
				expect(server).to be_a(Socket)
				
				thread = Thread.new do
					peer, address = server.accept
					peer.close
				end
				
				# Wait for server to be ready
				Thread.pass until thread.status == "sleep"
				
				server_endpoint = subject.new(["localhost", server.local_address.ip_port, nil, ::Socket::SOCK_STREAM])
				
				client = server_endpoint.connect
				expect(client).to be_a(Socket)
				
				# Wait for the connection to be closed
				client.wait_readable
				client.close
				
				thread.join
			end
		ensure
			bound&.close
		end
		
		it "raises error when all connections fail" do
			# Try to connect to a port that's definitely not listening
			endpoint = subject.new(["localhost", 65535, nil, ::Socket::SOCK_STREAM])
			
			expect do
				endpoint.connect
			end.to raise_exception(Errno::ECONNREFUSED)
		end
		
		it "respects happy_eyeballs_delay option" do
			bound = endpoint.bound
			
			bound.bind do |server|
				expect(server).to be_a(Socket)
				
				thread = Thread.new do
					peer, address = server.accept
					peer.close
				end
				
				Thread.pass until thread.status == "sleep"
				
				server_endpoint = subject.new(["localhost", server.local_address.ip_port, nil, ::Socket::SOCK_STREAM], happy_eyeballs_delay: 0.1)
				
				start_time = Time.now
				client = server_endpoint.connect
				elapsed = Time.now - start_time
				
				# Connection should succeed quickly (before the delay)
				expect(elapsed).to be < 0.1
				expect(client).to be_a(Socket)
				
				client.close
				thread.join
			end
		ensure
			bound&.close
		end
		
		it "can override happy_eyeballs_delay per connection" do
			bound = endpoint.bound
			
			bound.bind do |server|
				expect(server).to be_a(Socket)
				
				thread = Thread.new do
					peer, address = server.accept
					peer.close
				end
				
				Thread.pass until thread.status == "sleep"
				
				server_endpoint = subject.new(["localhost", server.local_address.ip_port, nil, ::Socket::SOCK_STREAM], happy_eyeballs_delay: 0.2)
				
				start_time = Time.now
				client = server_endpoint.connect(happy_eyeballs_delay: 0.01)
				elapsed = Time.now - start_time
				
				# Connection should succeed quickly (using the override delay)
				expect(elapsed).to be < 0.1
				expect(client).to be_a(Socket)
				
				client.close
				thread.join
			end
		ensure
			bound&.close
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
