require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'date'

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'lmnp_compta'
require 'lmnp_compta/command'
require 'lmnp_compta/commands/journal'
require 'lmnp_compta/settings'
require 'lmnp_compta/commands/journal/verifier'

# Test suite for lmnp journal verifier command
class VerifierCommandTest < Minitest::Test
    TEST_DIR = File.join(__dir__, 'tmp', 'verifier_cmd')

    def setup
        @original_stdout = $stdout
        $stdout = StringIO.new
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)

        LMNPCompta::Settings.instance.instance_variable_set(:@data_dir, TEST_DIR)
        LMNPCompta::Settings.instance.instance_variable_set(:@annee, 2025)

        # Mock extract_text on Invoice class
        LMNPCompta::Invoice.class_eval do
            class << self
                unless method_defined?(:original_extract_text)
                    alias_method :original_extract_text, :extract_text
                    remove_method :extract_text
                    def extract_text(f); "DUMMY TEXT"; end
                end
            end
        end

        # Setup journal directory
        @journal_dir = File.join(TEST_DIR, '2025')
        FileUtils.mkdir_p(@journal_dir)
        @journal_file = File.join(@journal_dir, 'journal.yaml')
        @journal = LMNPCompta::Journal.new(@journal_file, year: 2025)
    end

    def teardown
        $stdout = @original_stdout
        FileUtils.rm_rf(TEST_DIR)

        LMNPCompta::Invoice.class_eval do
            class << self
                if method_defined?(:original_extract_text)
                    remove_method :extract_text if method_defined?(:extract_text)
                    alias_method :extract_text, :original_extract_text
                    remove_method :original_extract_text
                end
            end
        end
    end

    def test_perfect_reconciliation
        # 1. Invoice YAML
        invoice_file = File.join(TEST_DIR, "facture.pdf.yaml")
        invoice_data = {
            'date' => '15/01/2025',
            'journal' => 'AC',
            'libelle' => 'Facture Internet',
            'lignes' => [
                {'compte' => '606000', 'debit' => 10},
                {'compte' => '512000', 'credit' => 10}
            ]
        }
        File.write(invoice_file, invoice_data.to_yaml)

        # 2. Airbnb CSV
        csv_file = File.join(TEST_DIR, "airbnb.csv")
        csv_content = <<~CSV
          Type,Date,Code de confirmation,Date de début,Date de fin,Nuits,Logement,Frais de service,Revenus bruts,Devise
          Réservation,01/16/2025,HM43H5YC8Z,01/15/2025,01/20/2025,5,Studio,10.00,100.00,EUR
        CSV
        File.write(csv_file, csv_content)

        # Add matches to journal
        e1 = LMNPCompta::Entry.new(
            date: "2025-01-15", journal: "AC", libelle: "Facture Internet", file: "facture.pdf"
        )
        e1.add_debit("606000", 10)
        e1.add_credit("512000", 10)
        @journal.add_entry(e1)

        e2 = LMNPCompta::Entry.new(
            date: "2025-01-16", journal: "VT", libelle: "Airbnb", ref: "HM43H5YC8Z-01", file: "airbnb.csv"
        )
        e2.add_credit("706000", 100)
        e2.add_debit("622600", 10)
        e2.add_debit("512000", 90)
        @journal.add_entry(e2)
        @journal.save!

        cmd = LMNPCompta::JournalCommand.new(["verifier", TEST_DIR])
        cmd.execute

        out = $stdout.string
        assert_match /2 écritures réconciliées avec succès/, out
        assert_match /AUDIT PARFAIT : Le journal correspond exactement aux justificatifs !/, out
    end

    def test_missing_documents
        # File provided but not in journal
        invoice_file = File.join(TEST_DIR, "facture.pdf.yaml")
        invoice_data = {
            'date' => '15/01/2025',
            'journal' => 'AC',
            'libelle' => 'Facture Internet',
            'lignes' => [
                {'compte' => '606000', 'debit' => 10},
                {'compte' => '512000', 'credit' => 10}
            ]
        }
        File.write(invoice_file, invoice_data.to_yaml)

        # Empty journal!

        cmd = LMNPCompta::JournalCommand.new(["verifier", TEST_DIR])
        cmd.execute

        out = $stdout.string
        assert_match /0 écritures réconciliées avec succès/, out
        assert_match /PIÈCES JUSTIFICATIVES NON ENREGISTRÉES \(1\)/, out
        assert_match /Facture Internet/, out
        assert_match /AUDIT ÉCHOUÉ : Des anomalies ont été détectées/, out
    end

    def test_orphan_entries
        # Add entry to journal
        e1 = LMNPCompta::Entry.new(
            date: "2025-01-15", journal: "AC", libelle: "Facture Internet", file: "facture.pdf"
        )
        e1.add_debit("606000", 10)
        e1.add_credit("512000", 10)
        @journal.add_entry(e1)
        @journal.save!

        # But do not provide any files!
        # Create a dummy pdf just to pass empty file check, but it will fail parsing since extract_text is empty
        File.write(File.join(TEST_DIR, "dummy.pdf"), "hello")

        cmd = LMNPCompta::JournalCommand.new(["verifier", TEST_DIR])
        cmd.execute

        out = $stdout.string
        assert_match /0 écritures réconciliées avec succès/, out
        assert_match /ÉCRITURES ORPHELINES DANS LE JOURNAL \(1\)/, out
        assert_match /Facture Internet/, out
        assert_match /AUDIT ÉCHOUÉ : Des anomalies ont été détectées/, out
    end

    def test_until_date
        # CSV with 2 rows, one in Jan, one in Feb
        csv_file = File.join(TEST_DIR, "airbnb.csv")
        csv_content = <<~CSV
          Type,Date,Code de confirmation,Date de début,Date de fin,Nuits,Logement,Frais de service,Revenus bruts,Devise
          Réservation,01/16/2025,HM43H5YC8Z,01/15/2025,01/20/2025,5,Studio,10.00,100.00,EUR
          Réservation,02/16/2025,HM43H5YC8Z,01/15/2025,01/20/2025,5,Studio,10.00,100.00,EUR
        CSV
        File.write(csv_file, csv_content)

        # Journal only has Jan entry
        e1 = LMNPCompta::Entry.new(
            date: "2025-01-16", journal: "VT", libelle: "Airbnb", ref: "HM43H5YC8Z-01", file: "airbnb.csv"
        )
        e1.add_credit("706000", 100)
        e1.add_debit("622600", 10)
        e1.add_debit("512000", 90)
        @journal.add_entry(e1)
        @journal.save!

        # If we run without --until, Feb entry should be reported missing
        cmd = LMNPCompta::JournalCommand.new(["verifier", TEST_DIR])
        cmd.execute
        out = $stdout.string
        assert_match /PIÈCES JUSTIFICATIVES NON ENREGISTRÉES \(1\)/, out

        $stdout.reopen
        # If we run with --until Jan 31, Feb entry is skipped, so Audit is perfect!
        cmd = LMNPCompta::JournalCommand.new(["verifier", "-u", "2025-01-31", TEST_DIR])
        cmd.execute
        out = $stdout.string
        assert_match /1 écritures réconciliées avec succès/, out
        assert_match /AUDIT PARFAIT : Le journal correspond exactement aux justificatifs !/, out
    end

    def test_verifier_handles_unrecognized_invoice_without_crash
        # 1. Create unrecognized PDF file (extract_text mocked to return DUMMY TEXT, which has no parser)
        unrecognized_file = File.join(TEST_DIR, "unrecognized_invoice.pdf")
        File.write(unrecognized_file, "PDF content")

        # 2. Run verifier
        cmd = LMNPCompta::JournalCommand.new(["verifier", unrecognized_file])
        cmd.execute

        out = $stdout.string
        # Verify it outputs the unrecognized error cleanly instead of crashing
        assert_match /Erreur de parsing pour.*unrecognized_invoice.pdf.*Document PDF non reconnu/, out
    end

    def test_verifier_does_not_recurse_directories
        # 1. Create a subdirectory and a YAML invoice inside it
        subdir = File.join(TEST_DIR, "subdir")
        FileUtils.mkdir_p(subdir)
        subdir_invoice = File.join(subdir, "facture_nested.pdf.yaml")
        invoice_data = {
            'date' => '15/01/2025',
            'journal' => 'AC',
            'libelle' => 'Facture Internet nested',
            'lignes' => [
                {'compte' => '606000', 'debit' => 10},
                {'compte' => '512000', 'credit' => 10}
            ]
        }
        File.write(subdir_invoice, invoice_data.to_yaml)

        # 2. Run verifier passing TEST_DIR
        # Since it does not recurse, it should NOT find facture_nested.pdf.yaml,
        # so it should output that no files were found.
        cmd = LMNPCompta::JournalCommand.new(["verifier", TEST_DIR])
        cmd.execute

        out = $stdout.string
        assert_match /Aucun fichier CSV, PDF ou YAML trouvé pour la vérification/, out
    end

    def test_verifier_ignores_bad_year_entries
        # 1. Create a YAML invoice with a date in the next fiscal year (2026) while target is 2025
        invoice_file = File.join(TEST_DIR, "facture_bad_year.pdf.yaml")
        invoice_data = {
            'date' => '05/01/2026', # Next year!
            'journal' => 'AC',
            'libelle' => 'Facture EDF next year',
            'lignes' => [
                {'compte' => '606100', 'debit' => 50},
                {'compte' => '512000', 'credit' => 50}
            ]
        }
        File.write(invoice_file, invoice_data.to_yaml)

        # 2. Run verifier
        # Since ignore_bad_year is true, the 2026 entry is ignored, leaving 0 expected entries
        cmd = LMNPCompta::JournalCommand.new(["verifier", invoice_file])
        cmd.execute

        out = $stdout.string
        refute_match /Erreur pour.*Date hors année fiscale/, out
        assert_match /0 écritures réconciliées avec succès/, out
        assert_match /AUDIT PARFAIT/, out
    end

    def test_verifier_with_side_yaml_matching
        # 1. Create a PDF and its side .yaml file
        pdf_file = File.join(TEST_DIR, "divers_decorations.pdf")
        FileUtils.touch(pdf_file)
        yaml_file = "#{pdf_file}.yaml"
        invoice_data = {
            'date' => '26/01/2025',
            'journal' => 'AC',
            'libelle' => 'Sotrene - Divers décorations',
            'lignes' => [
                {'compte' => '606300', 'debit' => 45.13},
                {'compte' => '512000', 'credit' => 45.13}
            ]
        }
        File.write(yaml_file, invoice_data.to_yaml)

        # 2. Add matching entry referencing the PDF file name
        e = LMNPCompta::Entry.new(
            date: "2025-01-26",
            journal: "AC",
            libelle: "Sotrene - Divers décorations",
            file: "divers_decorations.pdf"
        )
        e.add_debit("606300", 45.13)
        e.add_credit("512000", 45.13)
        @journal.add_entry(e)
        @journal.save!

        # 3. Run verifier passing both files (or just directory)
        cmd = LMNPCompta::JournalCommand.new(["verifier", TEST_DIR])
        cmd.execute

        out = $stdout.string
        assert_match /1 écritures réconciliées avec succès/, out
        assert_match /AUDIT PARFAIT/, out
    end
end
