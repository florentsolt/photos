namespace :photos do

  task :config do
    require 'yaml'
    require 'flickraw'
    require File.join(__dir__, 'models')

    FlickRaw.api_key = Model::CONFIG['flickr']['apikey']
    FlickRaw.shared_secret = Model::CONFIG['flickr']['secret']
  end

  desc "Authorization for your flickr account"
  task :auth => :config do
    if Model::CONFIG['flickr']['access'].nil?
      token = flickr.get_request_token
      auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => :read)

      puts "Open this url in your process to complete the authication process : #{auth_url}"
      puts "Copy here the number given when you complete the process."
      verify = STDIN.gets.strip

      flickr.get_access_token(token['oauth_token'] , token['oauth_token_secret'] , verify)
      flickr.test.login
        Model::CONFIG['flickr']['access'] = {
          'token' => flickr.access_token,
          'secret' => flickr.access_secret
        }

        File.open(File.dirname(__FILE__) / 'config.yml', 'w') do |fd|
          fd.puts Model::CONFIG.to_yaml
        end
    else
      flickr.access_token = Model::CONFIG['flickr']['access']['token']
      flickr.access_secret = Model::CONFIG['flickr']['access']['secret']
    end
  end

  task :init, [:name] => :auth do |task, args|
    if args[:name].nil?
      puts "You must provide a <name>"
      exit
    end
    @stream = Model::Stream.new(args[:name])
  end

  desc "Clear downloaded zip files"
  task :clean_tmp do
    sh "find /tmp -name photos-\*.zip -ctime +6 -print -exec rm {} \\;"
  end

  desc "Download photos"
  task :download, [:name] => :init do
    @stream.download!
  end

  desc "Generate thumbnails"
  task :thumbs, [:name] => :init do
    @stream.thumbs!
  end

  desc "Force generate thumbnails"
  task :force_thumbs, [:name] => :init do
    @stream.thumbs! true
  end

  desc "Generate samples"
  task :samples, [:name] => :thumbs do
    @stream.samples!
  end

  desc "Force generate samples"
  task :force_samples, [:name] => :thumbs do
    @stream.samples! true
  end

  desc "Generate sizes"
  task :sizes, [:name] => :init do |task, args|
    @stream.sizes!
    @stream = Model::Stream.new(args[:name]) # re create
  end

  desc "Force generate sizes"
  task :force_sizes, [:name] => :init do |task, args|
    @stream.sizes! true
    @stream = Model::Stream.new(args[:name]) # re create
  end

  desc "Compress the photos"
  task :zip, [:name] => :download do
    @stream.zip!
  end

  desc "Extract EXIF"
  task :exif, [:name] => :init do
    @stream.exif!
  end

  desc "Force extract EXIF"
  task :force_exif, [:name] => :init do
    @stream.exif! true
  end

  desc "Extract times"
  task :times, [:name] => :exif do
    @stream.times!
  end

  desc "Force extract times"
  task :force_times, [:name] => :exif do
    @stream.times! true
  end

  desc "Optimize the photos"
  task :optimize, [:name] => :thumbs do
    @stream.optimize!
  end

  desc "Clear all photos"
  task :clear, [:name] => :init do
    @stream.clear!
  end

  desc "Rebuild"
  task :rebuild, [:name] => :init do
    @stream.clear! true
    @stream.thumbs! true
    @stream.samples! true
    @stream.sizes! true
    @stream.optimize!
    @stream.exif! true
    @stream.times! true
  end

  desc "La totale"
  task :all, [:name] => [:download, :thumbs, :sizes, :exif, :samples, :zip, :optimize, :times]

end

