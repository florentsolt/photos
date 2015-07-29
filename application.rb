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

  def password?
    if @album.nil?
      if Lib::Index.protected?
        pwd = Lib::Index.password
        name = 'pwd'
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
      headers "Cache-Control" => "no-cache, no-store, must-revalidate"
      headers "Pragma" => "no-cache"
      headers "Expires" => "0"
      halt 403, haml(:password)
    end
  end

  def deliver(file, type, download = false, filename = nil)
    filename ||= File.basename(file)
    headers "Content-Disposition" => "attachment; filename=#{filename}" if download
    content_type type
    if settings.production?
      file = "/direct/" + file
      headers "X-Accel-Redirect" => file
    else
      etag "#{file}@#{File.mtime(Lib::Config.default(:path) / file)}"
      if not download
        send_file Lib::Config.default(:path) / file, :type => type
      else
        send_file Lib::Config.default(:path) / file, :type => type, :filename => filename
      end
    end
  end

  def domain
    if request.port == 80
      request.host
    else
      "#{request.host}:#{request.port}"
    end
  end

  def original(photo)
    "#{request.scheme}://#{domain}/download/#{@album.name}/#{photo.id}/original.#{photo.ext}"
  end

  def preview(photo)
    "#{request.scheme}://#{domain}/#{@album.name}/#{photo.id}/preview.#{photo.ext}"
  end

  def thumb(photo)
    "#{request.scheme}://#{domain}/#{@album.name}/#{photo.id}/thumb.#{photo.ext}"
  end
end

get '/' do
  password?
  haml :index
end

post '/password' do
    cookies.options[:domain] = ''

    value = Digest::SHA1.hexdigest(params[:password] + Time.now.strftime("%y%-m%-d"))
    if params[:name].empty?
      cookies["pwd"] = value
      redirect '/'
    else
      cookies["pwd-#{params[:name]}"] = value
      redirect "/#{params[:name]}"
    end
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
    $JS = Dir[File.dirname(__FILE__) / :public / :js / '*.js'].sort do |a,b|
        File.basename(a).to_i <=> File.basename(b).to_i
    end.collect do |js|
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

[:thumb, :preview, :original].each do |type|
  get "/:name/:id/#{type}.:ext" do
    @album = Lib::Album.load params[:name]
    password?
    @photo = @album.photos[params[:id]]
    deliver @photo.uri(type), @photo.ext
  end

  get "/download/:name/:id/#{type}.:ext" do
    @album = Lib::Album.load params[:name]
    password?
    @photo = @album.photos[params[:id]]
    deliver @photo.uri(type), @photo.ext, true, "#{@album.name}-#{type}-#{@photo.id}.#{@photo.ext}"
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
  deliver @album.name / @album.zip, :zip, true, "#{@album.name}.zip"
end

get '/:name/?' do
    @album = Lib::Album.load params[:name]
    password?

    if @album.reverse?
      @photos = @album.photos.values.reverse
    else
      @photos = @album.photos.values
    end
    @gallery = @photos.map do |photo|
      {:src => preview(photo)}
    end
    @photos = @photos[0,@album.config(:page)] || []

    haml :album
end

get '/:name/page/:page' do
  @album = Lib::Album.load params[:name]
  password?

  size = @album.config(:page)
  page = params[:page].to_i

  if @album.reverse?
    @photos = @album.photos.values.reverse
  else
    @photos = @album.photos.values
  end
  @photos = @photos[page * size, size] || []
  if @photos.empty?
    halt 404, "No more pictures"
  else
    haml :page, :layout => false
  end
end
