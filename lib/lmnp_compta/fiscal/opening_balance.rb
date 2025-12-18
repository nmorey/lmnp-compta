require_relative '../montant'
require_relative '../amortization'
require 'date'

module LMNPCompta
    module Fiscal
        # Calcule le Bilan d'Ouverture (A-Nouveaux) au 1er Janvier de l'année fiscale
        class OpeningBalance
            attr_reader :annee, :assets

            def initialize(assets, annee)
                @assets = assets
                @annee = annee
            end

            # Valeur Brute des Immobilisations (Débit 21xx)
            def immo_brut
                total = Montant.new(0)
                @assets.each do |asset_data|
                    comps = asset_data.is_a?(Hash) ? asset_data['composants'] : asset_data.composants
                    comps.each do |c|
                        val = c.is_a?(Hash) ? c['valeur'] : c.valeur
                        total += val
                    end
                end
                total
            end

            # Amortissements Cumulés à l'ouverture (Crédit 28xx)
            # C'est-à-dire la somme des amortissements jusqu'au 31/12/N-1
            def amort_cumules_start
                total_amort = Montant.new(0)

                @assets.each do |asset_data|
                    is_hash = asset_data.is_a?(Hash)
                    start_date = is_hash ? asset_data['date_mise_en_location'] : asset_data.date_mise_en_location
                    comps = is_hash ? asset_data['composants'] : asset_data.composants

                    comps.each do |c|
                        valeur = is_hash ? c['valeur'] : c.valeur
                        duree = is_hash ? c['duree'] : c.duree

                        # Somme des dotations jusqu'à l'année N-1 incluse
                        start_year = Date.parse(start_date.to_s).year
                        (start_year...(@annee)).each do |y|
                             total_amort += Amortization.calcul_dotation(valeur, duree, start_date, y)
                        end
                    end
                end
                total_amort
            end

            # Capital Initial (Crédit 101)
            # Capital = Actif Net d'Ouverture (sauf si dettes/trésorerie initiales connues, ici supposées 0)
            def capital_start
                immo_brut - amort_cumules_start
            end

            # Génère les lignes d'écriture pour le FEC (Journal AN)
            def fec_lines
                lines = []

                # Soldes par compte
                asset_balances = Hash.new { |h, k| h[k] = Montant.new(0) }
                amort_balances = Hash.new { |h, k| h[k] = Montant.new(0) }

                @assets.each do |asset_data|
                    # Extraction des données
                    is_hash = asset_data.is_a?(Hash)
                    start_date = is_hash ? asset_data['date_mise_en_location'] : asset_data.date_mise_en_location
                    comps = is_hash ? asset_data['composants'] : asset_data.composants

                    comps.each do |c|
                        nom = (is_hash ? c['nom'] : c.nom).to_s
                        valeur = is_hash ? c['valeur'] : c.valeur
                        duree = is_hash ? c['duree'] : c.duree

                        # Classification (cohérente avec command/amortize.rb + plan_comptable.rb)
                        asset_acc, amort_acc = classify_component(nom)

                        # 1. Cumul Actif Brut
                        asset_balances[asset_acc] += valeur

                        # 2. Cumul Amortissements antérieurs
                        if duree > 0
                            amt_comp = Montant.new(0)
                            start_year = Date.parse(start_date.to_s).year
                            (start_year...(@annee)).each do |y|
                                amt_comp += Amortization.calcul_dotation(valeur, duree, start_date, y)
                            end
                            amort_balances[amort_acc] += amt_comp if amt_comp > Montant.new(0)
                        end
                    end
                end

                # Génération des lignes Actif (21xx)
                asset_balances.sort.each do |acc, val|
                    next if val == Montant.new(0)
                    lib = PLAN_COMPTABLE[acc] || "Immo #{acc}"
                    lines << { compte: acc, libelle: "Reprise #{lib}", debit: val, credit: Montant.new(0) }
                end

                # Génération des lignes Amortissements (28xx)
                amort_balances.sort.each do |acc, val|
                    next if val == Montant.new(0)
                    lib = PLAN_COMPTABLE[acc] || "Amort #{acc}"
                    lines << { compte: acc, libelle: "Reprise #{lib}", debit: Montant.new(0), credit: val }
                end

                # 3. Capital (108 - Compte de l'exploitant)
                # On utilise le 108 pour l'EI/LMNP pour être cohérent avec le compte de clôture
                cap = capital_start
                lines << { compte: '108000', libelle: 'Capital Initial (A-Nouveaux)', debit: Montant.new(0), credit: cap }

                lines
            end

            private

            def classify_component(nom)
                n = nom.downcase
                if n.include?('terrain')
                    ['211000', nil] # Pas d'amortissement
                elsif n.include?('meuble') || n.include?('mobilier')
                    ['218400', '281840']
                elsif n.include?('gros oeuvre') || n.include?('façade') || n.include?('mur')
                    ['213000', '281300']
                elsif n.include?('installation') || n.include?('cuisine')
                    ['218100', '281200'] # Utilisation de 281200 faute de mieux ou 281810 si existe
                else
                    # Par défaut: Agencements (212000)
                    ['212000', '281200']
                end
            end
        end
    end
end
