# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "io/endpoint/tls/openssl"
require "sus/fixtures/openssl"

describe IO::Endpoint::TLS::OpenSSL do
	include Sus::Fixtures::OpenSSL::ValidCertificateContext
	
	let(:trust_store) do
		IO::Endpoint::TLS::TrustStore.parse(certificate_authority_certificate.to_pem)
	end
	
	with ".build_certificate_store" do
		it "builds an OpenSSL certificate store from trusted certificates" do
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
	
	with ".apply" do
		let(:context) {::OpenSSL::SSL::SSLContext.new}
		
		it "applies the trust store and local identity" do
			configuration = IO::Endpoint::TLS::Configuration.new(
				trust_store: trust_store,
				certificate_chain: [certificate.to_pem, certificate_authority_certificate.to_pem],
				private_key: key.to_pem,
			)
			
			result = subject.apply(context, configuration)
			
			expect(result).to be_equal(context)
			expect(context.cert_store.verify(certificate)).to be_truthy
			expect(context.cert.to_der).to be == certificate.to_der
			expect(context.extra_chain_cert.map(&:to_der)).to be == [certificate_authority_certificate.to_der]
			expect(context.key.public_to_der).to be == key.public_to_der
		end
		
		it "preserves the verification mode when no policy is specified" do
			context.verify_mode = ::OpenSSL::SSL::VERIFY_PEER
			configuration = IO::Endpoint::TLS::Configuration.new
			
			subject.apply(context, configuration)
			
			expect(context.verify_mode).to be == ::OpenSSL::SSL::VERIFY_PEER
		end
		
		it "disables peer verification when requested" do
			context.verify_mode = ::OpenSSL::SSL::VERIFY_PEER
			context.verify_hostname = true
			configuration = IO::Endpoint::TLS::Configuration.new(verification: :none)
			
			subject.apply(context, configuration)
			
			expect(context.verify_mode).to be == ::OpenSSL::SSL::VERIFY_NONE
			expect(context.verify_hostname).to be_falsey
		end
		
		it "enables peer verification" do
			configuration = IO::Endpoint::TLS::Configuration.new(verification: :peer)
			
			subject.apply(context, configuration)
			
			expect(context.verify_mode).to be == ::OpenSSL::SSL::VERIFY_PEER
			expect(context.verify_hostname).to be_falsey
		end
		
		it "enables hostname verification for verified clients" do
			configuration = IO::Endpoint::TLS::Configuration.new(verification: :peer)
			
			subject.apply(context, configuration, hostname: "example.com")
			
			expect(context.verify_hostname).to be_truthy
		end
		
		it "requires a peer certificate" do
			configuration = IO::Endpoint::TLS::Configuration.new(verification: :required)
			required_verification = ::OpenSSL::SSL::VERIFY_PEER | ::OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
			
			subject.apply(context, configuration)
			
			expect(context.verify_mode).to be == required_verification
		end
	end
end
