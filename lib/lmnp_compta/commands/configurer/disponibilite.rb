require 'lmnp_compta/commands/configurer/sub_command'
require 'lmnp_compta/disponibilite'
require 'lmnp_compta/asset'
require 'lmnp_compta/settings'
require 'optparse'

module LMNPCompta
  module Commands
    module Configurer
      # Sous-commande pour configurer les jours de disponibilité annuelle d'un bien (prorata temporis).
      class DisponibiliteCommand < SubCommand
        register 'disponibilite', 'Configurer les jours de disponibilité annuelle (prorata temporis)'

        # Exécute la configuration ou l'affichage de la disponibilité.
        # @return [void]
        def execute
          options = {}
          parser = OptionParser.new do |opts|
            opts.banner = "Usage: lmnp configurer disponibilite [options]"
            opts.on("--bien NOM", "Nom du bien immobilier") { |v| options[:bien] = v }
            opts.on("--annee AAAA", Integer, "Année fiscale (défaut : année courante)") { |v| options[:annee] = v }
            opts.on("--disponibles N", Integer, "Nombre de jours disponibles (déduit les indisponibles)") { |v| options[:disponibles] = v }
            opts.on("--indisponibles N", Integer, "Nombre de jours indisponibles (déduit les disponibles)") { |v| options[:indisponibles] = v }
            opts.on("--pleine-annee", "--100", "Indique que le bien est disponible 100% de l'année") { options[:pleine_annee] = true }
            opts.on("-l", "--lister", "Lister les disponibilités configurées") { options[:lister] = true }
            opts.on("-h", "--help", "Affiche l'aide") do
              puts opts
              exit 0
            end
          end

          begin
            parser.parse!(@args)
          rescue OptionParser::InvalidOption => e
            puts "❌ Erreur: #{e.message}"
            puts parser
            return
          end

          target_year = options[:annee] || Settings.instance.annee
          total_days = Date.leap?(target_year) ? 366 : 365

          if options[:lister]
            lister_disponibilites(target_year)
            return
          end

          nom_bien = options[:bien]
          disponibles = options[:disponibles]
          indisponibles = options[:indisponibles]
          pleine_annee = options[:pleine_annee]

          if pleine_annee
            disponibles = total_days
            indisponibles = 0
          elsif disponibles && indisponibles.nil?
            indisponibles = total_days - disponibles
          elsif indisponibles && disponibles.nil?
            disponibles = total_days - indisponibles
          end

          if nom_bien.nil? || (disponibles.nil? && indisponibles.nil?)
            puts "=== Configuration de la Disponibilité Annuelle ==="
            nom_bien ||= prompt_bien
            target_year = prompt("Année fiscale", default: target_year.to_s).to_i if options[:annee].nil?
            total_days = Date.leap?(target_year) ? 366 : 365

            indisp_input = prompt("Jours indisponibles (usage personnel / travaux)", default: "0")
            indisponibles = indisp_input.to_i
            disponibles = total_days - indisponibles
          end

          dispo = Disponibilite.new(
            nom_bien: nom_bien,
            annee: target_year,
            disponibles: disponibles,
            indisponibles: indisponibles,
            pleine_annee: pleine_annee
          )

          begin
            dispo.validate!
          rescue => e
            puts "❌ Erreur: #{e.message}"
            return
          end

          Disponibilite.save(dispo)

          pct_dispo = (dispo.prorata_temporis * 100).round(2)

          puts "\n✅ Disponibilité enregistrée pour '#{nom_bien}' (#{target_year}) :"
          puts "  - Jours disponibles     : #{dispo.disponibles} (#{pct_dispo} %)"
          puts "  - Jours indisponibles   : #{dispo.indisponibles}"
          puts "  - Total jours           : #{dispo.total_nuits}"
          puts "  => Prorata temporis retenu : #{pct_dispo} %"
          puts "💾 Fichier : #{Disponibilite.file_path(target_year)}"
        end

        private

        # Affiche la liste des disponibilités configurées pour une année donnée.
        # @param year [Integer] année fiscale
        # @return [void]
        def lister_disponibilites(year)
          all = Disponibilite.load_all(year)
          if all.empty?
            puts "Aucune disponibilité configurée pour l'année #{year} (#{Disponibilite.file_path(year)})."
            return
          end

          puts "Disponibilités configurées pour l'année #{year} :"
          all.each do |nom, d|
            pct = (d.prorata_temporis * 100).round(2)
            puts "  - #{nom.ljust(25)} : #{d.disponibles}/#{d.total_nuits} jours dispo (#{pct} %) [Disponibles: #{d.disponibles}, Indisponibles: #{d.indisponibles}]"
          end
        end

        # Demande interactivement le nom du bien à configurer.
        # @return [String] nom du bien
        def prompt_bien
          assets = Asset.load(Settings.instance.immo_file)
          default_name = assets.first&.nom
          prompt("Nom du bien immobilier", default: default_name)
        end

        # Affiche une invite de commande et lit la saisie utilisateur.
        # @param q [String] question ou libellé de l'invite
        # @param default [String, nil] valeur par défaut si saisie vide
        # @return [String] réponse saisie ou valeur par défaut
        def prompt(q, default: nil)
          label = default ? "#{q} [#{default}]: " : "#{q}: "
          print label
          input = STDIN.gets.chomp
          input = default if input.empty? && default
          input
        end
      end
    end
  end
end
