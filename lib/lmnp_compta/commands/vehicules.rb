require 'lmnp_compta/command'
require 'lmnp_compta/vehicle'

module LMNPCompta
  class VehiculesCommand < Command
    register :vehicules, "Gère les véhicules personnels (ajouter <nom> <cv>, lister)"

    def execute
      subcommand = @args.shift
      case subcommand
      when 'ajouter'
        add_vehicle
      when 'lister'
        list_vehicles
      else
        puts "Usage: lmnp vehicules ajouter <nom> <cv>"
        puts "       lmnp vehicules lister"
      end
    end

    def add_vehicle
      name = @args.shift
      cv = @args.shift

      if name.nil? || cv.nil?
        puts "Erreur : Nom et CV requis."
        puts "Usage: lmnp vehicules ajouter \"Ma Voiture\" 5"
        return
      end

      begin
        Vehicle.add(name, cv)
        puts "Véhicule '#{name}' (#{cv} CV) ajouté."
      rescue => e
        puts "Erreur: #{e.message}"
      end
    end

    def list_vehicles
      vehicles = Vehicle.load_all
      if vehicles.empty?
        puts "Aucun véhicule enregistré."
      else
        puts "Véhicules enregistrés :"
        vehicles.each do |v|
          puts "- #{v.name} (#{v.fiscal_power} CV)"
        end
      end
    end
  end
end
