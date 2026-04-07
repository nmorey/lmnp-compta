require_relative '../montant'
require_relative 'reporting'

module LMNPCompta
    module Fiscal
        # Classe de base pour l'analyse fiscale, contenant la logique commune
        class Base
            attr_reader :balances, :entries, :assets, :stock, :year

            # Initialise l'analyseur
            # @param entries [Array<Entry>] Liste des écritures
            # @param assets [Array<Hash>] Liste des immobilisations (Hash ou Asset objects, ici traités génériquement)
            # @param stock [Hash] État des stocks (ARD, Déficits)
            # @param year [Integer] Année fiscale
            def initialize(entries, assets, stock, year)
                @entries = entries
                @assets = assets
                @stock = stock
                @year = year
                @balances = Hash.new(Montant.new("0"))
                calculate_balances
            end

            # Calcule les soldes comptables pour l'année donnée
            def calculate_balances
                @entries.each do |e|
                    # Filtrage strict : inclure uniquement les écritures de l'année fiscale
                    next if Date.parse(e.date.to_s).year != @year
                    # Ignorer les AN pour éviter les doublons dans les calculs de flux
                    next if e.journal == 'AN'

                    e.lines.each do |l|
                        debit = l[:debit]
                        credit = l[:credit]
                        @balances[l[:compte].to_s] += (debit - credit)
                    end
                end
            end

            # Somme les soldes des comptes commençant par un préfixe donné
            # @param prefix [String] Préfixe du compte (ex: "60")
            # @return [Montant] La somme
            def sum_prefix(prefix)
                @balances.select { |k, _| k.to_s.start_with?(prefix) }.values.sum(Montant.new(0))
            end

            # Calcule toutes les données requises pour le rapport et renvoie un Hash
            # @return [Hash]
            def calculate_data
                raise NotImplementedError
            end

            # Génère le rapport fiscal de manière déclarative en se basant sur self.class::LAYOUT
            # @return [LMNPCompta::Fiscal::Reporting::Document]
            def generate_report
                data = calculate_data
                doc = Reporting::Document.new("AIDE À LA DÉCLARATION LMNP (Année #{@year})")

                self.class::LAYOUT.each do |form_def|
                    form = Reporting::Form.new(form_def[:title])

                    form_def[:sections].each do |sec_def|
                        sec = Reporting::Section.new(sec_def[:title])

                        sec_def[:elements].each do |elem|
                            case elem[:type]
                            when :text
                                text_str = elem[:text]
                                # Permet des interpolations simples si un :source est fourni (bien qu'on privilégiera :info)
                                text_str = text_str.gsub("%{val}", data[elem[:source]].to_s) if elem[:source] && data[elem[:source]]
                                sec.add_text(text_str)
                            when :box
                                val = data[elem[:source]]
                                # On passe si la valeur est nil (utile pour les champs mutuellement exclusifs)
                                next if val.nil?
                                sec.add_box(elem[:code], elem[:label], val, show_zero: elem[:show_zero] || false)
                            when :info
                                val = data[elem[:source]]
                                next if val.nil?
                                sec.add_info(elem[:label], val, elem[:comment])
                            end
                        end
                        form.add_section(sec) if sec.items.any? || elem_types_all_text?(sec_def[:elements])
                    end
                    doc.add_form(form)
                end

                doc
            end

            # Retourne les données de stock à sauvegarder pour l'année suivante
            # @return [Hash]
            def stock_update_data
                raise NotImplementedError
            end

            def resultat_comptable
                recettes - (charges_exploit + charges_fi + dotations)
            end

            private

            def elem_types_all_text?(elements)
                elements.all? { |e| e[:type] == :text }
            end
        end
    end
end
