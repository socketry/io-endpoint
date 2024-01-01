require 'io/endpoint'

describe IO::Endpoint do
	with ".file_descriptor_limit" do
		it "has a file descriptor limit" do
			expect(IO::Endpoint.file_descriptor_limit).to be_a Integer
		end
	end
end
