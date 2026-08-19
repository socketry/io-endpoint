# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "io/endpoint/tls/trust_store"
require "with_temporary_directory"

describe IO::Endpoint::TLS::TrustStore do
	let(:certificate) {"trusted certificate"}
	let(:certificates) {[certificate]}
	
	with "custom certificates" do
		let(:trust_store) {subject.new(certificates: certificates)}
		
		it "retains the supplied certificate material" do
			expect(trust_store.certificates).to be_equal(certificates)
		end
		
		it "does not expose certificate material when inspected" do
			representation = trust_store.inspect
			
			expect(representation).not.to be(:include?, certificate)
			expect(representation).to be(:include?, "certificates")
		end
	end
	
	with ".load" do
		include WithTemporaryDirectory
		
		let(:certificate) {"-----BEGIN CERTIFICATE-----\ntrusted\n-----END CERTIFICATE-----"}
		let(:path) {File.join(temporary_directory, "certificates.pem")}
		
		it "loads and parses a certificate bundle" do
			File.write(path, certificate)
			
			trust_store = subject.load(path, system_certificates: true)
			
			expect(trust_store.certificates).to be == [certificate]
			expect(trust_store).to be(:system_certificates?)
		end
		
		it "propagates file loading errors" do
			expect do
				subject.load(path)
			end.to raise_exception(Errno::ENOENT)
		end
	end
	
	with ".parse" do
		let(:first_certificate) {"-----BEGIN CERTIFICATE-----\nfirst\n-----END CERTIFICATE-----"}
		let(:second_certificate) {"-----BEGIN CERTIFICATE-----\nsecond\n-----END CERTIFICATE-----"}
		
		it "splits a certificate bundle" do
			trust_store = subject.parse("#{first_certificate}\n#{second_certificate}\n")
			
			expect(trust_store.certificates).to be == [first_certificate, second_certificate]
		end
		
		it "rejects a bundle without certificates" do
			expect do
				subject.parse("not a certificate bundle")
			end.to raise_exception(ArgumentError, message: be =~ /does not contain any certificates/)
		end
		
		it "rejects a bundle which is not a string" do
			expect do
				subject.parse(Object.new)
			end.to raise_exception(TypeError, message: be =~ /must be provided as a string/)
		end
	end
	
	with "system certificates" do
		it "can include them" do
			trust_store = subject.new(system_certificates: true)
			
			expect(trust_store).to be(:system_certificates?)
		end
	end
	
	with "no trusted certificate source" do
		it "is rejected" do
			expect do
				subject.new
			end.to raise_exception(ArgumentError, message: be =~ /At least one source/)
		end
	end
	
	with "an unsupported certificate representation" do
		it "is rejected" do
			expect do
				subject.new(certificates: certificate)
			end.to raise_exception(TypeError, message: be =~ /array of strings/)
		end
	end
end
