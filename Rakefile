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

  namespace :stats do

    desc "Rebuild"
    task :rebuild => :auth do
      require :apps / :photos / :models

      # Clear all
      keys = DB.keys("stat*")
      DB.del *keys if not keys.empty?

      # Last 30 days
      @dates = 1.upto(30).collect do |i|
        (Time.now - 3600 * 24 * i).strftime("%Y-%m-%d")
      end.reverse

      # Execute flickr
      Rake::Task["photos:stats:flickr:daily"].execute

      # Since Epoch
      @dates = [Time.utc(2005, 1, 1), Time.now - 3600 * 24].collect do |time|
        time.strftime("%Y-%m-%d")
      end

      # Execute ganalytics
      Rake::Task["photos:stats:ganalytics"].execute

      # Fix missing views from flickr
      Rake::Task["photos:stats:flickr:totals"].execute

      @dates = (DB.keys("stat.flickr.*") + DB.keys("stat.ganalytics.*")).collect do |key|
        DB.hkeys key
      end.flatten.sort.uniq
      
      # Execute streams
      Rake::Task["photos:stats:streams"].execute

      # Execute totals
      Rake::Task["photos:stats:totals"].execute

    end

    desc "Daily stats"
    task :daily => [:auth, :dates, 'flickr:daily', :ganalytics, :streams, :totals]
    
    task :dates do
      # Crawl the last 8 days starting from yesterday
      @dates = 1.upto(30).collect do |i|
        (Time.now - 3600 * 24 * i).strftime("%Y-%m-%d")
      end.reverse
    end

    namespace :flickr do
      task :totals => :auth do
        require :apps / :photos / :models

        epoch = Time.at(0).strftime('%Y-%m-%d')

        DB.hgetall('flickr').invert.each do |uri, data|
          stream, id = uri.split('/')
          puts uri
          flickr_total = flickr.photos.getInfo(:photo_id => data.split('-').last)["views"].to_i
          DB.hdel "stat.flickr.#{stream}.#{id}", epoch
          known_total = DB.hvals("stat.flickr.#{stream}.#{id}").map{|v|v.to_i}.reduce(:+)
          DB.hset "stat.flickr.#{stream}.#{id}", epoch, flickr_total.to_i - known_total.to_i
        end
      end

      task :daily do
        require :apps / :photos / :models

        puts "Crawling flickr stats..."
        @dates.each do |date|
          # TODO: support more than 1 page
          flickr.stats.getPopularPhotos(:date => date, :per_page => 100).each do |stat|
            begin
              photo = Model::Photo.from_flickr(stat["farm"], stat["server"], stat["id"])
              photo.stat!(:flickr, date, stat["stats"]["views"])
            rescue
              puts " * Photo not found: #{stat["title"].inspect} > http://www.flickr.com/photos/#{stat["owner"]}/#{stat["id"]}"
            end
          end
        end
      end
    end

    task :ganalytics do 
      puts "Crawling Google Analytics stats..."
      require "gattica"
      ga = Gattica.new({
        :email => Model::CONFIG['ganalytics']['email'],
        :password => Model::CONFIG['ganalytics']['password']
      })
      if not Model::CONFIG['ganalytics'].key? 'profile'
        puts "Select your account and fill the config:"
        ga.accounts.each do |account|
          puts "* #{account.profile_id}: #{account.account_name} / #{account.title}"
        end
        exit
      end
      ga.profile_id = Model::CONFIG['ganalytics']['profile']
      # http://ga-dev-tools.appspot.com/explorer/
      data = ga.get({
        :start_date   => @dates.first,
        :end_date     => @dates.last,
        :dimensions   => ['date', 'pagePath'],
        :metrics      => ['uniquePageviews'],
        :max_results  => 1000000
      })
      data.points.each do |point|
        date = point.dimensions.first[:date]
        date = "#{date[0..3]}-#{date[4..5]}-#{date[6..7]}"
        uri = point.dimensions.last[:pagePath]
        views = point.metrics.first[:uniquePageviews]
        if uri =~ %r|/([^/]+/\d+)|
          begin
            photo = Model::Photo.from_uri($1)
            photo.stat!(:ganalytics, date, views)
          rescue
            puts " * Photo not found: #{uri}"
            next
          end
        end
      end
    end

    task :streams do
      Model::Stream.each do |stream|
        @dates.each do |date|
          stream.stats! date
        end
      end
    end

    task :totals do
      require :apps / :photos / :models
      Model::Stream.totals!
    end

  end
end

