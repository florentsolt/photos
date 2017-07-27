# encoding: utf-8

require 'sinatra'
require 'sinatra/cookies'
require 'sinatra/r18n'
require 'haml'
require 'sass'
require 'digest/sha1'
require 'base64'
require 'curb'

require File.join(__dir__, 'lib')

ASSETS_CACHE = {}

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
      @css = sass(:style)
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
  @css = sass(:style)
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

get '/js' do
  jquery = "http://code.jquery.com/jquery-3.2.0.min.js"
  ASSETS_CACHE[jquery] ||= Curl.get(jquery).body_str

  fancybox = "https://cdnjs.cloudflare.com/ajax/libs/fancybox/3.1.20/jquery.fancybox.min.js"
  ASSETS_CACHE[fancybox] ||= Curl.get(fancybox).body_str

  ASSETS_CACHE["album"] ||= File.read(__dir__ / :public / 'album.js')

  content_type :js
  etag Digest::SHA1.hexdigest(jquery + fancybox + ASSETS_CACHE["album"])
  ASSETS_CACHE[jquery] + "\n" + ASSETS_CACHE[fancybox] + "\n" + ASSETS_CACHE["album"]
end

get "/:name/:name-:id.:ext" do
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
    ASSETS_CACHE[@album.font_href] ||= Curl.get(@album.font_href).body_str
    fancybox = "https://cdnjs.cloudflare.com/ajax/libs/fancybox/3.1.20/jquery.fancybox.min.css"
    ASSETS_CACHE[fancybox] ||= Curl.get(fancybox).body_str.force_encoding('utf-8')
    @css = sass(:style)
    @css += "\n#{ASSETS_CACHE[@album.font_href]}"
    @css += "\n#title, #desc, #zip, .caption {font-family: '#{@album.font_family}', sans-serif !important;}"
    @css += "\n#{ASSETS_CACHE[fancybox]}"

    if @album.reverse?
      @photos = @album.photos.values.reverse
    else
      @photos = @album.photos.values
    end

    haml :album
end
