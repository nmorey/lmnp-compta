require_relative 'montant'

module LMNPCompta
    class Entry
        attr_accessor :id, :date, :journal, :libelle, :ref
        attr_accessor :lines # Array of hashes {compte:, debit:, credit:, libelle_ligne:}

        # Metadata for analysis/import (from Transaction class concept)
        attr_accessor :source_file, :parser_type, :error, :warnings

        def initialize(attrs = {})
            @id = attrs[:id] || attrs['id']
            @date = attrs[:date] || attrs['date']
            @journal = attrs[:journal] || attrs['journal']
            @libelle = attrs[:libelle] || attrs['libelle']
            @ref = attrs[:ref] || attrs['ref']

            @lines = []

            # Import helpers (Transient data)
            @source_file = attrs[:file] || attrs['file']
            @parser_type = attrs[:type] || attrs['type']
            @error = attrs[:error] || attrs['error']
            @warnings = attrs[:extra] || attrs['extra'] || []

            # Load lines if present
            (attrs[:lignes] || attrs['lignes'] || attrs[:lines] || []).each do |l|
                add_line(l)
            end
        end

        def add_line(attrs)
            compte = attrs[:compte] || attrs['compte']
            debit = Montant.new(attrs[:debit] || attrs['debit'] || 0)
            credit = Montant.new(attrs[:credit] || attrs['credit'] || 0)
            libelle_ligne = attrs[:libelle_ligne] || attrs['libelle_ligne']

            @lines << {
                compte: compte,
                debit: debit,
                credit: credit,
                libelle_ligne: libelle_ligne
            }
        end

        # Helper to add a debit movement easily
        def add_debit(compte, montant, label = nil)
            add_line(compte: compte, debit: montant, credit: 0, libelle_ligne: label)
        end

        # Helper to add a credit movement easily
        def add_credit(compte, montant, label = nil)
            add_line(compte: compte, debit: 0, credit: montant, libelle_ligne: label)
        end

        def balance
            @lines.sum { |l| l[:debit] - l[:credit] }
        end

        def balanced?
            balance.zero?
        end

        def valid?
            return false if @error
            return false if @lines.empty?
            balanced?
        end

        def to_h
            # Enforce specific key order: id, date, libelle, journal, ref, lignes
            h = {}
            h['id'] = @id
            h['date'] = @date.to_s
            h['libelle'] = @libelle
            h['journal'] = @journal
            h['ref'] = @ref

            h['lignes'] = @lines.map { |l|
                line_h = {}
                line_h['compte'] = l[:compte]

                # Serialize Montant to formatted string (%.2f)
                line_h['debit'] = l[:debit].to_s if l[:debit] > Montant.new(0)
                line_h['credit'] = l[:credit].to_s if l[:credit] > Montant.new(0)

                line_h['libelle_ligne'] = l[:libelle_ligne] if l[:libelle_ligne]
                line_h
            }
            h
        end
    end
end
