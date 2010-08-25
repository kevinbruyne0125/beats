class SongParseError < RuntimeError; end

class SongParser
  NO_SONG_HEADER_ERROR_MSG =
"Song must have a header. Here's an example:

  Song:
    Tempo: 120
    Structure:
      - Verse: x2
      - Chorus: x2"
  
  def initialize
  end
  
  def parse(base_path, definition = nil)
    raw_song_definition = canonicalize_definition(definition)
    raw_song_components = split_raw_yaml_into_components(raw_song_definition)
    
    song = Song.new(base_path)
    
    # 1.) Set tempo
    begin
      if raw_song_components[:tempo] != nil
        song.tempo = raw_song_components[:tempo]
      end
    rescue InvalidTempoError => detail
      raise SongParseError, "#{detail}"
    end
    
    # 2.) Build the kit
    begin
      kit = build_kit(base_path, raw_song_components[:kit], raw_song_components[:patterns])
    rescue SoundNotFoundError => detail
      raise SongParseError, "#{detail}"
    end
    song.kit = kit
    
    # 3.) Load patterns
    add_patterns_to_song(song, raw_song_components[:patterns])
    
    # 4.) Set structure
    if raw_song_components[:structure] == nil
      raise SongParseError, "Song must have a Structure section in the header."
    else
      set_song_structure(song, raw_song_components[:structure])
    end
    
    return song
  end
  
private

  # Is "canonicalize" a word?
  def canonicalize_definition(definition)
    if definition.class == String
      begin
        raw_song_definition = YAML.load(definition)
      rescue ArgumentError => detail
        raise SongParseError, "Syntax error in YAML file"
      end
    elsif definition.class == Hash
      raw_song_definition = definition
    else
      raise SongParseError, "Invalid song input"
    end
    
    return raw_song_definition
  end

  def split_raw_yaml_into_components(raw_song_definition)
    raw_song_components = {}
    raw_song_components[:full_definition] = downcase_hash_keys(raw_song_definition)
    
    if raw_song_components[:full_definition]["song"] != nil
      raw_song_components[:header] = downcase_hash_keys(raw_song_components[:full_definition]["song"])
    else
      raise SongParseError, NO_SONG_HEADER_ERROR_MSG
    end
    raw_song_components[:tempo]     = raw_song_components[:header]["tempo"]
    raw_song_components[:kit]       = raw_song_components[:header]["kit"]
    raw_song_components[:structure] = raw_song_components[:header]["structure"]
    raw_song_components[:patterns]  = raw_song_components[:full_definition].reject {|k, v| k == "song"}
  
    return raw_song_components
  end
      
  def build_kit(base_path, raw_kit, raw_patterns)
    kit_items = {}
    
    # Add sounds defined in the Kit section of the song header
    # TODO: Raise error is same name is defined more than once in the Kit
    unless raw_kit == nil
      raw_kit.each do |kit_item|
        kit_items[kit_item.keys.first] = kit_item.values.first
      end
    end
    
    # Add sounds not defined in Kit section, but used in individual tracks
    # TODO Investigate detecting duplicate keys already defined in the Kit section, as this could possibly
    # result in a performance improvement when the sound has to be converted to a different bit rate/num channels,
    # as well as use less memory.
    raw_patterns.keys.each do |key|
      track_list = raw_patterns[key]
      
      unless track_list == nil
        track_list.each do |track_definition|
          track_name = track_definition.keys.first
          track_path = track_name
        
          if track_name.end_with? ".wav"
            kit_items[track_name] = track_path
          end
        end
      end
    end
    
    kit = Kit.new(base_path, kit_items)
    return kit
  end
  
  def add_patterns_to_song(song, raw_patterns)
    raw_patterns.keys.each do |key|
      new_pattern = song.pattern key.to_sym
      flow = ""

      track_list = raw_patterns[key]
      # TODO Also raise error if only there is only 1 track and it's a flow track
      if track_list == nil
        # TODO: Use correct capitalization of pattern name in error message
        # TODO: Possibly allow if pattern not referenced in the Structure, or has 0 repeats?
        raise SongParseError, "Pattern '#{key}' has no tracks. It needs at least one."
      end
      
      # TODO: What if there is more than one flow? Raise error, or have last one win?
      track_list.each do |track_definition|
        track_name = track_definition.keys.first
        
        if track_name == "flow"
          flow = track_definition[track_name]
        else  
          # Handle case where no track rhythm is specified (i.e. "- foo.wav:" instead of "- foo.wav: X.X.X.X.")
          track_definition[track_name] ||= ""

          new_pattern.track track_name, song.kit.get_sample_data(track_name), track_definition[track_name]
        end
      end
      
      new_pattern = PatternExpander.expand_pattern(flow, new_pattern)
    end
  end
  
  def set_song_structure(song, raw_structure)
    structure = []

    raw_structure.each{|pattern_item|
      if pattern_item.class == String
        pattern_item = {pattern_item => "x1"}
      end
      
      pattern_name = pattern_item.keys.first
      pattern_name_sym = pattern_name.downcase.to_sym
      
      # Convert the number of repeats from a String such as "x4" into an integer such as 4.
      multiples_str = pattern_item[pattern_name]
      multiples_str.slice!(0)
      multiples = multiples_str.to_i
      
      unless multiples_str.match(/[^0-9]/) == nil
        raise SongParseError, "'#{multiples_str}' is an invalid number of repeats for pattern '#{pattern_name}'. Number of repeats should be a whole number."
      else
        if multiples < 0
          raise SongParseError, "'#{multiples_str}' is an invalid number of repeats for pattern '#{pattern_name}'. Must be 0 or greater."
        elsif multiples > 0 && !song.patterns.has_key?(pattern_name_sym)
          # This test is purposefully designed to only throw an error if the number of repeats is greater
          # than 0. This allows you to specify an undefined pattern in the structure with "x0" repeats.
          # This can be convenient for defining the structure before all patterns have been added to the song file.
          raise SongParseError, "Song structure includes non-existent pattern: #{pattern_name}."
        end
      end
      
      multiples.times { structure << pattern_name_sym }
    }
    song.structure = structure
  end
    
  # Converts all hash keys to be lowercase
  def downcase_hash_keys(hash)
    return hash.inject({}) do |new_hash, pair|
        new_hash[pair.first.downcase] = pair.last
        new_hash
    end
  end
end