require 'yaml'
require 'date'
require 'open3'
require_relative 'invoice_parser'
require_relative 'entry'
require_relative 'montant'
require_relative 'asset'
require_relative 'settings'

module LMNPCompta
    # Centralise le chargement, l'extraction de texte, le parsing PDF
    # et le traitement des YAML de secours pour toutes les factures.
    class Invoice
        # Parse un fichier de facture (PDF ou YAML) et retourne les écritures générées.
        #
        # @param file_path [String] Le chemin vers le fichier (PDF ou YAML)
        # @param options [Hash] Les options de parsing (type forcé, amortize_duration, no_amortize, interactive)
        # @return [Array<Entry>] La liste des écritures attendues
        # @raise [RuntimeError, InvoiceParser::ParsingError] Si le parsing échoue
        def self.parse(file_path, options = {})
            raise "Introuvable: #{file_path}" unless File.exist?(file_path)

            entries_list = []

            # Si c'est directement un fichier YAML
            if file_path.end_with?('.yaml')
                return load_yaml_invoice_entry(file_path, file_path, options)
            end

            content = extract_text(file_path)
            parser = InvoiceParser::Factory.build(options[:type], content)

            unless parser
                return handle_unrecognized_invoice(file_path, options)
            end

            begin
                parsed = parser.parse
                target_year = Settings.instance.annee

                # Support multi-échéances (comme EdfEcheancier qui renvoie un tableau)
                parsed = [parsed] unless parsed.is_a?(Array)

                parsed.each do |data|
                     # Note: La commande verifier gèrera le filtrage par target_year si nécessaire,
                     # mais pour analyser-facture, on conserve le comportement d'erreur d'année en libellé/erreur
                     if data[:date].year != target_year
                         next if options[:ignore_bad_year]
                         entries_list << Entry.new(
                             file: File.basename(file_path),
                             libelle: "Bad Year",
                             error: "# ⚠️  Date hors année fiscale (#{data[:date]})"
                         )
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
                     entries_list << entry
                end
            rescue InvoiceParser::ParsingError => e
                 e.ftype = parser.class.parser_name.upcase
                 raise e
            end

            entries_list
        end

        private

        def self.handle_unrecognized_invoice(file_path, options)
            yaml_path = "#{file_path}.yaml"
            if File.exist?(yaml_path)
                 load_yaml_invoice_entry(yaml_path, file_path, options)
            else
                 # Pour le vérificateur on veut échouer directement (fail-fast) s'il n'y a pas d'interaction
                 if options[:interactive] == false
                     raise "Document PDF non reconnu et aucun fichier .yaml d'accompagnement trouvé : #{file_path}"
                 end

                 create_invoice_template(file_path)
                 [Entry.new(
                     file: File.basename(file_path),
                     libelle: "Template created",
                     error: "# ⚠️  Non reconnu. Template créé: #{yaml_path}.tpl"
                 )]
            end
        end

        def self.load_yaml_invoice_entry(yaml_path, original_file, options)
            data = YAML.load_file(yaml_path)
            data = [data] unless data.is_a?(Array)
            entries_list = []
            target_year = Settings.instance.annee

            data.each do |d|
                validate_yaml_entry!(d)

                # Check for bad year
                date_val = d['date'].is_a?(Date) ? d['date'] : Date.parse(d['date'])
                if date_val.year != target_year
                    next if options[:ignore_bad_year]
                end

                # If original_file is a .pdf.yaml side file, strip the .yaml suffix so it matches the PDF filename
                base_name = File.basename(original_file)
                base_name = base_name.sub(/\.yaml$/i, "") if base_name.downcase.end_with?('.pdf.yaml') || (base_name.downcase.end_with?('.yaml') && base_name.downcase.include?('.pdf'))
                d['file'] ||= base_name

                if d['amortize']
                     charge_line = d['lignes'].find { |l| l['debit'] }
                     if charge_line
                         amt = Montant.new(charge_line['debit'])
                         # Option interactive passée pour bloquer stdin.gets si non interactif
                         create_asset_entry(
                            d['nom_actif'] || d['libelle'],
                            amt,
                            d['date'],
                            d['duree_amortissement']
                         ) if options.fetch(:simulate_assets, true)
                         charge_line['compte'] = '218400'
                     end
                end

                entries_list << Entry.new(d)
            end
            entries_list
        end

        def self.validate_yaml_entry!(d)
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

            journal_type = d['journal'].to_s.upcase
            if journal_type == 'AC'
                unless d['lignes'].any? { |l| l['compte'].to_s == LMNPCompta::COMPTE["Banque"] && l['credit'] }
                    raise "Le compte #{LMNPCompta::COMPTE["Banque"]} doit être présent au CRÉDIT pour un journal d'Achats (AC)."
                end
            elsif journal_type == 'VT'
                unless d['lignes'].any? { |l| l['compte'].to_s == LMNPCompta::COMPTE["Banque"] && l['debit'] }
                    raise "Le compte #{LMNPCompta::COMPTE["Banque"]} doit être présent au DÉBIT pour un journal de Ventes (VT)."
                end
            elsif journal_type == 'OD'
                # OD can have 108000 (Compte de l'exploitant) or 512000, both are fine
                unless d['lignes'].any? { |l| [LMNPCompta::COMPTE["Banque"], LMNPCompta::COMPTE["Compte de l'exploitant"]].include?(l['compte'].to_s) }
                    raise "Le compte #{LMNPCompta::COMPTE["Banque"]} ou #{LMNPCompta::COMPTE["Compte de l'exploitant"]} doit être présent dans un journal d'Opérations Diverses (OD)."
                end
            end
        end

        def self.create_invoice_template(file_path)
            tpl_path = "#{file_path}.yaml.tpl"
            return if File.exist?(tpl_path)
            tpl = { 'date' => Date.today.strftime("%d/%m/%Y"), 'journal' => 'AC', 'libelle' => "Facture #{File.basename(file_path)}", 'lignes' => [{'compte' => '6XXX', 'debit' => 0}, {'compte' => '512000', 'credit' => 0}] }
            File.write(tpl_path, tpl.to_yaml)
        end

        def self.apply_invoice_amortization(data, file_path, options)
            return if options[:no_amortize]
            duration = options[:amortize_duration]
            asset_name = data[:libelle]

            if options[:interactive] == false
                # Mode vérification strict: si pas forcé via option, on ne bloque pas sur stdin
                # On utilise des valeurs par défaut sécurisées
                duration ||= 5
            else
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
            end

            if options.fetch(:simulate_assets, true)
                create_asset_entry(asset_name, data[:montant], data[:date], duration)
                puts "✅ Immobilisation créée." if options[:interactive] != false
            end

            data[:compte_charge] = '218400'
        end

        def self.create_asset_entry(name, amount, date, duration)
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

        def self.extract_text(path)
            stdout, stderr, status = Open3.capture3("pdftotext -layout -enc UTF-8 \"#{path}\" -")
            raise "pdftotext error: #{stderr}" unless status.success?
            stdout
        rescue Errno::ENOENT
            raise "'pdftotext' introuvable."
        end
    end
end