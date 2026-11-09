require 'yaml'
require 'date'
require 'fileutils'
require_relative 'settings'

module LMNPCompta
  # Représente un déplacement professionnel déductible au barème kilométrique
  class Trip
    attr_accessor :date, :vehicle_name, :reason, :distance_km

    # Initialise un nouveau trajet
    # @param attrs [Hash] Attributs du trajet (:date, :vehicle_name, :reason, :distance_km)
    def initialize(attrs = {})
      @date = Date.parse(attrs[:date].to_s)
      @vehicle_name = attrs[:vehicle_name] || attrs['vehicle_name']
      @reason = attrs[:reason] || attrs['reason']
      @distance_km = Montant.new(attrs[:distance_km] || attrs['distance_km'])
    end

    # Retourne le chemin du fichier YAML des trajets pour une année
    # @param year [Integer, String] Année fiscale
    # @return [String] Chemin vers trips.yaml
    def self.file_path(year)
      File.join(Settings.instance.data_dir, year.to_s, 'trips.yaml')
    end

    # Charge tous les trajets d'une année donnée
    # @param year [Integer, String] Année fiscale
    # @return [Array<Trip>] Liste des trajets
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

    # Sauvegarde une liste de trajets pour une année
    # @param year [Integer, String] Année fiscale
    # @param trips [Array<Trip>] Liste des trajets à enregistrer
    # @return [void]
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

    # Ajoute un trajet pour une année donnée
    # @param year [Integer, String] Année fiscale
    # @param trip [Trip] Trajet à ajouter
    # @raise [RuntimeError] Si l'année du trajet ne correspond pas
    # @return [void]
    def self.add(year, trip)
      if trip.date.year != year.to_i
        raise "Erreur : La date du trajet (#{trip.date}) ne correspond pas à l'année demandée (#{year})"
      end

      trips = load_all(year)
      trips << trip
      save_all(year, trips)
    end

    # Convertit le trajet en Hash pour la sérialisation
    # @return [Hash]
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
