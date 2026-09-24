# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "io/endpoint/tls/configuration"
require "sus/shared"

DifferentTLSConfiguration = Sus::Shared("a different TLS configuration") do |name, options|
	it "keeps cache entries separate with different #{name}" do
		first = configuration.freeze
		second = configuration(**options).freeze
		
		expect(first).not.to be == second
		expect(second).not.to be(:eql?, first)
		expect({first => :client}[second]).to be_nil
	end
end

describe IO::Endpoint::TLS::Configuration do
	let(:certificate) {"trusted certificate"}
	let(:certificates) {[certificate]}
	let(:trust_store) {IO::Endpoint::TLS::TrustStore.new(certificates: certificates)}
	let(:certificate_chain) {["certificate chain"]}
	let(:private_key) {"private key"}
	
	with "value equality" do
		def configuration(**options)
			subject.new(
				trust_store: IO::Endpoint::TLS::TrustStore.new(certificates: ["trusted certificate".dup]),
				certificate_chain: ["leaf certificate".dup, "intermediate certificate".dup],
				private_key: "private key".dup,
				verification: :peer,
				**options
			)
		end
		
		it "uses independently constructed equivalent configurations as the same hash key" do
			first = configuration.freeze
			second = configuration.freeze
			clients = {["https://example.com", first] => :client}
			
			expect(first).to be == second
			expect(first).to be(:eql?, second)
			expect(first.hash).to be == second.hash
			expect(first).not.to be_equal(second)
			expect(clients[["https://example.com", second]]).to be == :client
		end
		
		it "compares empty configurations" do
			expect({subject.new.freeze => :client}[subject.new]).to be == :client
		end
		
		it "compares the effective default verification policy" do
			expect(configuration(verification: nil)).to be == configuration(verification: :peer)
		end
		
		it_behaves_like DifferentTLSConfiguration, "trust store presence", {trust_store: nil}
		it_behaves_like DifferentTLSConfiguration, "trust roots", {trust_store: IO::Endpoint::TLS::TrustStore.new(certificates: ["other certificate"])}
		it_behaves_like DifferentTLSConfiguration, "system certificate policy", {trust_store: IO::Endpoint::TLS::TrustStore.new(certificates: ["trusted certificate"], system_certificates: true)}
		it_behaves_like DifferentTLSConfiguration, "certificate chain", {certificate_chain: ["other certificate"]}
		it_behaves_like DifferentTLSConfiguration, "certificate order", {certificate_chain: ["intermediate certificate", "leaf certificate"]}
		it_behaves_like DifferentTLSConfiguration, "private key", {private_key: "other private key"}
		it_behaves_like DifferentTLSConfiguration, "disabled verification", {verification: :none}
		it_behaves_like DifferentTLSConfiguration, "required verification", {verification: :required}
		it_behaves_like DifferentTLSConfiguration, "local identity presence", {certificate_chain: nil, private_key: nil}
		
		it "does not compare equal to other types or subclasses" do
			value = subject.new
			subclass = Class.new(subject).new
			
			expect(value).not.to be == nil
			expect(value).not.to be == Object.new
			expect(value).not.to be == subclass
			expect(subclass).not.to be == value
		end
		
		it "keeps a frozen snapshot usable after the original data changes" do
			original = configuration
			snapshot = original.dup.freeze
			clients = {snapshot => :client}
			
			original.trust_store.certificates.first.replace("other root")
			original.trust_store.certificates.clear
			original.certificate_chain.first.replace("other leaf")
			original.certificate_chain.clear
			original.private_key.replace("other key")
			
			expect(original).not.to be(:frozen?)
			expect(original.trust_store).not.to be(:frozen?)
			expect(snapshot).to be == configuration
			expect(clients[configuration]).to be == :client
			expect(clients[original]).to be_nil
		end
		
		it "prevents mutation through a frozen configuration" do
			snapshot = configuration.freeze
			
			expect{snapshot.trust_store.certificates.clear}.to raise_exception(FrozenError)
			expect{snapshot.trust_store.certificates.first.clear}.to raise_exception(FrozenError)
			expect{snapshot.certificate_chain.clear}.to raise_exception(FrozenError)
			expect{snapshot.certificate_chain.first.clear}.to raise_exception(FrozenError)
			expect{snapshot.private_key.clear}.to raise_exception(FrozenError)
			expect(snapshot.freeze).to be_equal(snapshot)
		end
	end
	
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
			expect(configuration).to be(:verify_peer?)
		end
		
		it "does not expose certificate or private key material when inspected" do
			representation = configuration.inspect
			
			expect(representation).not.to be(:include?, certificate)
			expect(representation).not.to be(:include?, certificate_chain.first)
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
	
	with "an unsupported certificate chain representation" do
		it "rejects a concatenated string" do
			expect do
				subject.new(certificate_chain: "certificate chain", private_key: private_key)
			end.to raise_exception(TypeError, message: be =~ /array of strings/)
		end
		
		it "rejects an empty chain" do
			expect do
				subject.new(certificate_chain: [], private_key: private_key)
			end.to raise_exception(ArgumentError, message: be =~ /at least one certificate/)
		end
	end
	
	with "an unsupported private key representation" do
		it "rejects a value which is not a string" do
			expect do
				subject.new(certificate_chain: certificate_chain, private_key: Object.new)
			end.to raise_exception(TypeError, message: be =~ /private key must be provided as a string/)
		end
	end
	
	with "an unsupported verification policy" do
		it "rejects the policy" do
			expect do
				subject.new(verification: :unsupported)
			end.to raise_exception(ArgumentError, message: be =~ /Unsupported verification policy/)
		end
		
		it "does not replace a false policy when a trust store is provided" do
			expect do
				subject.new(trust_store: trust_store, verification: false)
			end.to raise_exception(ArgumentError, message: be =~ /Unsupported verification policy/)
		end
	end
	
	with "verification disabled" do
		it "does not verify peers" do
			configuration = subject.new(verification: :none)
			
			expect(configuration).not.to be(:verify_peer?)
		end
	end
end
