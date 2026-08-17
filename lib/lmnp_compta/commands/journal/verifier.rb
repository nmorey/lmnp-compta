require 'lmnp_compta/commands/journal/sub_command'
require 'lmnp_compta/invoice'
require 'lmnp_compta/airbnb_importer'
require 'lmnp_compta/journals'
require 'lmnp_compta/settings'
require 'optparse'
require 'date'

module LMNPCompta
  module Commands
    module Journal
      class Verifier < SubCommand
        register 'verifier', 'Auditer et réconcilier le journal avec les pièces justificatives'

        def execute
          options = { until_date: nil, blanchisserie_configs: [], files: [] }
          parser = OptionParser.new do |opts|
            opts.banner = "Usage: lmnp journal verifier [options] <fichiers_ou_dossiers...>"

            opts.on("-u", "--until DATE", "Date limite (ex: 2025-12-31)") do |v|
              options[:until_date] = Date.parse(v)
            end

            opts.on("--blanchisserie ID_OU_NOM", "Configuration blanchisserie") do |v|
              options[:blanchisserie_configs] << v
            end
          end

          parser.parse!(@args)

          if @args.empty?
            puts parser
            return
          end

          resolve_files(@args, options[:files])

          if options[:files].empty?
            puts "⚠️  Aucun fichier CSV, PDF ou YAML trouvé pour la vérification."
            return
          end

          # Load the journals securely in volatile mode
          settings = Settings.instance
          journal = LMNPCompta::Journal.new(settings.journal_file, year: settings.annee, volatile: true)
          journals = LMNPCompta::Journals.new

          until_date = options[:until_date]

          # Pool of actual entries in the journal that need reconciliation
          # Exclude entries newer than --until date
          unmatched_entries = journal.entries.dup
          unmatched_entries += journals.entries.reject { |e| unmatched_entries.any? { |ue| ue.id == e.id } }

          if until_date
              unmatched_entries.reject! { |e| Date.parse(e.date) > until_date }
          end

          missing_entries = []
          matched_entries = []

          options[:files].each do |file|
            process_file(file, unmatched_entries, matched_entries, missing_entries, options)
          end

          print_report(matched_entries, missing_entries, unmatched_entries)
        end

        private

        def resolve_files(args, out_files)
          args.each do |arg|
            if File.directory?(arg)
              Dir.glob(File.join(arg, "*.{csv,pdf,yaml}")).each do |file|
                # Skip template files, journal.yaml, and side yaml files whose PDF exists!
                is_side_yaml = file.downcase.end_with?('.yaml') && File.exist?(file.sub(/\.yaml$/i, ""))
                out_files << file unless file.end_with?('.tpl') || File.basename(file) == 'journal.yaml' || is_side_yaml
              end
            elsif File.exist?(arg)
              is_side_yaml = arg.downcase.end_with?('.yaml') && File.exist?(arg.sub(/\.yaml$/i, ""))
              out_files << arg unless arg.end_with?('.tpl') || File.basename(arg) == 'journal.yaml' || is_side_yaml
            else
              puts "⚠️  Introuvable : #{arg}"
            end
          end
        end

        def process_file(file, unmatched_entries, matched_entries, missing_entries, options)
          if file.downcase.end_with?('.csv')
            process_csv(file, unmatched_entries, matched_entries, missing_entries, options)
          elsif file.downcase.end_with?('.pdf') || file.downcase.end_with?('.yaml')
            process_invoice(file, unmatched_entries, matched_entries, missing_entries, options)
          end
        end

        def process_csv(file, unmatched_entries, matched_entries, missing_entries, options)
           # Create a dummy empty journal in volatile mode to avoid conflicts
           dummy_journal = LMNPCompta::Journal.new("dummy.yaml", year: Settings.instance.annee, volatile: true)
           importer = LMNPCompta::AirbnbImporter.new(file, dummy_journal, blanchisserie_configs: options[:blanchisserie_configs])

           # Parse lines manually from the importer's parse_csv logic to ensure chronological sequence
           reservations_map = importer.parse_csv

           matched_csv_refs = []

           reservations_map.each do |code, items|
               items.sort_by! { |item| item[:date_comptable] }
               first_row = items.first[:csv_data]
               res_end_date_str = first_row['Date de départ'] || first_row[6]
               res_end_date = LMNPCompta::ParsingUtils.parse_us_date(res_end_date_str)

               items.each_with_index do |item, index|
                   date_virement = item[:date_comptable]

                   # Skip if beyond until_date
                   next if options[:until_date] && date_virement > options[:until_date]

                   row = item[:csv_data]
                   type = row['Type']

                   # Retrieve existing entries to determine suffix
                   # We only count real journal entries that are strictly prior in date,
                   # or entries that have already been matched/simulated in the current CSV file loop!
                   existing_for_res = (unmatched_entries + matched_entries).select do |e|
                       ref_pattern = (type == 'Versement de résolution') ? /^#{Regexp.escape(code)}-RES-\d+$/ : /^#{Regexp.escape(code)}-\d+$/
                       e.ref =~ ref_pattern && (Date.parse(e.date) < date_virement || matched_csv_refs.include?(e.ref))
                   end

                   idx = importer.next_available_index(existing_for_res)
                   suffix = (type == 'Versement de résolution') ? "-RES-#{idx.to_s.rjust(2, '0')}" : "-#{idx.to_s.rjust(2, '0')}"
                   full_ref = "#{code}#{suffix}"

                   expected_entry = importer.entry_for_row(row, date_virement, full_ref)

                   match_entry = match_and_consume(expected_entry, unmatched_entries, matched_entries, missing_entries)
                   if match_entry
                       matched_csv_refs << match_entry.ref
                   else
                       # If it is missing, we still record its calculated reference suffix to keep sequence alignment
                       matched_csv_refs << full_ref
                   end

                   if index == items.length - 1 && options[:blanchisserie_configs].any?
                       # Create a laundry entry
                       laundry = importer.instance_variable_get(:@blanchisseries).find do |l|
                           l.nom_bien == (row['Logement'] || row['Hébergement'] || row[6])
                       end

                       if laundry && (!options[:until_date] || res_end_date <= options[:until_date])
                           # Only add if it does not already exist in matched entries
                           ref_lndry = "LNDRY-#{code}"
                           unless matched_entries.any? { |e| e.ref == ref_lndry }
                               lndry_cost = LMNPCompta::Montant.new(laundry.cost_per_wash)
                               expected_lndry = LMNPCompta::Entry.new(
                                   date: res_end_date.to_s,
                                   journal: "OD",
                                   libelle: "Blanchisserie - #{laundry.nom_bien}",
                                   ref: ref_lndry,
                                   file: File.basename(file)
                               )
                               expected_lndry.add_debit(LMNPCompta::COMPTE["Entretien et réparations"], lndry_cost, "Frais de blanchisserie")
                               expected_lndry.add_credit(LMNPCompta::COMPTE["Compte de l'exploitant"], lndry_cost, "Frais avancés")

                               match_and_consume(expected_lndry, unmatched_entries, matched_entries, missing_entries)
                           end
                       end
                   end
               end
           end
        end

        def process_invoice(file, unmatched_entries, matched_entries, missing_entries, options)
          begin
            expected_entries = LMNPCompta::Invoice.parse(file, interactive: false, simulate_assets: false, ignore_bad_year: true)
          rescue => e
            puts "❌ Erreur de parsing pour #{file} : #{e.message}"
            return
          end

          expected_entries.each do |expected|
            if expected.date.nil? || expected.date.to_s.empty?
              error_msg = expected.error ? expected.error.sub(/^#\s*/, "") : "Date manquante dans l'écriture suggérée."
              puts "❌ Erreur pour #{file} : #{error_msg}"
              missing_entries << expected
              next
            end

            # Skip if beyond until_date
            next if options[:until_date] && Date.parse(expected.date.to_s) > options[:until_date]

            match_and_consume(expected, unmatched_entries, matched_entries, missing_entries)
          end
        end

        def match_and_consume(expected, unmatched_entries, matched_entries, missing_entries)
            # Find a matching entry in unmatched_entries
            idx = unmatched_entries.find_index do |ue|
                reconcile_match?(expected, ue)
            end

            if idx
                entry = unmatched_entries.delete_at(idx)
                matched_entries << entry
                entry
            else
                missing_entries << expected
                nil
            end
        end

        def reconcile_match?(expected, real)
            return false unless Date.parse(expected.date) == Date.parse(real.date)
            return false unless expected.total_debit == real.total_debit
            return false unless expected.total_credit == real.total_credit

            # Accounts must match perfectly (ignoring line labels)
            expected_accts = expected.lines.map { |l| [l[:compte], l[:debit], l[:credit]] }.sort
            real_accts = real.lines.map { |l| [l[:compte], l[:debit], l[:credit]] }.sort
            return false unless expected_accts == real_accts

            true
        end

        def print_report(matched, missing, unmatched)
            puts "\n==========================================================="
            puts "       RAPPORT DE RÉCONCILIATION DU JOURNAL"
            puts "==========================================================="

            puts "✅ #{matched.length} écritures réconciliées avec succès."

            if missing.any?
                puts "\n❌ PIÈCES JUSTIFICATIVES NON ENREGISTRÉES (#{missing.length}) :"
                missing.each do |e|
                    puts "  - [#{e.date}] #{e.libelle} (#{e.total_debit} €) [Fichier: #{e.source_file || 'Inconnu'}]"
                end
            end

            # Filter out Cloture entries from orphans
            orphans = unmatched.reject { |e| e.ref.to_s.start_with?("CLOTURE") }

            if orphans.any?
                puts "\n⚠️  ÉCRITURES ORPHELINES DANS LE JOURNAL (#{orphans.length}) :"
                orphans.each do |e|
                    puts "  - [#{e.date}] [ID: #{e.id}] #{e.libelle} (#{e.total_debit} €)"
                end
            end

            if missing.empty? && orphans.empty?
                puts "\n🎉 AUDIT PARFAIT : Le journal correspond exactement aux justificatifs !"
            else
                puts "\n🚨 AUDIT ÉCHOUÉ : Des anomalies ont été détectées."
            end
        end
      end
    end
  end
end
