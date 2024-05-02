require 'pathname'
require 'fileutils'
require 'nokogiri'
require 'time'

class DirectoryNotFoundError < StandardError; end
class NoWavFilesFoundError < StandardError; end

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
    output_base = File.join(File.dirname(@input_dir), "output")
    @output_dir = File.join(output_base, Time.now.to_i.to_s)
    FileUtils.mkdir_p(@output_dir)
  end

  def process_file(file)
    puts "Extracting metadata from: #{file}"
    create_empty_xml(file)
  end

  def create_empty_xml(file)
    file_name = File.basename(file, ".*") + ".xml"
    output_path = File.join(@output_dir, file_name)
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do
      # Future XML content can added here
    end
    File.write(output_path, builder.to_xml)
    puts "Generated empty XML for: #{file_name}"
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
