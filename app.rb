require "sinatra"
require 'active_support/all'
require "httparty"

$stdout.sync = true

ENDPOINT = "https://cloudapi.beddit.com"

class User
  attr_reader :access_token, :id

  def initialize(opts={})
    @access_token = opts["access_token"]
    @id = opts["user"].to_i
  end

end

# use Rack::Auth::Basic, "Restricted Area" do |username, password|
#
#   if ENV['BEDDIT_ACCESS_TOKEN'] && ENV['BEDDIT_USER_ID']
#     $user = User.new({
#       "user" => ENV["BEDDIT_USER_ID"],
#       "access_token" => ENV["BEDDIT_ACCESS_TOKEN"]
#     })
#
#   else
#
#     login_options = {
#       "grant_type" => "password",
#       "username" => username,
#       "password" => password
#     }
#
#     login_response = HTTParty.post "#{ENDPOINT}/api/v1/auth/authorize", {
#       body: login_options
#     }
#
#     if login_response.code == 200
#       $user = User.new(login_response.parsed_response)
#     end
#   end
#
#   $user != nil
# end

class Sleep
  attr_reader :id

  def initialize(opts={})
    @id = opts["start_timestamp"].to_s.gsub(".", "").to_i
    @user_id = opts["user_id"]

    @started_at = Time.at(opts["start_timestamp"]).utc.iso8601
    @ended_at = Time.at(opts["end_timestamp"]).utc.iso8601

    # session_range_start && _end are undocumented


    @time_value_tracks = {}
    opts["time_value_tracks"].each_key do |what|

      @time_value_tracks[what] = {}
      @time_value_tracks[what]["items"] = []

      opts["time_value_tracks"][what]["items"].each do |unix_timestamp_and_value|
        unix_timestamp, value = unix_timestamp_and_value
        @time_value_tracks[what]["items"] << [Time.at(unix_timestamp).utc.iso8601, value]
      end

      @time_value_tracks[what]["value_data_type"] = opts["time_value_tracks"][what]["value_data_type"]
    end

    @updated = Time.at(opts["updated"]).utc.iso8601

    @properties = opts["properties"]

    @properties.merge!({
      "snoring_episodes_count" => @time_value_tracks["snoring_episodes"]["items"].count
    })

    deepness_levels = {}
    previous_time = nil
    @time_value_tracks["sleep_cycles"]["items"].each do |time_and_deepness|
      time_string, deepness = time_and_deepness

      time = Time.parse(time_string)

      unless previous_time
        previous_time = time
        next
      end

      seconds = (time - previous_time).to_i
      level = (deepness.round(1) * 10).round

      deepness_levels[level] = 0 unless deepness_levels[level]
      deepness_levels[level] += seconds

      previous_time = time
    end

    @properties["deepness_levels"] = deepness_levels

  end

  def to_json
    {
      id: @id,
      user_id: @user_id,
      started_at: @started_at,
      ended_at: @ended_at,
      properties: @properties,
      time_value_tracks: @time_value_tracks,
      updated: @updated
    }
  end
end

get '/v2/authenticated_user/sleeps' do

  login_options = {
    "grant_type" => "password",
    "username" => params[:username],
    "password" => params[:password]
  }

  login_response = HTTParty.post "#{ENDPOINT}/api/v1/auth/authorize", {
    body: login_options
  }

  if login_response.code == 200
    $user = User.new(login_response.parsed_response)
  else
    raise "lul"
  end

  sleeps_response = HTTParty.get "#{ENDPOINT}/api/v1/user/#{$user.id}/sleep", {
    :headers => {
      "Authorization" => "UserToken #{$user.access_token}"
    }
  }

  raise "lol" unless sleeps_response.code == 200

  sleeps = sleeps_response.parsed_response

  better_sleeps = []

  for sleep in sleeps do
    sleep.merge!({ "user_id" => $user.id })
    better_sleeps << Sleep.new(sleep).to_json
  end

  better_sleeps.to_json

end
