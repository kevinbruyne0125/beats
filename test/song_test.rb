$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/includes'

class SongTest < Test::Unit::TestCase
  DEFAULT_TEMPO = 120
  
  def generate_test_data
    kit = Kit.new("test/sounds")
    kit.add("bass.wav",      "bass_mono_8.wav")
    kit.add("snare.wav",     "snare_mono_8.wav")
    kit.add("hh_closed.wav", "hh_closed_mono_8.wav")
    kit.add("ride.wav",      "ride_mono_8.wav")
    
    test_songs = SongParserTest.generate_test_data()
    
    test_songs[:blank] = Song.new("test/sounds")
    
    test_songs[:no_structure] = Song.new("test/sounds")
    verse = test_songs[:no_structure].pattern :verse
    verse.track "bass.wav",      kit.get_sample_data("bass.wav"),      "X.......X......."
    verse.track "snare.wav",     kit.get_sample_data("snare.wav"),     "....X.......X..."
    verse.track "hh_closed.wav", kit.get_sample_data("hh_closed.wav"), "X.X.X.X.X.X.X.X."
    
    overflow_yaml = "
Song:
  Tempo: 100
  Structure:
    - Verse: x2

Verse:
  - test/sounds/snare_mono_8.wav: ...X"
    test_songs[:overflow] = SongParser.new().parse(File.dirname(__FILE__) + "/..", overflow_yaml)
    
    test_songs[:from_code] = Song.new("test/sounds")
    verse = test_songs[:from_code].pattern :verse
    verse.track "bass.wav",      kit.get_sample_data("bass.wav"),      "X.......X......."
    verse.track "snare.wav",     kit.get_sample_data("snare.wav"),     "....X.......X..."
    verse.track "hh_closed.wav", kit.get_sample_data("hh_closed.wav"), "X.X.X.X.X.X.X.X."
    chorus = test_songs[:from_code].pattern :chorus
    chorus.track "bass.wav",  kit.get_sample_data("bass.wav"),  "X......."
    chorus.track "snare.wav", kit.get_sample_data("snare.wav"), "....X..X"
    chorus.track "ride.wav",  kit.get_sample_data("ride.wav"),  "X.....X."
    test_songs[:from_code].structure = [:verse, :chorus, :verse, :chorus, :chorus]
    test_songs[:from_code].kit = kit
    
    return test_songs
  end
    
  def test_initialize
    test_songs = generate_test_data()
    
    assert_equal(test_songs[:blank].structure, [])
    assert_equal(test_songs[:blank].tick_sample_length, (Song::SAMPLE_RATE * Song::SECONDS_PER_MINUTE) / DEFAULT_TEMPO / 4.0)
    
    assert_equal(test_songs[:no_structure].structure, [])
    assert_equal(test_songs[:no_structure].tick_sample_length, (Song::SAMPLE_RATE * Song::SECONDS_PER_MINUTE) / DEFAULT_TEMPO / 4.0)
    
    assert_equal(test_songs[:from_code].structure, [:verse, :chorus, :verse, :chorus, :chorus])
    assert_equal(test_songs[:from_code].tick_sample_length, (Song::SAMPLE_RATE * Song::SECONDS_PER_MINUTE) / DEFAULT_TEMPO / 4.0)
  end
  
  def test_total_tracks
    test_songs = generate_test_data()
    
    assert_equal(test_songs[:blank].total_tracks, 0)
    assert_equal(test_songs[:no_structure].total_tracks, 3)
    assert_equal(test_songs[:from_code].total_tracks, 3)
    assert_equal(test_songs[:repeats_not_specified].total_tracks, 1)
    assert_equal(test_songs[:overflow].total_tracks, 1)
    assert_equal(test_songs[:from_valid_yaml_string].total_tracks, 5)
  end
  
  def test_sample_length
    test_songs = generate_test_data()

    assert_equal(test_songs[:blank].sample_length, 0)
    assert_equal(test_songs[:no_structure].sample_length, 0)
    
    assert_equal(test_songs[:from_code].sample_length,
                            (test_songs[:from_code].tick_sample_length * 16 * 2) +
                            (test_songs[:from_code].tick_sample_length * 8 * 3))
                            
    assert_equal(test_songs[:repeats_not_specified].sample_length,
                            test_songs[:repeats_not_specified].tick_sample_length)
                            
    assert_equal(test_songs[:overflow].sample_length, test_songs[:overflow].tick_sample_length * 8)
  end
  
  def test_sample_length_with_overflow
    test_songs = generate_test_data()
    
    assert_equal(test_songs[:blank].sample_length_with_overflow, 0)
    assert_equal(test_songs[:no_structure].sample_length_with_overflow, 0)
    
    snare_overflow =
      (test_songs[:from_code].kit.get_sample_data("snare.wav").length -
       test_songs[:from_code].tick_sample_length).ceil   
    assert_equal(test_songs[:from_code].sample_length_with_overflow, test_songs[:from_code].sample_length + snare_overflow)    
    
    assert_equal(test_songs[:repeats_not_specified].sample_length_with_overflow,
                 test_songs[:repeats_not_specified].tick_sample_length)
    
    snare_overflow =
      (test_songs[:overflow].kit.get_sample_data("test/sounds/snare_mono_8.wav").length -
       test_songs[:overflow].tick_sample_length).ceil
    assert_equal(test_songs[:overflow].sample_length_with_overflow,
                 (test_songs[:overflow].tick_sample_length * 8) + snare_overflow)
    
    snare_overflow =
      (test_songs[:from_valid_yaml_string].kit.get_sample_data("test/sounds/snare_mono_8.wav").length -
       test_songs[:from_valid_yaml_string].tick_sample_length).ceil
    assert_equal(test_songs[:from_valid_yaml_string].sample_length_with_overflow, test_songs[:from_valid_yaml_string].sample_length + snare_overflow)
  end
  
  def test_sample_data
    test_songs = generate_test_data()
    
    test_songs.values.each {|song|
      sample_data = song.sample_data("", false)
      assert_equal(sample_data.class, Array)
      assert_equal(sample_data.length, song.sample_length_with_overflow)
      sample_data = song.sample_data("", true)
      assert_equal(sample_data.class, Hash)
    }
    
    [:from_code, :repeats_not_specified, :overflow, :from_valid_yaml_string].each {|key|
      assert_equal(test_songs[key].sample_data("verse", false).class, Array)
      assert_equal(test_songs[key].sample_data("verse", true).class, Hash)
    }
    
    snare_sample_data = test_songs[:overflow].kit.get_sample_data("test/sounds/snare_mono_8.wav")
    expected = [].fill(0, 0, test_songs[:overflow].tick_sample_length * 4)
    expected[0...(snare_sample_data.length)] = snare_sample_data
    expected += snare_sample_data
    expected = [].fill(0, 0, test_songs[:overflow].tick_sample_length * 3) + expected
    assert_equal(test_songs[:overflow].sample_data("", false)[0], expected[0])
  end
end