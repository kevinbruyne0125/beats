$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/includes'

class AudioUtilsTest < Test::Unit::TestCase
  def test_composite
    # Mono empty arrays
    assert_equal([], AudioUtils.composite([]))
    assert_equal([], AudioUtils.composite([[]]))
    assert_equal([], AudioUtils.composite([[], [], [], []]))

    # Stereo empty arrays
    assert_equal([[]], AudioUtils.composite([[[]]]))
    assert_equal([[]], AudioUtils.composite([[[]], [[]], [[]], [[]]]))

    # Mono
    assert_equal([10, 20, 30, 40], AudioUtils.composite([[10, 20, 30, 40]]))
    assert_equal([10, 20, 30, 40], AudioUtils.composite([[10, 20, 30, 40], []]))
    assert_equal([30, 50, 70, -10], AudioUtils.composite([[10, 20, 30, 40], [20, 30, 40, -50]]))
    assert_equal([70, 80, 60], AudioUtils.composite([[20, 30], [10], [40, 50, 60]]))

    # Stereo
    assert_equal([[10, 20], [30, 40]], AudioUtils.composite([[[10, 20], [30, 40]]]))
    assert_equal([[10, 20], [30, 40]], AudioUtils.composite([[[10, 20], [30, 40]], [[]]]))
    assert_equal([[30, 50], [70, -10]], AudioUtils.composite([[[10, 20], [30, 40]], [[20, 30], [40, -50]]]))
    assert_equal([[90, 120], [120, 140], [100, 110]], AudioUtils.composite([[[20, 30], [40, 50]], [[10, 20]], [[60, 70], [80, 90], [100, 110]]]))
  end

  def test_num_channels
    assert_equal(1, AudioUtils.num_channels([1, 2, 3, 4]))
    assert_equal(2, AudioUtils.num_channels([[1, 2], [3, 4], [5, 6], [7, 8]]))
  end

  def test_normalize
    assert_equal([], AudioUtils.normalize([], 5))
    assert_equal([[]], AudioUtils.normalize([[]], 5))
    assert_equal([100, 200, 300, 400, 500], AudioUtils.normalize([100, 200, 300, 400, 500], 1))
    assert_equal([20, 40, 60, 80, 100], AudioUtils.normalize([100, 200, 300, 400, 500], 5))
  end

  def test_tick_sample_length
    assert_equal(6615.0, AudioUtils.tick_sample_length(44100, 100))
    assert_equal(3307.5, AudioUtils.tick_sample_length(44100, 200))
    assert_equal(3307.5, AudioUtils.tick_sample_length(22050, 100))
  end
end
