require "digest/sha1"

module Lib
class Set

  def initialize(album, url)
    @album = album
    @url = URI.parse url
  end

  def type
    @url.scheme
  end

  def flickr?
    ['flickr', 'gp'].include? type
  end

  def zip?
    ['zip', 'zip+scp', 'zip+http'].include? type
  end

  def photos
    urls = []

    case type
    when "flickr"
      photos = flickr.photosets.getPhotos(:photoset_id => @url.host, :extras => 'url_o')
      puts "Found #{photos.photo.count} photos in set #{@url.host}"
      urls += photos.photo.collect(&:url_o)

    when "zip", "zip+http", "zip+scp"

      case type
      when "zip"
        if @url.path.empty?
          filename = @album.config(:path) / @album.name / @url.host
        else
          filename = @url.path
        end
        throw "File does not exists #{@url}" if not File.exists? filename
      when "zip+http"
        filename = "/tmp/photos-#{Digest::SHA1.hexdigest(@url.to_s)}.zip"
        if not File.exists? filename
          url = @url.clone
          url.scheme = "http"
          system "curl '#{url}' -o '#{filename}'"
        end
      when "zip+scp"
        filename = "/tmp/photos-#{Digest::SHA1.hexdigest(@url.to_s)}.zip"
        system "scp '#{@url.user}@#{@url.host}:#{@url.path}' '#{filename}'" if not File.exists? filename
      end

      require 'zip'
      zip = Zip::File.open(filename)
      i = 0
      zip.map.each do |entry|
        ext = File.extname(entry.to_s).downcase
        if not entry.directory? and 
            not entry.to_s.include?('__MACOSX') and 
            not File.basename(entry.to_s)[0] == '.' and
            ['.jpg', '.jpeg', '.gif'].include?(ext)
          out = @album.config(:path) / @album.name / "zip-#{[@url.host, *@url.path.split('/')].join('-')}-#{i += 1}#{ext}"
          puts "Extract #{entry} in #{File.basename(out)}"
          File.open(out, 'w:BINARY') do |fd|
              fd.write zip.read(entry)
          end
          urls << "file://#{out}"
        else
          puts "Skip #{entry}"
        end
      end

    when "gp"
      require 'nokogiri'

      http = Curl::Easy.new
      http.resolve_mode = :ipv4
      http.follow_location = true
      http.enable_cookies = true
      http.cookies = "localization=en-us%3Bus%3Bfr"
      http.url = "http://flickr.com/gp" / @url.host / @url.path
      http.perform

      doc = Nokogiri::HTML(http.body_str)
      doc.css('.thumb a').each do |thumb|
        puts "Found a thumb for #{thumb['href']}"

        http.url = "http://www.flickr.com" + thumb['href'].sub(/\/in\//, '/sizes/o/in/')
        http.perform

        original = Nokogiri::HTML(http.body_str)
        original.css('#all-sizes-header a').each do |link|
          if link.content =~ /Download/i
            urls << link['href']
          end
        end
      end

    when "local"
      photo = Album.load(@url.host).photos[@url.path[1..-1]]
      urls << "file://#{photo.uri(:original)}"

    else
      throw "Unkown set type #{@url}"
    end
    urls
  end

end
end
