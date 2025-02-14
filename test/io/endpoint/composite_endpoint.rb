# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require "io/endpoint/composite_endpoint"
require "io/endpoint/unix_endpoint"
require "with_temporary_directory"

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
		servers&.each(&:close)
		thread&.join
	end
	
	with "#size" do
		it "returns the number of endpoints" do
			expect(endpoint.size).to be == 1
		end
	end
	
	with "#endpoints" do
		it "returns the endpoints" do
			expect(endpoint.endpoints).to be == [internal_endpoint]
		end
	end
	
	with "#with" do
		it "can propagate options" do
			updated_endpoint = endpoint.with(timeout: 10)
			
			# Did't change original:
			expect(endpoint).to have_attributes(timeout: be_nil)
			
			endpoint.each do |endpoint|
				expect(endpoint).to have_attributes(timeout: be_nil)
			end
			
			# Changed copy:
			expect(updated_endpoint).to have_attributes(timeout: be == 10)
			
			updated_endpoint.each do |endpoint|
				expect(endpoint).to have_attributes(timeout: be == 10)
			end
		end
	end
	
	with "#to_s" do
		it "can generate a string representation" do
			expect(endpoint.to_s).to be =~ /composite:/
		end
	end

	with "#inspect" do
		it "can generate a string representation" do
			expect(endpoint.inspect).to be =~ /#<IO::Endpoint::CompositeEndpoint endpoints=/
		end
	end
end
