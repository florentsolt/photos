module Lib
class Index

  def self.protected?
    not Config.default(:index).nil? and not Config.default(:index, :password).nil?
  end

  def self.password
    self.protected? && Config.default(:index, :password)
  end

  def self.albums
    sort = Config.default(:index, :sort) || "name"

    albums = Dir[Config.default(:path) / '*'].collect do |dir|
      if File.directory? dir and File.exists? dir / 'config.yml'
        Album.load(File.basename(dir))
      end
    end.compact

    case sort
    when "name"
      albums.sort!{|a,b| a.name <=> b.name}
    when "title"
      albums.sort!{|a,b| a.config(:title) <=> b.config(:title)}
    when "time", "times", "date", "dates"
      albums.sort!{|a,b| b.timestamp <=> a.timestamp}
    end

    albums
  end

  def self.protected?
    not Config.default(:index).nil? and not Config.default(:index, :password).nil?
  end

  def self.password
    self.protected? && Config.default(:index, :password)
  end

end
end
