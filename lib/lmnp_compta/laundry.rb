require 'yaml'
require 'fileutils'
require_relative 'settings'

module LMNPCompta
  # Configuration et calcul des frais de blanchisserie (lavage de linge)
  class Laundry
    attr_accessor :id, :nom_bien, :conso_eau, :prix_eau, :conso_kwh, :prix_kwh, :prix_produit

    # Initialise une configuration de blanchisserie
    # @param id [String, Integer] Identifiant unique
    # @param nom_bien [String] Nom du bien immobilier associé
    # @param conso_eau [Numeric, String] Consommation d'eau en m³ par lavage
    # @param prix_eau [Numeric, String] Prix du m³ d'eau en euros
    # @param conso_kwh [Numeric, String] Consommation électrique en kWh par lavage
    # @param prix_kwh [Numeric, String] Prix du kWh en euros
    # @param prix_produit [Numeric, String] Coût des produits lessiviels par lavage en euros
    def initialize(id, nom_bien, conso_eau, prix_eau, conso_kwh, prix_kwh, prix_produit)
      @id = id.to_s
      @nom_bien = nom_bien
      @conso_eau = conso_eau.to_f
      @prix_eau = prix_eau.to_f
      @conso_kwh = conso_kwh.to_f
      @prix_kwh = prix_kwh.to_f
      @prix_produit = prix_produit.to_f
    end

    # Calcule le coût unitaire d'un lavage
    # @return [Float] Coût en euros par cycle
    def cost_per_wash
      (@conso_eau * @prix_eau) + (@conso_kwh * @prix_kwh) + @prix_produit
    end

    # Retourne le chemin du fichier YAML de configuration
    # @return [String]
    def self.file_path
      File.join(Settings.instance.data_dir, 'blanchisserie.yaml')
    end

    # Charge toutes les configurations de blanchisserie
    # @return [Array<Laundry>]
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

    # Sauvegarde toutes les configurations de blanchisserie
    # @param laundries [Array<Laundry>] Liste des configurations à enregistrer
    # @return [void]
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

    # Ajoute une nouvelle configuration de blanchisserie
    # @param id [String, Integer] Identifiant
    # @param nom_bien [String] Nom du bien
    # @param conso_eau [Numeric, String] Consommation d'eau en m³
    # @param prix_eau [Numeric, String] Prix du m³
    # @param conso_kwh [Numeric, String] Consommation électrique en kWh
    # @param prix_kwh [Numeric, String] Prix du kWh
    # @param prix_produit [Numeric, String] Coût des produits
    # @raise [RuntimeError] Si l'identifiant existe déjà
    # @return [void]
    def self.add(id, nom_bien, conso_eau, prix_eau, conso_kwh, prix_kwh, prix_produit)
      laundries = load_all
      if laundries.any? { |l| l.id == id.to_s }
        raise "Une configuration de blanchisserie avec l'id '#{id}' existe déjà."
      end
      laundries << new(id, nom_bien, conso_eau, prix_eau, conso_kwh, prix_kwh, prix_produit)
      save_all(laundries)
    end

    # Recherche une configuration de blanchisserie par id ou nom de bien
    # @param id [String, Integer] Identifiant ou nom du bien
    # @return [Laundry, nil]
    def self.find(id)
      load_all.find { |l| l.id == id.to_s || l.nom_bien == id.to_s }
    end
  end
end
