# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "trust_store"
require_relative "configuration"

require "openssl"

module IO::Endpoint
	module TLS
		# Provides OpenSSL compilation for transport-neutral TLS configuration.
		module OpenSSL
			# Build an OpenSSL certificate store from transport-neutral trusted certificate configuration.
			# @parameter trust_store [TrustStore] The trusted certificate sources.
			# @returns [OpenSSL::X509::Store] The configured OpenSSL certificate store.
			def self.build_certificate_store(trust_store)
				::OpenSSL::X509::Store.new.tap do |store|
					store.set_default_paths if trust_store.system_certificates?
					
					trust_store.certificates.each do |certificate_pem|
						::OpenSSL::X509::Certificate.load(certificate_pem).each do |certificate|
							store.add_cert(certificate)
						end
					end
				end
			end
			
			# Apply transport-neutral TLS configuration to an OpenSSL context.
			# @parameter context [OpenSSL::SSL::SSLContext] The OpenSSL context to configure.
			# @parameter configuration [Configuration] The transport-neutral TLS configuration.
			# @parameter hostname [String | Nil] The hostname to verify for client connections.
			# @returns [OpenSSL::SSL::SSLContext] The configured OpenSSL context.
			def self.apply(context, configuration, hostname: nil)
				if trust_store = configuration.trust_store
					context.cert_store = build_certificate_store(trust_store)
				end
				
				if certificate_chain = configuration.certificate_chain
					certificates = certificate_chain.map do |certificate|
						::OpenSSL::X509::Certificate.new(certificate)
					end
					
					context.cert = certificates.shift
					context.extra_chain_cert = certificates unless certificates.empty?
					context.key = ::OpenSSL::PKey.read(configuration.private_key)
				end
				
				case configuration.verification
				when :none
					context.verify_mode = ::OpenSSL::SSL::VERIFY_NONE
					context.verify_hostname = false
				when :peer
					context.verify_mode = ::OpenSSL::SSL::VERIFY_PEER
				when :required
					context.verify_mode = ::OpenSSL::SSL::VERIFY_PEER | ::OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
				end
				
				if hostname && configuration.verify_peer?
					context.verify_hostname = true
				end
				
				return context
			end
		end
	end
end
