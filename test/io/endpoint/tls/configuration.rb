# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "io/endpoint/tls/configuration"

describe IO::Endpoint::TLS::Configuration do
	let(:certificate) {"trusted certificate"}
	let(:certificates) {[certificate]}
	let(:trust_store) {IO::Endpoint::TLS::TrustStore.new(certificates: certificates)}
	let(:certificate_chain) {"certificate chain"}
	let(:private_key) {"private key"}
	
	with "certificate material" do
		let(:configuration) do
			subject.new(
				trust_store: trust_store,
				certificate_chain: certificate_chain,
				private_key: private_key,
			)
		end
		
		it "retains the supplied certificate material" do
			expect(configuration.trust_store).to be == trust_store
			expect(configuration.certificate_chain).to be_equal(certificate_chain)
			expect(configuration.private_key).to be_equal(private_key)
		end
		
		it "verifies peers by default when a trust store is provided" do
			expect(configuration.verification).to be == :peer
		end
		
		it "does not expose certificate or private key material when inspected" do
			representation = configuration.inspect
			
			expect(representation).not.to be(:include?, certificate)
			expect(representation).not.to be(:include?, certificate_chain)
			expect(representation).not.to be(:include?, private_key)
			expect(representation).to be(:include?, "private_key")
		end
	end
	
	with "incomplete local identity" do
		it "rejects a certificate chain without a private key" do
			expect do
				subject.new(certificate_chain: certificate_chain)
			end.to raise_exception(ArgumentError, message: be =~ /provided together/)
		end
		
		it "rejects a private key without a certificate chain" do
			expect do
				subject.new(private_key: private_key)
			end.to raise_exception(ArgumentError, message: be =~ /provided together/)
		end
	end
	
	with "an unsupported verification policy" do
		it "rejects the policy" do
			expect do
				subject.new(verification: :unsupported)
			end.to raise_exception(ArgumentError, message: be =~ /Unsupported verification policy/)
		end
	end
end
