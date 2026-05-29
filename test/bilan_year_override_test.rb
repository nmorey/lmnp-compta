require 'minitest/autorun'
require 'fileutils'
require 'stringio'
require_relative '../lib/lmnp_compta'
require_relative '../lib/lmnp_compta/commands/bilan'
require_relative '../lib/lmnp_compta/commands/bilan/liasse'
require_relative '../lib/lmnp_compta/commands/bilan/fec'
require_relative '../lib/lmnp_compta/settings'

class BilanYearOverrideTest < Minitest::Test
    TEST_DIR = File.join(__dir__, 'tmp', 'year_override')
    CONFIG_FILE = File.join(TEST_DIR, 'lmnp.yaml')

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)

        # Create a config for year 2025
        File.write(CONFIG_FILE, <<~YAML)
            siren: "123456789"
            annee: 2025
            data_dir: "#{TEST_DIR}"
            journal_file: "journal.yaml"
            immo_file: "immobilisations.yaml"
            stock_file: "stock_fiscal.yaml"
        YAML

        # Force reload settings
        LMNPCompta::Settings.load(CONFIG_FILE)

        # Create data for 2024 (the year we want to override to)
        # We need a journal file for 2024
        dir_2024 = File.join(TEST_DIR, '2024')
        FileUtils.mkdir_p(dir_2024)
        File.write(File.join(dir_2024, 'journal.yaml'), [].to_yaml) # Empty journal is fine for liasse/fec basics

        # Create data for 2025 (default year)
        dir_2025 = File.join(TEST_DIR, '2025')
        FileUtils.mkdir_p(dir_2025)
        File.write(File.join(dir_2025, 'journal.yaml'), [].to_yaml)
    end

    def teardown
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_liasse_year_override
        # Given config is 2025
        assert_equal 2025, LMNPCompta::Settings.instance.annee

        # When we run liasse with --year 2024
        # Capture stdout
        out, err = capture_io do
            # Simulate CLI arguments
            LMNPCompta::Commands::Bilan::Liasse.new(["--year", "2024"]).execute
        end

        # Then Settings should have been updated
        assert_equal 2024, LMNPCompta::Settings.instance.annee
    end

    def test_fec_year_override
        # Reset year to 2025
        LMNPCompta::Settings.instance.annee = 2025
        assert_equal 2025, LMNPCompta::Settings.instance.annee

        out, err = capture_io do
            LMNPCompta::Commands::Bilan::Fec.new(["--year", "2024"]).execute
        end

        # Verify Settings updated
        assert_equal 2024, LMNPCompta::Settings.instance.annee

        # Verify FEC file exists
        expected_file = File.join(TEST_DIR, '2024', "123456789FEC20241231.txt")
        assert File.exist?(expected_file), "FEC file for 2024 should exist"
    end
end
