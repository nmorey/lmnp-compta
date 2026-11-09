require 'yaml'
require 'fileutils'
require 'date'
require_relative 'settings'

module LMNPCompta
    # Gère les métriques annuelles de disponibilité d'un bien immobilier
    # pour le calcul du prorata temporis des charges mixtes.
    class Disponibilite
        attr_accessor :nom_bien, :annee, :disponibles, :indisponibles, :pleine_annee

        # Initialise une nouvelle métrique de disponibilité
        # @param attrs [Hash] Attributs (:nom_bien, :annee, :disponibles, :indisponibles, :pleine_annee)
        def initialize(attrs = {})
            @nom_bien = attrs['nom_bien'] || attrs[:nom_bien]
            @annee = (attrs['annee'] || attrs[:annee] || Date.today.year).to_i
            @pleine_annee = attrs['pleine_annee'] == true || attrs[:pleine_annee] == true

            expected = expected_days_in_year
            raw_disp = attrs['disponibles'] || attrs[:disponibles]
            raw_indisp = attrs['indisponibles'] || attrs[:indisponibles]

            if @pleine_annee
                @disponibles = expected
                @indisponibles = 0
            elsif raw_disp && raw_indisp.nil?
                @disponibles = raw_disp.to_i
                @indisponibles = expected - @disponibles
            elsif raw_indisp && raw_disp.nil?
                @indisponibles = raw_indisp.to_i
                @disponibles = expected - @indisponibles
            else
                @disponibles = (raw_disp || expected).to_i
                @indisponibles = (raw_indisp || 0).to_i
            end
        end

        # Calcule le total des jours/nuits saisis (disponibles + indisponibles)
        # @return [Integer]
        def total_nuits
            @disponibles + @indisponibles
        end

        # Nombre de jours attendus pour l'année civile (365 ou 366 si bissextile)
        # @return [Integer]
        def expected_days_in_year
            Date.leap?(@annee) ? 366 : 365
        end

        # Vérifie si la somme des jours saisis est cohérente avec l'année
        # @return [Boolean]
        def valid_days_sum?
            @disponibles >= 0 && @indisponibles >= 0 && total_nuits == expected_days_in_year
        end

        # Indique si le bien est loué toute l'année sans période personnelle
        # @return [Boolean]
        def pleine_annee?
            @pleine_annee || (@indisponibles == 0 && total_nuits == expected_days_in_year)
        end

        # Valide la cohérence du nombre de jours
        # @raise [RuntimeError] Si le total de jours ne correspond pas à l'année
        # @return [void]
        def validate!
            expected = expected_days_in_year
            unless valid_days_sum?
                raise "Incohérence du nombre de jours pour l'année #{@annee} : #{total_nuits} jours saisis (disponibles: #{@disponibles}, indisponibles: #{@indisponibles}), attendu: #{expected} jours."
            end
        end

        # Calcule le prorata temporis de déductibilité (jours disponibles / jours totaux)
        # @return [Float] Ratio entre 0.0 et 1.0 arrondi à 6 décimales
        def prorata_temporis
            return 0.0 if total_nuits == 0
            (@disponibles.to_f / total_nuits.to_f).round(6)
        end

        # Convertit en Hash pour la sérialisation YAML
        # @return [Hash]
        def to_h
            h = {
                'disponibles' => @disponibles,
                'indisponibles' => @indisponibles,
                'prorata_temporis' => prorata_temporis
            }
            h['pleine_annee'] = true if @pleine_annee
            h
        end

        # Retourne le chemin du fichier YAML des disponibilités pour une année
        # @param year [Integer, String] Année fiscale
        # @return [String] Chemin vers disponibilite.yaml
        def self.file_path(year)
            File.join(Settings.instance.data_dir, year.to_s, "disponibilite.yaml")
        end

        # Charge toutes les disponibilités pour une année
        # @param year [Integer, String] Année fiscale
        # @return [Hash{String => Disponibilite}] Dictionnaire nom de bien => Disponibilite
        def self.load_all(year)
            path = file_path(year)
            return {} unless File.exist?(path)

            raw = YAML.load_file(path) || {}
            result = {}
            raw.each do |bien_nom, data|
                data = data.merge('nom_bien' => bien_nom, 'annee' => year)
                result[bien_nom] = Disponibilite.new(data)
            end
            result
        end

        # Recherche la disponibilité d'un bien pour une année
        # @param nom_bien [String] Nom du bien
        # @param year [Integer, String] Année fiscale
        # @return [Disponibilite, nil]
        def self.find(nom_bien, year)
            load_all(year)[nom_bien]
        end

        # Enregistre une configuration de disponibilité dans le fichier YAML
        # @param dispo [Disponibilite] Disponibilité à enregistrer
        # @return [void]
        def self.save(dispo)
            dispo.validate!
            all = load_all(dispo.annee)
            all[dispo.nom_bien] = dispo

            data_to_write = {}
            all.each do |nom, d|
                data_to_write[nom] = d.to_h
            end

            path = file_path(dispo.annee)
            FileUtils.mkdir_p(File.dirname(path))
            File.write(path, data_to_write.to_yaml)
        end
    end
end
