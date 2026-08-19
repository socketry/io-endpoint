# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.
# Copyright, 2026, by Delton Ding.

require "io/endpoint/unix_endpoint"
require "with_temporary_directory"
require "sus/fixtures/async/reactor_context"
require "async/variable"

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
		
		thread = Thread.new do
			accepted_socket, _address = server.accept
			accepted_socket.close
		end
		
		endpoint.connect do |socket|
			expect(socket).to be_a(Socket)
			
			# Wait for the connection to be closed.
			socket.wait_readable
		end
		
		thread.value
	ensure
		sockets&.each(&:close)
		thread&.kill
		thread&.join
	end
	
	it "can determine whether it is bound" do
		sockets = endpoint.bind
		
		expect(endpoint).to be(:bound?)
	ensure
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
	
	with "#symlink?" do
		it "returns false for a normal path" do
			expect(endpoint).not.to be(:symlink?)
		end
	end
	
	with "a long path" do
		let(:path) {File.join(temporary_directory, "a" * 140, "test.ipc")}
		let(:endpoint) {subject.new(path)}
		
		it "does not change the current working directory" do
			cwd = Dir.pwd
			
			subject.new(path)
			
			expect(Dir.pwd).to be == cwd
		end
		
		it "binds using a short path and creates a symlink at the original path" do
			sockets = endpoint.bind
			
			expect(sockets.first).to be_a(Socket)
			
			# Verify that a symlink was created at the original path
			expect(File.symlink?(endpoint.path)).to be == true
			expect(endpoint).to be(:symlink?)
			
			# Verify that the symlink points to a shorter path
			actual_socket_path = File.readlink(endpoint.path)
			expect(actual_socket_path.bytesize).to be < endpoint.path.bytesize
		ensure
			sockets&.each(&:close)
		end
	end
end

describe IO::Endpoint do
	let(:endpoint) {subject.unix("/tmp/test.ipc", Socket::SOCK_DGRAM)}
	
	with ".unix" do
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
