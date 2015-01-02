require 'yaml'
require 'uri'
require 'json'

# / helpers
class String; def /(path); File.join(self, path.to_s); end; end
class Symbol; def /(path); File.join(self.to_s, path.to_s); end; end

require __dir__ / :lib / :config
require __dir__ / :lib / :index
require __dir__ / :lib / :times
require __dir__ / :lib / :album
require __dir__ / :lib / :set
require __dir__ / :lib / :size
require __dir__ / :lib / :exif
require __dir__ / :lib / :photo
require __dir__ / :lib / :optimize

