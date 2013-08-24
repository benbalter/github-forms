require 'octokit'
require 'sinatra_auth_github'
require 'redis'
require 'json'

module GithubForms
  class App < Sinatra::Base
    enable :sessions

    set :github_options, {
      :scopes    => "user, public_repo",
      :secret    => ENV['GITHUB_CLIENT_SECRET'],
      :client_id => ENV['GITHUB_CLIENT_ID'],
    }

    register Sinatra::Auth::Github

    TTL = 60*5

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
      session['session_id']
    end

    def cache(data)
      redis.set session_id, data
      redis.expire session_id, TTL
    end

    def retrieve
      JSON.parse redis.get(session_id)
    end

    def submit(repo, branch, path, data)
      client = Octokit::Client.new :access_token => env['warden'].user.token
      file = client.contents( repo, :branch => branch, :path => path )
      data = data #todo: encode as CSV
      current = Base64.decode64 file.contents
      client.update_contents( repo, path, message, file.sha, "#{current}\n{#data}", :branch => branch )
    end

    get '/:owner/:repo/blob/:branch/*' do |owner,repo,branch,path|
      puts owner
      puts repo
      puts branch
      puts path

      submit "#{owner}/#{repo}", branch, path, "foo"

    end

    post '/:owner/:repo/blob/:branch/*' do |owner,repo,branch,path|
      unless authenticated?
         cache({
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
