require_relative 'base'

require_relative '../amortization'
require_relative 'opening_balance'
require 'bigdecimal'

module LMNPCompta
    module Fiscal
        class Year2025 < Base
            # Barème kilométrique 2024 (pour les revenus 2023 et probable 2024/2025 jusqu'à mise à jour)
            MILEAGE_SCALE = {
                3 => {
                    limits: [5000, 20000],
                    factors: [
                        { mult: 0.529, add: 0 },             # d <= 5000
                        { mult: 0.316, add: 1065 },          # 5000 < d <= 20000
                        { mult: 0.370, add: 0 }              # d > 20000
                    ]
                },
                4 => {
                    limits: [5000, 20000],
                    factors: [
                        { mult: 0.606, add: 0 },
                        { mult: 0.340, add: 1330 },
                        { mult: 0.407, add: 0 }
                    ]
                },
                5 => {
                    limits: [5000, 20000],
                    factors: [
                        { mult: 0.636, add: 0 },
                        { mult: 0.357, add: 1395 },
                        { mult: 0.427, add: 0 }
                    ]
                },
                6 => {
                    limits: [5000, 20000],
                    factors: [
                        { mult: 0.665, add: 0 },
                        { mult: 0.374, add: 1457 },
                        { mult: 0.447, add: 0 }
                    ]
                },
                7 => { # 7 CV et plus
                    limits: [5000, 20000],
                    factors: [
                        { mult: 0.697, add: 0 },
                        { mult: 0.394, add: 1515 },
                        { mult: 0.470, add: 0 }
                    ]
                }
            }

            def self.calculate_mileage_allowance(cv, distance_km)
                cv = 7 if cv > 7
                cv = 3 if cv < 3

                scale = MILEAGE_SCALE[cv]
                raise "Barème introuvable pour #{cv} CV" unless scale

                d = BigDecimal(distance_km.to_f)
                factors = nil

                if d <= scale[:limits][0]
                    factors = scale[:factors][0]
                elsif d <= scale[:limits][1]
                    factors = scale[:factors][1]
                else
                    factors = scale[:factors][2]
                end
                amount = (d * BigDecimal(factors[:mult].to_s)) + BigDecimal(factors[:add].to_s)
                Montant.new(amount.round(2))
            end

            def initialize(entries, assets, stock, year)
                super
                @opening = OpeningBalance.new(assets, year)
                categorize_accounts
            end

            # --- BILAN (2033-A) ---

            def tresorerie
                sum_prefix('5')
            end

            # Actif : Clients et Comptes rattachés (Box 068)
            def creances_clients
                @creances_clients
            end

            # Actif : Autres créances (Box 072)
            def autres_creances
                @autres_creances
            end

            # Passif : Emprunts (Box 156)
            def emprunts
                -sum_prefix('16')
            end

            # Passif : Fournisseurs (Box 166)
            def dettes_fournisseurs
                @dettes_fournisseurs
            end

            # Passif : Dettes fiscales et sociales (Box 169)
            def dettes_fiscales_sociales
                @dettes_fiscales_sociales
            end

            # Passif : Autres dettes (Box 172)
            def autres_dettes
                @autres_dettes
            end

            def capital
                # Capital Fin = Capital Début (calculé par OpeningBalance) + Mouvements de l'exploitant (108)
                mouvements_exploitant = sum_prefix('108')
                @opening.capital_start - mouvements_exploitant
            end

            # --- COMPTE DE RÉSULTAT (2033-B) ---

            def recettes
                -(sum_prefix('70') + sum_prefix('75') + sum_prefix('79'))
            end

            def charges_exploit
                sum_prefix('60') + sum_prefix('61') + sum_prefix('62') +
                    sum_prefix('63') + sum_prefix('64') + sum_prefix('65')
            end

            def charges_fi
                sum_prefix('66')
            end

            def dotations
                sum_prefix('68')
            end

            def chiffre_affaires
                -sum_prefix('70')
            end

            def achats_matieres
                # Box 238: Achats de marchandises (607) et matières premières (601)
                sum_prefix('60') - sum_prefix('606')
            end

            def autres_charges_externes
                # Box 242: Autres charges externes (606 + 61 + 62)
                sum_prefix('606') + sum_prefix('61') + sum_prefix('62')
            end

            def impots_taxes
                sum_prefix('63')
            end

            # --- ANALYSE FISCALE ---

            def analyze
                return @analysis_result if @analysis_result

                # 1. Résultat Comptable avant amortissement
                resultat_avant_amort = recettes - (charges_exploit + charges_fi)

                # 2. Limite de déduction des amortissements
                limite_deduction = [resultat_avant_amort, Montant.new(0)].max
                amort_deductible = [limite_deduction, dotations].min

                ard_cree = dotations - amort_deductible
                resultat_fiscal_intermediaire = resultat_avant_amort - amort_deductible

                # 3. Utilisation des stocks
                ard_utilise = Montant.new(0)
                stock_ard_dispo = @stock.ard

                if resultat_fiscal_intermediaire > Montant.new(0) && stock_ard_dispo > Montant.new(0)
                    ard_utilise = [resultat_fiscal_intermediaire, stock_ard_dispo].min
                    resultat_fiscal_intermediaire -= ard_utilise
                end

                deficit_utilise = Montant.new(0)
                stock_deficit_dispo = @stock.deficit

                # Résultat Fiscal AVANT Imputation des Déficits (Box 352/354)
                # Note : ARD utilisé est déduit AVANT le déficit.
                resultat_avant_deficit = resultat_fiscal_intermediaire

                if resultat_avant_deficit > Montant.new(0) && stock_deficit_dispo > Montant.new(0)
                    deficit_utilise = [resultat_avant_deficit, stock_deficit_dispo].min
                    resultat_fiscal_intermediaire -= deficit_utilise
                end

                # 4. Nouveaux stocks
                @nouveau_stock_ard = stock_ard_dispo + ard_cree - ard_utilise

                deficit_cree = (resultat_avant_amort < Montant.new(0)) ? resultat_avant_amort.abs : Montant.new(0)
                @nouveau_stock_deficit = stock_deficit_dispo + deficit_cree - deficit_utilise

                @resultat_fiscal_final = resultat_fiscal_intermediaire

                @analysis_result = {
                    resultat_avant_amort: resultat_avant_amort,
                    limite_deduction: limite_deduction,
                    amort_deductible: amort_deductible,
                    ard_cree: ard_cree,
                    ard_utilise: ard_utilise,
                    resultat_avant_deficit: resultat_avant_deficit,
                    deficit_utilise: deficit_utilise,
                    deficit_cree: deficit_cree,
                    stock_ard_debut: stock_ard_dispo,
                    stock_deficit_debut: stock_deficit_dispo,
                    stock_ard_fin: @nouveau_stock_ard,
                    stock_deficit_fin: @nouveau_stock_deficit,
                    resultat_fiscal: @resultat_fiscal_final
                }
            end

            def stock_update_data
                analyze unless @analysis_result
                Stock.new({
                              'ard' => @nouveau_stock_ard.to_f,
                              'deficit' => @nouveau_stock_deficit.to_f
                          })
            end


            LAYOUT = [
                {
                    title: "FORMULAIRE 2031-SD (Déclaration de résultats)",
                    sections: [
                        {
                            title: "C. RÉCAPITULATION DES ÉLÉMENTS D'IMPOSITION",
                            elements: [
                                { type: :box, code: "1.", label: "Résultat fiscal (Bénéfice)", source: :res_fisc_benefice, show_zero: true },
                                { type: :box, code: "1.", label: "Résultat fiscal (Déficit)", source: :res_fisc_deficit, show_zero: true },
                                { type: :box, code: "7a.", label: "dont BIC non professionnels (Bénéfice)", source: :res_avant_def_benefice, show_zero: true },
                                { type: :box, code: "7b.", label: "dont BIC non professionnels (Déficit)", source: :res_avant_def_deficit, show_zero: true }
                            ]
                        },
                        {
                            title: "H. PLUS-VALUES ACQUISES EN FRANCHISE D'IMPÔT",
                            elements: [
                                { type: :text, text: "  (Non géré par ce logiciel - se référer à la notice)" }
                            ]
                        },
                        {
                            title: "I. BIC NON PROFESSIONNELS",
                            elements: [
                                { type: :box, code: "-", label: "Autres locations meublées non professionnelles (Bénéfice)", source: :res_avant_def_benefice, show_zero: true },
                                { type: :box, code: "-", label: "Résultat avant imputation des déficits antérieurs (reporter case 7a)", source: :res_avant_def_benefice, show_zero: true },
                                { type: :box, code: "-", label: "Autres locations meublées non professionnelles (Déficit)", source: :res_avant_def_deficit, show_zero: true },
                                { type: :box, code: "-", label: "Résultat avant imputation des déficits antérieurs (reporter case 7b)", source: :res_avant_def_deficit, show_zero: true }
                            ]
                        }
                    ]
                },
                {
                    title: "FORMULAIRE 2033-A (Bilan Actif / Passif)",
                    sections: [
                        {
                            title: "ACTIF",
                            elements: [
                                { type: :box, code: "028", label: "Immobilisations Corporelles (Brut)", source: :val_immo_brut },
                                { type: :box, code: "030", label: "Amortissements corporelles (à déduire)", source: :val_amort_cumules },
                                { type: :box, code: "032", label: "Immobilisations Corporelles (Net)", source: :val_immo_net },
                                { type: :box, code: "084", label: "Trésorerie & Disponibilités (Banque)", source: :tresorerie },
                                { type: :box, code: "068", label: "Créances clients et comptes rattachés", source: :creances_clients },
                                { type: :box, code: "072", label: "Autres créances (TVA, État...)", source: :autres_creances },
                                { type: :text, text: "--- TOTAUX ACTIF ---" },
                                { type: :box, code: "110", label: "Total Général ACTIF (Brut)", source: :total_actif_brut },
                                { type: :box, code: "112", label: "Total Général ACTIF (Amortissements)", source: :val_amort_cumules },
                                { type: :box, code: "11X", label: "Total Général ACTIF (Net)", source: :total_actif_net }
                            ]
                        },
                        {
                            title: "PASSIF (Avant répartition du résultat)",
                            elements: [
                                { type: :text, text: "  > Capital Initial (Au 01/01) .... : %{val} €", source: :capital_start_text },
                                { type: :text, text: "  > Apports / Retraits (108) ...... : -%{val} €", source: :mouv_expl_text },
                                { type: :box, code: "120", label: "Capital & Report à nouveau", source: :capital },
                                { type: :box, code: "136", label: "Résultat de l'exercice (Bénéfice ou Perte)", source: :rc },
                                { type: :box, code: "142", label: "Total Capitaux Propres", source: :total_capitaux },
                                { type: :box, code: "156", label: "Emprunts et dettes assimilées", source: :emprunts },
                                { type: :box, code: "166", label: "Fournisseurs et comptes rattachés", source: :dettes_fournisseurs },
                                { type: :box, code: "172", label: "Dettes fiscales et sociales", source: :dettes_fiscales_sociales },
                                { type: :box, code: "175", label: "Autres dettes", source: :autres_dettes },
                                { type: :text, text: "--- TOTAUX PASSIF ---" },
                                { type: :box, code: "180", label: "Total Général PASSIF", source: :total_passif }
                            ]
                        }
                    ]
                },
                {
                    title: "FORMULAIRE 2033-B (Compte de résultat)",
                    sections: [
                        {
                            title: "A. RÉSULTAT COMPTABLE",
                            elements: [
                                { type: :box, code: "218", label: "Chiffre d'affaires (Loyers)", source: :ca },
                                { type: :box, code: "232", label: "Total produits d'exploitation hors TVA", source: :ca },
                                { type: :box, code: "238", label: "Achats de matières/approvisionnements", source: :achats },
                                { type: :box, code: "242", label: "Autres charges externes", source: :ext },
                                { type: :box, code: "244", label: "Impôts et Taxes", source: :imp },
                                { type: :box, code: "254", label: "Dotations aux amortissements", source: :dot },
                                { type: :box, code: "264", label: "Total charges d'exploitation", source: :total_charges_exploit },
                                { type: :box, code: "270", label: "Résultat d'exploitation", source: :res_exploit },
                                { type: :box, code: "294", label: "Charges financières (Intérêts)", source: :charges_fi },
                                { type: :box, code: "310", label: "RÉSULTAT COMPTABLE (Bénéfice)", source: :rc_benefice },
                                { type: :box, code: "310", label: "RÉSULTAT COMPTABLE (Perte)", source: :rc_deficit }
                            ]
                        },
                        {
                            title: "B. RÉSULTAT FISCAL",
                            elements: [
                                { type: :box, code: "312", label: "Reporter le bénéfice comptable col. 1", source: :rc_benefice },
                                { type: :box, code: "314", label: "Reporter le déficit comptable col. 2", source: :rc_deficit },
                                { type: :box, code: "318", label: "Réintégrations (Amort. excédentaires / ARD créés)", source: :reint },
                                { type: :box, code: "350", label: "Déductions (Divers / ARD utilisés)", source: :deduc },
                                { type: :box, code: "352", label: "Résultat fiscal avant imputation déficits (Bénéfice)", source: :res_avant_def_benefice },
                                { type: :box, code: "354", label: "Résultat fiscal avant imputation déficits (Déficit)", source: :res_avant_def_deficit },
                                { type: :box, code: "360", label: "Déficits antérieurs imputés", source: :def_imp },
                                { type: :box, code: "370", label: "BÉNÉFICE FISCAL FINAL", source: :res_fisc_benefice },
                                { type: :box, code: "372", label: "DÉFICIT FISCAL FINAL", source: :res_fisc_deficit }
                            ]
                        }
                    ]
                },
                {
                    title: "FORMULAIRE 2033-C (Immobilisations & Amortissements)",
                    sections: [
                        {
                            title: "I - IMMOBILISATIONS (Valeur Brute)",
                            elements: [
                                { type: :text, text: "--- Terrains (211) ---" },
                                { type: :box, code: "420", label: "Valeur brute début", source: :c_terrains_brute_start },
                                { type: :box, code: "422", label: "Augmentations", source: :c_terrains_brute_aug },
                                { type: :box, code: "426", label: "Valeur brute fin", source: :c_terrains_brute_fin },

                                { type: :text, text: "--- Constructions (213) ---" },
                                { type: :box, code: "430", label: "Valeur brute début", source: :c_constructions_brute_start },
                                { type: :box, code: "432", label: "Augmentations", source: :c_constructions_brute_aug },
                                { type: :box, code: "436", label: "Valeur brute fin", source: :c_constructions_brute_fin },

                                { type: :text, text: "--- Inst. Techniques (215) ---" },
                                { type: :box, code: "440", label: "Valeur brute début", source: :c_inst_tech_brute_start },
                                { type: :box, code: "442", label: "Augmentations", source: :c_inst_tech_brute_aug },
                                { type: :box, code: "446", label: "Valeur brute fin", source: :c_inst_tech_brute_fin },

                                { type: :text, text: "--- Inst. Générales (2181/212) ---" },
                                { type: :box, code: "450", label: "Valeur brute début", source: :c_inst_gen_brute_start },
                                { type: :box, code: "452", label: "Augmentations", source: :c_inst_gen_brute_aug },
                                { type: :box, code: "456", label: "Valeur brute fin", source: :c_inst_gen_brute_fin },

                                { type: :text, text: "--- Autres / Mobilier (2184) ---" },
                                { type: :box, code: "470", label: "Valeur brute début", source: :c_autres_brute_start },
                                { type: :box, code: "472", label: "Augmentations", source: :c_autres_brute_aug },
                                { type: :box, code: "476", label: "Valeur brute fin", source: :c_autres_brute_fin },

                                { type: :text, text: "--- TOTAUX ---" },
                                { type: :box, code: "490", label: "Total Valeur brute début", source: :total_brut_debut },
                                { type: :box, code: "496", label: "Total Valeur brute fin", source: :total_brut_fin }
                            ]
                        },
                        {
                            title: "II - AMORTISSEMENTS",
                            elements: [
                                { type: :text, text: "--- Terrains (211) ---" },
                                { type: :box, code: "510", label: "Amortissements début", source: :c_terrains_amort_start },
                                { type: :box, code: "512", label: "Dotations", source: :c_terrains_dotation },
                                { type: :box, code: "516", label: "Amortissements fin", source: :c_terrains_amort_fin },

                                { type: :text, text: "--- Constructions (213) ---" },
                                { type: :box, code: "520", label: "Amortissements début", source: :c_constructions_amort_start },
                                { type: :box, code: "522", label: "Dotations", source: :c_constructions_dotation },
                                { type: :box, code: "526", label: "Amortissements fin", source: :c_constructions_amort_fin },

                                { type: :text, text: "--- Inst. Techniques (215) ---" },
                                { type: :box, code: "530", label: "Amortissements début", source: :c_inst_tech_amort_start },
                                { type: :box, code: "532", label: "Dotations", source: :c_inst_tech_dotation },
                                { type: :box, code: "536", label: "Amortissements fin", source: :c_inst_tech_amort_fin },

                                { type: :text, text: "--- Inst. Générales (2181/212) ---" },
                                { type: :box, code: "540", label: "Amortissements début", source: :c_inst_gen_amort_start },
                                { type: :box, code: "542", label: "Dotations", source: :c_inst_gen_dotation },
                                { type: :box, code: "546", label: "Amortissements fin", source: :c_inst_gen_amort_fin },

                                { type: :text, text: "--- Autres / Mobilier (2184) ---" },
                                { type: :box, code: "560", label: "Amortissements début", source: :c_autres_amort_start },
                                { type: :box, code: "562", label: "Dotations", source: :c_autres_dotation },
                                { type: :box, code: "566", label: "Amortissements fin", source: :c_autres_amort_fin },

                                { type: :text, text: "--- TOTAL ---" },
                                { type: :box, code: "570", label: "Total Amort. Début", source: :total_amort_start },
                                { type: :box, code: "572", label: "Total Dotations", source: :total_dotation },
                                { type: :box, code: "576", label: "Total Amort. Fin", source: :total_amort_fin }
                            ]
                        }
                    ]
                },
                {
                    title: "FORMULAIRE 2033-D (Suivi des Déficits)",
                    sections: [
                        {
                            title: "II. Suivi des Déficits",
                            elements: [
                                { type: :box, code: "982", label: "Déficits reportables au début de l'exercice", source: :def_rep_debut },
                                { type: :box, code: "983", label: "Déficits imputés sur le résultat (Box 360)", source: :def_imp_d },
                                { type: :box, code: "984", label: "Déficits antérieurs non imputés", source: :deficits_restants },
                                { type: :box, code: "860", label: "Déficits de l'exercice (Si Box 354)", source: :def_cree },
                                { type: :box, code: "870", label: "Total des déficits restant à reporter", source: :total_def_reporter }
                            ]
                        },
                        {
                            title: "III. DIVERS",
                            elements: [
                                { type: :box, code: "399", label: "Montant des prélèvements personnels", source: :prelev_perso }
                            ]
                        },
                        {
                            title: "IV. TRAVAILLEURS INDÉPENDANTS (Revenu Brut Social)",
                            elements: [
                                { type: :box, code: "690", label: "Sommes à réintégrer", source: :zero },
                                { type: :box, code: "691", label: "Sommes à déduire", source: :zero },
                                { type: :box, code: "693", label: "Revenu brut social (positif)", source: :res_avant_def_benefice },
                                { type: :box, code: "692", label: "Revenu brut social (négatif)", source: :res_avant_def_deficit }
                            ]
                        }
                    ]
                },
                {
                    title: "ANNEXE - SUIVI DES ARD (Hors Liasse)",
                    sections: [
                        {
                            title: "Stocks d'Amortissements Réputés Différés",
                            elements: [
                                { type: :info, label: "Stock ARD début exercice", source: :ard_debut },
                                { type: :info, label: "+ ARD créé (Box 318)", source: :ard_cree },
                                { type: :info, label: "- ARD utilisé (Box 350)", source: :ard_utilise },
                                { type: :info, label: "= STOCK ARD FIN D'EXERCICE", source: :ard_fin, comment: "<-- À conserver pour l'an prochain" }
                            ]
                        }
                    ]
                }
            ]

            # Calcule toutes les données requises pour le rapport et renvoie un Hash
            # Utilise et conserve Montant / RoundedMontant pour de futurs ajouts
            # et evite les erreurs d'arrondis cumulés.
            def calculate_data
                if sum_prefix('64') > Montant.new(0) || sum_prefix('65') > Montant.new(0)
                    raise "ERREUR FATALE: La liasse 2033-B ne gère pas les comptes 64x (Personnel) et 65x (Autres charges de gestion courante). Veuillez corriger les écritures ou adapter le logiciel."
                end

                result = analyze

                data_c = {
                    terrains: {},
                    constructions: {},
                    inst_tech: {},
                    inst_gen: {},
                    autres: {}
                }

                data_c.each do |k, v|
                    v[:brute_start] = Montant.new(0)
                    v[:brute_aug]   = Montant.new(0)
                    v[:amort_start] = Montant.new(0)
                    v[:dotation]    = Montant.new(0)
                end

                @assets.each do |asset_data|
                    start_date = asset_data.date_mise_en_location
                    comps = asset_data.composants

                    acquisition_year = Date.parse(start_date.to_s).year

                    comps.each do |c|
                        nom = (c.nom).to_s.downcase
                        valeur = c.valeur
                        duree = c.duree

                        cat = :inst_gen
                        if nom.include?('terrain')
                            cat = :terrains
                        elsif nom.include?('gros oeuvre') || nom.include?('façade') || nom.include?('mur') || nom.include?('toiture')
                            cat = :constructions
                        elsif nom.include?('technique') || nom.include?('industriel')
                            cat = :inst_tech
                        elsif nom.include?('meuble') || nom.include?('mobilier')
                            cat = :autres
                        end

                        if acquisition_year == @year
                            data_c[cat][:brute_aug] += valeur
                        else
                            data_c[cat][:brute_start] += valeur
                        end

                        if duree > 0
                            start_year_amort = Date.parse(start_date.to_s).year
                            (start_year_amort...@year).each do |y|
                                data_c[cat][:amort_start] += Amortization.calcul_dotation(valeur, duree, start_date, y)
                            end
                            data_c[cat][:dotation] += Amortization.calcul_dotation(valeur, duree, start_date, @year)
                        end
                    end
                end

                total_brut_debut = RoundedMontant.new(0)
                total_brut_fin = RoundedMontant.new(0)
                total_amort_start = RoundedMontant.new(0)
                total_dotation = RoundedMontant.new(0)

                data_c.each do |k, v|
                    brute_start_r = v[:brute_start].round
                    brute_aug_r = v[:brute_aug].round
                    total_brut_debut += brute_start_r
                    total_brut_fin += (brute_start_r + brute_aug_r)

                    amort_start_r = v[:amort_start].round
                    dotation_r = v[:dotation].round
                    total_amort_start += amort_start_r
                    total_dotation += dotation_r
                end

                total_amort_fin = total_amort_start + total_dotation

                final_val = result[:resultat_fiscal].round
                res_avant_def = result[:resultat_avant_deficit].round

                res_fisc_benefice = final_val >= RoundedMontant.new(0) ? final_val : nil
                res_fisc_deficit  = final_val <  RoundedMontant.new(0) ? final_val.abs : nil

                res_avant_def_benefice = res_avant_def >= RoundedMontant.new(0) ? res_avant_def : nil
                res_avant_def_deficit  = res_avant_def <  RoundedMontant.new(0) ? res_avant_def.abs : nil

                val_immo_brut_r = total_brut_fin
                val_amort_cumules_r = total_amort_fin
                val_immo_net_r = val_immo_brut_r - val_amort_cumules_r

                tresorerie_r = tresorerie.round
                creances_clients_r = @creances_clients.round
                autres_creances_r = @autres_creances.round

                total_actif_brut = val_immo_brut_r + tresorerie_r + creances_clients_r + autres_creances_r
                total_actif_net  = val_immo_net_r + tresorerie_r + creances_clients_r + autres_creances_r

                mouv_expl = sum_prefix('108')
                mouv_expl_r = mouv_expl.round

                capital_start_text = @opening.capital_start.round.rjust(10)
                mouv_expl_text = mouv_expl_r.rjust(10)

                capital_r = capital.round
                rc = resultat_comptable.round
                total_capitaux = capital_r + rc

                emprunts_r = emprunts.round
                dettes_fournisseurs_r = @dettes_fournisseurs.round
                dettes_fiscales_sociales_r = @dettes_fiscales_sociales.round
                autres_dettes_r = @autres_dettes.round

                total_dettes = emprunts_r + dettes_fournisseurs_r + dettes_fiscales_sociales_r + autres_dettes_r
                total_passif = total_capitaux + total_dettes

                ca = chiffre_affaires.round
                achats = achats_matieres.round
                ext = autres_charges_externes.round
                imp = impots_taxes.round
                dot = dotations.round

                total_charges_exploit = achats + ext + imp + dot
                res_exploit = ca - total_charges_exploit
                charges_fi_r = charges_fi.round

                rc_benefice = rc >= RoundedMontant.new(0) ? rc : nil
                rc_deficit  = rc <  RoundedMontant.new(0) ? rc.abs : nil

                reint = result[:ard_cree].round
                reint_disp = reint > RoundedMontant.new(0) ? reint : nil

                deduc = result[:ard_utilise].round
                deduc_disp = deduc > RoundedMontant.new(0) ? deduc : nil

                def_imp = result[:deficit_utilise].round
                def_imp_disp = def_imp > RoundedMontant.new(0) ? def_imp : nil

                deficits_restants = (result[:stock_deficit_debut] - result[:deficit_utilise]).round
                def_cree = result[:deficit_cree].round
                def_cree_disp = def_cree > RoundedMontant.new(0) ? def_cree : nil

                prelev_perso = prelevements_personnels.round
                prelev_perso_disp = prelev_perso > RoundedMontant.new(0) ? prelev_perso : nil

                ard_debut_r = result[:stock_ard_debut].round
                ard_cree_r  = result[:ard_cree].round
                ard_uti_r   = result[:ard_utilise].round
                ard_fin_r   = result[:stock_ard_fin].round

                h = {
                    res_fisc_benefice: res_fisc_benefice,
                    res_fisc_deficit: res_fisc_deficit,
                    res_avant_def_benefice: res_avant_def_benefice,
                    res_avant_def_deficit: res_avant_def_deficit,

                    val_immo_brut: val_immo_brut_r,
                    val_amort_cumules: val_amort_cumules_r,
                    val_immo_net: val_immo_net_r,

                    tresorerie: tresorerie_r,
                    creances_clients: (creances_clients_r > RoundedMontant.new(0) ? creances_clients_r : nil),
                    autres_creances: (autres_creances_r > RoundedMontant.new(0) ? autres_creances_r : nil),

                    total_actif_brut: total_actif_brut,
                    total_actif_amorts: val_amort_cumules_r,
                    total_actif_net: total_actif_net,

                    capital_start_text: capital_start_text,
                    mouv_expl_text: mouv_expl_text,

                    capital: capital_r,
                    rc: rc,
                    total_capitaux: total_capitaux,

                    emprunts: emprunts_r,
                    dettes_fournisseurs: (dettes_fournisseurs_r > RoundedMontant.new(0) ? dettes_fournisseurs_r : nil),
                    dettes_fiscales_sociales: (dettes_fiscales_sociales_r > RoundedMontant.new(0) ? dettes_fiscales_sociales_r : nil),
                    autres_dettes: (autres_dettes_r > RoundedMontant.new(0) ? autres_dettes_r : nil),

                    total_passif: total_passif,

                    ca: ca,
                    achats: achats,
                    ext: ext,
                    imp: imp,
                    dot: dot,
                    total_charges_exploit: total_charges_exploit,
                    res_exploit: res_exploit,
                    charges_fi: charges_fi_r,

                    rc_benefice: rc_benefice,
                    rc_deficit: rc_deficit,

                    reint: reint_disp,
                    deduc: deduc_disp,

                    def_imp: def_imp_disp,

                    def_rep_debut: result[:stock_deficit_debut].round,
                    def_imp_d: result[:deficit_utilise].round,
                    deficits_restants: deficits_restants,
                    def_cree: def_cree_disp,
                    total_def_reporter: result[:stock_deficit_fin].round,

                    prelev_perso: prelev_perso_disp,
                    zero: RoundedMontant.new(0),

                    ard_debut: ard_debut_r,
                    ard_cree: ard_cree_r,
                    ard_utilise: ard_uti_r,
                    ard_fin: ard_fin_r,

                    total_brut_debut: total_brut_debut,
                    total_brut_fin: total_brut_fin,
                    total_amort_start: total_amort_start,
                    total_dotation: total_dotation,
                    total_amort_fin: total_amort_fin
                }

                [:terrains, :constructions, :inst_tech, :inst_gen, :autres].each do |cat|
                    base_k = "c_#{cat}"
                    v = data_c[cat]

                    brute_start_r = v[:brute_start].round
                    brute_aug_r   = v[:brute_aug].round
                    brute_fin_r   = brute_start_r + brute_aug_r

                    amort_start_r = v[:amort_start].round
                    dotation_r    = v[:dotation].round
                    amort_fin_r   = amort_start_r + dotation_r

                    has_brute = brute_start_r > RoundedMontant.new(0) || brute_aug_r > RoundedMontant.new(0)
                    h["#{base_k}_brute_start".to_sym] = has_brute ? brute_start_r : nil
                    h["#{base_k}_brute_aug".to_sym]   = has_brute && brute_aug_r > RoundedMontant.new(0) ? brute_aug_r : nil
                    h["#{base_k}_brute_fin".to_sym]   = has_brute ? brute_fin_r : nil

                    has_amort = amort_start_r > RoundedMontant.new(0) || dotation_r > RoundedMontant.new(0)
                    h["#{base_k}_amort_start".to_sym] = has_amort ? amort_start_r : nil
                    h["#{base_k}_dotation".to_sym]    = has_amort ? dotation_r : nil
                    h["#{base_k}_amort_fin".to_sym]   = has_amort ? amort_fin_r : nil
                end

                h
            end
            private

            def prelevements_personnels
                total = Montant.new(0)
                @entries.each do |e|
                    next if Date.parse(e.date.to_s).year != @year
                    next if e.journal == 'AN'
                    e.lines.each do |l|
                        if l[:compte].to_s.start_with?('108') && l[:debit] > Montant.new(0)
                            total += l[:debit]
                        end
                    end
                end
                total
            end

            def categorize_accounts
                @creances_clients = Montant.new(0)
                @autres_creances = Montant.new(0)
                @dettes_fournisseurs = Montant.new(0)
                @dettes_fiscales_sociales = Montant.new(0)
                @autres_dettes = Montant.new(0)

                @balances.each do |compte, solde|
                    s = compte.to_s
                    next unless s.start_with?('4')

                    if solde > Montant.new(0)
                        # Solde DEBITEUR -> ACTIF (Créance)
                        if s.start_with?('41')
                            @creances_clients += solde
                        else
                            @autres_creances += solde
                        end
                    elsif solde < Montant.new(0)
                        # Solde CREDITEUR -> PASSIF (Dette)
                        val = solde.abs
                        if s.start_with?('40')
                            @dettes_fournisseurs += val
                        elsif s.start_with?('42') || s.start_with?('43') || s.start_with?('44')
                            @dettes_fiscales_sociales += val
                        else
                            @autres_dettes += val
                        end
                    end
                end
            end

        end
    end
end
