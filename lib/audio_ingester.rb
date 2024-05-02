require 'pathname'
require 'fileutils'
require 'nokogiri'
require 'time'

class DirectoryNotFoundError < StandardError; end
class NoWavFilesFoundError < StandardError; end
class FileCreationError < StandardError; end

class AudioIngester
  attr_reader :input_dir, :output_dir

  def initialize(input_dir)
    @input_dir = input_dir
  end

   def run
    check_directory_existence
    wav_files = fetch_wav_files
    create_output_directory
    wav_files.each { |file| process_file(file) }
  end


  private

  def check_directory_existence
    raise DirectoryNotFoundError unless Dir.exist?(@input_dir)
  end

  def fetch_wav_files
    wav_files = Dir.glob(File.join(@input_dir, '*.wav'))
    raise NoWavFilesFoundError if wav_files.empty?
    wav_files
  end

  def create_output_directory
    output_base = File.join(File.dirname(@input_dir), 'output')
    @output_dir = File.join(output_base, Time.now.to_i.to_s)
    FileUtils.mkdir_p(@output_dir)
  end

  def process_file(file)
    metadata = extract_metadata(file)
    create_xml(file, metadata)
  end

  def extract_metadata(file_path)
    #  open the file in binary mode
    wav_file = File.open(file_path, 'rb')

    # metadata can be found in the first 44 bytes of the file
    header = wav_file.read(44)
    # `unpack` converts binary data to readable format
    # the argument specifies the format of the binary data
    # S is for short (16-bit) and L is for long (32-bit), < is for little-endian
    audio_format = header[20..21].unpack('S<').first == 1 ? 'PCM' : 'Compressed'
    num_channels = header[22..23].unpack('S<').first
    sample_rate = header[24..27].unpack('L<').first
    byte_rate = header[28..31].unpack('L<').first
    bits_per_sample = header[34..35].unpack('S<').first
    bit_rate = sample_rate * num_channels * bits_per_sample

    {
      audio_format:     audio_format,
      num_channels:     num_channels,
      sample_rate:      sample_rate,
      byte_rate:        byte_rate,
      bits_per_sample:  bits_per_sample,
      bit_rate:         bit_rate
    }

  ensure
    wav_file&.close
  end

  def create_xml(file, metadata)
    begin
      file_name = File.basename(file, '.*') + '.xml'
      output_path = File.join(@output_dir, file_name)
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.track do
          xml.format metadata[:audio_format]
          xml.channel_count metadata[:num_channels]
          xml.sampling_rate metadata[:sample_rate]
          xml.bit_depth metadata[:bits_per_sample]
          xml.byte_rate metadata[:byte_rate] if metadata[:byte_rate]
          xml.bit_rate metadata[:bit_rate]
        end
      end
      File.write(output_path, builder.to_xml)
    rescue StandardError => e
      raise FileCreationError, "Error creating XML file, #{file}: #{e.message}"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.length != 1
    raise ArgumentError,
      "Invalid number of arguments,
      expected command: ruby #{File.basename(__FILE__)} <input_files_directory>"
  end

  directory = ARGV[0]
  ingester = AudioIngester.new(directory)
  ingester.run
end
