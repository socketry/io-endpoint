# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.
# Copyright, 2026, by Delton Ding.

require "io/endpoint/unix_endpoint"
require "io/endpoint/exclusive_unix_endpoint"
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
	
	it "does not remove the path when a bound endpoint closes" do
		bound_endpoint = endpoint.bound
		
		expect(File).to be(:socket?, path)
		bound_endpoint.close
		expect(File).to be(:socket?, path)
	ensure
		bound_endpoint&.close
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

describe IO::Endpoint::ExclusiveUNIXEndpoint do
	include WithTemporaryDirectory
	
	let(:path) {File.join(temporary_directory, "test.ipc")}
	let(:endpoint) {subject.new(path)}
	
	it "removes the path when the bound endpoint closes" do
		bound_endpoint = endpoint.bound
		lock_path = endpoint.address.unix_path + ".lock"
		
		expect(File).to be(:socket?, path)
		expect(File).to be(:file?, lock_path)
		bound_endpoint.close
		expect(File).not.to be(:exist?, path)
		expect(File).not.to be(:exist?, lock_path)
	ensure
		bound_endpoint&.close
	end
	
	it "releases ownership when closing the socket raises" do
		File.write(path, "owned")
		lock = File.open(path + ".lock", File::RDWR | File::CREAT, 0o600)
		ownership = subject::Ownership.new(lock, [path])
		
		socket = Class.new do
			def close
				raise IOError, "Could not close socket!"
			end
		end.new
		
		socket.instance_variable_set(:@exclusive_ownership, ownership)
		socket.extend(subject::OwnedSocket)
		
		expect do
			socket.close
		end.to raise_exception(IOError, message: be == "Could not close socket!")
		
		expect(File).not.to be(:exist?, path)
		expect(lock).to be(:closed?)
	ensure
		lock&.close unless lock&.closed?
	end
	
	it "removes the path when a bind block completes" do
		threads = endpoint.bind do |socket|
			expect(socket).to be_a(Socket)
		end
		
		threads.each(&:join)
		expect(File).not.to be(:exist?, path)
	end
	
	it "preserves ownership through a delegating endpoint" do
		wrapper_class = Class.new(IO::Endpoint::Generic) do
			def initialize(endpoint)
				super()
				@endpoint = endpoint
			end
			
			def bind(...)
				@endpoint.bind(...)
			end
		end
		
		bound_endpoint = wrapper_class.new(endpoint).bound
		expect(File).to be(:socket?, path)
		
		bound_endpoint.close
		expect(File).not.to be(:exist?, path)
	ensure
		bound_endpoint&.close
	end
	
	it "does not replace an active socket" do
		bound_endpoint = endpoint.bound
		
		expect do
			subject.new(path).bound
		end.to raise_exception(Errno::EADDRINUSE)
		
		expect(File).to be(:socket?, path)
	ensure
		bound_endpoint&.close
	end
	
	it "does not remove a replacement filesystem entry when closed" do
		bound_endpoint = endpoint.bound
		File.unlink(path)
		File.write(path, "replacement")
		
		bound_endpoint.close
		expect(File.read(path)).to be == "replacement"
	ensure
		bound_endpoint&.close
	end
	
	it "does not remove a replacement lock file when closed" do
		bound_endpoint = endpoint.bound
		lock_path = endpoint.address.unix_path + ".lock"
		File.unlink(lock_path)
		File.write(lock_path, "replacement")
		
		bound_endpoint.close
		expect(File.read(lock_path)).to be == "replacement"
	ensure
		bound_endpoint&.close
	end
	
	it "recovers a stale socket left by a previous owner" do
		stale_endpoint = IO::Endpoint::UNIXEndpoint.new(path).bound
		stale_endpoint.close
		
		expect(File).to be(:socket?, path)
		
		bound_endpoint = endpoint.bound
		expect(File).to be(:socket?, path)
		
		bound_endpoint.close
		expect(File).not.to be(:exist?, path)
	ensure
		stale_endpoint&.close
		bound_endpoint&.close
	end
	
	it "does not replace an unrelated filesystem entry" do
		File.write(path, "important")
		
		expect do
			endpoint.bound
		end.to raise_exception(Errno::EADDRINUSE)
		
		expect(File.read(path)).to be == "important"
	end
	
	with "a long path" do
		let(:path) {File.join(temporary_directory, "a" * 140, "test.ipc")}
		
		it "removes both paths when closed" do
			bound_endpoint = endpoint.bound
			target_path = endpoint.address.unix_path
			
			expect(File).to be(:symlink?, path)
			expect(File).to be(:socket?, target_path)
			
			bound_endpoint.close
			
			expect(File).not.to be(:symlink?, path)
			expect(File).not.to be(:exist?, target_path)
		ensure
			bound_endpoint&.close
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
	
	with ".exclusive_unix" do
		it "constructs an exclusive UNIX endpoint" do
			endpoint = subject.exclusive_unix("/tmp/test.ipc")
			
			expect(endpoint).to be_a(IO::Endpoint::ExclusiveUNIXEndpoint)
			expect(endpoint).to have_attributes(path: be == "/tmp/test.ipc")
		end
		
		with "a unique prefix" do
			include WithTemporaryDirectory
			
			it "constructs distinct endpoints within an existing directory" do
				first = subject.exclusive_unix(temporary_directory, unique: "worker")
				second = subject.exclusive_unix(temporary_directory, unique: "worker")
				
				expect(File.dirname(first.path)).to be == temporary_directory
				expect(File.basename(first.path)).to be =~ /\Aworker-#{Process.pid}-[0-9a-f]{16}\.ipc\z/
				expect(second.path).not.to be == first.path
			end
			
			it "binds and removes the generated socket and lock paths" do
				endpoint = subject.exclusive_unix(temporary_directory, unique: "worker")
				bound_endpoint = endpoint.bound
				lock_path = endpoint.address.unix_path + ".lock"
				
				expect(File).to be(:socket?, endpoint.path)
				expect(File).to be(:file?, lock_path)
				
				bound_endpoint.close
				
				expect(File).not.to be(:exist?, endpoint.path)
				expect(File).not.to be(:exist?, lock_path)
			ensure
				bound_endpoint&.close
			end
			
			it "requires a valid prefix and an existing directory" do
				file_path = File.join(temporary_directory, "file")
				File.write(file_path, "not a directory")
				
				expect do
					subject.exclusive_unix(temporary_directory, unique: false)
				end.to raise_exception(ArgumentError)
				
				expect do
					subject.exclusive_unix(temporary_directory, unique: "worker/nested")
				end.to raise_exception(ArgumentError)
				
				expect do
					subject.exclusive_unix(File.join(temporary_directory, "missing"), unique: "worker")
				end.to raise_exception(Errno::ENOENT)
				
				expect do
					subject.exclusive_unix(file_path, unique: "worker")
				end.to raise_exception(Errno::ENOTDIR)
			end
		end
	end
end
