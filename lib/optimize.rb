module Lib
module Optimize
  def self.file(filename)
    return if not File.exists? filename
    ext = File.extname(filename)[1..-1]
    send(ext, filename)
  end

  private

  def self.jpg(filename)
    puts "Optimize JPG #{File.basename(filename)}"
    system "jpegtran -optimize -copy none -progressive -outfile '#{filename}' '#{filename}'"
  end

  def self.png(filename)
    puts "Optimize PNG #{File.basename(filename)}"
    system "pngcrush -q '#{filename}' '#{filename}.new'; mv '#{filename}.new' '#{filename}'"
  end

  def self.gif(filename)
    puts "Optimize GIF #{File.basename(filename)}"
    system "gifsicle -b '#{filename}'"
  end
end
end
