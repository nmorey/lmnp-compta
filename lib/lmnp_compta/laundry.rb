require 'yaml'
require 'fileutils'
require_relative 'settings'

module LMNPCompta
  class Laundry
    attr_accessor :id, :nom_bien, :conso_eau, :prix_eau, :conso_kwh, :prix_kwh, :prix_produit

    def initialize(id, nom_bien, conso_eau, prix_eau, conso_kwh, prix_kwh, prix_produit)
      @id = id.to_s
      @nom_bien = nom_bien
      @conso_eau = conso_eau.to_f
      @prix_eau = prix_eau.to_f
      @conso_kwh = conso_kwh.to_f
      @prix_kwh = prix_kwh.to_f
      @prix_produit = prix_produit.to_f
    end

    def cost_per_wash
      (@conso_eau * @prix_eau) + (@conso_kwh * @prix_kwh) + @prix_produit
    end

    def self.file_path
      File.join(Settings.instance.data_dir, 'blanchisserie.yaml')
    end

    def self.load_all
      path = file_path
      return [] unless File.exist?(path)

      YAML.load_file(path).map do |data|
        new(
          data['id'],
          data['nom_bien'],
          data['conso_eau'],
          data['prix_eau'],
          data['conso_kwh'],
          data['prix_kwh'],
          data['prix_produit']
        )
      end
    end

    def self.save_all(laundries)
      FileUtils.mkdir_p(File.dirname(file_path))
      data = laundries.map do |l|
        {
          'id' => l.id,
          'nom_bien' => l.nom_bien,
          'conso_eau' => l.conso_eau,
          'prix_eau' => l.prix_eau,
          'conso_kwh' => l.conso_kwh,
          'prix_kwh' => l.prix_kwh,
          'prix_produit' => l.prix_produit
        }
      end
      File.write(file_path, data.to_yaml)
    end

    def self.add(id, nom_bien, conso_eau, prix_eau, conso_kwh, prix_kwh, prix_produit)
      laundries = load_all
      if laundries.any? { |l| l.id == id.to_s }
        raise "Une configuration de blanchisserie avec l'id '#{id}' existe déjà."
      end
      laundries << new(id, nom_bien, conso_eau, prix_eau, conso_kwh, prix_kwh, prix_produit)
      save_all(laundries)
    end

    def self.find(id)
      load_all.find { |l| l.id == id.to_s || l.nom_bien == id.to_s }
    end
  end
end
