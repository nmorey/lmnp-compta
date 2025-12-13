require 'lmnp_compta/command'
require 'lmnp_compta/journal'
require 'lmnp_compta/fiscal_analyzer'
require 'yaml'

module LMNPCompta
  module Commands
    class Report < Command
      register 'liasse', 'Générer la liasse fiscale (2033) et mettre à jour les stocks'

      def execute
        OptionParser.new do |opts|
          opts.banner = "Usage: lmnp liasse"
        end.parse!(@args)

        settings = LMNPCompta::Settings.instance
        journal_file = settings.journal_file
        immo_file = settings.immo_file
        stock_file = settings.stock_file
        annee = settings.annee

        unless File.exist?(journal_file)
          raise "Fichier journal introuvable (#{journal_file})"
        end

        journal = LMNPCompta::Journal.new(journal_file)
        entries = journal.entries
        assets = File.exist?(immo_file) ? YAML.load_file(immo_file) : []
        stock = File.exist?(stock_file) ? YAML.load_file(stock_file) : { 'stock_ard' => 0.0, 'stock_deficit' => 0.0 }

        analyzer = LMNPCompta::FiscalAnalyzer.new(entries, assets, stock, annee)

        puts "\n==========================================================="
        puts "       AIDE À LA DÉCLARATION LMNP (Année #{annee})"
        puts "==========================================================="

        puts "\n📝 FORMULAIRE 2033-A (Bilan Actif / Passif)"
        puts "-----------------------------------------------------------"

        puts "ACTIF :"
        print_case("010", "Immobilisations Incorporelles/Corporelles (Brut)", analyzer.immo_brut)
        print_case("012", "Amortissements cumulés (à déduire)", analyzer.amort_cumules)
        print_case("016", "Trésorerie & Disponibilités (Banque)", analyzer.tresorerie)
        if analyzer.creances > Montant.new(0)
          print_case("018", "Créances clients / Autres", analyzer.creances)
        end
        puts "       TOTAL ACTIF (Net) ............................ : #{(analyzer.immo_net + analyzer.tresorerie + analyzer.creances).rjust(10)} €"

        puts "\nPASSIF (Avant répartition du résultat) :"
        print_case("--- ", "Capital & Report à nouveau", analyzer.capital)
        print_case("156", "Emprunts et dettes assimilées", analyzer.emprunts)
        if analyzer.dettes_fournisseurs > Montant.new(0)
          print_case("164", "Dettes fournisseurs", analyzer.dettes_fournisseurs)
        end
        puts "       (Le résultat de l'exercice viendra équilibrer ce Passif)"

        puts "\n\n📝 FORMULAIRE 2033-B (Compte de résultat)"
        puts "-----------------------------------------------------------"

        print_case("210", "Chiffre d'affaires (Loyers)", -analyzer.sum_prefix('70'))
        print_case("238", "Achats & Charges externes", analyzer.sum_prefix('60') + analyzer.sum_prefix('61') + analyzer.sum_prefix('62'))
        print_case("244", "Impôts et Taxes", analyzer.sum_prefix('63'))
        print_case("250", "Charges financières (Intérêts)", analyzer.charges_fi)
        print_case("254", "Dotations aux amortissements", analyzer.dotations)

        puts "\n\n📝 FORMULAIRE 2033-C (Immobilisations & Amortissements)"
        puts "-----------------------------------------------------------"
        valeur_brute_immo = Montant.new(0.0)
        assets.each do |bien|
          bien['composants'].each { |c| valeur_brute_immo += c['valeur'] }
        end

        puts "CADRE A (Valeurs Brutes) :"
        print_case("400", "Valeur brute en début d'exercice", valeur_brute_immo)
        puts "       (Si achats cette année, remplir col. Augmentations)"
        puts "       (Si ventes cette année, remplir col. Diminutions)"

        puts "\n\n📝 FORMULAIRE 2033-D (Déficits & ARD)"
        puts "-----------------------------------------------------------"

        result = analyzer.analyze

        puts "I. Stocks d'Amortissements Réputés Différés (ARD) :"
        puts "   Stock ARD début exercice ........ : #{result[:stock_ard_debut]} €"
        puts " + ARD créé cette année ............ : #{result[:ard_cree]} € (Car bénéfice insuffisant)"
        puts " - ARD utilisé cette année ......... : #{result[:ard_utilise]} €"
        puts " = STOCK ARD FIN D'EXERCICE ........ : #{result[:stock_ard_fin]} €  <-- À conserver"

        puts "\nII. Suivi des Déficits :"
        puts "   Stock Déficit début exercice .... : #{result[:stock_deficit_debut]} €"
        print_case("350", "Déficits antérieurs imputés (Utilisés)", result[:deficit_utilise])
        if result[:deficit_cree] > Montant.new(0)
          puts " + Déficit créé cette année ........ : #{result[:deficit_cree]} €"
        end
        puts " = STOCK DÉFICIT FIN D'EXERCICE .... : #{result[:stock_deficit_fin]} €  <-- À reporter Case 360"

        puts "\n\n==========================================================="
        puts "🏁 RÉSULTAT FISCAL FINAL (Case 370 / 372)"
        if result[:resultat_fiscal] >= Montant.new(0)
          puts " ✅ BÉNÉFICE IMPOSABLE ........................ : \e[32m#{result[:resultat_fiscal]} €\e[0m"
        else
          puts " 📉 DÉFICIT DE L'EXERCICE ..................... : \e[31m#{result[:resultat_fiscal].abs} €\e[0m"
        end
        puts "==========================================================="

        File.write(stock_file, {
          'stock_ard' => result[:stock_ard_fin].to_f,
          'stock_deficit' => result[:stock_deficit_fin].to_f
        }.to_yaml)
        puts "💾 Fichier #{stock_file} mis à jour pour l'an prochain."
      end

      private

      def print_case(code, label, value)
        return if value.zero?
        puts " #{code.ljust(4)} | #{label.ljust(45)} : #{value.rjust(10)} €"
      end
    end
  end
end
