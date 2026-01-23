require 'lmnp_compta/commands/journal/sub_command'
require 'lmnp_compta/invoice_parser'
require 'lmnp_compta/entry'
require 'lmnp_compta/montant'
require 'lmnp_compta/asset'
require 'lmnp_compta/settings'
require 'optparse'
require 'open3'
require 'yaml'
require 'fileutils'
require 'date'

module LMNPCompta
  module Commands
    module Journal
      class AnalyserFacture < SubCommand
        register 'analyser-facture', 'Analyser des PDF pour suggérer des écritures'

        def execute
           options = { type: nil }
           parser = OptionParser.new do |opts|
               opts.banner = "Usage: lmnp journal analyser-facture [options] <pdf>..."
               opts.on("-t", "--type TYPE", "Forcer le type") { |t| options[:type] = t.downcase.to_sym }
               opts.on("--amortize-duration N", Integer) { |n| options[:amortize_duration] = n }
               opts.on("--no-amortize") { options[:no_amortize] = true }
           end
           parser.parse!(@args)

           if @args.empty?
               puts parser
               return
           end

           errors = 0
           entries_list = []

           @args.each do |file_path|
               process_file(file_path, options, entries_list)
           rescue => e
               entry = Entry.new(
                   file: File.basename(file_path),
                   libelle: "Error: #{file_path}",
                   error: "# ❌ #{e.message.gsub(/\n/, "\n# ")}"
               )
               add_or_merge_entry(entries_list, entry)
               errors += 1
           end

           entries_list.sort_by! { |x| "#{x.source_file}-#{x.date}" }
           entries_list.each { |e| puts format_invoice_entry(e) }
           puts "# {entries_list.length} transactions, {errors} erreurs."
        end

        # Made public or accessible for testing purposes if needed via send
        private

        def process_file(file_path, options, entries_list)
            raise "Introuvable: #{file_path}" unless File.exist?(file_path)
            content = extract_text(file_path)
            parser = InvoiceParser::Factory.build(options[:type], content)

            unless parser
                handle_unrecognized_invoice(file_path, entries_list, options)
                return
            end

            begin
                parsed = parser.parse
                target_year = Settings.instance.annee
                parsed.each do |data|
                     if data[:date].year != target_year
                         add_or_merge_entry(entries_list, Entry.new(
                             file: File.basename(file_path),
                             libelle: "Bad Year",
                             error: "# ⚠️  Date hors année fiscale (#{data[:date]})"
                         ))
                         next
                     end

                     entry = Entry.new(
                         file: File.basename(file_path),
                         type: parser.class.parser_name.upcase,
                         date: data[:date].strftime("%d/%m/%Y"),
                         journal: "AC",
                         libelle: data[:libelle],
                         ref: data[:ref]
                     )

                     if !options[:no_amortize] && data[:montant] >= Montant.new(600)
                         apply_invoice_amortization(data, file_path, options)
                     end

                     entry.add_debit(data[:compte_charge], data[:montant])
                     entry.add_credit(data[:compte_banque], data[:montant])
                     add_or_merge_entry(entries_list, entry)
                end
            rescue InvoiceParser::ParsingError => e
                 e.ftype = parser.class.parser_name.upcase
                 raise e
            end
        end

        def handle_unrecognized_invoice(file_path, entries_list, options)
            yaml_path = "#{file_path}.yaml"
            if File.exist?(yaml_path)
                 load_yaml_invoice_entry(yaml_path, file_path, entries_list, options)
            else
                 create_invoice_template(file_path)
                 add_or_merge_entry(entries_list, Entry.new(
                     file: File.basename(file_path),
                     libelle: "Template created",
                     error: "# ⚠️  Non reconnu. Template créé: #{yaml_path}.tpl"
                 ))
            end
        end

        def load_yaml_invoice_entry(yaml_path, original_file, entries_list, options)
            data = YAML.load_file(yaml_path)
            data = [data] unless data.is_a?(Array)
            data.each do |d|
                validate_yaml_entry!(d)
                d['file'] ||= File.basename(original_file)

                if d['amortize']
                     charge_line = d['lignes'].find { |l| l['debit'] }
                     if charge_line
                         amt = Montant.new(charge_line['debit'])
                         create_asset_entry(
                            d['nom_actif'] || d['libelle'],
                            amt,
                            d['date'],
                            d['duree_amortissement']
                         )
                         charge_line['compte'] = '218400'
                     end
                end

                entry = Entry.new(d)
                add_or_merge_entry(entries_list, entry)
            end
        rescue => e
            add_or_merge_entry(entries_list, Entry.new(libelle: "YAML Error", error: "# #{e.message}"))
        end

        def validate_yaml_entry!(d)
            missing = []
            missing << "date" unless d['date']
            missing << "journal" unless d['journal']
            missing << "libelle" unless d['libelle']
            missing << "lignes" unless d['lignes'] && !d['lignes'].empty?

            raise "Champs manquants: #{missing.join(', ')}" if missing.any?

            d['lignes'].each_with_index do |l, idx|
                raise "Ligne #{idx+1}: 'compte' manquant" unless l['compte']
                unless l['debit'] || l['credit']
                     raise "Ligne #{idx+1}: 'debit' ou 'credit' requis"
                end
            end

            unless d['lignes'].any? { |l| l['compte'].to_s == '512000' && l['credit'] }
                raise "Le compte 512000 doit être présent au CRÉDIT (Paiement facture)."
            end
        end

        def create_invoice_template(file_path)
            tpl_path = "#{file_path}.yaml.tpl"
            return if File.exist?(tpl_path)
            tpl = { 'date' => Date.today.strftime("%d/%m/%Y"), 'journal' => 'AC', 'libelle' => "Facture #{File.basename(file_path)}", 'lignes' => [{'compte' => '6XXX', 'debit' => 0}, {'compte' => '512000', 'credit' => 0}] }
            File.write(tpl_path, tpl.to_yaml)
        end

        def apply_invoice_amortization(data, file_path, options)
            return if options[:no_amortize]
            duration = options[:amortize_duration]
            asset_name = data[:libelle]

            unless duration
                 puts "Facture > 600€ (#{data[:montant]}). Amortir ? [O/n]"
                 return if $stdin.gets.chomp.downcase == 'n'
                 print "Durée [5]: "
                 d = $stdin.gets.chomp
                 duration = d.empty? ? 5 : d.to_i
            end

            unless options[:amortize_duration]
                 print "Nom de l'immobilisation [#{asset_name}]: "
                 inp = $stdin.gets.chomp
                 asset_name = inp unless inp.empty?
            end

            create_asset_entry(asset_name, data[:montant], data[:date], duration)
            puts "✅ Immobilisation créée."
            data[:compte_charge] = '218400'
        end

        def create_asset_entry(name, amount, date, duration)
            immo_file = Settings.instance.immo_file
            assets = File.exist?(immo_file) ? YAML.load_file(immo_file) : []
            assets ||= []

            date_str = date.is_a?(Date) ? date.to_s : Date.parse(date).to_s

            new_asset = Asset.new(
                 nom: name,
                 date_achat: date_str,
                 date_mise_en_location: date_str,
                 valeur_achat: amount.to_f,
                 composants: [Asset::Component.new(nom: "Mobilier", valeur: amount, duree: duration || 5)]
            )
            assets << new_asset.to_h
            FileUtils.mkdir_p(File.dirname(immo_file))
            File.write(immo_file, assets.to_yaml)
        end

        def extract_text(path)
            stdout, stderr, status = Open3.capture3("pdftotext -layout -enc UTF-8 \"#{path}\" -")
            raise "pdftotext error: #{stderr}" unless status.success?
            stdout
        rescue Errno::ENOENT
            raise "'pdftotext' introuvable."
        end

        def add_or_merge_entry(list, new_e)
            idx = list.find_index { |e| e.libelle == new_e.libelle }
            if idx
                list[idx] = new_e
            else
                list << new_e
            end
        end

        def format_invoice_entry(entry)
            str = "# Fichier: #{entry.source_file}\n"
            str += "# Libelle: #{entry.libelle}\n"
            if entry.error
                str += entry.error.to_s + "\n\n"
            else
                str += generate_invoice_command(entry) + "\n\n"
            end
            str
        end

        def generate_invoice_command(entry)
            cmd_lines = []
            entry.lines.each do |l|
                if l[:debit] > Montant.new(0)
                    cmd_lines << "-c #{l[:compte]} -s D -m #{l[:debit]}"
                elsif l[:credit] > Montant.new(0)
                    cmd_lines << "-c #{l[:compte]} -s C -m #{l[:credit]}"
                end
            end

            [
                "lmnp journal saisir",
                "-d #{entry.date}",
                "-j #{entry.journal}",
                "-l \"#{entry.libelle}\"",
                "-r \"#{entry.ref}\"",
                "-f \"#{entry.source_file}\"",
                cmd_lines.join(" ")
            ].join(" ")
        end
      end
    end
  end
end
