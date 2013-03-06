# encoding: utf-8

require 'sinatra'
require 'sinatra/cookies'
require 'sinatra/r18n'
require 'haml'
require 'sass'
require 'digest/sha1'
require 'json'

require File.join(__dir__, 'models')

set :sass, {
  :cache_store => Sass::CacheStores::Memory.new,
  :style => production? ? :compressed : :expanded
}

helpers do

  include Rack::Utils
  alias_method :h, :escape_html

  def cycle
    %w{even odd}[@_cycle = ((@_cycle || -1) + 1) % 2]
  end

  def password?
    if @stream.nil?
      if Model::Stream::Index.protected?
        pwd = Model::Stream::Index.password
        name = 'pwd-'
      else
        halt 204
      end
    elsif @stream.protected?
      pwd = @stream.config(:password)
      name = 'pwd-' + @stream.name
    else
      return
    end

    value = Digest::SHA1.hexdigest(pwd + Time.now.strftime("%y%-m%-d"))
    if not cookies[name] == value
      cookies.delete name
      halt 403, haml(:password)
    end
  end

  def ios?
    request.user_agent =~ /ipad|iphone/i
  end

  def deliver(file, type)
    if production?
      file = "/direct/" + file
      content_type :jpeg
      headers "Content-Disposition" => "attachment; filename=#{File.basename(file)}" if not ios?
      headers "X-Accel-Redirect" => file
    else
      if ios?
        send_file Model::Stream::PATH / file, :type => type
      else
        send_file Model::Stream::PATH / file, :type => type, :filename => File.basename(file)
      end
    end
  end

  def exif(photo)
    data = photo.exif
    if @stream.config(:exif) and @stream.config(:date)
      "%dmm &nbsp; %ss &nbsp; f/%.1f &nbsp; ISO %d — %s" % [
        data['focal'].to_i,
        data['speed'] || 0,
        data['aperture'] || 0,
        data['iso'].to_i,
        l(Time.at(data['time'].to_i), :human)
      ]
    elsif @stream.config(:exif)
      "%dmm &nbsp; %ss &nbsp; f/%.1f &nbsp; ISO %d" % [
        data['focal'].to_i,
        data['speed'] || 0,
        data['aperture'] || 0,
        data['iso'].to_i
      ]
    elsif @stream.config(:date)
      l(Time.at(data['time'].to_i), :human)
    else
      ""
    end
  end

  def time(times)
    return "" if times.nil? or times.empty?
    if times[:max] - times[:min] < 3600*24 # all photos in a day
      l times[:max].to_date, :human
    elsif times[:max] - times[:min] < 3600*48 # all photos in two day
      t.time.two l(times[:min].to_date, :human), l(times[:max].to_date, :human)
    else
      t.time.interval l(times[:min].to_date, :human), l(times[:max].to_date, :human)
    end
  end

  # domain is used for preview and photo_page when sharing
  def domain
    if request.port == 80
      request.host
    else
      "#{request.host}:#{request.port}"
    end
  end

  def photo_page(photo)
    "#{request.scheme}://#{domain}/#{@stream.name}/#{photo.id}"
  end

  def preview(photo)
    "#{request.scheme}://#{domain}/#{@stream.name}/#{photo.id}/preview.#{photo.ext}"
  end

  def thumb(photo)
    type = @stream.config(:thumb).to_sym
    type = [:square, :resize].sample if type == :random

    "<img class='lazy' width='%d' height='%d' data-original='%s' src='/gfx/transparent.gif'>" % [
      photo.size(type).x.to_i,
      photo.size(type).y.to_i,
      "/#{@stream.name}/#{photo.id}/#{type}.#{photo.ext}"
    ]
  end
end

get '/' do
  password?
  haml :index
end

['/robots.txt',
 '/apple-touch-icon.png',
 '/apple-touch-icon-precomposed.png',
 '/apple-touch-icon-114x114.png',
 '/apple-touch-icon-114x114-precomposed.png'
].each do |route|
  get route do
    status 404
  end
end

get '/css' do
  if production?
    $CSS_SHA1 ||= Digest::SHA1.hexdigest(Dir[File.dirname(__FILE__) / :views / '*.sass'].collect do |css|
      File.read(css)
    end.join)
    etag $CSS_SHA1
  end
  content_type :css
  sass :style
end

get '/js' do
  if not production? or $JS.nil?
    $JS = Dir[File.dirname(__FILE__) / :public / :js / '*.js'].sort.collect do |js|
      "#{File.read(js)}\n"
    end.join
  end
  if production?
    $JS_SHA1 ||= Digest::SHA1
    etag $JS_SHA1.hexdigest($JS)
  end
  content_type :js
  $JS
end

[:square, :resize, :preview, :original].each do |type|
  get "/:name/:id/#{type}.:ext" do
    @stream = Model::Stream.new params[:name]
    password?
    @photo = Model::Photo.new @stream, params[:id], params[:ext]
    deliver @photo.uri(type), @photo.ext
  end
end

get "/:name/samples" do
  password? # ask before setting @stream for the master password
  @stream = Model::Stream.new params[:name]
  deliver @stream.name / 'samples.png', :png
end

get "/:name/zip" do
  @stream = Model::Stream.new params[:name]
  password?
  deliver @stream.name / @stream.zip, :zip
end

get "/:name/stats" do
  @stream = Model::Stream.new params[:name]
  if not params[:date].nil?
    @stats = @stream.stats(params[:date])
    haml :stats_details, :layout => !request.xhr?
  else
    @viewport = 500
    @stats = @stream.stats
    haml :stats
  end
end

['/:name/', '/:name/:id/'].each do |route|
  get route do
    redirect request.path.sub(/\/$/, '')
  end
end

get '/:name/:id/exif' do
  @stream = Model::Stream.new params[:name]
  password?
  @photo = Model::Photo.new @stream, params[:id]
  "<html><body><pre>" + @photo.exif(true).collect do |k,v|
    "<b>#{k}:</b> #{v}"
  end.join("\n") + "</pre></body></html>"
end

['/:name', '/:name/:id'].each do |route|
  get route do
    @stream = Model::Stream.new params[:name]
    password?
    etag @stream.etag if production?

    if params[:id].nil?
      haml :stream
    else
      halt 404 if not @stream.ids.key? params[:id]
      @photo = Model::Photo.new @stream, params[:id]
      @stats = @photo.stats
      haml :photo, :layout => params[:ajax].nil?
    end
  end
end
