# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'io/endpoint/ssl_endpoint'
require 'with_temporary_directory'

describe IO::Endpoint::SSLEndpoint do
	include WithTemporaryDirectory
	
	let(:path) {File.join(temporary_directory, "test.ipc")}
	let(:internal_endpoint) {IO::Endpoint::UNIXEndpoint.new(path)}
end
