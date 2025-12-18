require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'lmnp_compta/commands/init_immo'
require 'lmnp_compta/settings'

class InitImmoTest < Minitest::Test
    TEST_DIR = 'tmp_test_immo'

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)
        @original_dir = Dir.pwd
        Dir.chdir(TEST_DIR)

        # Default mock settings
        File.write('lmnp.yaml', "immo_file: immobilisations.yaml\n")
        LMNPCompta::Settings.load('lmnp.yaml')
    end

    def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_cli_generation_default
        valeur = "200000"
        args = ["--valeur", valeur, "--date", "2025-01-01", "--nom", "Test Flat"]

        capture_io do
            LMNPCompta::Commands::InitImmo.new(args).execute
        end

        data = LMNPCompta::Asset.load('immobilisations.yaml').first
        assert_equal 5, data.composants.length

        terrain = data.composants.find { |c| c.nom == "Terrain" }
        assert_equal LMNPCompta::Montant.new(30000), terrain.valeur # 15%
    end

    def test_append_mode
        # First Apartment
        args1 = ["--valeur", "100000", "--date", "2025-01-01", "--nom", "Flat A"]
        capture_io { LMNPCompta::Commands::InitImmo.new(args1).execute }

        # Second Apartment
        args2 = ["--valeur", "200000", "--date", "2025-02-01", "--nom", "Flat B"]
        capture_io { LMNPCompta::Commands::InitImmo.new(args2).execute }

        # Check file
        assert File.exist?('immobilisations.yaml')
        data = YAML.load_file('immobilisations.yaml')

        assert_equal 2, data.length
        assert_equal "Flat A", data[0]['nom']
        assert_equal 100000.0, data[0]['valeur_achat']

        assert_equal "Flat B", data[1]['nom']
        assert_equal 200000.0, data[1]['valeur_achat']
    end

    def test_cli_custom_percentages
        # Custom: Terrain 20%, Gros Oeuvre 35% -> implies changing defaults.
        # To pass validation, we need to balance it.
        # Default: Terrain 15, GO 40, Facade 15, Install 15, Agenc 15 = 100
        # Change: Terrain 20 (+5), GO 35 (-5) = 100

        valeur = "100000"
        args = [
            "--valeur", valeur,
            "--date", "2025-01-01",
            "--nom", "Custom Percent Test",
            "--terrain", "20",
            "--gros-oeuvre", "35"
        ]

        capture_io do
            LMNPCompta::Commands::InitImmo.new(args).execute
        end

        data = LMNPCompta::Asset.load('immobilisations.yaml').first

        terrain = data.composants.find { |c| c.nom == "Terrain" }
        assert_equal LMNPCompta::Montant.new(20000), terrain.valeur # 20%

        go = data.composants.find { |c| c.nom == "Gros Oeuvre" }
        assert_equal LMNPCompta::Montant.new(35000), go.valeur # 35%

        # Check untouched component
        facade = data.composants.find { |c| c.nom == "Façade" }
        assert_equal LMNPCompta::Montant.new(15000), facade.valeur # Default 15%
    end

    def test_validation_100_percent
        # Terrain 20 (Total 105) -> Should fail
        args = [
            "--valeur", "100000",
            "--date", "2025-01-01",
            "--nom", "Fail",
            "--terrain", "20"
        ]

        err = assert_raises(RuntimeError) do
            capture_io { LMNPCompta::Commands::InitImmo.new(args).execute }
        end
        assert_match /doit être égal à 100%/, err.message
    end

    def test_directory_creation
        File.write('lmnp.yaml', "immo_file: subdir/immo.yaml\n")
        LMNPCompta::Settings.load('lmnp.yaml')

        args = ["--valeur", "100", "--date", "2025-01-01", "--nom", "DirTest"]
        capture_io { LMNPCompta::Commands::InitImmo.new(args).execute }

        assert File.exist?('subdir/immo.yaml')
    end
end
