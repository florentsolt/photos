# encoding: utf-8

require 'sinatra'
require 'sinatra/cookies'
require 'sinatra/r18n'
require 'haml'
require 'sass'
require 'digest/sha1'
require 'openssl'
require 'digest/sha1'
require 'base64'

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

  def crypt(path)
    cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc").encrypt
    iv = cipher.random_iv
    cipher.key = Digest::SHA1.hexdigest("yourpass")
    cipher.iv = iv
    encrypted = cipher.update('thailande-2014/00545')
    encrypted << cipher.final
    Base64.urlsafe_encode64(iv+encrypted)
  end

  def decrypt(token)
    token = Base64.urlsafe_decode64(token)
    cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc").decrypt
    cipher.key = Digest::SHA1.hexdigest("yourpass")
    cipher.iv = token[0..15]
    result = cipher.update(token[16..-1])
    result << cipher.final
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
      headers "Cache-Control" => "no-cache, no-store, must-revalidate"
      headers "Pragma" => "no-cache"
      headers "Expires" => "0"
      halt 403, haml(:password)
    end
  end

  def mobile?
    request.user_agent =~ /ipad|iphone|mobile|android/i
  end

  def ipad?
    request.user_agent =~ /ipad/i
  end

  def deliver(file, type, download = false)
    if download and not mobile?
      headers "Content-Disposition" => "attachment; filename=#{File.basename(file)}"
    end
    content_type type
    if settings.production?
      file = "/direct/" + file
      headers "X-Accel-Redirect" => file
    else
      etag "#{file}@#{File.mtime(Lib::Config.default(:path) / file)}"
      if mobile? or not download
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
    if mobile?
      preview(photo)
    else
      "#{request.scheme}://#{domain}/#{@album.name}/#{photo.id}"
    end
  end

  def preview(photo)
    "#{request.scheme}://#{domain}/#{@album.name}/#{photo.id}/preview.#{photo.ext}"
  end

  def thumb(photo)
    if ipad?
      type = :preview
      width = 720
      height = width * photo.size(type).y.to_i / photo.size(type).x.to_i,
    else
      type = :resize
      width = photo.size(:resize).x.to_i
      height = photo.size(:resize).y.to_i)
    end

    "<img class='lazy' width='%d' height='%d' data-original='%s' src='/gfx/transparent.gif'>" % [
      width,
      height,
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

get '/link/:token/:type.:ext' do
  call env.merge("PATH_INFO" => "/#{decrypt(params[:token])}/#{params[:type]}.#{params[:ext]}")
end

[:square, :resize, :preview, :original].each do |type|
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
    deliver @photo.uri(type), @photo.ext, true
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
  deliver @album.name / @album.zip, :zip, true
end

get '/:name/:id/exif' do
  @album = Lib::Album.load params[:name]
  password?
  @photo = @album.photos[params[:id]]
  "<html><body><pre>" + @photo.exif(true).collect do |k,v|
    "<b>#{k}:</b> #{v}"
  end.join("\n") + "</pre></body></html>"
end

get '/:name/?' do
    @album = Lib::Album.load params[:name]
    password?

    if @album.reverse?
      @photos = @album.photos.values.reverse
    else
      @photos = @album.photos.values
    end
    haml :album
end

get '/:name/:id/?' do
  @album = Lib::Album.load params[:name]
  password?

  halt 404 if not @album.photos.key? params[:id]
  @photo = @album.photos[params[:id]]

  @data = {
    :preview => preview(@photo),
    :back => "/#{@album.name}/##{@photo.id}",
    :zip => @album.config(:zip) && !mobile?,
    :album => @album.name,
    :id => @photo.id,
    :ext => @photo.ext,
    :exif => exif(@photo),
    :share => @album.config(:share),
    :page => photo_page(@photo),
    :next => photo_page(@album.reverse? && @photo.prev || @photo.next),
    :prev => photo_page(@album.reverse? && @photo.next || @photo.prev),
    :crypt => crypt(@album.name + "/" + @photo.id.to_s),
  }

  if request.xhr?
    content_type :json
    @data.to_json
  else
    haml :photo
  end
end

