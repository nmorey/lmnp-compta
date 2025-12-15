require 'lmnp_compta/command'
require 'lmnp_compta/montant'
require 'yaml'
require 'date'
require 'readline'
require 'optparse'
require 'fileutils'

module LMNPCompta
  module Commands
    class InitImmo < Command
      register 'creer-immo', 'Générer le fichier d\'immobilisations avec une ventilation par défaut'

      DEFAULT_BREAKDOWN = [
        { name: "Terrain", percent: 15, duration: 0 },
        { name: "Gros Oeuvre", percent: 40, duration: 50 },
        { name: "Façade", percent: 15, duration: 25 },
        { name: "Installations Générales", percent: 15, duration: 20 },
        { name: "Agencements Intérieurs", percent: 15, duration: 15 }
      ]

      def execute
        options = {}
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lmnp creer-immo [options]"
          opts.on("--valeur MONTANT", "Valeur totale du bien (frais de notaire inclus si activable)") { |v| options[:valeur] = v }
          opts.on("--date DATE", "Date d\'achat/Mise en location (AAAA-MM-JJ)") { |v| options[:date] = v }
          opts.on("--nom NOM", "Nom du bien (ex: 'Appartement Lyon')") { |v| options[:nom] = v }
          opts.on("-f", "--force", "Écraser le fichier existant") { options[:force] = true }
        end
        parser.parse!(@args)

        settings = LMNPCompta::Settings.instance
        immo_file = settings.immo_file

        if File.exist?(immo_file) && !options[:force]
          puts "⚠️  Le fichier '#{immo_file}' existe déjà."
          print "Voulez-vous l\'écraser ? (o/N) "
          response = STDIN.gets.chomp.downcase
          unless response == 'o'
            puts "Annulé."
            exit 0
          end
        end

        # Interactive Mode if missing args
        unless options[:valeur] && options[:date] && options[:nom]
          puts "=== Création du fichier d\'immobilisations ==="
          puts "Ce script va générer une ventilation par composants par défaut :"
          DEFAULT_BREAKDOWN.each do |c|
            duration = c[:duration] == 0 ? "Non amortissable" : "#{c[:duration]} ans"
            puts "  - #{c[:name].ljust(25)} : #{c[:percent]}% (#{duration})"
          end
          puts ""
        end

        nom = options[:nom] || prompt("Nom du bien")
        date_str = options[:date] || prompt("Date d\'achat (AAAA-MM-JJ)", default: Date.today.to_s)
        
        valeur_str = options[:valeur]
        unless valeur_str
          valeur_str = prompt("Valeur totale du bien (Euros)")
        end
        valeur_totale = Montant.new(valeur_str)

        puts "\nCalcul de la ventilation pour une valeur de #{valeur_totale} € :"
        
        composants = []
        check_total = Montant.new(0)

        DEFAULT_BREAKDOWN.each do |item|
          # Montant * Percent / 100
          valeur_compo = valeur_totale * (item[:percent] / 100.0)
          check_total += valeur_compo
          
          puts "  - #{item[:name].ljust(25)} : #{valeur_compo} €"
          
          composants << {
            'nom' => item[:name],
            'valeur' => valeur_compo.to_f, # YAML dump prefers native types
            'duree' => item[:duration]
          }
        end

        # Adjust rounding errors on the biggest component (Gros Oeuvre)
        diff = valeur_totale - check_total
        unless diff.zero?
          puts "  (Ajustement arrondi : #{diff} € sur Gros Oeuvre)"
          gros_oeuvre = composants.find { |c| c['nom'] == "Gros Oeuvre" }
          gros_oeuvre['valeur'] = (Montant.new(gros_oeuvre['valeur']) + diff).to_f
        end

        # Data structure
        data = [{
          'nom' => nom,
          'date_achat' => date_str,
          'date_mise_en_location' => date_str,
          'valeur_achat' => valeur_totale.to_f,
          'composants' => composants
        }]

        # Confirm write in interactive mode
        if options[:valeur].nil? then
          print "\nConfirmer l'enregistrement ? (O/n) "
          r = STDIN.gets.chomp.downcase
          return if r == 'n'
        end

        FileUtils.mkdir_p(File.dirname(immo_file))
        File.write(immo_file, data.to_yaml)
        puts "✅ Fichier créé : #{immo_file}"
      end

      private

      def prompt(question, default: nil)
        label = default ? "#{question} [#{default}]: " : "#{question}: "
        print label
        input = STDIN.gets.chomp
        input.empty? && default ? default : input
      end
    end
  end
end
