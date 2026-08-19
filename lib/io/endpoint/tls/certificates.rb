# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module IO::Endpoint
	# @namespace
	module TLS
		# Utilities for parsing PEM-encoded certificates.
		module Certificates
			# Matches individual certificates in a PEM bundle.
			CERTIFICATE_PATTERN = /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m
			private_constant :CERTIFICATE_PATTERN
			
			# Parse a PEM-encoded certificate bundle into individual certificates.
			# @parameter certificate_bundle [String] One or more certificates encoded as PEM.
			# @returns [Array(String)] The individual PEM-encoded certificates in their original order.
			# @raises [ArgumentError] If the bundle does not contain any certificates.
			# @raises [TypeError] If the bundle is not a string.
			def self.parse(certificate_bundle)
				unless certificate_bundle.is_a?(String)
					raise TypeError, "The certificate bundle must be provided as a string!"
				end
				
				certificates = certificate_bundle.scan(CERTIFICATE_PATTERN)
				
				unless certificates.any?
					raise ArgumentError, "The certificate bundle does not contain any certificates!"
				end
				
				return certificates
			end
		end
	end
end
