# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/ssl_endpoint'
require 'io/endpoint/shared_endpoint'
require 'sus/fixtures/openssl/hosts_certificates_context'

describe IO::Endpoint::SSLEndpoint do
	include Sus::Fixtures::OpenSSL::HostsCertificatesContext
	
	let(:endpoint) {IO::Endpoint.tcp("localhost", 0)}
	let(:server_endpoint) {subject.new(endpoint, ssl_context: server_context)}
	
	def client_endpoint(endpoint)
		subject.new(endpoint, ssl_context: client_context)
	end
	
	it "can connect to bound address" do
		bound = server_endpoint.bound
		
		bound.bind do |server|
			expect(server).to be_a(Socket)
			
			peer, address = server.accept
			peer.close
		end
		
		bound.sockets.each do |server|
			connect_endpoint = client_endpoint(server.local_address)
			
			client = connect_endpoint.connect
			expect(client).to be_a(Socket)
			
			# Wait for the connection to be closed.
			client.wait_readable
			
			client.close
		end
	ensure
		bound&.close
	end
end
