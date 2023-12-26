# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

source 'https://rubygems.org'

gemspec

# gem "decode", path: "../../ioquatix/decode"

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-gem"
	
	gem "utopia-project" #, path: "../utopia-project"
end

group :test do
	gem "bake"
	gem "covered"
	gem "sus"
	
	gem "bake-test"
	gem "bake-test-external"
end
