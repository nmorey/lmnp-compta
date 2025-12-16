require_relative 'montant'

module LMNPCompta
    # Représente une écriture comptable composée de plusieurs lignes (débit/crédit)
    class Entry
        attr_accessor :id, :date, :journal, :libelle, :ref
        attr_accessor :lines # Array of hashes {compte:, debit:, credit:, libelle_ligne:}

        # Métadonnées pour l'analyse/import (transitoires)
        attr_accessor :source_file, :parser_type, :error, :warnings

        # Initialise une nouvelle entrée
        # @param attrs [Hash] Attributs de l'écriture
        def initialize(attrs = {})
            @id = attrs[:id] || attrs['id']
            @date = attrs[:date] || attrs['date']
            @journal = attrs[:journal] || attrs['journal']
            @libelle = attrs[:libelle] || attrs['libelle']
            @ref = attrs[:ref] || attrs['ref']
            @source_file = attrs[:file] || attrs['file']

            @lines = []

            # Helpers d'import (Données transitoires)
            @parser_type = attrs[:type] || attrs['type']
            @error = attrs[:error] || attrs['error']
            @warnings = attrs[:extra] || attrs['extra'] || []

            # Chargement des lignes si présentes
            (attrs[:lignes] || attrs['lignes'] || attrs[:lines] || []).each do |l|
                add_line(l)
            end
        end

        # Ajoute une ligne à l'écriture
        # @param attrs [Hash] Attributs de la ligne (compte, debit, credit, libelle_ligne)
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

        # Ajoute un mouvement au débit
        # @param compte [String] Numéro de compte
        # @param montant [Numeric, String, Montant] Montant du débit
        # @param label [String, nil] Libellé spécifique à la ligne (optionnel)
        def add_debit(compte, montant, label = nil)
            add_line(compte: compte, debit: montant, credit: 0, libelle_ligne: label)
        end

        # Ajoute un mouvement au crédit
        # @param compte [String] Numéro de compte
        # @param montant [Numeric, String, Montant] Montant du crédit
        # @param label [String, nil] Libellé spécifique à la ligne (optionnel)
        def add_credit(compte, montant, label = nil)
            add_line(compte: compte, debit: 0, credit: montant, libelle_ligne: label)
        end

        # Calcule le solde de l'écriture (Débit - Crédit)
        # @return [Montant] Le solde (doit être 0 pour une écriture valide)
        def balance
            @lines.sum { |l| l[:debit] - l[:credit] }
        end

        # Vérifie si l'écriture est équilibrée
        # @return [Boolean] true si le solde est 0
        def balanced?
            balance.zero?
        end

        # Vérifie si l'écriture est valide (pas d'erreur, lignes présentes, équilibrée)
        # @return [Boolean] true si valide
        def valid?
            return false if @error
            return false if @lines.empty?
            balanced?
        end

        # Sérialise l'écriture en Hash pour l'export YAML/JSON
        # @return [Hash] Représentation hash de l'écriture
        def to_h
            # Force l'ordre des clés : id, date, libelle, journal, ref, lignes
            h = {}
            h['id'] = @id
            h['date'] = @date.to_s
            h['libelle'] = @libelle
            h['journal'] = @journal
            h['ref'] = @ref
            h['file'] = @source_file if @source_file

            h['lignes'] = @lines.map { |l|
                line_h = {}
                line_h['compte'] = l[:compte]

                # Sérialisation des Montants en chaînes formatées (%.2f)
                line_h['debit'] = l[:debit].to_s if l[:debit] > Montant.new(0)
                line_h['credit'] = l[:credit].to_s if l[:credit] > Montant.new(0)

                line_h['libelle_ligne'] = l[:libelle_ligne] if l[:libelle_ligne]
                line_h
            }
            h
        end
    end
end
