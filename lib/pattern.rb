class Pattern
  FLOW_TRACK_NAME = "flow"
  
  def initialize(name)
    @name = name
    @tracks = {}
  end
  
  # Adds a new track to the pattern.
  def track(name, wave_data, rhythm)
    track_key = unique_track_name(name)
    new_track = Track.new(track_key, wave_data, rhythm)        
    @tracks[track_key] = new_track

    # If the new track is longer than any of the previously added tracks,
    # pad the other tracks with trailing . to make them all the same length.
    # Necessary to prevent incorrect overflow calculations for tracks.
    longest_track_length = tick_count()
    @tracks.values.each do |track|
      if track.rhythm.length < longest_track_length
        track.rhythm += "." * (longest_track_length - track.rhythm.length)
      end
    end
    
    return new_track
  end
  
  # The number of samples required for the pattern at the given tempo. DOES NOT include samples
  # necessary for sound that overflows past the last tick of the pattern.
  def sample_length(tick_sample_length)
    @tracks.keys.collect {|track_name| @tracks[track_name].sample_length(tick_sample_length) }.max || 0
  end
  
  # The number of samples required for the pattern at the given tempo. Include sound overflow
  # past the last tick of the pattern.
  def sample_length_with_overflow(tick_sample_length)
    @tracks.keys.collect {|track_name| @tracks[track_name].sample_length_with_overflow(tick_sample_length) }.max || 0
  end
  
  def tick_count
    return @tracks.values.collect {|track| track.rhythm.length }.max || 0
  end
  
  # Returns whether or not this pattern has the same number of tracks as other_pattern, and that
  # each of the tracks has the same name and rhythm. Ordering of tracks does not matter; will
  # return true if the two patterns have the same tracks but in a different ordering.
  def same_tracks_as?(other_pattern)
    @tracks.keys.each do |track_name|
      other_pattern_track = other_pattern.tracks[track_name]
      if other_pattern_track == nil || @tracks[track_name].rhythm != other_pattern_track.rhythm
        return false
      end
    end
    
    return @tracks.length == other_pattern.tracks.length
  end
  
  # Returns a YAML representation of the Pattern. Produces nicer looking output than the default
  # version of to_yaml().
  def to_yaml
    longest_track_name_length =
      @tracks.keys.inject(0) do |max_length, name|
        (name.to_s.length > max_length) ? name.to_s.length : max_length
      end
    ljust_amount = longest_track_name_length + 7
    
    yaml = "#{@name.to_s.capitalize}:\n"
    @tracks.keys.sort.each do |track_name|
      yaml += "  - #{track_name}:".ljust(ljust_amount)
      yaml += "#{@tracks[track_name].rhythm}\n"
    end
    
    return yaml
  end
  
  attr_accessor :tracks, :name
  
private

  # Returns a unique track name that is not already in use by a track in
  # this pattern. Used to help support having multiple tracks with the same
  # sample in a track.
  def unique_track_name(name)
    i = 2
    name_key = name
    while @tracks.has_key? name_key
      name_key = "#{name}#{i.to_s}"
      i += 1
    end
    
    return name_key
  end
end
