# This class actually generates the output sound data for the performance.
# Applies a Kit to a Song (which contains sub Patterns and Tracks) to
# produce output sample data.
class AudioEngine
  SAMPLE_RATE = 44100
  PACK_CODE = "s*"   # All sample data is assumed to be 16-bit

  def initialize(song, kit)
    @song = song
    @kit = kit
    
    @tick_sample_length = AudioUtils.tick_sample_length(SAMPLE_RATE, @song.tempo) 
    @pattern_cache = {}
    @track_cache = {}
  end

  def write_to_file(output_file_name)
    packed_pattern_cache = {}
    num_tracks_in_song = @song.total_tracks
    samples_written = 0
    
    # Open output wave file and preparing it for writing sample data.
    wave_file = BeatsWaveFile.new(@kit.num_channels, SAMPLE_RATE, @kit.bits_per_sample)
    file = wave_file.open_for_appending(output_file_name)

    # Generate each pattern's sample data, or pull it from cache, and append it to the wave file.
    incoming_overflow = {}
    @song.flow.each do |pattern_name|
      key = [pattern_name, incoming_overflow.hash]
      unless packed_pattern_cache.member?(key)
        sample_data = generate_pattern_sample_data(@song.patterns[pattern_name], incoming_overflow)

        if @kit.num_channels == 1
          # Don't flatten the sample data Array, since it is already flattened. That would be a waste of time, yo.
          packed_pattern_cache[key] = {:primary        => sample_data[:primary].pack(PACK_CODE),
                                       :overflow       => sample_data[:overflow],
                                       :primary_length => sample_data[:primary].length}
        else
          packed_pattern_cache[key] = {:primary        => sample_data[:primary].flatten.pack(PACK_CODE),
                                       :overflow       => sample_data[:overflow],
                                       :primary_length => sample_data[:primary].length}
        end
      end

      file.syswrite(packed_pattern_cache[key][:primary])
      incoming_overflow = packed_pattern_cache[key][:overflow]
      samples_written += packed_pattern_cache[key][:primary_length]
    end

    # Write any remaining overflow from the final pattern
    final_overflow_composite = AudioUtils.composite(incoming_overflow.values, @kit.num_channels)
    final_overflow_composite = AudioUtils.normalize(final_overflow_composite, @kit.num_channels, num_tracks_in_song)
    if @kit.num_channels == 1
      file.syswrite(final_overflow_composite.pack(PACK_CODE))
    else
      file.syswrite(final_overflow_composite.flatten.pack(PACK_CODE))
    end
    samples_written += final_overflow_composite.length
    
    # Now that we know how many samples have been written, go back and re-write the correct header.
    file.sysseek(0)
    wave_file.write_header(file, samples_written)

    file.close()

    return wave_file.calculate_duration(SAMPLE_RATE, samples_written)
  end

  attr_reader :tick_sample_length

private

  # Generates the sample data for a single track, using the specified sound's sample data.
  def generate_track_sample_data(track, sound)
    beats = track.beats
    if beats == [0]
      return {:primary => [], :overflow => []}    # Is this really what should happen? Why throw away overflow?
    end

    fill_value = (@kit.num_channels == 1) ? 0 : [0, 0]
    primary_sample_data = [].fill(fill_value, 0, AudioUtils.tick_start_sample(track.tick_count, @tick_sample_length))

    tick_index = beats[0]
    beat_sample_length = 0
    beats[1...(beats.length)].each do |beat_tick_length|
      start_sample = AudioUtils.tick_start_sample(tick_index, @tick_sample_length)
      end_sample = [(start_sample + sound.length), primary_sample_data.length].min
      beat_sample_length = end_sample - start_sample

      primary_sample_data[start_sample...end_sample] = sound[0...beat_sample_length]

      tick_index += beat_tick_length
    end

    overflow_sample_data = (sound == []) ? [] : sound[beat_sample_length...(sound.length)]

    return {:primary => primary_sample_data, :overflow => overflow_sample_data}
  end

  def generate_pattern_sample_data(pattern, incoming_overflow)
    primary_sample_data, overflow_sample_data = generate_main_sample_data(pattern)
    primary_sample_data, overflow_sample_data = handle_incoming_overflow(pattern,
                                                                         incoming_overflow,
                                                                         primary_sample_data,
                                                                         overflow_sample_data)
    primary_sample_data = AudioUtils.normalize(primary_sample_data, @kit.num_channels, @song.total_tracks)
    
    return {:primary => primary_sample_data, :overflow => overflow_sample_data}
  end

  # Composites the sample data for each of the pattern's tracks, and returns the overflow sample data
  # from tracks whose last sound trigger extends past the end of the pattern. This overflow can be
  # used by the next pattern to avoid sounds cutting off when the pattern changes.
  #
  # Overflow can't be composited here because the next pattern might truncate each track's overflow
  # separately depending on when the track's first trigger occurs.
  def generate_main_sample_data(pattern)
    primary_sample_data = []
    overflow_sample_data = {}
    
    if @pattern_cache[pattern] == nil
      raw_track_sample_arrays = []
      pattern.tracks.each do |track_name, track|
        temp = generate_track_sample_data(track, @kit.get_sample_data(track.name))
        raw_track_sample_arrays << temp[:primary]
        overflow_sample_data[track_name] = temp[:overflow]
      end

      primary_sample_data = AudioUtils.composite(raw_track_sample_arrays, @kit.num_channels)
      
      @pattern_cache[pattern] = {:primary => primary_sample_data.dup, :overflow => overflow_sample_data.dup}
    else
      primary_sample_data = @pattern_cache[pattern][:primary].dup
      overflow_sample_data = @pattern_cache[pattern][:overflow].dup
    end
  
    return primary_sample_data, overflow_sample_data
  end

  # Applies sound overflow (i.e. long sounds such as cymbal crash which extend past the last step)
  # from the previous pattern in the flow to the current pattern. This prevents sounds from being
  # cut off when the pattern changes.
  # 
  # It would probably be shorter and conceptually simpler to deal with incoming overflow in
  # generate_track_sample_data() instead of this method. (In fact, this method would go away).
  # However, doing it this way allows for caching composited pattern sample data, and
  # applying incoming overflow to the composite. This allows each pattern to only be composited once,
  # regardless of the incoming overflow that each performance of it receives. If incoming overflow
  # was handled at the Track level we couldn't do that.
  def handle_incoming_overflow(pattern, incoming_overflow, primary_sample_data, overflow_sample_data)
    pattern_track_names = pattern.tracks.keys
    sample_arrays = [primary_sample_data]

    incoming_overflow.each do |incoming_track_name, incoming_sample_data|
      end_sample = incoming_sample_data.length
      
      if pattern_track_names.member?(incoming_track_name)
        track = pattern.tracks[incoming_track_name]

        if track.beats.length > 1
          intro_length = (pattern.tracks[incoming_track_name].beats[0] * tick_sample_length).floor
          end_sample = [end_sample, intro_length].min
        end
      end

      if end_sample > primary_sample_data.length
        end_sample = primary_sample_data.length
        overflow_sample_data[incoming_track_name] = incoming_sample_data[(primary_sample_data.length)...(incoming_sample_data.length)]
      end

      sample_arrays << incoming_sample_data[0...end_sample]
    end

    return AudioUtils.composite(sample_arrays, @kit.num_channels), overflow_sample_data
  end
end
