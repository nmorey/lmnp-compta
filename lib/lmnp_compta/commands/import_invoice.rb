require 'lmnp_compta/command'
require 'lmnp_compta/invoice_parser'
require 'lmnp_compta/entry'
require 'optparse'
require 'open3'

module LMNPCompta
  module Commands
    class ImportInvoice < Command
      register 'importer-facture', 'Scanner des factures PDF et suggérer des écritures'

      def execute
        options = { type: nil }
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lmnp importer-facture [options] <fichier_pdf>..."
          opts.on("-t", "--type TYPE", "Forcer le type") { |t| options[:type] = t.downcase.to_sym }
        end
        parser.parse!(@args)

        if @args.empty?
          puts parser
          exit 1
        end

        errors = 0
        entries_list = []

        @args.each do |file_path|
          process_file(file_path, options, entries_list)
        rescue => e
            entry = LMNPCompta::Entry.new(
                file: File.basename(file_path),
                libelle: "❌ Erreur en traitant: #{file_path}",
                error: "# ❌ Erreur: #{e.message}",
            )
            add_or_merge_entry(entries_list, entry)
            errors += 1
        end

        entries_list.sort_by! { |x| "#{x.source_file}-#{x.date}" }
        entries_list.each { |entry| puts format_entry(entry) }

        puts "# #{entries_list.length} transactions générées avec #{errors} erreurs"
        exit(errors > 0 ? 1 : 0)
      end

      private

      def process_file(file_path, options, entries_list)
        raise "Fichier introuvable." unless File.exist?(file_path)

        content = extract_text(file_path)
        parser = LMNPCompta::InvoiceParser::Factory.build(options[:type], content)
        raise "Type non reconnu" unless parser

        begin
          parsed_data = parser.parse
          target_year = LMNPCompta::Settings.instance.annee

          parsed_data.each do |data|
            if data[:date].year != target_year
                entry = LMNPCompta::Entry.new(
                    file: File.basename(file_path),
                    libelle: "❌ Erreur en traitant: #{file_path} #{data[:date]}",
                    date: data[:date].strftime("%d/%m/%Y"),
                    error: "# ⚠️  Ignored invoice from #{data[:date]} (Year #{data[:date].year} != #{target_year})"
                )
              add_or_merge_entry(entries_list, entry)
              next
            end

            entry = LMNPCompta::Entry.new(
              file: File.basename(file_path),
              type: parser.class.parser_name.upcase,
              date: data[:date].strftime("%d/%m/%Y"),
              journal: "AC",
              libelle: data[:libelle],
              ref: data[:ref]
            )
            
            entry.add_debit(data[:compte_charge], data[:montant])
            entry.add_credit(data[:compte_banque], data[:montant])

            add_or_merge_entry(entries_list, entry)
          end
        rescue LMNPCompta::InvoiceParser::ParsingError => e
          raise e.message
        end
      end

      def extract_text(file_path)
        stdout, stderr, status = Open3.capture3("pdftotext -layout -enc UTF-8 \"#{file_path}\" -")
        raise "pdftotext: #{stderr}" unless status.success?
        stdout
      rescue Errno::ENOENT
        raise "'pdftotext' introuvable."
      end

      def add_or_merge_entry(entries, new_entry)
        existing_idx = entries.find_index { |e| e.libelle == new_entry.libelle }
        
        if existing_idx
          old_entry = entries[existing_idx]
          old_entry.warnings ||= []
          new_entry.warnings = old_entry.warnings
          new_entry.warnings << "# ⚠️ Warning: Remplacement de la transaction '#{old_entry.libelle}'\n"
          new_entry.warnings << "# 	 Originale venant de #{old_entry.source_file}\n"
          new_entry.warnings << "# 	 Remplacante venant de #{new_entry.source_file}\n"
          
          entries[existing_idx] = new_entry
        else
          entries << new_entry
        end
      end

      def format_entry(entry)
        str = ""
        str += "# --------------------------------------\n"
        str += "# Fichier : #{entry.source_file}\n"
        str += "# Type    : #{entry.parser_type}\n" if entry.parser_type
        str += "# Libelle : #{entry.libelle}\n" if entry.libelle
        str += "# Ref     : #{entry.ref}\n" if entry.ref
        
        entry.lines.each do |l|
          if l[:debit] > Montant.new(0)
              str += "# Mvt     : Compte #{l[:compte]} (D) : #{l[:debit]} €\n"
          else
              str += "# Mvt     : Compte #{l[:compte]} (C) : #{l[:credit]} €\n"
          end
        end

        if entry.error
          str += entry.error.to_s + "\n"
          str += "# --------------------------------------\n\n"
          return str
        end

        entry.warnings.each { |msg| str += msg } if entry.warnings
        str += "# --------------------------------------\n"
        str += generate_command(entry)
        str += "\n\n"
        str
      end

      def generate_command(entry)
        cmd_lines = []
        entry.lines.each do |l|
          if l[:debit] > Montant.new(0)
            cmd_lines << "-c #{l[:compte]} -s D -m #{l[:debit]}"
          elsif l[:credit] > Montant.new(0)
            cmd_lines << "-c #{l[:compte]} -s C -m #{l[:credit]}"
          end
        end
        
        [
          "lmnp ajouter",
          "-d #{entry.date}",
          "-j #{entry.journal}",
          "-l \"#{entry.libelle}\"",
          "-r \"#{entry.ref}\"",
          cmd_lines.join(" ")
        ].join(" ")
      end
    end
  end
end
