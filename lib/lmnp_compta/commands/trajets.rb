require 'lmnp_compta/command'
require 'lmnp_compta/trip'
require 'lmnp_compta/vehicle'

module LMNPCompta
  class TrajetsCommand < Command
    register :trajets, "Gère les trajets (ajouter <date> <vehicule> <km> <raison>, lister)"

    def execute
      subcommand = @args.shift
      case subcommand
      when 'ajouter'
        add_trip
      when 'lister'
        list_trips
      else
        puts "Usage: lmnp trajets ajouter <date> <vehicule> <km> <raison>"
        puts "       lmnp trajets lister"
      end
    end

    def add_trip
      date_str = @args.shift
      vehicle_name = @args.shift
      km = @args.shift
      reason = @args.join(' ')

      if date_str.nil? || vehicle_name.nil? || km.nil? || reason.empty?
        puts "Erreur : Arguments manquants."
        puts "Usage: lmnp trajets ajouter 2025-01-20 \"Ma Voiture\" 50 \"Visite locataire\""
        return
      end

      # Validate vehicle exists
      unless Vehicle.find(vehicle_name)
        puts "Erreur : Le véhicule '#{vehicle_name}' n'existe pas."
        puts "Utilisez 'lmnp vehicules lister' pour voir les véhicules disponibles."
        return
      end

      begin
        trip = Trip.new(
          date: date_str,
          vehicle_name: vehicle_name,
          distance_km: km,
          reason: reason
        )

        # Determine year from date
        year = trip.date.year
        Trip.add(year, trip)

        puts "Trajet ajouté au journal #{year}."
      rescue => e
        puts "Erreur: #{e.message}"
      end
    end

    def list_trips
      year = Settings.instance.annee
      trips = Trip.load_all(year)

      if trips.empty?
        puts "Aucun trajet enregistré pour #{year}."
      else
        puts "Trajets enregistrés pour #{year} :"
        total_km = 0
        trips.sort_by(&:date).each do |t|
          puts "#{t.date} | #{t.vehicle_name.ljust(15)} | #{t.distance_km.to_s.rjust(5)} km | #{t.reason}"
          total_km += t.distance_km
        end
        puts "-" * 50
        puts "Total: #{total_km} km"
      end
    end
  end
end
