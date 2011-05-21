$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'includes'

class PatternExpanderTest < Test::Unit::TestCase  
  def test_expand_pattern_no_repeats
    expected_pattern = Pattern.new :verse
    expected_pattern.track "bass",  "X...X.X."
    expected_pattern.track "snare", "....X..."
        
    # All of these should result in no expansion, since there are no repeats.
    # In other words, the pattern shouldn't change.
    # TODO: Add test for when flow is longer than longest track in pattern
    ["", "|----|----|", "|----", "----:-:1"].each do |flow|
      actual_pattern = Pattern.new :verse
      actual_pattern.track "bass",  "|X...|X.X.|"
      actual_pattern.track "snare", "|....|X...|"
      actual_pattern = PatternExpander.expand_pattern(flow, actual_pattern)
      assert(expected_pattern.same_tracks_as?(actual_pattern))
    end
  end
  
  def test_expand_pattern_single_repeats
    expected_pattern = Pattern.new :verse
    expected_pattern.track "bass",  "X...X.X.X...X.X."
    expected_pattern.track "snare", "....X.......X..."
    
    ["|----|---:|", "|----|---:2|", ":------:"].each do |flow|
      actual_pattern = Pattern.new :verse
      actual_pattern.track "bass",  "|X...|X.X.|"
      actual_pattern.track "snare", "|....|X...|"
      actual_pattern = PatternExpander.expand_pattern(flow, actual_pattern)
      assert(expected_pattern.same_tracks_as?(actual_pattern))
    end
    
    
    expected_pattern = Pattern.new :verse
    expected_pattern.track "bass",  "X...X.X.X.X.X.X.X.X...X."
    expected_pattern.track "snare", "....X...X...X...X...XXXX"
    
    ["|----|:-:4|----|"].each do |flow|
      actual_pattern = Pattern.new :verse
      actual_pattern.track "bass",  "|X...|X.X.|..X.|"
      actual_pattern.track "snare", "|....|X...|XXXX|"
      actual_pattern = PatternExpander.expand_pattern(flow, actual_pattern)  
      assert(expected_pattern.same_tracks_as?(actual_pattern))
    end
    
    
    # Zero repeats, so section gets removed from pattern
    expected_pattern = Pattern.new :verse
    expected_pattern.track "bass",  "X.....X."
    expected_pattern.track "snare", "....XXXX"
    
    ["|----|:-:0|----|"].each do |flow|
      actual_pattern = Pattern.new :verse
      actual_pattern.track "bass",  "|X...|X.X.|..X.|"
      actual_pattern.track "snare", "|....|X...|XXXX|"
      actual_pattern = PatternExpander.expand_pattern(flow, actual_pattern)  
      assert(expected_pattern.same_tracks_as?(actual_pattern))
    end
  end
  
  def test_expand_pattern_multiple_repeats
    expected_pattern = Pattern.new :verse
    expected_pattern.track "bass",  "X...X...X.X.X.X."
    expected_pattern.track "snare", "........X...X..."
    
    [":--::--:", ":-:2:--:", ":-:2:-:2"].each do |flow|
      actual_pattern = Pattern.new :verse
      actual_pattern.track "bass",  "|X...|X.X.|"
      actual_pattern.track "snare", "|....|X...|"
      actual_pattern = PatternExpander.expand_pattern(flow, actual_pattern)
      assert(expected_pattern.same_tracks_as?(actual_pattern))
    end
    
    
    expected_pattern = Pattern.new :verse
    expected_pattern.track "bass",  "X...X.X.X.X.X.X..XXX..XX.."
    expected_pattern.track "snare", "....X...X...X...X...XX..XX"
    
    ["----:-:3--:--:", "|----|:-:3|--|:-:2|"].each do |flow|
      actual_pattern = Pattern.new :verse
      actual_pattern.track "bass",  "|X...|X.X.|.X|XX..|"
      actual_pattern.track "snare", "|....|X...|X.|..XX|"
      actual_pattern = PatternExpander.expand_pattern(flow, actual_pattern)
      assert(expected_pattern.same_tracks_as?(actual_pattern))
    end
  end
  
  def test_expand_pattern_invalid
    pattern = Pattern.new :verse
    pattern.track "bass",  "|X...|X.X.|"
    pattern.track "snare", "|....|X...|"
    
    # Patterns with an invalid character
    ["a", "|---!---|", "|....|....|"].each do |invalid_flow|
      assert_raise(InvalidFlowError) do
        PatternExpander.expand_pattern(invalid_flow, pattern)
      end
    end
    
    ["----4:--", ":-:-:4-:", ":4-:-:-:"].each do |invalid_flow|
      assert_raise(InvalidFlowError) do
        PatternExpander.expand_pattern(invalid_flow, pattern)
      end
    end
  end
  
  def test_valid_flow?
    # Contains nothing but :, always valid
    assert_equal(true, PatternExpander.valid_flow?(""))
    assert_equal(true, PatternExpander.valid_flow?(":"))
    assert_equal(true, PatternExpander.valid_flow?("::"))
    assert_equal(true, PatternExpander.valid_flow?(":::"))
    assert_equal(true, PatternExpander.valid_flow?("::::"))
    assert_equal(true, PatternExpander.valid_flow?("|:--:|----|:--:|"))
    
    # Contains characters other than :|- and [0-9]
    assert_equal(false, PatternExpander.valid_flow?("a"))
    assert_equal(false, PatternExpander.valid_flow?("1"))
    assert_equal(false, PatternExpander.valid_flow?(":--:z---"))
    assert_equal(false, PatternExpander.valid_flow?(":   :"))
    
    assert_equal(true, PatternExpander.valid_flow?(":0"))
    assert_equal(true, PatternExpander.valid_flow?(":1"))
    assert_equal(true, PatternExpander.valid_flow?(":4"))
    assert_equal(true, PatternExpander.valid_flow?(":4"))
    assert_equal(true, PatternExpander.valid_flow?(":16"))
    assert_equal(true, PatternExpander.valid_flow?("::4"))
    assert_equal(true, PatternExpander.valid_flow?(":::4"))
    assert_equal(true, PatternExpander.valid_flow?(":2::4"))
    assert_equal(true, PatternExpander.valid_flow?("::2::4"))
    
    assert_equal(false, PatternExpander.valid_flow?(":4:"))
    assert_equal(false, PatternExpander.valid_flow?("::4:"))
    assert_equal(false, PatternExpander.valid_flow?(":4:4"))
    assert_equal(false, PatternExpander.valid_flow?("::2:4"))
    assert_equal(false, PatternExpander.valid_flow?("::2:"))
    assert_equal(false, PatternExpander.valid_flow?("::2:::"))
  end
end
