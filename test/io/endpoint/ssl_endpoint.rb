# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/ssl_endpoint'
require 'io/endpoint/shared_endpoint'
require 'sus/fixtures/openssl'

describe IO::Endpoint::SSLEndpoint do
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
			peer.close
		end
		
		bound.sockets.each do |server|
			connect_endpoint = client_endpoint(server.local_address)
			
			client = connect_endpoint.connect
			expect(client).to be_a(::OpenSSL::SSL::SSLSocket)
			
			# Wait for the connection to be closed.
			client.to_io.wait_readable
			
			client.close
		end
	ensure
		bound&.close
	end
end
