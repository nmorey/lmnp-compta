require 'yaml'
require 'fileutils'
require_relative 'settings'

module LMNPCompta
  class Vehicle
    attr_accessor :name, :fiscal_power

    def initialize(name, fiscal_power)
      @name = name
      @fiscal_power = fiscal_power.to_i
    end

    def self.file_path
      File.join(Settings.instance.data_dir, 'vehicles.yaml')
    end

    def self.load_all
      path = file_path
      return [] unless File.exist?(path)

      YAML.load_file(path).map do |data|
        new(data['name'], data['fiscal_power'])
      end
    end

    def self.save_all(vehicles)
      FileUtils.mkdir_p(File.dirname(file_path))
      data = vehicles.map do |v|
        { 'name' => v.name, 'fiscal_power' => v.fiscal_power }
      end
      File.write(file_path, data.to_yaml)
    end

    def self.add(name, fiscal_power)
      vehicles = load_all
      if vehicles.any? { |v| v.name == name }
        raise "Un véhicule nommé '#{name}' existe déjà."
      end
      vehicles << new(name, fiscal_power)
      save_all(vehicles)
    end

    def self.find(name)
      load_all.find { |v| v.name == name }
    end
  end
end
