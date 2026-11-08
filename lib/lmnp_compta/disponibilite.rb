require 'yaml'
require 'fileutils'
require 'date'
require_relative 'settings'

module LMNPCompta
    # Gère les métriques annuelles de disponibilité d'un bien immobilier
    # pour le calcul du prorata temporis des charges mixtes.
    class Disponibilite
        attr_accessor :nom_bien, :annee, :disponibles, :indisponibles, :pleine_annee

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

        def total_nuits
            @disponibles + @indisponibles
        end

        def expected_days_in_year
            Date.leap?(@annee) ? 366 : 365
        end

        def valid_days_sum?
            @disponibles >= 0 && @indisponibles >= 0 && total_nuits == expected_days_in_year
        end

        def pleine_annee?
            @pleine_annee || (@indisponibles == 0 && total_nuits == expected_days_in_year)
        end

        def validate!
            expected = expected_days_in_year
            unless valid_days_sum?
                raise "Incohérence du nombre de jours pour l'année #{@annee} : #{total_nuits} jours saisis (disponibles: #{@disponibles}, indisponibles: #{@indisponibles}), attendu: #{expected} jours."
            end
        end

        def prorata_temporis
            return 0.0 if total_nuits == 0
            (@disponibles.to_f / total_nuits.to_f).round(6)
        end

        def to_h
            h = {
                'disponibles' => @disponibles,
                'indisponibles' => @indisponibles,
                'prorata_temporis' => prorata_temporis
            }
            h['pleine_annee'] = true if @pleine_annee
            h
        end

        def self.file_path(year)
            File.join(Settings.instance.data_dir, year.to_s, "disponibilite.yaml")
        end

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

        def self.find(nom_bien, year)
            load_all(year)[nom_bien]
        end

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
