require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'date'

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'lmnp_compta'
require 'lmnp_compta/command'
require 'lmnp_compta/settings'

# Load all commands
Dir.glob(File.join(__dir__, '../lib/lmnp_compta/commands/*.rb')).each do |file|
    require file
end

class MileageIntegrationTest < Minitest::Test
    TEST_DIR = File.join(__dir__, 'tmp', 'mileage')

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)
        @original_dir = Dir.pwd
        Dir.chdir(TEST_DIR)

        # Init Project
        args_init = ["init", "--siren", "123456789", "--annee", "2025"]
        LMNPCompta::ConfigurerCommand.new(args_init).execute
        LMNPCompta::Settings.load('lmnp.yaml')
    end

    def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_mileage_workflow
        # 1. Add Vehicle (4 CV)
        puts "\n--- Test: Add Vehicle ---"
        LMNPCompta::ConfigurerCommand.new(['vehicules', 'ajouter', 'MyPrius', '4']).execute

        vehicles_file = File.join('data', 'vehicles.yaml')
        assert File.exist?(vehicles_file)
        vehicles = YAML.load_file(vehicles_file)
        assert_equal 1, vehicles.length
        assert_equal 'MyPrius', vehicles[0]['name']
        assert_equal 4, vehicles[0]['fiscal_power']

        # 2. Add Trips (Total 6000 km)
        puts "\n--- Test: Add Trips ---"
        # Trip 1: 3000 km
        LMNPCompta::JournalCommand.new(['trajets', 'ajouter', '2025-02-15', 'MyPrius', '3000', 'Visit 1']).execute
        # Trip 2: 3000 km
        LMNPCompta::JournalCommand.new(['trajets', 'ajouter', '2025-06-20', 'MyPrius', '3000', 'Visit 2']).execute

        trips_file = File.join('data', '2025', 'trips.yaml')
        assert File.exist?(trips_file)
        trips = YAML.load_file(trips_file)
        assert_equal 2, trips.length

        # 3. Close Year
        puts "\n--- Test: Close Year (Generate Mileage Entry) ---"
        LMNPCompta::BilanCommand.new(['cloturer']).execute

        # 4. Verify Journal Entry
        journal_file = File.join('data', '2025', 'journal.yaml')
        assert File.exist?(journal_file)
        journal_entries = YAML.load_file(journal_file)

        # Find the Mileage Entry
        # Ref should be IK2025-MyPrius
        ik_entry = journal_entries.find { |e| e['ref'] == 'IK2025-MyPrius' }
        assert ik_entry, "Mileage entry not found in journal"

        # Check amount
        # 4 CV, 6000 km -> (6000 * 0.340) + 1330 = 2040 + 1330 = 3370.00

        l_debit = ik_entry['lignes'].find { |l| l['compte'] == '625100' } # Voyages et dep
        l_credit = ik_entry['lignes'].find { |l| l['compte'] == '108000' } # Exploitant

        assert l_debit, "Debit line 625100 missing"
        assert l_credit, "Credit line 108000 missing"

        assert_equal "3370,00", l_debit['debit']
        assert_equal "3370,00", l_credit['credit']
    end
end
