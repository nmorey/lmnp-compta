require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'date'

require 'lmnp_compta'
require 'lmnp_compta/command'
require 'lmnp_compta/commands/journal'
require 'lmnp_compta/commands/journal/analyser_facture'
require 'lmnp_compta/commands/journal/verifier'
require 'lmnp_compta/settings'
require 'lmnp_compta/asset'
require 'lmnp_compta/disponibilite'
require 'lmnp_compta/invoice'

class InvoiceProrataTest < Minitest::Test
    TEST_DIR = File.join(__dir__, 'tmp', 'invoice_prorata')

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)
        @original_dir = Dir.pwd
        Dir.chdir(TEST_DIR)

        @immo_file = File.join(TEST_DIR, 'immobilisations.yaml')
        @dispo_dir = File.join(TEST_DIR, '2025')
        FileUtils.mkdir_p(@dispo_dir)

        File.write('lmnp.yaml', <<~YAML)
            data_dir: .
            annee: 2025
            immo_file: immobilisations.yaml
        YAML
        LMNPCompta::Settings.load('lmnp.yaml')

        # Create Asset "Chalet" with 40m2 / 100m2 = 40% surface
        asset = LMNPCompta::Asset.new(
            nom: "Chalet",
            date_achat: "2025-01-01",
            surface_totale: 100.0,
            surface_louee: 40.0,
            valeur_achat: 100000.0,
            composants: []
        )
        File.write(@immo_file, [asset.to_h].to_yaml)

        # Create Disponibilite for Chalet in 2025:
        # 219 nuits dispo / 365 = 60.0%
        dispo = LMNPCompta::Disponibilite.new(
            nom_bien: "Chalet",
            annee: 2025,
            disponibles: 219,
            indisponibles: 146
        )
        LMNPCompta::Disponibilite.save(dispo)
    end

    def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_compute_prorata_calculation
        # 40% surface * 60% temporis = 24% global
        res = LMNPCompta::Invoice.compute_prorata("Chalet", 2025, 100.0)
        assert_in_delta 0.40, res[:p_surface], 0.001
        assert_in_delta 0.60, res[:p_temporis], 0.001
        assert_in_delta 0.24, res[:taux], 0.001
        assert_equal LMNPCompta::Montant.new(24.0), res[:part_pro]
        assert_equal LMNPCompta::Montant.new(76.0), res[:part_perso]
    end

    def test_compute_prorata_fail_fast_missing_bien
        err = assert_raises(RuntimeError) do
            LMNPCompta::Invoice.compute_prorata(nil, 2025, 100.0)
        end
        assert_match /aucun bien spécifié/, err.message
    end

    def test_compute_prorata_fail_fast_unknown_asset
        err = assert_raises(RuntimeError) do
            LMNPCompta::Invoice.compute_prorata("Studio Inconnu", 2025, 100.0)
        end
        assert_match /Bien immobilier introuvable : 'Studio Inconnu'/, err.message
    end

    def test_compute_prorata_fail_fast_missing_surface
        # Asset without surface
        no_surface_asset = LMNPCompta::Asset.new(nom: "No Surface", date_achat: "2025-01-01")
        File.write(@immo_file, [no_surface_asset.to_h].to_yaml)

        err = assert_raises(RuntimeError) do
            LMNPCompta::Invoice.compute_prorata("No Surface", 2025, 100.0)
        end
        assert_match /Prorata de surface manquant ou invalide/, err.message
    end

    def test_compute_prorata_fail_fast_missing_disponibilite
        # Create asset with surface but no dispo
        asset = LMNPCompta::Asset.new(
            nom: "Autre Bien",
            date_achat: "2025-01-01",
            surface_totale: 100.0,
            surface_louee: 50.0
        )
        File.write(@immo_file, [asset.to_h].to_yaml)

        err = assert_raises(RuntimeError) do
            LMNPCompta::Invoice.compute_prorata("Autre Bien", 2025, 100.0)
        end
        assert_match /Disponibilité non configurée pour le bien 'Autre Bien'/, err.message
    end

    def test_compute_prorata_with_pleine_annee_asset_without_disponibilite_file
        # Asset with surface and pleine_annee: true (no disponibilite.yaml needed!)
        asset = LMNPCompta::Asset.new(
            nom: "Appartement 100",
            date_achat: "2025-01-01",
            surface_totale: 100.0,
            surface_louee: 50.0,
            pleine_annee: true
        )
        chalet = LMNPCompta::Asset.find("Chalet")
        File.write(@immo_file, [chalet.to_h, asset.to_h].to_yaml)

        # compute_prorata succeeds with p_temporis = 1.0 without requiring disponibilite.yaml
        res = LMNPCompta::Invoice.compute_prorata("Appartement 100", 2025, 200.0)
        assert_in_delta 0.50, res[:p_surface], 0.001
        assert_in_delta 1.0, res[:p_temporis], 0.001
        assert_in_delta 0.50, res[:taux], 0.001
        assert_equal LMNPCompta::Montant.new(100.0), res[:part_pro]
        assert_equal LMNPCompta::Montant.new(100.0), res[:part_perso]
    end

    def test_yaml_invoice_with_prorata_paid_by_bank
        invoice_file = File.join(TEST_DIR, 'electricite.yaml')
        File.write(invoice_file, <<~YAML)
            - date: "2025-05-10"
              journal: "AC"
              libelle: Facture EDF Chalet
              ref: EDF-2025-05
              bien: Chalet
              prorata: true
              lignes:
                - compte: 606100
                  debit: 200.00
                - compte: 512000
                  credit: 200.00
        YAML

        entries = LMNPCompta::Invoice.parse(invoice_file)
        assert_equal 1, entries.length
        entry = entries.first

        assert entry.valid?, "Entry should be balanced and valid"
        # 24% of 200.00 = 48.00 pro, 152.00 perso
        assert_equal 3, entry.lines.length

        charge_line = entry.lines.find { |l| l[:compte].to_s == '606100' }
        assert_equal LMNPCompta::Montant.new(48.00), charge_line[:debit]

        perso_line = entry.lines.find { |l| l[:compte].to_s == '108000' }
        assert_equal LMNPCompta::Montant.new(152.00), perso_line[:debit]

        banque_line = entry.lines.find { |l| l[:compte].to_s == '512000' }
        assert_equal LMNPCompta::Montant.new(200.00), banque_line[:credit]
    end

    def test_yaml_invoice_with_prorata_paid_by_exploitant
        invoice_file = File.join(TEST_DIR, 'eau.yaml')
        File.write(invoice_file, <<~YAML)
            - date: "2025-06-15"
              journal: "OD"
              libelle: Facture Eau Chalet (payé perso)
              ref: EAU-2025-06
              bien: Chalet
              prorata: true
              lignes:
                - compte: 606100
                  debit: 100.00
                - compte: 108000
                  credit: 100.00
        YAML

        entries = LMNPCompta::Invoice.parse(invoice_file)
        assert_equal 1, entries.length
        entry = entries.first

        assert entry.valid?, "Entry should be balanced and valid"
        # 24% of 100.00 = 24.00 pro debit on 606100 and 24.00 credit on 108000
        assert_equal 2, entry.lines.length

        charge_line = entry.lines.find { |l| l[:compte].to_s == '606100' }
        assert_equal LMNPCompta::Montant.new(24.00), charge_line[:debit]

        credit_line = entry.lines.find { |l| l[:compte].to_s == '108000' }
        assert_equal LMNPCompta::Montant.new(24.00), credit_line[:credit]
    end

    def test_analyser_facture_with_prorata_flag
        invoice_file = File.join(TEST_DIR, 'assurance.yaml')
        File.write(invoice_file, <<~YAML)
            - date: "2025-03-01"
              journal: "AC"
              libelle: Assurance Habitation
              ref: ASSUR-2025
              lignes:
                - compte: 616000
                  debit: 500.00
                - compte: 512000
                  credit: 500.00
        YAML

        # Run analyser-facture with --prorata Chalet
        cmd = LMNPCompta::Commands::Journal::AnalyserFacture.new([
            "--prorata", "Chalet",
            invoice_file
        ])

        out, _ = capture_io { cmd.execute }

        # 24% of 500.00 = 120.00 pro, 380.00 perso
        assert_match /-c 616000 -s D -m 120,00 -L "Part pro \(Prorata 24\.0%\)"/, out
        assert_match /-c 108000 -s D -m 380,00 -L "Part perso \(Non déductible\)"/, out
        assert_match /-c 512000 -s C -m 500,00/, out
    end

    def test_verifier_multi_property_prorata
        # Setup second property: Studio with 50% surface and 100% temporis = 50%
        studio = LMNPCompta::Asset.new(
            nom: "Studio",
            date_achat: "2025-01-01",
            surface_totale: 50.0,
            surface_louee: 25.0,
            valeur_achat: 80000.0
        )
        chalet = LMNPCompta::Asset.find("Chalet")
        File.write(@immo_file, [chalet.to_h, studio.to_h].to_yaml)

        dispo_studio = LMNPCompta::Disponibilite.new(
            nom_bien: "Studio",
            annee: 2025,
            disponibles: 365,
            indisponibles: 0
        )
        LMNPCompta::Disponibilite.save(dispo_studio)

        # Invoice 1: Chalet (24% pro of 100 = 24.00)
        inv_chalet = File.join(TEST_DIR, 'inv_chalet.yaml')
        File.write(inv_chalet, <<~YAML)
            - date: "2025-04-01"
              journal: "AC"
              libelle: Gaz Chalet
              ref: GAZ-01
              lignes:
                - compte: 606100
                  debit: 100.00
                - compte: 512000
                  credit: 100.00
        YAML

        # Invoice 2: Studio (50% pro of 100 = 50.00)
        inv_studio = File.join(TEST_DIR, 'inv_studio.yaml')
        File.write(inv_studio, <<~YAML)
            - date: "2025-04-02"
              journal: "AC"
              libelle: Internet Studio
              ref: NET-01
              lignes:
                - compte: 626000
                  debit: 100.00
                - compte: 512000
                  credit: 100.00
        YAML

        # Global Invoice: Not prorated (100% pro = 80.00)
        inv_global = File.join(TEST_DIR, 'inv_global.yaml')
        File.write(inv_global, <<~YAML)
            - date: "2025-04-03"
              journal: "AC"
              libelle: Logiciel Compta
              ref: SOFT-01
              lignes:
                - compte: 651100
                  debit: 80.00
                - compte: 512000
                  credit: 80.00
        YAML

        # Create journal with matching entries
        journal_file = File.join(@dispo_dir, 'journal.yaml')
        journal = LMNPCompta::Journal.new(journal_file, year: 2025)

        # Chalet entry (24 pro, 76 perso, 100 banque)
        e_chalet = LMNPCompta::Entry.new(
            date: "01/04/2025",
            libelle: "Gaz Chalet",
            ref: "GAZ-01",
            journal: "AC",
            file: "inv_chalet.yaml"
        )
        e_chalet.add_debit("606100", 24.00, "Part pro (Prorata 24.0%)")
        e_chalet.add_debit("108000", 76.00, "Part perso (Non déductible)")
        e_chalet.add_credit("512000", 100.00)
        journal.add_entry(e_chalet)

        # Studio entry (50 pro, 50 perso, 100 banque)
        e_studio = LMNPCompta::Entry.new(
            date: "02/04/2025",
            libelle: "Internet Studio",
            ref: "NET-01",
            journal: "AC",
            file: "inv_studio.yaml"
        )
        e_studio.add_debit("626000", 50.00, "Part pro (Prorata 50.0%)")
        e_studio.add_debit("108000", 50.00, "Part perso (Non déductible)")
        e_studio.add_credit("512000", 100.00)
        journal.add_entry(e_studio)

        # Global entry (80 pro, 80 banque)
        e_global = LMNPCompta::Entry.new(
            date: "03/04/2025",
            libelle: "Logiciel Compta",
            ref: "SOFT-01",
            journal: "AC",
            file: "inv_global.yaml"
        )
        e_global.add_debit("651100", 80.00)
        e_global.add_credit("512000", 80.00)
        journal.add_entry(e_global)

        journal.save!

        # Run verifier with mixed arguments:
        # lmnp journal verifier inv_global.yaml --prorata Chalet inv_chalet.yaml --prorata Studio inv_studio.yaml
        verifier_cmd = LMNPCompta::Commands::Journal::Verifier.new([
            inv_global,
            "--prorata", "Chalet", inv_chalet,
            "--prorata", "Studio", inv_studio
        ])

        out, _ = capture_io { verifier_cmd.execute }
        assert_match /3 écritures réconciliées avec succès/, out
        assert_match /AUDIT PARFAIT/, out
    end
end
