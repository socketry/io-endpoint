# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "io/endpoint/tls/openssl"
require "sus/fixtures/openssl"

describe IO::Endpoint::TLS::OpenSSL do
	include Sus::Fixtures::OpenSSL::ValidCertificateContext
	
	with ".build_certificate_store" do
		it "builds an OpenSSL certificate store from trusted certificates" do
			trust_store = IO::Endpoint::TLS::TrustStore.parse(certificate_authority_certificate.to_pem)
			
			openssl_certificate_store = subject.build_certificate_store(trust_store)
			
			expect(openssl_certificate_store).to be_a(::OpenSSL::X509::Store)
			expect(openssl_certificate_store.verify(certificate)).to be_truthy
		end
		
		it "builds an OpenSSL certificate store from system certificates" do
			trust_store = IO::Endpoint::TLS::TrustStore.new(system_certificates: true)
			
			openssl_certificate_store = subject.build_certificate_store(trust_store)
			
			expect(openssl_certificate_store).to be_a(::OpenSSL::X509::Store)
		end
	end
end
