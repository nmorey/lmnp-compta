require 'lmnp_compta/commands/journal/sub_command'
require 'lmnp_compta/trip'
require 'lmnp_compta/vehicle'
require 'lmnp_compta/settings'
require 'date'

module LMNPCompta
  module Commands
    module Journal
      class Trajets < SubCommand
        register 'trajets', 'Gérer les trajets kilométriques'

        def execute
          sub = @args.shift
          case sub
          when 'ajouter'
             date = @args.shift
             veh = @args.shift
             km = @args.shift
             raison = @args.join(' ')
             if date.nil? || veh.nil? || km.nil? || raison.empty?
                 puts "Usage: lmnp journal trajets ajouter DATE VEHICULE KM RAISON"
                 return
             end
             unless Vehicle.find(veh)
                 puts "Erreur: Véhicule inconnu '#{veh}'"
                 return
             end
             Trip.add(Date.parse(date).year, Trip.new(date: date, vehicle_name: veh, distance_km: km, reason: raison))
             puts "✅ Trajet ajouté."
          when 'lister'
             year = Settings.instance.annee
             trips = Trip.load_all(year)
             puts "Trajets #{year}:"
             trips.each { |t| puts "#{t.date} | #{t.vehicle_name} | #{t.distance_km}km | #{t.reason}" }
             puts "Total: #{trips.sum(&:distance_km)} km"
          else
             puts "Usage: lmnp journal trajets {ajouter|lister}"
          end
        end
      end
    end
  end
end
