require 'lmnp_compta/command'
require 'lmnp_compta/journal'
require 'lmnp_compta/entry'
require 'lmnp_compta/asset'
require 'lmnp_compta/amortization'
require 'yaml'

module LMNPCompta
    module Commands
        class Amortize < Command
            register 'amortir', 'Calculer et générer les dotations aux amortissements'

            def execute
                OptionParser.new do |opts|
                    opts.banner = "Usage: lmnp amortir"
                end.parse!(@args)

                settings = Settings.instance
                immo_file = settings.immo_file
                journal_file = settings.journal_file
                annee = settings.annee
                journal = Journal.new(journal_file, year: annee)

                assets_data = YAML.load_file(immo_file) || []
                assets = assets_data.map { |a| Asset.new(a) }

                lines = []
                total = Montant.new(0)

                puts "Calcul pour #{annee}..."
                assets.each do |bien|
                    bien.composants.each do |comp|
                        next if comp.duree == 0

                        mt = Amortization.calcul_dotation(
                            comp.valeur,
                            comp.duree,
                            bien.date_mise_en_location,
                            annee
                        )

                        if mt > Montant.new(0)
                            total += mt
                            c_amort = case comp.nom
                                      when /Meuble|Mobilier/ then "281840"
                                      when /Gros Oeuvre|Façade/ then "281300"
                                      else "281200"
                                      end
                            lines << { "compte" => c_amort, "credit" => mt, "libelle_ligne" => "Amort. #{bien.nom} - #{comp.nom}" }
                        end
                    end
                end

                entry = Entry.new(
                    date: "#{annee}-12-31",
                    journal: "OD",
                    libelle: "Dotations Amortissements #{annee}",
                    ref: "DOTA#{annee}",
                    file: File.basename(immo_file)
                )

                entry.add_debit("681100", total)

                lines.each do |l|
                    entry.add_credit(l["compte"], l["credit"], l["libelle_ligne"])
                end

                journal.add_entry(entry)
                journal.save!

                puts "✅ Écriture générée dans #{journal_file} (Total: #{total} €)"
            end
        end
    end
end
