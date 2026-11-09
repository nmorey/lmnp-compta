require 'yaml'
require 'fileutils'
require_relative 'settings'

module LMNPCompta
  # Représente un véhicule utilisé pour les déplacements professionnels
  class Vehicle
    attr_accessor :name, :fiscal_power

    # Initialise un nouveau véhicule
    # @param name [String] Nom ou identifiant du véhicule
    # @param fiscal_power [Integer, String] Puissance fiscale en CV
    def initialize(name, fiscal_power)
      @name = name
      @fiscal_power = fiscal_power.to_i
    end

    # Chemin du fichier YAML de configuration des véhicules
    # @return [String]
    def self.file_path
      File.join(Settings.instance.data_dir, 'vehicles.yaml')
    end

    # Charge tous les véhicules configurés
    # @return [Array<Vehicle>]
    def self.load_all
      path = file_path
      return [] unless File.exist?(path)

      YAML.load_file(path).map do |data|
        new(data['name'], data['fiscal_power'])
      end
    end

    # Sauvegarde la liste complète des véhicules
    # @param vehicles [Array<Vehicle>] Liste des véhicules à sauvegarder
    # @return [void]
    def self.save_all(vehicles)
      FileUtils.mkdir_p(File.dirname(file_path))
      data = vehicles.map do |v|
        { 'name' => v.name, 'fiscal_power' => v.fiscal_power }
      end
      File.write(file_path, data.to_yaml)
    end

    # Ajoute un nouveau véhicule à la configuration
    # @param name [String] Nom du véhicule
    # @param fiscal_power [Integer, String] Puissance fiscale en CV
    # @raise [RuntimeError] Si un véhicule avec ce nom existe déjà
    # @return [void]
    def self.add(name, fiscal_power)
      vehicles = load_all
      if vehicles.any? { |v| v.name == name }
        raise "Un véhicule nommé '#{name}' existe déjà."
      end
      vehicles << new(name, fiscal_power)
      save_all(vehicles)
    end

    # Recherche un véhicule par son nom
    # @param name [String] Nom du véhicule
    # @return [Vehicle, nil]
    def self.find(name)
      load_all.find { |v| v.name == name }
    end
  end
end
