# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/bound_endpoint'
require 'io/endpoint/unix_endpoint'
require 'with_temporary_directory'

describe IO::Endpoint::BoundEndpoint do
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
		sockets = internal_endpoint.bind
		server = sockets.first
		
		server.listen(1)
		
		thread = Thread.new do
			peer, address = server.accept
			peer.close
		end
		
		endpoint = internal_endpoint.connected
		
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
	
	with "timeouts" do
		let(:timeout) {1.0}
		
		let(:internal_endpoint) {IO::Endpoint::UNIXEndpoint.new(path, timeout: timeout)}
		
		it "can accept with distinct timeouts" do
			expect(internal_endpoint.timeout).to be == timeout
			
			bound_endpoint = internal_endpoint.bound
			expect(bound_endpoint.timeout).to be == timeout
			
			expect(bound_endpoint.sockets).not.to be(:empty?)
			bound_endpoint.sockets.each do |socket|
				expect(socket).to have_attributes(timeout: be_nil)
			end
			
			thread = Thread.new do
				threads = bound_endpoint.accept do |peer, address|
					expect(peer).to have_attributes(timeout: be == timeout)
					peer.close
				end
			ensure
				threads&.each(&:kill)
			end
			
			connected_endpoint = internal_endpoint.connected
			
			connected_endpoint.connect do |socket|
				expect(socket).to have_attributes(timeout: be == timeout)
				
				# Wait for the connection to be closed.
				socket.wait_readable
			end
		ensure
			thread&.kill
			bound_endpoint&.close
			connected_endpoint&.close
		end
	end
end
