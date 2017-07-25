# encoding: utf-8

require 'sinatra'
require 'sinatra/cookies'
require 'sinatra/r18n'
require 'haml'
require 'sass'
require 'digest/sha1'
require 'base64'

require File.join(__dir__, 'lib')

set :sass, {
  :cache_store => Sass::CacheStores::Memory.new,
  :style => :compressed
}

configure :production do
  # preload albums
  Lib::Index.albums
end

helpers do

  include Rack::Utils
  alias_method :h, :escape_html

  def touch_device?
    user_agent = env["HTTP_USER_AGENT"]
    !user_agent.nil? && user_agent =~ /\b(Android|iPhone|iPad|Windows Phone|Opera Mobi|Kindle|BackBerry|PlayBook)\b/i
  end

  def password?
    if @album.nil?
      if Lib::Index.protected?
        pwd = Lib::Index.password
        name = 'pwd'
      else
        return
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

  def domain
    if request.port == 80
      request.host
    else
      "#{request.host}:#{request.port}"
    end
  end

  # Need full url for layout.haml (also used in index.haml)
  def gallery(album)
    "#{request.scheme}://#{domain}/#{album.name}/"
  end

  # Need full url for layout.haml (also used in index.haml)
  def samples(album)
    "#{request.scheme}://#{domain}/#{album.name}/samples"
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

get "/:name/:id/original.:ext" do
  @album = Lib::Album.load params[:name]
  password?
  @photo = @album.photos[params[:id]]
  headers "Content-Disposition" => "attachment; filename=#{File.basename(@photo.filename(:original))}"
  send_file @photo.filename(:original), :type => @photo.ext
end

[:thumb, :preview].each do |type|
  get "/:name/:id/#{type}.:ext" do
    @album = Lib::Album.load params[:name]
    password?
    @photo = @album.photos[params[:id]]
    # Dynamic generation is not a so good idea
    # @photo.thumbs!
    # @photo.optimize!
    send_file @photo.filename(type), :type => @photo.ext
  end
end

get "/:name/samples" do
  # password? # ask before setting @album for the master password
  @album = Lib::Album.load params[:name]
  send_file @album.samples, :type => :jpg
end

get "/:name/zip" do
  @album = Lib::Album.load params[:name]
  password?
  headers "Content-Disposition" => "attachment; filename=#{@album.name}.zip"
  send_file @album.zip, :type => :zip
end

get '/:name/?' do
    @album = Lib::Album.load params[:name]
    password?
    @css = sass(:style) + File.read(__dir__ / :public / :css / "jquery.fancybox.min.css")
    @css += "\n#title, #desc, #zip, .caption {font-family: '#{@album.font_family}', sans-serif !important;}"

    if @album.reverse?
      @photos = @album.photos.values.reverse
    else
      @photos = @album.photos.values
    end

    haml :album
end
