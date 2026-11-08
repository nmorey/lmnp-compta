require 'minitest/autorun'
require 'fileutils'
require 'lmnp_compta/commands/configurer'
require 'lmnp_compta/commands/configurer/disponibilite'
require 'lmnp_compta/settings'
require 'lmnp_compta/disponibilite'

class DisponibiliteCommandTest < Minitest::Test
    TEST_DIR = File.join(__dir__, 'tmp', 'disponibilite_cmd')

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)
        @original_dir = Dir.pwd
        Dir.chdir(TEST_DIR)

        File.write('lmnp.yaml', "data_dir: .\nannee: 2025\nimmo_file: immobilisations.yaml\n")
        LMNPCompta::Settings.load('lmnp.yaml')
    end

    def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_cli_disponibilite_save_with_disponibles_only
        args = [
            "disponibilite",
            "--bien", "Chalet Alpin",
            "--annee", "2025",
            "--disponibles", "220"
        ]

        out, _ = capture_io do
            LMNPCompta::ConfigurerCommand.new(args).execute
        end

        assert_match /Disponibilité enregistrée pour 'Chalet Alpin' \(2025\)/, out
        assert_match /Prorata temporis retenu : 60\.27 %/, out

        dispo = LMNPCompta::Disponibilite.find("Chalet Alpin", 2025)
        refute_nil dispo
        assert_equal 220, dispo.disponibles
        assert_equal 145, dispo.indisponibles
    end

    def test_cli_disponibilite_save_with_indisponibles_only
        args = [
            "disponibilite",
            "--bien", "Chalet Alpin",
            "--annee", "2025",
            "--indisponibles", "145"
        ]

        out, _ = capture_io do
            LMNPCompta::ConfigurerCommand.new(args).execute
        end

        assert_match /Disponibilité enregistrée pour 'Chalet Alpin' \(2025\)/, out
        assert_match /Prorata temporis retenu : 60\.27 %/, out

        dispo = LMNPCompta::Disponibilite.find("Chalet Alpin", 2025)
        refute_nil dispo
        assert_equal 220, dispo.disponibles
        assert_equal 145, dispo.indisponibles
    end

    def test_cli_disponibilite_save_with_pleine_annee
        args = [
            "disponibilite",
            "--bien", "Appartement 100",
            "--annee", "2025",
            "--pleine-annee"
        ]

        out, _ = capture_io do
            LMNPCompta::ConfigurerCommand.new(args).execute
        end

        assert_match /Disponibilité enregistrée pour 'Appartement 100' \(2025\)/, out
        assert_match /Prorata temporis retenu : 100\.0 %/, out

        dispo = LMNPCompta::Disponibilite.find("Appartement 100", 2025)
        refute_nil dispo
        assert_equal 365, dispo.disponibles
        assert_equal 0, dispo.indisponibles
        assert dispo.pleine_annee?
    end

    def test_cli_disponibilite_validation_failure
        args = [
            "disponibilite",
            "--bien", "Chalet Alpin",
            "--annee", "2025",
            "--disponibles", "200",
            "--indisponibles", "100" # sum = 300 != 365
        ]

        out, _ = capture_io do
            LMNPCompta::ConfigurerCommand.new(args).execute
        end

        assert_match /Erreur: Incohérence du nombre de jours/, out
        assert_nil LMNPCompta::Disponibilite.find("Chalet Alpin", 2025)
    end

    def test_cli_disponibilite_lister
        # Save one entry first
        LMNPCompta::Disponibilite.save(
            LMNPCompta::Disponibilite.new(
                nom_bien: "Appart Mer",
                annee: 2025,
                disponibles: 200,
                indisponibles: 165
            )
        )

        args = ["disponibilite", "--annee", "2025", "--lister"]
        out, _ = capture_io do
            LMNPCompta::ConfigurerCommand.new(args).execute
        end

        assert_match /Appart Mer/, out
        assert_match /200\/365 jours dispo/, out
        assert_match /54\.79 %/, out
    end
end
