# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

source 'https://rubygems.org'

gemspec

# gem "decode", path: "../../ioquatix/decode"

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-gem"
	
	gem "utopia-project" #, path: "../utopia-project"
end

group :test do
	gem "bake", "~> 0.19.0"
	gem "covered"
	gem "sus", ">= 0.24.3"
	
	gem "bake-test"
	gem "bake-test-external"
	
	gem "sus-fixtures-openssl"
	gem "sus-fixtures-async"
end
