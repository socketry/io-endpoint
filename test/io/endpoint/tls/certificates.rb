# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "io/endpoint/tls/certificates"

describe IO::Endpoint::TLS::Certificates do
	let(:first_certificate) {"-----BEGIN CERTIFICATE-----\nfirst\n-----END CERTIFICATE-----"}
	let(:second_certificate) {"-----BEGIN CERTIFICATE-----\nsecond\n-----END CERTIFICATE-----"}
	
	with ".parse" do
		it "splits a certificate bundle while preserving order" do
			certificates = subject.parse("#{first_certificate}\n#{second_certificate}\n")
			
			expect(certificates).to be == [first_certificate, second_certificate]
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
end
