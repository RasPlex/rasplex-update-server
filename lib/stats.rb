
require_relative 'models.rb'

class StatsJob

  def initialize( interval, geo_ip )
    # make this a config constant
    @stats = ""
    @geo_ip = geo_ip
    loadStats
    EM.add_periodic_timer(interval) do
      loadStats
    end
  end

  def loadStats
    @stats = getStats(@geo_ip)
  end

  def cachedStats
    return @stats
  end
end


