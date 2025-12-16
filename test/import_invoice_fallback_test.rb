require 'minitest/autorun'
require 'fileutils'
require 'lmnp_compta/commands/import_invoice'
require 'lmnp_compta/settings'

class ImportInvoiceFallbackTest < Minitest::Test
    TEST_DIR = 'tmp_test_import_invoice'

    def setup
        @original_stdout = $stdout
        FileUtils.mkdir_p(TEST_DIR)
        LMNPCompta::Settings.instance.instance_variable_set(:@annee, 2025)
        # Mock extract_text to return empty string (so no parser matches)
        @cmd = LMNPCompta::Commands::ImportInvoice.new([])

        # We need to stub extract_text. Minitest stubbing is usually on the object.
        # Since extract_text is private instance method, we can define it on the instance or use define_method.
        def @cmd.extract_text(file_path)
            "DUMMY CONTENT"
        end

        # We also need to capture stdout to verify output
        @original_stdout = $stdout
        $stdout = StringIO.new
    end

    def teardown
        FileUtils.rm_rf(TEST_DIR)
        $stdout = @original_stdout if @original_stdout
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
                {'compte' => '401000', 'credit' => 100}
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
            'lignes' => [{'compte' => '606000', 'debit' => 10}, {'compte' => '401', 'credit' => 10}]
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
        @cmd.send(:process_file, file_path, {}, entries)

        assert_equal 1, entries.length
        assert entries.first.error.include?("Champs manquants: journal")
        assert entries.first.error.include?("lignes")
    end
end
