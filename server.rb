require 'octokit'
require 'json'
require 'parseconfig'
require 'sinatra'
require 'timerizer'

class Issue
  def initialize(resource)
    @underlying = resource
  end
  
  def pull_request?
    @underlying.pull_request != nil
  end

  def priority
    priority_labels = @underlying.labels.collect {|x| x.name}.select { |x| x.include? 'priority' }
    if priority_labels.empty?
      "30 - undefined"
    else
      if priority_labels[0].include? 'high'
        "10 - high"
      elsif priority_labels[0].include? 'medium'
        "20 - medium"
      elsif priority_labels[0].include? 'low'
        "40 - low"
      end
    end
  end

  def opened_since? date
    @underlying.created_at > date
  end

  def closed_since? date
    @underlying.closed_at && (@underlying.closed_at > date)
  end

  def closed?
    @underlying.closed_at != nil
  end
    
  def to_json(ignored)
   {"description" => @underlying.title,
      "when_opened" => @underlying.created_at,
      "when_closed" =>  @underlying.closed_at,
      "url" =>  @underlying.html_url,
      "raiser" => @underlying.user.login,
      "owner" => @underlying.assignee && @underlying.assignee.login,
      "priority" => priority
    }.to_json
  end
end

class IssueServer
  def read_config
    cfg = ParseConfig.new('githubissues.cfg')
    repo_names = JSON.parse cfg['repoNames']
    @repos = repo_names.collect { |name| "#{cfg['repoOwner']}/#{name}"}
    token = cfg['oauthToken']
    @client = Octokit::Client.new(:access_token => token)
    @client.auto_paginate = true
  end

  def start_data_retrieval_thread
    Thread.new do
      loop do
        sleep 300
        read_config
        get_data
      end
    end
  end
  
  def get_data
    raw_data = []
    @repos.each do |repo_name|
      raw_data += @client.list_issues(repo_name, state: "all")
    end

    data = raw_data.collect { |x| Issue.new(x) }

    @issues = data.reject { |i| i.pull_request? || i.closed? }
    @prs = data.select { |i| i.pull_request?}
    @recently_closed_issues = data.reject { |i| i.pull_request? }
                                  .select { |i| i.closed_since? 2.weeks.ago }
    @recently_opened_issues = data.reject { |i| i.pull_request? }
                                  .select { |i| i.opened_since? 2.weeks.ago }

  end

  def wrapper(list)
    {"recentlyClosed" => @recently_closed_issues.length,
      "recentlyOpened" => @recently_opened_issues.length,
      "issues" => list}
  end

  def issues
    wrapper(@issues)
  end

  def prs
    wrapper(@prs)
  end

  def recently_closed_issues
    wrapper(@recently_closed_issues)
  end
end

server = IssueServer.new
server.read_config
puts "Waiting to retrieve data from Github"
server.get_data
server.start_data_retrieval_thread

set :port, 3005

get '/issues' do
  content_type :json
  server.issues.to_json
end

get '/prs' do
  content_type :json
  server.prs.to_json
end

get '/recentlyClosed' do
  content_type :json
  server.recently_closed_issues.to_json
end

get '/dashboard' do
  redirect to('/dashboard.html')
end


get "/coffee/*.js" do
  filename = params[:splat].first
  coffee "../public/coffee/#{filename}".to_sym
end
