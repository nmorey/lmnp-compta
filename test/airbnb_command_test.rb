require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'date'

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'lmnp_compta'
require 'lmnp_compta/command'
require 'lmnp_compta/settings'
require 'lmnp_compta/commands/import_airbnb'
require 'lmnp_compta/commands/init'

class AirbnbCommandTest < Minitest::Test
    TEST_DIR = File.expand_path('tmp_test_airbnb_cmd', __dir__)

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)
        @original_dir = Dir.pwd
        Dir.chdir(TEST_DIR)

        # Init project
        LMNPCompta::Commands::Init.new(["--siren", "123456789", "--annee", "2025"]).execute
        LMNPCompta::Settings.load('lmnp.yaml')

        # Create dummy CSV
        @csv_file = "airbnb.csv"
        csv_content = <<~CSV
          Type,Date,Code de confirmation,Date de début,Date de départ,Nuits,Hébergement,Ménage,Frais de service,Revenus bruts,Devise
          Payout,01/05/2025,,,,,,,,,
          Réservation,01/01/2025,REF001,01/01/2025,01/05/2025,4,100.00,,0.00,100.00,EUR
        CSV
        File.write(@csv_file, csv_content)
    end

    def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_dry_run_option
        # Ensure journal is empty
        journal_file = 'data/2025/journal.yaml'
        assert !File.exist?(journal_file) || YAML.load_file(journal_file).empty?

        # Execute with --dry-run
        out, err = capture_io do
            LMNPCompta::Commands::ImportAirbnb.new(["-f", @csv_file, "--dry-run"]).execute
        end

        # Verify Output
        assert_match /DRY RUN : Simulation de l'importation/, out
        assert_match /Les 1 écritures suivantes seraient ajoutées/, out
        assert_match /REF001-01/, out
        assert_match /Net: 0,00 € \(Solde\)/, out
        assert_match /Aucune modification n'a été enregistrée/, out

        # Verify Journal NOT saved/updated
        # Journal might be created by Init/Journal.new but should be empty
        journal = LMNPCompta::Journal.new(journal_file)
        assert_empty journal.entries
    end

    def test_normal_run
        # Execute without --dry-run
        out, err = capture_io do
            LMNPCompta::Commands::ImportAirbnb.new(["-f", @csv_file]).execute
        end

        assert_match /Importation terminée. 1 écritures générées/, out
        assert_match /Journal sauvegardé/, out

        # Verify Journal Saved
        journal = LMNPCompta::Journal.new('data/2025/journal.yaml')
        assert_equal 1, journal.entries.length
        assert_equal "REF001-01", journal.entries.first.ref
    end
end
