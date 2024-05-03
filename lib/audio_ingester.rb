require 'pathname'
require 'fileutils'
require 'nokogiri'
require 'time'
require 'wavefile'

class DirectoryNotFoundError < StandardError; end
class NoWavFilesFoundError < StandardError; end
class MetadataExtractionError < StandardError; end
class FileCreationError < StandardError; end

class AudioIngester
  attr_reader :input_dir, :output_dir

  def initialize(input_dir)
    @input_dir = input_dir
    puts "Initialized AudioIngester with input directory: #{@input_dir}"
  end

  def run
    check_directory_existence
    wav_files = fetch_wav_files
    puts "Found #{wav_files.length} WAV files"
    create_output_directory
    wav_files.each { |file| process_file(file) }
  end


  private

  def check_directory_existence
    raise DirectoryNotFoundError unless Dir.exist?(input_dir)
  end

  def fetch_wav_files
    wav_files = Dir.glob(File.join(input_dir, '*.wav'))
    raise NoWavFilesFoundError if wav_files.empty?
    wav_files
  end

  def create_output_directory
    output_base = File.join(File.dirname(input_dir), 'output')
    @output_dir = File.join(output_base, Time.now.to_i.to_s)
    FileUtils.mkdir_p(output_dir)
    puts "Output directory created at: #{output_dir}"
  end

  def process_file(file)
    puts "Processing file: #{file}"
    metadata = extract_metadata(file)
    create_xml(file, metadata)
    puts "XML created for: #{file}"
  end

  def extract_metadata(file_path)
    # Extract metadata using WaveFile gem
    metadata = {}
    begin
      WaveFile::Reader.new(file_path) do |reader|
        format = reader.native_format
        metadata = {
          audio_format: format.audio_format == 1 ? 'PCM' : 'Compressed',
          num_channels: format.channels,
          sample_rate: format.sample_rate,
          byte_rate: format.byte_rate,
          bits_per_sample: format.bits_per_sample,
          bit_rate: format.sample_rate * format.channels * format.bits_per_sample,
        }
      end
    rescue StandardError => e
      raise MetadataExtractionError,
        "Error extracting metadata from #{file_path}: #{e.message}"
    end
    metadata
  end

  def create_xml(file, metadata)
    begin
      file_name = File.basename(file, '.*') + '.xml'
      output_path = File.join(output_dir, file_name)
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
