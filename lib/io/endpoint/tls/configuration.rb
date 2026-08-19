# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "trust_store"

module IO::Endpoint
	# @namespace
	module TLS
		# Represents transport-neutral TLS certificate and verification configuration.
		class Configuration
			# Initialize a TLS configuration from PEM-encoded certificate and private key material.
			# @parameter trust_store [TrustStore | Nil] The trusted certificate sources.
			# @parameter certificate_chain [String | Nil] The local certificate chain encoded as PEM, with the leaf certificate first.
			# @parameter private_key [String | Nil] The private key encoded as PEM.
			# @parameter verification [Symbol | Nil] The peer verification policy: `:none`, `:peer`, or `:required`. When omitted, `:peer` is used if a trust store is provided.
			# @raises [ArgumentError] If the certificate chain and private key are not provided together, or the verification policy is invalid.
			def initialize(trust_store: nil, certificate_chain: nil, private_key: nil, verification: nil)
				if certificate_chain.nil? != private_key.nil?
					raise ArgumentError, "The certificate chain and private key must be provided together!"
				end
				
				verification = :peer if verification.nil? && trust_store
				unless [nil, :none, :peer, :required].include?(verification)
					raise ArgumentError, "Unsupported verification policy: #{verification.inspect}!"
				end
				
				@trust_store = trust_store
				@certificate_chain = certificate_chain
				@private_key = private_key
				@verification = verification
			end
			
			# @attribute [TrustStore | Nil] The trusted certificate sources.
			attr :trust_store
			
			# @attribute [String | Nil] The local certificate chain encoded as PEM, with the leaf certificate first.
			attr :certificate_chain
			
			# @attribute [String | Nil] The private key encoded as PEM.
			attr :private_key
			
			# @attribute [Symbol | Nil] The peer verification policy.
			attr :verification
			
			# Get a representation of the configuration without exposing certificate or private key material.
			# @returns [String] A redacted representation of the configuration.
			def inspect
				attributes = {
					trust_store: !@trust_store.nil?,
					certificate_chain: !@certificate_chain.nil?,
					private_key: !@private_key.nil?,
					verification: @verification,
				}
				
				return "\#<#{self.class} #{attributes.inspect}>"
			end
		end
	end
end
