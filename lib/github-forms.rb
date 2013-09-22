require 'octokit'
require 'sinatra_auth_github'
require 'redis'
require 'json'
require 'securerandom'
require 'csv'
require 'redcarpet'

module GithubForms
  class App < Sinatra::Base
    enable :sessions

    set :github_options, {
      :scopes    => "user,repo",
      :secret    => ENV['GITHUB_CLIENT_SECRET'],
      :client_id => ENV['GITHUB_CLIENT_ID'],
    }

    TTL = 60*5

    register Sinatra::Auth::Github
    use Rack::Session::Cookie, :expire_after => TTL
    set :markdown, :layout_engine => :erb

    # create unique sesion ID for redis storage, if not already assigned
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

    # store POST data to redis cache
    def cache_data(data)
      redis.set session_id, data
      redis.expire session_id, TTL
    end

    # retrieve POST data from redis cache
    def retrieve_data
      data = redis.get(session_id)
      JSON.parse data unless data.nil?
    end

    # convert POST data to csv of values
    def prepare_csv(data)
      row = CSV::Row.new([],[],false)
      data.each do |key,value|
        row << value
      end
      row
    end

    # return current file with data appended
    def updated_file(current,submission)
      "#{Base64.decode64(current)}\n#{prepare_csv(submission)}"
    end

    # Abstraction of Octokit client for both pre- and post 2.0 tokens
    def new_client(token)
      Octokit::Client.new :access_token => token, :oauth_token => token
    end

    # user client
    def client
      new_client env['warden'].user.nil? ? "" : env['warden'].user.token
    end

    # client with write access to file
    def sudo_client
      new_client ENV['GITHUB_TOKEN']
    end

    # perform the save action
    def submit(repo, branch, path, data)
      user = env['warden'].user
      file = client.contents( repo, :ref => branch, :path => path )
      message = "[github forms] update #{path}"
      content =  updated_file file.content, data
      result = sudo_client.update_contents repo, path, message, file.sha, content, {
          :ref => branch, :author => { "name" => user.name, "email" => user.email }
      }
      halt markdown :success if result
      markdown :fail
    end

    # Post oauth request
    get '/:owner/:repo/blob/:branch/*' do |owner,repo,branch,path|
      data = retrieve_data
      redirect "/" if data.nil?
      submit "#{owner}/#{repo}", branch, path, data["data"]
      redis.del session_id
    end

    # initial POST request
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

    # Demo
    get '/' do
      markdown :index
    end

  end
end
