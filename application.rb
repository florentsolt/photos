# encoding: utf-8

require 'sinatra'
require 'sinatra/cookies'
require 'sinatra/r18n'
require 'haml'
require 'sass'
require 'digest/sha1'

require File.join(__dir__, 'lib')

set :sass, {
  :cache_store => Sass::CacheStores::Memory.new,
  :style => settings.production? ? :compressed : :expanded
}

configure :production do
  # preload albums
  Lib::Index.albums
end

helpers do

  include Rack::Utils
  alias_method :h, :escape_html

  def cycle
    %w{even odd}[@_cycle = ((@_cycle || -1) + 1) % 2]
  end

  def password?
    if @album.nil?
      if Lib::Index.protected?
        pwd = Lib::Index.password
        name = 'pwd-'
      else
        halt 204
      end
    elsif @album.protected?
      pwd = @album.config(:password)
      name = 'pwd-' + @album.name
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
    if settings.production?
      file = "/direct/" + file
      content_type :jpeg
      headers "Content-Disposition" => "attachment; filename=#{File.basename(file)}" if not ios?
      headers "X-Accel-Redirect" => file
    else
      etag "#{file}@#{File.mtime(Lib::Config.default(:path) / file)}"
      if ios?
        send_file Lib::Config.default(:path) / file, :type => type
      else
        send_file Lib::Config.default(:path) / file, :type => type, :filename => File.basename(file)
      end
    end
  end

  def exif(photo)
    if @album.config(:exif) and @album.config(:date)
      "%dmm &nbsp; %ss &nbsp; f/%.1f &nbsp; ISO %d — %s" % [
        photo.exif.focal,
        photo.exif.speed,
        photo.exif.aperture,
        photo.exif.iso,
        l(Time.at(photo.exif.time), :human)
      ]
    elsif @album.config(:exif)
      "%dmm &nbsp; %ss &nbsp; f/%.1f &nbsp; ISO %d" % [
        photo.exif.focal,
        photo.exif.speed,
        photo.exif.aperture,
        photo.exif.iso
      ]
    elsif @album.config(:date)
      l(Time.at(photo.exif.time), :human)
    else
      ""
    end
  end

  def time(times)
    return "" if times.min.nil? or times.max.nil?
    if times.max - times.min < 3600*24 # all photos in a day
      l Time.at(times.max).to_date, :human
    elsif times.max - times.min < 3600*48 # all photos in two day
      t.time.two l(Time.at(times.min).to_date, :human), l(Time.at(times.max).to_date, :human)
    else
      t.time.interval l(Time.at(times.min).to_date, :human), l(Time.at(times.max).to_date, :human)
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
    "#{request.scheme}://#{domain}/#{@album.name}/#{photo.id}"
  end

  def preview(photo)
    "#{request.scheme}://#{domain}/#{@album.name}/#{photo.id}/preview.#{photo.ext}"
  end

  def thumb(photo)
    type = @album.config(:thumb).to_sym
    type = [:square, :resize].sample if type == :random

    "<img class='lazy' width='%d' height='%d' data-original='%s' src='/gfx/transparent.gif'>" % [
      photo.size(type).x.to_i,
      photo.size(type).y.to_i,
      "/#{@album.name}/#{photo.id}/#{type}.#{photo.ext}"
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
  if settings.production?
    $CSS_SHA1 ||= Digest::SHA1.hexdigest(Dir[File.dirname(__FILE__) / :views / '*.sass'].collect do |css|
      File.read(css)
    end.join)
    etag $CSS_SHA1
  end
  content_type :css
  sass :style
end

get '/js' do
  if not settings.production? or $JS.nil?
    $JS = Dir[File.dirname(__FILE__) / :public / :js / '*.js'].sort.collect do |js|
      "#{File.read(js)}\n"
    end.join
  end
  if settings.production?
    $JS_SHA1 ||= Digest::SHA1
    etag $JS_SHA1.hexdigest($JS)
  end
  content_type :js
  $JS
end

[:square, :resize, :preview, :original].each do |type|
  get "/:name/:id/#{type}.:ext" do
    @album = Lib::Album.load params[:name]
    password?
    @photo = @album.photos[params[:id]]
    deliver @photo.uri(type), @photo.ext
  end
end

get "/:name/samples" do
  password? # ask before setting @album for the master password
  @album = Lib::Album.load params[:name]
  deliver @album.name / 'samples.png', :png
end

get "/:name/zip" do
  @album = Lib::Album.load params[:name]
  password?
  deliver @album.name / @album.zip, :zip
end

['/:name/', '/:name/:id/'].each do |route|
  get route do
    redirect request.path.sub(/\/$/, '')
  end
end

get '/:name/:id/exif' do
  @album = Lib::Album.load params[:name]
  password?
  @photo = @album.photos[params[:id]]
  "<html><body><pre>" + @photo.exif(true).collect do |k,v|
    "<b>#{k}:</b> #{v}"
  end.join("\n") + "</pre></body></html>"
end

['/:name', '/:name/:id'].each do |route|
  get route do
    @album = Lib::Album.load params[:name]
    password?

    if params[:id].nil?
      if @album.reverse?
        @photos = @album.photos.values.reverse
      else
        @photos = @album.photos.values
      end
      haml :album
    else
      halt 404 if not @album.photos.key? params[:id]
      @photo = @album.photos[params[:id]]
      if @album.reverse?
        @next = @photo.prev
        @prev = @photo.next
      else
        @prev = @photo.prev
        @next = @photo.next
      end
      haml :photo, :layout => params[:ajax].nil?
    end
  end
end

