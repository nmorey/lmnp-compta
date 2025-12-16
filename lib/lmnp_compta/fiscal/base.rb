require_relative '../montant'

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

            # Méthodes abstraites (Doivent être implémentées par les sous-classes annuelles)
            def analyze; raise NotImplementedError; end
            def immo_brut; raise NotImplementedError; end
            def amort_cumules; raise NotImplementedError; end
            def tresorerie; raise NotImplementedError; end
            def creances; raise NotImplementedError; end
            def capital; raise NotImplementedError; end
            def emprunts; raise NotImplementedError; end
            def dettes_fournisseurs; raise NotImplementedError; end
            def recettes; raise NotImplementedError; end
            def charges_exploit; raise NotImplementedError; end
            def charges_fi; raise NotImplementedError; end
            def dotations; raise NotImplementedError; end

            def immo_net
                immo_brut - amort_cumules
            end

            def resultat_comptable
                recettes - (charges_exploit + charges_fi + dotations)
            end
        end
    end
end
