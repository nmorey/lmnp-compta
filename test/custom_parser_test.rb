require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'lmnp_compta/invoice_parser'
require 'lmnp_compta/settings'

class CustomParserTest < Minitest::Test
    TEST_DIR = 'tmp_test_parser'
    CUSTOM_PARSER_DIR = 'custom_parsers'

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(File.join(TEST_DIR, CUSTOM_PARSER_DIR))
        @original_dir = Dir.pwd
        Dir.chdir(TEST_DIR)

        # Create a custom parser file
        File.write(File.join(CUSTOM_PARSER_DIR, 'my_parser.rb'), <<~RUBY)
      module LMNPCompta
        module InvoiceParser
          class MyParser < Base
            def self.parser_name; :my_parser; end
            def self.match?(content)
              content.match?(/MY_CUSTOM_TOKEN/)
            end

            def extract_ref
              "CUSTOM-123"
            end

            def extract_date
              Date.new(2025, 12, 25)
            end

            def extract_amount
              "42.00"
            end

            def extract_label
              "Custom Invoice"
            end
          end
        end
      end
    RUBY

        # Configure Settings
        config = {
            'extra_invoice_dir' => File.expand_path(CUSTOM_PARSER_DIR)
        }
        File.write('lmnp.yaml', config.to_yaml)
        LMNPCompta::Settings.load('lmnp.yaml')
    end

    def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_loads_and_uses_custom_parser
        # Ensure custom parser is loaded
        LMNPCompta.load_external_parsers

        content = "Some text containing MY_CUSTOM_TOKEN here."

        parser = LMNPCompta::InvoiceParser::Factory.build(nil, content)

        refute_nil parser, "Factory should find the custom parser"
        assert_equal :my_parser, parser.class.parser_name

        data = parser.parse.first
        assert_equal "CUSTOM-123", data[:ref]
        assert_equal "42.00", data[:montant].to_s
    end
end
