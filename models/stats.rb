module Model
class Stream

  class << self
    def totals!
      self.each do |stream|
        totals = []
        stream.ids.each do |id,ext|
          total = []
          total += DB.hvals("stat.flickr.#{stream.name}.#{id}")
          total += DB.hvals("stat.ganalytics.#{stream.name}.#{id}")
          total = total.map{|v| v.to_i}.reduce(:+).to_i
          DB.hset "stat.total", "#{stream.name}.#{id}", total.to_i
          totals << total
        end
        DB.hset "stat.total", "#{stream.name}", totals.reduce(:+).to_i
      end
    end
  end

  def stats!(date)
    [:flickr, :ganalytics].each do |source|
      sum = ids.keys.collect do |id|
        DB.hget("stat.#{source}.#{@name}.#{id}", date).to_i
      end.inject(:+)
      DB.hset "stat.#{source}.#{@name}", date, sum
    end
  end

  def stats(date = false)
    if date

      result = {}

      # All details for the given date
      result[:all] = ids.keys.collect do |id|
        flickr = DB.hget("stat.flickr.#{@name}.#{id}", date).to_i
        ganalytics = DB.hget("stat.ganalytics.#{@name}.#{id}", date).to_i

        {:photo => Photo.new(self, id),
         :flickr => flickr,
         :ganalytics => ganalytics,
         :sum => flickr + ganalytics,
         :total => DB.hget("stat.total", "#{@name}.#{id}").to_i}
      end.delete_if do |stat|
        stat[:flickr] + stat[:ganalytics] == 0
      end.sort do |a,b|
        b[:sum] <=> a[:sum]
      end

      # Build sums
      result[:sum]= {}
      result[:sum][:flickr] = result[:all].map{|v|v[:flickr]}.reduce(:+).to_i
      result[:sum][:ganalytics] = result[:all].map{|v|v[:ganalytics]}.reduce(:+).to_i

      # Total
      result[:total] = DB.hget("stat.total", @name).to_i

      result

    else
      # Values for the last 90 days
      dates = []
      weeks = {}
      1.upto(90).collect do |i|
        time = Time.now - 3600 * 24 * i
        dates << time.strftime("%Y-%m-%d")
        week = time.strftime("%Y-%V")
        weeks[week] ||= []
        weeks[week] << dates.last
      end
      dates.reverse!

      result = {:flickr => [], :ganalytics => []}
      result.keys.each do |source|
        result[source] = DB.hmget("stat.#{source}.#{@name}", *dates).map{|v| v.to_i}
      end
      result[:dates] = dates

      # Trends init
      result[:trends] = []

      # Convert dates in index, then sum stats
      weeks.keys.each do |week|
        weeks[week] = weeks[week].map do |date|
          i = dates.index(date)
          result[:flickr][i] + result[:ganalytics][i]
        end.reduce(:+)
      end

      2.upto(5).each do |i|
        keys = weeks.keys.sort[-i,2]
        result[:trends] << {
          :week => keys.last.split('-').last,
          :trend => weeks[keys.last] - weeks[keys.first]
        }
      end

      result[:trends].reverse!

      result
    end
  end
end

class Photo

  def stat!(source, date, views)
    if views.to_i > 0 and [:flickr, :ganalytics].include? source
      # because this function is used with 0 to rebuild all totals
      key = "stat.#{source}.#{@stream.name}.#{@id}"
      DB.hset key, date, views.to_i
    end

    # Calculate photo total
    total = []
    total += DB.hvals("stat.flickr.#{@stream.name}.#{@id}")
    total += DB.hvals("stat.ganalytics.#{@stream.name}.#{@id}")
    total = total.inject{|sum, n| sum = sum.to_i + n.to_i}.to_i
    DB.hset "stat.total", "#{@stream.name}.#{@id}", total
  end

  def stats
    dates = 1.upto(20).collect do |i|
      (Time.now - 3600 * 24 * i).strftime("%Y-%m-%d")
    end.reverse
    result = {:flickr => [], :ganalytics => []}
    result.keys.each do |source|
      result[source] = DB.hmget("stat.#{source}.#{@stream.name}.#{@id}", *dates)
      result[source].collect!{|value| value.to_i }
    end
    result[:total] = DB.hget("stat.total", "#{@stream.name}.#{@id}").to_i
    result[:dates] = dates
    result
  end

end
end

