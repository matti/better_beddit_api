require "sinatra"
require "httparty"

$stdout.sync = true

ENDPOINT = "https://cloudapi.beddit.com"

class User
  def initialize(opts={})
    @access_token = opts["access_token"]
    @id = opts["user"]
  end

end

use Rack::Auth::Basic, "Restricted Area" do |username, password|
  login_options = {
    "grant_type" => "password",
    "username" => username,
    "password" => password
  }

  login_response = HTTParty.post "#{ENDPOINT}/api/v1/auth/authorize", {
    body: login_options
  }

  if login_response.code == 200
    @@user = User.new(login_response.parsed_response)
  end

  @@user != nil
end

get '/hello' do
  @@user.access_token
end
