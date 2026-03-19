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

    TEST_DIR = File.join(__dir__, 'tmp', 'amortization')



    def setup

        @original_stdout = $stdout

        @original_stdin = $stdin

        $stdout = StringIO.new

        $stdin = StringIO.new



        FileUtils.mkdir_p(TEST_DIR)

        LMNPCompta::Settings.instance.instance_variable_set(:@annee, 2025)

                # We need immo file for amortization

                File.write(File.join(TEST_DIR, 'immobilisations.yaml'), "[]")

                LMNPCompta::Settings.instance.instance_variable_set(:@immo_file_setting, 'immobilisations.yaml')

                LMNPCompta::Settings.instance.instance_variable_set(:@data_dir, TEST_DIR)





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

        path = File.join(TEST_DIR, filename)

        File.write(path, content)

        path

    end



    def mock_invoice_parser(amount)

        # We need to stub InvoiceParser::Factory.build to return a parser that gives us specific data

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

        LMNPCompta::InvoiceParser::Factory.singleton_class.class_eval do
            alias_method :original_build, :build
            define_method(:build) { |*args| parser }
        end
        begin

             # verify extract_text doesn't crash, we can stub it in the instance strictly if needed

             # or just write a file. process_file calls extract_text.

             # We can stub ImportInvoice#extract_text (private method) but let's just let it run

             # and if we assume the Factory ignores content it is fine.

             # Wait, Factory.build takes content. So we are good.

             block.call

        ensure
            LMNPCompta::InvoiceParser::Factory.singleton_class.class_eval do
                remove_method :build
                alias_method :build, :original_build
                remove_method :original_build
            end
        end

    end



    def test_invoice_under_threshold

        pdf_path = create_dummy_pdf("small.pdf")



        with_mocked_parser(500) do

            output, _ = capture_io do

                LMNPCompta::JournalCommand.new(["analyser-facture"] + [pdf_path]).execute

            end

            assert_match /-c 606400 -s D -m 500.00/, output

        end

    end



    def test_invoice_over_threshold_amortize_no

        pdf_path = create_dummy_pdf("large.pdf")



        with_mocked_parser(800) do

            # Simulate "n" to prompt

            $stdin.puts "n"

            $stdin.rewind



            output, _ = capture_io do

                LMNPCompta::JournalCommand.new(["analyser-facture"] + [pdf_path]).execute

            end



            # Should stay as charge

            assert_match /-c 606400 -s D -m 800.00/, output



            # Immo file should be empty (except header)

            assets = LMNPCompta::Asset.load(File.join(TEST_DIR, 'immobilisations.yaml'))

            assert_empty assets

        end

    end



    def test_invoice_over_threshold_amortize_yes

        pdf_path = create_dummy_pdf("large_asset.pdf")



        with_mocked_parser(1000) do

            # Simulate "y", duration "5", name "My Mac"

            $stdin.puts "y\n5\nMy Mac\n"

            $stdin.rewind



            output, _ = capture_io do

                LMNPCompta::JournalCommand.new(["analyser-facture"] + [pdf_path]).execute

            end



            # Check Check output command: Account should start with 2

            assert_match /-c 218400 -s D -m 1000.00/, output



            # Check Immo File

            assets = LMNPCompta::Asset.load(File.join(TEST_DIR, 'immobilisations.yaml'))

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

        pdf_path = create_dummy_pdf("yaml_inv.pdf")

        File.write(pdf_path + ".yaml", {

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



        LMNPCompta::InvoiceParser::Factory.singleton_class.class_eval do
            alias_method :original_build, :build
            define_method(:build) { |*args| nil }
        end
        begin

             output, _ = capture_io do

                LMNPCompta::JournalCommand.new(["analyser-facture"] + [pdf_path]).execute

            end



             # Check Immo File

            assets = LMNPCompta::Asset.load(File.join(TEST_DIR, 'immobilisations.yaml'))

            assert_equal 1, assets.length

            asset = assets.first

            assert_equal "Office Chair", asset.nom

            assert_equal 7, asset.composants.first.duree



            assert_match /-c 218400 -s D -m 900/, output

        ensure
            LMNPCompta::InvoiceParser::Factory.singleton_class.class_eval do
                remove_method :build
                alias_method :build, :original_build
                remove_method :original_build
            end
        end

    end


end
