require 'minitest/autorun'
require 'fileutils'
require 'lmnp_compta/commands/journal/analyser_facture'
require 'lmnp_compta/settings'

class ImportInvoiceFallbackTest < Minitest::Test
    TEST_DIR = File.join(__dir__, 'tmp', 'import_invoice')

    def setup
        @original_stdout = $stdout
        FileUtils.mkdir_p(TEST_DIR)
        LMNPCompta::Settings.instance.instance_variable_set(:@annee, 2025)
        @cmd = LMNPCompta::Commands::Journal::AnalyserFacture.new([])

        # Mock extract_text on Invoice class
        LMNPCompta::Invoice.class_eval do
            class << self
                unless method_defined?(:original_extract_text)
                    alias_method :original_extract_text, :extract_text
                    remove_method :extract_text
                    def extract_text(f); "DUMMY CONTENT"; end
                end
            end
        end

        # We also need to capture stdout to verify output
        @original_stdout = $stdout
        $stdout = StringIO.new
    end

    def teardown
        FileUtils.rm_rf(TEST_DIR)
        $stdout = @original_stdout if @original_stdout

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

    def test_fallback_creates_template
        file_path = File.join(TEST_DIR, 'unknown.pdf')
        FileUtils.touch(file_path)

        # Execute on the file
        @cmd.send(:process_file, file_path, {}, [])

        # Check if template created
        tpl_path = "#{file_path}.yaml.tpl"
        assert File.exist?(tpl_path), "Template should be created"

        content = YAML.load_file(tpl_path)
        assert_equal "Facture unknown.pdf", content['libelle']
    end

    def test_fallback_loads_yaml
        file_path = File.join(TEST_DIR, 'manual.pdf')
        FileUtils.touch(file_path)
        yaml_path = "#{file_path}.yaml"

        # Create the YAML file
        entry_data = {
            'date' => '01/01/2025',
            'journal' => 'AC',
            'libelle' => 'Manual Entry',
            'lignes' => [
                {'compte' => '606000', 'debit' => 100},
                {'compte' => '512000', 'credit' => 100}
            ]
        }
        File.write(yaml_path, entry_data.to_yaml)

        entries = []
        @cmd.send(:process_file, file_path, {}, entries)

        assert_equal 1, entries.length
        assert_equal 'Manual Entry', entries.first.libelle
        assert_equal 'manual.pdf', entries.first.source_file # Should default to basename
    end

    def test_fallback_loads_yaml_with_custom_file
        file_path = File.join(TEST_DIR, 'custom.pdf')
        FileUtils.touch(file_path)
        yaml_path = "#{file_path}.yaml"

        # Create the YAML file with explicit file source
        entry_data = {
            'date' => '01/01/2025',
            'journal' => 'AC',
            'libelle' => 'Custom File Entry',
            'file' => 'other_source.pdf',
            'lignes' => [{'compte' => '606000', 'debit' => 10}, {'compte' => '512000', 'credit' => 10}]
        }
        File.write(yaml_path, entry_data.to_yaml)

        entries = []
        @cmd.send(:process_file, file_path, {}, entries)

        assert_equal 1, entries.length
        assert_equal 'other_source.pdf', entries.first.source_file # Should use specified file
    end

    def test_fallback_validates_yaml
        file_path = File.join(TEST_DIR, 'invalid.pdf')
        FileUtils.touch(file_path)
        yaml_path = "#{file_path}.yaml"

        # Invalid data (missing journal)
        entry_data = {
            'date' => '01/01/2025',
            'libelle' => 'Invalid Entry',
            'lignes' => []
        }
        File.write(yaml_path, entry_data.to_yaml)

        entries = []
        err = assert_raises(RuntimeError) do
            @cmd.send(:process_file, file_path, {}, entries)
        end

        assert err.message.include?("Champs manquants: journal")
        assert err.message.include?("lignes")
    end
end
