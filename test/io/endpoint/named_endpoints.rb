# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "io/endpoint/host_endpoint"
require "io/endpoint/shared_endpoint"
require "io/endpoint/named_endpoints"

describe IO::Endpoint::NamedEndpoints do
	let(:endpoint1) {IO::Endpoint.tcp("localhost", 0)}
	let(:endpoint2) {IO::Endpoint.tcp("localhost", 0)}
	let(:endpoints) {{http1: endpoint1, http2: endpoint2}}
	let(:named_endpoints) {subject.new(endpoints)}
	
	with "#initialize" do
		it "can be initialized with a hash of endpoints" do
			expect(named_endpoints).to be_a(subject)
			expect(named_endpoints.endpoints).to be == endpoints
		end
	end
	
	with "#[]" do
		it "can access endpoints by key" do
			expect(named_endpoints[:http1]).to be == endpoint1
			expect(named_endpoints[:http2]).to be == endpoint2
			expect(named_endpoints[:nonexistent]).to be_nil
		end
	end
	
	with "#each" do
		it "can enumerate endpoints with names" do
			results = []
			named_endpoints.each do |name, endpoint|
				results << [name, endpoint]
			end
			
			expect(results).to have_attributes(size: be == 2)
			expect(results[0]).to be == [:http1, endpoint1]
			expect(results[1]).to be == [:http2, endpoint2]
		end
		
		it "returns an enumerator when no block is given" do
			enumerator = named_endpoints.each
			expect(enumerator).to be_a(Enumerator)
			expect(enumerator.to_a).to have_attributes(size: be == 2)
		end
	end
	
	with "#bound" do
		it "creates a new instance with all endpoints bound" do
			bound_named = named_endpoints.bound
			expect(bound_named).to be_a(subject)
			expect(bound_named).not.to be == named_endpoints
			
			# Check that endpoints are bound
			bound_named.each do |name, bound_endpoint|
				expect(bound_endpoint).to respond_to(:sockets)
			end
		ensure
			bound_named&.each{|name, endpoint| endpoint.close}
		end
		
		it "propagates options to bound endpoints" do
			bound_named = named_endpoints.bound(backlog: 5)
			expect(bound_named).to be_a(subject)
		ensure
			bound_named&.each{|name, endpoint| endpoint.close}
		end
	end
	
	with "#connected" do
		it "creates a new instance with all endpoints connected" do
			bound = endpoint1.bound
			server = bound.sockets.first
			server.listen(1)
			
			thread = Thread.new do
				loop do
					peer, address = server.accept
					peer.close
				rescue
					break
				end
			end
			
			client_endpoint = IO::Endpoint.tcp("localhost", server.local_address.ip_port)
			named = subject.new({primary: client_endpoint})
			
			connected_named = named.connected
			expect(connected_named).to be_a(subject)
			expect(connected_named).not.to be == named
			
			# Check that endpoints are connected
			connected_named.each do |name, connected_endpoint|
				expect(connected_endpoint).to respond_to(:socket)
			end
		ensure
			bound&.close
			thread&.kill
			thread&.join
		end
	end
	
	with "#close" do
		it "closes all endpoints" do
			bound1 = endpoint1.bound
			bound2 = endpoint2.bound
			
			named = subject.new({
				http1: bound1,
				http2: bound2
			})
			
			expect(bound1.sockets).not.to be(:empty?)
			expect(bound2.sockets).not.to be(:empty?)
			
			named.close
			
			expect(bound1.sockets).to be(:empty?)
			expect(bound2.sockets).to be(:empty?)
		end
	end
	
	with "#endpoints" do
		it "returns the endpoints hash" do
			expect(named_endpoints.endpoints).to be == endpoints
		end
	end
	
	with "#to_s" do
		it "can generate a string representation" do
			expect(named_endpoints.to_s).to be =~ /named:/
			expect(named_endpoints.to_s).to be =~ /http1:/
			expect(named_endpoints.to_s).to be =~ /http2:/
		end
	end
	
	with "#inspect" do
		it "can generate a detailed string representation" do
			expect(named_endpoints.inspect).to be =~ /#<IO::Endpoint::NamedEndpoints/
			expect(named_endpoints.inspect).to be =~ /http1:/
			expect(named_endpoints.inspect).to be =~ /http2:/
			expect(named_endpoints.inspect).to be =~ /HostEndpoint/
		end
	end
end

describe IO::Endpoint do
	with ".named" do
		let(:endpoint1) {IO::Endpoint.tcp("localhost", 0)}
		let(:endpoint2) {IO::Endpoint.tcp("localhost", 0)}
		
		it "can create NamedEndpoints from keyword arguments" do
			named = subject.named(http1: endpoint1, http2: endpoint2)
			expect(named).to be_a(IO::Endpoint::NamedEndpoints)
			expect(named[:http1]).to be == endpoint1
			expect(named[:http2]).to be == endpoint2
		end
	end
end
