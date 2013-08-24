require 'octokit'
require 'sinatra_auth_github'
require 'redis'
require 'json'
require 'securerandom'
require 'csv'

module GithubForms
  class App < Sinatra::Base
    enable :sessions

    set :github_options, {
      :scopes    => "user,public_repo,repo",
      :secret    => ENV['GITHUB_CLIENT_SECRET'],
      :client_id => ENV['GITHUB_CLIENT_ID'],
    }

    register Sinatra::Auth::Github
    use Rack::Session::Cookie, :expire_after => 60*60

    TTL = 60*5

    before do
      session[:id] = SecureRandom.uuid if session_id.nil?
    end

    def redis
      @redis ||= Redis.new \
        :host     => redis_url.host,
        :port     => redis_url.port,
        :password => redis_url.password
    end

    def redis_url
      @redis_url ||=
        URI.parse(ENV["REDISTOGO_URL"] || "redis://localhost:16379")
    end

    def session_id
      session[:id]
    end

    def cache_data(data)
      redis.set session_id, data
      redis.expire session_id, TTL
    end

    def retrieve_data
      data = redis.get(session_id)
      JSON.parse data unless data.nil?
    end

    def prepare_csv(data)
      row = CSV::Row.new([],[],false)
      data.each do |key,value|
        row << value
      end
      row
    end

    def update_file(current,submission)
      Base64.encode64 "#{Base64.decode64(current)}\n#{prepare_csv(submission)}"
    end

    def client
      token = env['warden'].user.nil? ? "" : env['warden'].user.token
      Octokit::Client.new :access_token => token
    end

    def submit(repo, branch, path, data)
      file = client.contents( repo, :branch => branch, :path => path )
      message = "[github forms] update #{path}"
      content =  update_file file.content, data
      client.update_contents( repo, path, message, file.sha, content, :branch => branch )
  end

    get '/:owner/:repo/blob/:branch/*' do |owner,repo,branch,path|
      data = retrieve_data
      redirect "/" if data.nil?
      submit "#{owner}/#{repo}", branch, path, data["data"]
      redis.del session_id
      "SUBMITTED"
    end

    post '/:owner/:repo/blob/:branch/*' do |owner,repo,branch,path|

      unless authenticated?
        cache_data({
            :owner => owner,
            :repo => repo,
            :branch => branch,
            :path => path,
            :data => request.POST
          }.to_json)
        authenticate!
      end

      submit "#{owner}/#{repo}", branch, path, request.POST

    end

    get '/' do
      send_file File.join(settings.public_folder, 'form.html')
    end

  end
end
