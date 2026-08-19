# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module IO::Endpoint
	# @namespace
	module TLS
		# Represents transport-neutral trusted certificate sources.
		class TrustStore
			# Matches individual certificates in a PEM bundle.
			CERTIFICATE_PATTERN = /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m
			private_constant :CERTIFICATE_PATTERN
			
			# Load a PEM-encoded certificate bundle from the given path.
			# @parameter path [String | Interface(:to_path)] The path to the certificate bundle.
			# @parameter options [Hash] Options forwarded to {.parse}.
			# @returns [TrustStore] The loaded trust store.
			def self.load(path, **options)
				return parse(File.read(path), **options)
			end
			
			# Parse a PEM-encoded certificate bundle into a trust store.
			# @parameter certificate_bundle [String] One or more trusted certificates encoded as PEM.
			# @parameter system_certificates [Boolean] Whether system-provided trusted certificates should be included.
			# @returns [TrustStore] The parsed trust store.
			# @raises [ArgumentError] If the bundle does not contain any certificates.
			# @raises [TypeError] If the bundle is not a string.
			def self.parse(certificate_bundle, system_certificates: false)
				unless certificate_bundle.is_a?(String)
					raise TypeError, "The certificate bundle must be provided as a string!"
				end
				
				certificates = certificate_bundle.scan(CERTIFICATE_PATTERN)
				
				unless certificates.any?
					raise ArgumentError, "The certificate bundle does not contain any certificates!"
				end
				
				return self.new(certificates: certificates, system_certificates: system_certificates)
			end
			
			# Initialize a trust store from PEM-encoded trusted certificates.
			# @parameter certificates [Array(String)] The trusted certificates encoded as PEM.
			# @parameter system_certificates [Boolean] Whether system-provided trusted certificates should be included.
			# @raises [ArgumentError] If no source of trusted certificates is specified.
			# @raises [TypeError] If certificates are not provided as strings.
			def initialize(certificates: [], system_certificates: false)
				unless certificates.is_a?(Array) && certificates.all?{|certificate| certificate.is_a?(String)}
					raise TypeError, "Certificates must be provided as an array of strings!"
				end
				
				unless certificates.any? || system_certificates
					raise ArgumentError, "At least one source of trusted certificates must be specified!"
				end
				
				@certificates = certificates
				@system_certificates = system_certificates
			end
			
			# @attribute [Array(String)] The trusted certificate bundles encoded as PEM.
			attr :certificates
			
			# Whether system-provided trusted certificates should be included.
			# @returns [Boolean] `true` if system-provided trusted certificates should be included.
			def system_certificates?
				@system_certificates
			end
			
			# Get a representation of the trust store without exposing certificate material.
			# @returns [String] A redacted representation of the trust store.
			def inspect
				attributes = {
					certificates: @certificates.size,
					system_certificates: @system_certificates,
				}
				
				return "\#<#{self.class} #{attributes.inspect}>"
			end
		end
	end
end
