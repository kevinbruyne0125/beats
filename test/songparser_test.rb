require 'includes'

class SongParserTest < Minitest::Test
  FIXTURE_BASE_PATH = File.dirname(__FILE__) + "/.."

  INVALID_FIXTURES = [:bad_repeat_count,
                      :bad_flow,
                      :bad_tempo,
                      :bad_swing_rate_1,
                      :bad_swing_rate_2,
                      :no_header,
                      :no_flow,
                      :with_structure,
                      :pattern_with_no_tracks,
                      :leading_bar_line,
                      :sound_in_kit_not_found,
                      :sound_in_track_not_found,
                      :sound_in_kit_wrong_format,
                      :sound_in_track_wrong_format]

  # TODO: Add somes tests to validate the Kits

  def test_no_tempo
    song, kit = load_fixture("valid/no_tempo.txt")

    assert_equal(120, song.tempo)
    assert_equal([:verse], song.flow)
  end

  def test_fractional_tempo
    song, kit = load_fixture("valid/fractional_tempo.txt")

    assert_equal(95.764, song.tempo)
    assert_equal([:verse, :verse, :chorus, :chorus], song.flow)
  end

  def test_repeats_not_specified
    song, kit = load_fixture("valid/repeats_not_specified.txt")

    assert_equal(100, song.tempo)
    assert_equal([:verse], song.flow)
  end

  def test_song_with_unused_kit
    no_kit_song, no_kit_kit = load_fixture("valid/example_no_kit.txt")
    kit_song, kit_kit = load_fixture("valid/example_with_kit.txt")

    # These two songs should be the same, except that one uses a kit in the song header
    # and the other doesn't.
    [no_kit_song, kit_song].each do |song|
      assert_equal([:verse, :verse,
                    :chorus, :chorus,
                    :verse, :verse,
                    :chorus, :chorus, :chorus, :chorus,
                    :bridge,
                    :chorus, :chorus, :chorus, :chorus],
                   song.flow)
      assert_equal(99, song.tempo)
      assert_equal(["bridge", "chorus", "verse"], song.patterns.keys.map{|key| key.to_s}.sort)
      assert_equal(4, song.patterns[:verse].tracks.length)
      assert_equal(5, song.patterns[:chorus].tracks.length)
      assert_equal(1, song.patterns[:bridge].tracks.length)
    end
  end

  def test_empty_track
    song, kit = load_fixture("valid/example_with_empty_track.txt")

    assert_equal(1, song.patterns.length)
    assert_equal(2, song.patterns[:verse].tracks.length)
    assert_equal("........", song.patterns[:verse].tracks["test/sounds/bass_mono_8.wav"].rhythm)
    assert_equal("X...X...", song.patterns[:verse].tracks["test/sounds/snare_mono_8.wav"].rhythm)
  end

  def test_track_with_spaces
    song, kit = load_fixture("valid/track_with_spaces.txt")

    assert_equal(1, song.patterns.length)
    assert_equal(2, song.patterns[:verse].tracks.length)
    assert_equal("X...X...X...X...", song.patterns[:verse].tracks["bass"].rhythm)
    assert_equal("....X.......X...", song.patterns[:verse].tracks["snare"].rhythm)
  end

  def test_multiple_tracks_same_sound
    song, kit = load_fixture("valid/multiple_tracks_same_sound.txt")

    assert_equal(2, song.patterns.length)
    assert_equal(7, song.patterns[:verse].tracks.length)
    assert_equal(["agogo", "bass", "bass2", "bass3", "bass4", "hh_closed", "snare"],
                 song.patterns[:verse].tracks.keys.sort)
    assert_equal("X...............", song.patterns[:verse].tracks["bass"].rhythm)
    assert_equal("....X...........", song.patterns[:verse].tracks["bass2"].rhythm)
    assert_equal("........X.......", song.patterns[:verse].tracks["bass3"].rhythm)
    assert_equal("............X...", song.patterns[:verse].tracks["bass4"].rhythm)
    assert_equal("..............X.", song.patterns[:verse].tracks["snare"].rhythm)
    assert_equal("X.XXX.XXX.X.X.X.", song.patterns[:verse].tracks["hh_closed"].rhythm)
    assert_equal("..............XX", song.patterns[:verse].tracks["agogo"].rhythm)
    assert_equal(["bass", "bass2", "hh_closed", "snare", "test/sounds/tom2_mono_16.wav", "test/sounds/tom4_mono_16.wav"],
                 song.patterns[:chorus].tracks.keys.sort)
    assert_equal("X...X...XX..X...", song.patterns[:chorus].tracks["bass"].rhythm)
    assert_equal("....X.......X...", song.patterns[:chorus].tracks["snare"].rhythm)
    assert_equal("X.XXX.XXX.XX..X.", song.patterns[:chorus].tracks["hh_closed"].rhythm)
    assert_equal("..X..X..X..X..X.", song.patterns[:chorus].tracks["bass2"].rhythm)
    assert_equal("...........X....", song.patterns[:chorus].tracks["test/sounds/tom4_mono_16.wav"].rhythm)
    assert_equal("..............X.", song.patterns[:chorus].tracks["test/sounds/tom2_mono_16.wav"].rhythm)
  end

  def test_swung_8
    song, kit = load_fixture("valid/example_swung_8th.txt")

    assert_equal(180, song.tempo)
    assert_equal([:verse, :verse, :chorus, :chorus], song.flow)
    assert_equal(2, song.patterns.length)
    assert_equal(2, song.patterns[:verse].tracks.length)
    assert_equal("X.....X.....", song.patterns[:verse].tracks["bass"].rhythm)
    assert_equal("....X.....X.", song.patterns[:verse].tracks["snare"].rhythm)
    assert_equal(2, song.patterns[:chorus].tracks.length)
    assert_equal("X.X.XXX.X.XX", song.patterns[:chorus].tracks["bass"].rhythm)
    assert_equal("..X..X..X..X", song.patterns[:chorus].tracks["snare"].rhythm)
  end

  def test_swung_16
    song, kit = load_fixture("valid/example_swung_16th.txt")

    assert_equal(180, song.tempo)
    assert_equal([:verse, :verse, :chorus, :chorus], song.flow)
    assert_equal(2, song.patterns.length)
    assert_equal(2, song.patterns[:verse].tracks.length)
    assert_equal("X.....X.....", song.patterns[:verse].tracks["bass"].rhythm)
    assert_equal("...X.....X..", song.patterns[:verse].tracks["snare"].rhythm)
    assert_equal(2, song.patterns[:chorus].tracks.length)
    assert_equal("X.XX.XX.XX.X", song.patterns[:chorus].tracks["bass"].rhythm)
    assert_equal("..X..X..X..X", song.patterns[:chorus].tracks["snare"].rhythm)
  end

  def test_unswung_song
    song, kit = load_fixture("valid/example_unswung.txt")

    assert_equal(120, song.tempo)
    assert_equal([:verse, :verse, :chorus, :chorus], song.flow)
    assert_equal(2, song.patterns.length)
    assert_equal(2, song.patterns[:verse].tracks.length)
    assert_equal("X...X...", song.patterns[:verse].tracks["bass"].rhythm)
    assert_equal("..X...X.", song.patterns[:verse].tracks["snare"].rhythm)
    assert_equal(2, song.patterns[:chorus].tracks.length)
    assert_equal("XXXXXXXX", song.patterns[:chorus].tracks["bass"].rhythm)
    assert_equal(".X.X.X.X", song.patterns[:chorus].tracks["snare"].rhythm)
  end

  def test_track_with_composite_sounds
    song, kit = load_fixture("valid/track_with_composite_sounds.txt")

    assert_equal(100, song.tempo)
    assert_equal([:verse, :verse, :chorus, :chorus], song.flow)
    assert_equal(2, song.patterns.length)
    assert_equal(3, song.patterns[:verse].tracks.length)
    assert_equal("X...X...", song.patterns[:verse].tracks["bass"].rhythm)
    assert_equal("X...X...", song.patterns[:verse].tracks["hh_closed"].rhythm)
    assert_equal("..X...X.", song.patterns[:verse].tracks["snare"].rhythm)
    assert_equal(3, song.patterns[:chorus].tracks.length)
    assert_equal("XXXXXXXX", song.patterns[:chorus].tracks["bass"].rhythm)
    assert_equal(".X.X.X.X", song.patterns[:chorus].tracks["snare"].rhythm)
    assert_equal(".X.X.X.X", song.patterns[:chorus].tracks["bass2"].rhythm)
  end

  def test_invalid_parse
    INVALID_FIXTURES.each do |fixture|
      assert_raises(SongParser::ParseError) do
        song = load_fixture("invalid/#{fixture}.txt")
      end
    end

    assert_raises(Track::InvalidRhythmError) do
      song = load_fixture("invalid/bad_rhythm.txt")
    end
  end

private

  def load_fixture(fixture_name)
    SongParser.new.parse(FIXTURE_BASE_PATH, File.read("test/fixtures/#{fixture_name}"))
  end
end
