require 'minitest/autorun'
require 'fileutils'
require 'yaml'

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'lmnp_compta/laundry'
require 'lmnp_compta/settings'

class LaundryTest < Minitest::Test
  TEST_DIR = File.join(__dir__, 'tmp', 'laundry')

  def setup
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(TEST_DIR)
    @original_dir = Dir.pwd
    Dir.chdir(TEST_DIR)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(TEST_DIR)
  end

  def test_cost_calculation
    l = LMNPCompta::Laundry.new(
      1,
      "Appart",
      0.05, # conso eau
      4.0,  # prix eau
      1.0,  # conso kwh
      0.25, # prix kwh
      0.5   # prix produit
    )
    # (0.05 * 4.0) + (1.0 * 0.25) + 0.5 = 0.2 + 0.25 + 0.5 = 0.95
    assert_in_delta 0.95, l.cost_per_wash, 0.001
  end

  def test_add_and_find
    LMNPCompta::Laundry.add(
      'my-id',
      "Appart Paris",
      0.05, 4.0, 1.0, 0.25, 0.5
    )

    l = LMNPCompta::Laundry.find('my-id')
    assert l
    assert_equal 'Appart Paris', l.nom_bien

    # Also find by name
    l2 = LMNPCompta::Laundry.find('Appart Paris')
    assert l2
    assert_equal 'my-id', l2.id
  end

  def test_duplicate_id
    LMNPCompta::Laundry.add('1', 'Appart 1', 0, 0, 0, 0, 0)
    assert_raises(RuntimeError) do
      LMNPCompta::Laundry.add('1', 'Appart 2', 0, 0, 0, 0, 0)
    end
  end
end
