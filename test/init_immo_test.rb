require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'lmnp_compta/commands/configurer'
require 'lmnp_compta/settings'

class InitImmoTest < Minitest::Test
    TEST_DIR = 'tmp_test_immo'

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)
        @original_dir = Dir.pwd
        Dir.chdir(TEST_DIR)

        # Default mock settings
        File.write('lmnp.yaml', "data_dir: .\nimmo_file: immobilisations.yaml\n")
        LMNPCompta::Settings.load('lmnp.yaml')
    end

    def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_cli_generation_default
        valeur = "200000"
        args = ["immo", "--valeur", valeur, "--date", "2025-01-01", "--nom", "Test Flat"]

        capture_io do
            LMNPCompta::ConfigurerCommand.new(args).execute
        end

        data = LMNPCompta::Asset.load('immobilisations.yaml').first
        assert_equal 5, data.composants.length

        terrain = data.composants.find { |c| c.nom == "Terrain" }
        assert_equal LMNPCompta::Montant.new(30000), terrain.valeur # 15%
    end

    def test_append_mode
        # First Apartment
        args1 = ["immo", "--valeur", "100000", "--date", "2025-01-01", "--nom", "Flat A"]
        capture_io { LMNPCompta::ConfigurerCommand.new(args1).execute }

        # Second Apartment
        args2 = ["immo", "--valeur", "200000", "--date", "2025-02-01", "--nom", "Flat B"]
        capture_io { LMNPCompta::ConfigurerCommand.new(args2).execute }

        # Check file
        assert File.exist?('immobilisations.yaml')
        data = LMNPCompta::Asset.load('immobilisations.yaml')

        assert_equal 2, data.length
        assert_equal "Flat A", data[0].nom
        assert_equal LMNPCompta::Montant.new(100000), data[0].valeur_achat

        assert_equal "Flat B", data[1].nom
        assert_equal LMNPCompta::Montant.new(200000), data[1].valeur_achat
    end

    def test_cli_custom_percentages
        valeur = "100000"
        args = [
            "immo",
            "--valeur", valeur,
            "--date", "2025-01-01",
            "--nom", "Custom Percent Test",
            "--terrain", "20",
            "--gros-oeuvre", "35"
        ]

        capture_io do
            LMNPCompta::ConfigurerCommand.new(args).execute
        end

        data = LMNPCompta::Asset.load('immobilisations.yaml').first

        terrain = data.composants.find { |c| c.nom == "Terrain" }
        assert_equal LMNPCompta::Montant.new(20000), terrain.valeur # 20%

        go = data.composants.find { |c| c.nom == "Gros Oeuvre" }
        assert_equal LMNPCompta::Montant.new(35000), go.valeur # 35%
    end

    def test_validation_100_percent
        args = [
            "immo",
            "--valeur", "100000",
            "--date", "2025-01-01",
            "--nom", "Fail",
            "--terrain", "20"
        ]

        # ConfigurerCommand puts error and returns, doesn't raise exception anymore to be user-friendly
        # So we assert stdout contains error
        out, _ = capture_io { LMNPCompta::ConfigurerCommand.new(args).execute }
        assert_match /Erreur: Total pourcentages/, out
    end
end