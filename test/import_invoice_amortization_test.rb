$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'stringio'
require 'lmnp_compta/commands/journal'
require 'lmnp_compta/commands/journal/analyser_facture'
require 'lmnp_compta/settings'
require 'lmnp_compta/asset'

class ImportInvoiceAmortizationTest < Minitest::Test
    TEST_DIR = 'tmp_test_amortization'

    def setup
        @original_stdout = $stdout
        @original_stdin = $stdin
        $stdout = StringIO.new
        $stdin = StringIO.new

        FileUtils.mkdir_p(TEST_DIR)
        LMNPCompta::Settings.instance.instance_variable_set(:@annee, 2025)
        # We need immo file for amortization
        File.write('immobilisations.yaml', "[]")
        LMNPCompta::Settings.instance.instance_variable_set(:@immo_file_setting, 'immobilisations.yaml')
        LMNPCompta::Settings.instance.instance_variable_set(:@data_dir, '.')

        @cmd = LMNPCompta::JournalCommand.new([])

        # Mock extract_text globally for this test class on the actual command class
        LMNPCompta::Commands::Journal::AnalyserFacture.class_eval do
            unless method_defined?(:original_extract_text)
                alias_method :original_extract_text, :extract_text
            end
            remove_method :extract_text
            def extract_text(f); "dummy text"; end
        end
    end

    def teardown
        $stdout = @original_stdout
        $stdin = @original_stdin
        FileUtils.rm_rf(TEST_DIR)

        # Restore original extract_text
        LMNPCompta::Commands::Journal::AnalyserFacture.class_eval do
            if method_defined?(:original_extract_text)
                remove_method :extract_text if method_defined?(:extract_text)
                alias_method :extract_text, :original_extract_text
                remove_method :original_extract_text
            end
        end
    end



    def create_dummy_pdf(filename, content = "Dummy Content")
        # We mock extract_text, so the physical PDF doesn't matter much,
        # but the file must exist for checks.
        File.write(filename, content)
    end

    def mock_invoice_parser(amount)
        # We need to stub InvoiceParser::Factory.build to return a parser that gives us specific data
        parser_mock = Minitest::Mock.new
        parser_mock.expect :parse, [{
            date: Date.new(2025, 1, 15),
            libelle: "Test Invoice",
            ref: "REF-123",
            compte_charge: "606400",
            compte_banque: "512000",
            montant: LMNPCompta::Montant.new(amount)
        }]
        # parser_name is called in process_file
        parser_mock.expect :class, parser_mock
        parser_mock.expect :parser_name, "TEST_PARSER"
        # class.parser_name is tricky with Minitest::Mock,
        # simpler to just stub the Factory to return a simple object or struct

        # Let's use a real object class for the parser to avoid complex mocking logic
        stub_parser_class = Class.new do
            def initialize(amount)
                @amount = amount
            end
            def parse
                [{
                    date: Date.new(2025, 1, 15),
                    libelle: "Test Invoice",
                    ref: "REF-123",
                    compte_charge: "606400",
                    compte_banque: "512000",
                    montant: LMNPCompta::Montant.new(@amount)
                }]
            end
            def self.parser_name; "TEST_PARSER"; end
        end
        stub_parser_class.new(amount)
    end

    def with_mocked_parser(amount, &block)
        parser = mock_invoice_parser(amount)
        LMNPCompta::InvoiceParser::Factory.stub :build, parser do
             # verify extract_text doesn't crash, we can stub it in the instance strictly if needed
             # or just write a file. process_file calls extract_text.
             # We can stub ImportInvoice#extract_text (private method) but let's just let it run
             # and if we assume the Factory ignores content it is fine.
             # Wait, Factory.build takes content. So we are good.
             block.call
        end
    end

    def test_invoice_under_threshold
        create_dummy_pdf("small.pdf")

        with_mocked_parser(500) do
            output, _ = capture_io do
                LMNPCompta::JournalCommand.new(["analyser-facture"] + ["small.pdf"]).execute
            end
            assert_match /-c 606400 -s D -m 500.00/, output
        end
    end

    def test_invoice_over_threshold_amortize_no
        create_dummy_pdf("large.pdf")

        with_mocked_parser(800) do
            # Simulate "n" to prompt
            $stdin.puts "n"
            $stdin.rewind

            output, _ = capture_io do
                LMNPCompta::JournalCommand.new(["analyser-facture"] + ["large.pdf"]).execute
            end

            # Should stay as charge
            assert_match /-c 606400 -s D -m 800.00/, output

            # Immo file should be empty (except header)
            assets = LMNPCompta::Asset.load('immobilisations.yaml')
            assert_empty assets
        end
    end

    def test_invoice_over_threshold_amortize_yes
        create_dummy_pdf("large_asset.pdf")

        with_mocked_parser(1000) do
            # Simulate "y", duration "5", name "My Mac"
            $stdin.puts "y\n5\nMy Mac\n"
            $stdin.rewind

            output, _ = capture_io do
                LMNPCompta::JournalCommand.new(["analyser-facture"] + ["large_asset.pdf"]).execute
            end

            # Check Check output command: Account should start with 2
            assert_match /-c 218400 -s D -m 1000.00/, output

            # Check Immo File
            assets = LMNPCompta::Asset.load('immobilisations.yaml')
            assert_equal 1, assets.length
            asset = assets.first
            assert_equal "My Mac", asset.nom
            assert_equal 1000.0, asset.valeur_achat
            assert_equal 1, asset.composants.length
            assert_equal "Mobilier", asset.composants.first.nom
            assert_equal 5, asset.composants.first.duree
        end
    end

    def test_yaml_override
        create_dummy_pdf("yaml_inv.pdf")
        File.write("yaml_inv.pdf.yaml", {
            "date" => Date.today.strftime("%d/%m/%Y"),
            "journal" => "AC",
            "libelle" => "Yaml Asset",
            "ref" => "REFY",
            "amortize" => true,
            "duree_amortissement" => 7,
            "nom_actif" => "Office Chair",
            "lignes" => [
                {"compte" => "606400", "debit" => 900},
                {"compte" => "512000", "credit" => 900}
            ]
        }.to_yaml)

        LMNPCompta::InvoiceParser::Factory.stub :build, nil do
             output, _ = capture_io do
                LMNPCompta::JournalCommand.new(["analyser-facture"] + ["yaml_inv.pdf"]).execute
            end

             # Check Immo File
            assets = LMNPCompta::Asset.load('immobilisations.yaml')
            assert_equal 1, assets.length
            asset = assets.first
            assert_equal "Office Chair", asset.nom
            assert_equal 7, asset.composants.first.duree

            assert_match /-c 218400 -s D -m 900/, output
        end
    end
end
