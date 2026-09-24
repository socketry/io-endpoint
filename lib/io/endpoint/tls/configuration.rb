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
			# @parameter certificate_chain [Array(String) | Nil] The ordered local certificate chain encoded as individual PEM strings, with the leaf certificate followed by any intermediates.
			# @parameter private_key [String | Nil] The private key encoded as PEM.
			# @parameter verification [Symbol | Nil] The peer verification policy: `:none`, `:peer`, or `:required`. When omitted, `:peer` is used if a trust store is provided.
			# @raises [ArgumentError] If the certificate chain and private key are not provided together, or the verification policy is invalid.
			# @raises [TypeError] If the certificate chain or private key uses an unsupported representation.
			def initialize(trust_store: nil, certificate_chain: nil, private_key: nil, verification: nil)
				if certificate_chain
					unless certificate_chain.is_a?(Array) && certificate_chain.all?{|certificate| certificate.is_a?(String)}
						raise TypeError, "The certificate chain must be provided as an array of strings!"
					end
					
					unless certificate_chain.any?
						raise ArgumentError, "The certificate chain must contain at least one certificate!"
					end
				end
				
				unless private_key.nil? || private_key.is_a?(String)
					raise TypeError, "The private key must be provided as a string!"
				end
				
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
			
			# @attribute [Array(String) | Nil] The ordered local certificate chain encoded as individual PEM strings, with the leaf certificate followed by any intermediates.
			attr :certificate_chain
			
			# @attribute [String | Nil] The private key encoded as PEM.
			attr :private_key
			
			# @attribute [Symbol | Nil] The peer verification policy.
			attr :verification
			
			# Compare configurations by their certificate material and verification policy.
			# @parameter other [Object] The object to compare.
			# @returns [Boolean] Whether both configurations have the same class and values.
			def ==(other)
				return other.instance_of?(self.class) &&
					@trust_store.eql?(other.trust_store) &&
					@certificate_chain.eql?(other.certificate_chain) &&
					@private_key.eql?(other.private_key) &&
					@verification.eql?(other.verification)
			end
			
			alias eql? ==
			
			# Compute a hash from the configuration values. Freeze the configuration before using it as a hash key.
			# @returns [Integer] The hash of the configuration.
			def hash
				return [self.class, @trust_store, @certificate_chain, @private_key, @verification].hash
			end
			
			# Freeze the configuration and independent copies of its certificate material, without freezing caller-owned values.
			# @returns [Configuration] This immutable configuration. Use `dup.freeze` to preserve the original configuration too.
			def freeze
				return self if frozen?
				
				@trust_store = @trust_store&.dup&.freeze
				@certificate_chain = @certificate_chain&.map{|certificate| certificate.dup.freeze}&.freeze
				@private_key = @private_key&.dup&.freeze
				
				super
			end
			
			# Whether peer certificates should be verified.
			# @returns [Boolean] Whether peer verification is enabled.
			def verify_peer?
				return @verification == :peer || @verification == :required
			end
			
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
