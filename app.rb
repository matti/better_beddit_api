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

  attr_reader :id, :started_at, :ended_at, :properties, :time_value_tracks, :updated

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

get '/v2/authenticated_user/sleeps.csv' do
  authenticate_to_beddit(params[:username], params[:password])
  sleeps = get_sleeps()

  content_type 'application/csv'

  attachment "sleeps.csv"
  csv_string = CSV.generate do |csv|
    csv << [
      "id",
      "started at",
      "ended at",
      "avg respiration rate",
      "total snoring duration",
      "sleep latency",
      "short term avg respiration rate",
      "short term resting HR",
      "away count",
      "resting HR",
      "snoring count",
      "deepness_10",
      "deepness_9",
      "deepness_8",
      "deepness_7",
      "deepness_6",
      "deepness_5",
      "deepness_4",
      "deepness_3",
      "deepness_2",
      "deepness_1",
      "deepness_0"
    ]
    for sleep_hash in sleeps do
      sleep_hash.merge!({ "user_id" => $user.id })
      sleep = Sleep.new(sleep_hash)
      csv << [
        sleep.id,
        sleep.started_at,
        sleep.ended_at,
        sleep.properties["average_respiration_rate"],
        sleep.properties["total_snoring_episode_duration"],
        sleep.properties["sleep_latency"],
        sleep.properties["short_term_average_respiration_rate"],
        sleep.properties["short_term_resting_heart_rate"],
        sleep.properties["away_episode_count"],
        sleep.properties["resting_heart_rate"],
        sleep.properties["snoring_episodes_count"],
        sleep.properties["deepness_levels"][10],
        sleep.properties["deepness_levels"][9],
        sleep.properties["deepness_levels"][8],
        sleep.properties["deepness_levels"][7],
        sleep.properties["deepness_levels"][6],
        sleep.properties["deepness_levels"][5],
        sleep.properties["deepness_levels"][4],
        sleep.properties["deepness_levels"][3],
        sleep.properties["deepness_levels"][2],
        sleep.properties["deepness_levels"][1],
        sleep.properties["deepness_levels"][0]
      ]
    end
  end

  csv_string

end

get '/v2/authenticated_user/sleeps' do
  authenticate_to_beddit(params[:username], params[:password])
  sleeps = get_sleeps()

  better_sleeps = []

  for sleep in sleeps do
    sleep.merge!({ "user_id" => $user.id })
    better_sleeps << Sleep.new(sleep).to_json
  end

  better_sleeps.to_json

end

private

def get_sleeps
  sleeps_response = HTTParty.get "#{ENDPOINT}/api/v1/user/#{$user.id}/sleep", {
    :headers => {
      "Authorization" => "UserToken #{$user.access_token}"
    }
  }

  raise "lol" unless sleeps_response.code == 200

  sleeps_response.parsed_response
end

def authenticate_to_beddit(username, password)
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
end
