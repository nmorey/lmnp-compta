require 'yaml'
require 'date'
require 'fileutils'
require_relative 'settings'

module LMNPCompta
  class Trip
    attr_accessor :date, :vehicle_name, :reason, :distance_km

    def initialize(attrs = {})
      @date = Date.parse(attrs[:date].to_s)
      @vehicle_name = attrs[:vehicle_name] || attrs['vehicle_name']
      @reason = attrs[:reason] || attrs['reason']
      @distance_km = Montant.new(attrs[:distance_km] || attrs['distance_km'])
    end

    def self.file_path(year)
      File.join(Settings.instance.data_dir, year.to_s, 'trips.yaml')
    end

    def self.load_all(year)
      path = file_path(year)
      return [] unless File.exist?(path)

      YAML.load_file(path).map do |data|
        new({
          date: data['date'],
          vehicle_name: data['vehicle_name'],
          reason: data['reason'],
          distance_km: data['distance_km']
        })
      end
    end

    def self.save_all(year, trips)
      path = file_path(year)
      FileUtils.mkdir_p(File.dirname(path))

      # Sort by date
      sorted = trips.sort_by(&:date)

      data = sorted.map do |t|
        {
          'date' => t.date.to_s,
          'vehicle_name' => t.vehicle_name,
          'reason' => t.reason,
          'distance_km' => t.distance_km.to_s
        }
      end
      File.write(path, data.to_yaml)
    end

    def self.add(year, trip)
      if trip.date.year != year.to_i
        raise "Erreur : La date du trajet (#{trip.date}) ne correspond pas à l'année demandée (#{year})"
      end

      trips = load_all(year)
      trips << trip
      save_all(year, trips)
    end

    def to_h
       {
          'date' => @date.to_s,
          'vehicle_name' => @vehicle_name,
          'reason' => @reason,
          'distance_km' => @distance_km.to_s
        }
    end
  end
end
