namespace :photos do

  task :config, [:name] do |task, args|
    require 'yaml'
    require 'flickraw'
    require File.join(__dir__, 'lib')

    FlickRaw.api_key = Lib::Config.default(:flickr, :api_key)
    FlickRaw.shared_secret = Lib::Config.default(:flickr, :shared_secret)

    if args[:name].nil?
      pwd = ENV['PWD']
      root = File.realpath(Lib::Config.default(:path))
      if pwd.start_with? root
        @name = pwd[root.length+1..-1]
      else
        puts "You must provide a <name> or move to a folder containing a <config.yml>"
        exit
      end
    else
      @name = args[:name]
    end
    @album = Lib::Album.load @name
  end

  desc "Authorization for your flickr account"
  task :auth => :config do
    if @album.flickr?
      if Lib::Config.default(:flickr, :access_token).nil? or Lib::Config.default(:flickr, :access_secret).nil?
        token = flickr.get_request_token
        auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => :read)

        puts "Open this url in your process to complete the authication process : #{auth_url}"
        puts "Copy here the number given when you complete the process."
        verify = STDIN.gets.strip

        flickr.get_access_token(token['oauth_token'] , token['oauth_token_secret'] , verify)
        flickr.test.login
        Lib::Config.flickr = flickr
      else
        flickr.access_token = Lib::Config.default(:flickr, :access_token)
        flickr.access_secret = Lib::Config.default(:flickr, :access_secret)
      end
    end
  end

  desc "Clear downloaded zip files"
  task :clean_tmp do
    sh "find /tmp -name photos-\*.zip -ctime +6 -print -exec rm {} \\;"
  end

  desc "Download photos"
  task :download, [:name] => :auth do
    @album.download!
  end

  desc "Generate thumbnails"
  task :thumbs, [:name] => :auth do
    @album.thumbs!
  end

  desc "Force generate thumbnails"
  task :force_thumbs, [:name] => :auth do
    @album.thumbs! true
  end

  desc "Generate samples"
  task :samples, [:name] => :thumbs do
    @album.samples!
  end

  desc "Force generate samples"
  task :force_samples, [:name] => :thumbs do
    @album.samples! true
  end

  desc "Get sizes"
  task :sizes, [:name] => :auth do |task, args|
    @album.sizes!
  end

  desc "Force getting sizes"
  task :force_sizes, [:name] => :auth do |task, args|
    @album.sizes! true
  end

  desc "Get timestamp of the 1st photo"
  task :timestamp, [:name] => :auth do |task, args|
    @album.timestamp
  end

  desc "Compress the photos"
  task :zip, [:name] => :download do
    @album.zip!
  end

  desc "Optimize the photos"
  task :optimize, [:name] => :thumbs do
    @album.optimize!
  end

  desc "Clear all photos even originals"
  task :clear, [:name] => :auth do
    @album.clear!
  end

  desc "Rebuild (without removing originals)"
  task :rebuild, [:name] => :auth do |task, args|
    @album.clear! true
    @album = Lib::Album.load @name
    @album.scan!
    @album.thumbs! true
    @album.samples! true
    @album.sizes! true
    @album.optimize!
    @album.zip!
  end

  desc "Rebuild metadatas"
  task :meta, [:name] => :config do
    @album.scan!
    @album.sizes!
  end

  desc "Scan"
  task :scan, [:name] => :config do
    @album.scan!
    @album.thumbs!
    @album.samples!
    @album.sizes!
    @album.optimize!
    @album.zip!
  end

  desc "La totale"
  task :all, [:name] => [:download, :thumbs, :sizes, :samples, :zip, :optimize]

end

