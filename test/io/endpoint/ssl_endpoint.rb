# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require "io/endpoint/ssl_endpoint"
require "io/endpoint/shared_endpoint"
require "sus/fixtures/openssl"

describe IO::Endpoint::SSLEndpoint do
	with "valid certificates" do
		include Sus::Fixtures::OpenSSL::ValidCertificateContext
		include Sus::Fixtures::OpenSSL::VerifiedCertificateContext
		
		let(:endpoint) {IO::Endpoint.tcp("localhost", 0)}
		let(:server_endpoint) {subject.new(endpoint, ssl_context: server_context)}
		
		def client_endpoint(address)
			endpoint = IO::Endpoint::AddressEndpoint.new(address)
			return subject.new(endpoint, ssl_context: client_context)
		end
		
		it "can connect to bound address" do
			bound = server_endpoint.bound
			
			bound.bind do |server|
				expect(server).to be_a(::OpenSSL::SSL::SSLServer)
				
				peer, address = server.accept
				peer.accept
				peer.close
			end
			
			bound.sockets.each do |server|
				connect_endpoint = client_endpoint(server.local_address)
				
				client = connect_endpoint.connect
				expect(client).to be_a(::OpenSSL::SSL::SSLSocket)
				expect(client).to be(:sync_close)
				
				# Wait for the connection to be closed.
				client.wait_readable
				
				client.close
			end
		ensure
			bound&.close
		end
	end
	
	with "invalid certificates" do
		include Sus::Fixtures::OpenSSL::InvalidCertificateContext
		include Sus::Fixtures::OpenSSL::VerifiedCertificateContext
		
		let(:endpoint) {IO::Endpoint.tcp("localhost", 0)}
		let(:server_endpoint) {subject.new(endpoint, ssl_context: server_context)}
		
		def client_endpoint(address)
			endpoint = IO::Endpoint::AddressEndpoint.new(address)
			return subject.new(endpoint, ssl_context: client_context)
		end
		
		it "doesn't cause the accept loop to exit" do
			bound = server_endpoint.bound
			
			bound.bind do |server|
				wrapper = IO::Endpoint::Wrapper.default
				
				wrapper.accept(server) do |peer|
					peer.close
				end
			rescue IOError
				# Normal exit from bound&.close
			end
			
			2.times do
				bound.sockets.each do |server|
					connect_endpoint = client_endpoint(server.local_address)
					begin
						connect_endpoint.connect
					rescue
						# Ignore.
					end
				end
			end
		ensure
			bound&.close
		end
	end
	
	with "a simple SSL endpoint" do
		let(:endpoint) {subject.new(IO::Endpoint.tcp("localhost", 0))}
		
		with "#to_s" do
			it "can generate a string representation" do
				expect(endpoint.to_s).to be =~ /ssl:/
			end
		end

		with "#inspect" do
			it "can generate a string representation" do
				expect(endpoint.inspect).to be =~ /#<IO::Endpoint::SSLEndpoint endpoint=/
			end
		end
	end
end
