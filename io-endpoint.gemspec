# frozen_string_literal: true

require_relative "lib/io/endpoint/version"

Gem::Specification.new do |spec|
	spec.name = "io-endpoint"
	spec.version = IO::Endpoint::VERSION
	
	spec.summary = "Provides a separation of concerns interface for IO endpoints."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.homepage = "https://github.com/socketry/io-endpoint"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/io-endpoint",
	}
	
	spec.files = Dir.glob(['{lib}/**/*', '*.md'], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.0"
end
