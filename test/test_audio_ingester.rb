require 'minitest/autorun'
require_relative '../lib/audio_ingester'
require 'fileutils'

class TestAudioIngester < Minitest::Test
  def setup
    @input_dir = File.expand_path('input_files', __dir__)
  end

  def teardown
    output_dir = File.join(File.dirname(@input_dir), 'output')
    FileUtils.remove_entry_secure(output_dir) if Dir.exist?(output_dir)
  end

  def test_directory_not_found
    ingester = AudioIngester.new('/non/existent/directory')
    assert_raises(DirectoryNotFoundError,
      "DirectoryNotFoundError should be raised") { ingester.run }
  end

  def test_no_wav_files_found
    # Create a temporary empty directory
    temp_dir = Dir.mktmpdir
    ingester = AudioIngester.new(temp_dir)
    assert_raises(NoWavFilesFoundError,
      "NoWavFilesFoundError should be raised") { ingester.run }
    FileUtils.remove_entry_secure(temp_dir)  # Clean up the temporary directory
  end

  # Test successful processing of WAV files and creation of XML files
  def test_output_dir_and_xml_file_creation
    ingester = AudioIngester.new(@input_dir)
    ingester.run

    # Check for the creation of the output directory and subdirectory
    output_base = File.join(File.dirname(@input_dir), 'output')
    assert Dir.exist?(output_base), "output directory should exist"
    assert Dir.exist?(ingester.output_dir),
      "output/timestamped subdirectory should exist"

    # Check for each XML file creation
    Dir.glob(File.join(@input_dir, '*.wav')).each do |wav_file|
      xml_file = File.join(ingester.output_dir,
        File.basename(wav_file, '.wav') + '.xml')
      assert File.exist?(xml_file),
        "XML file for #{File.basename(wav_file)} should be created"
    end

    assert_equal 2, Dir.children(ingester.output_dir).size,
      "output directory should have 2 files"
  end

  def test_xml_file_conformity
    ingester = AudioIngester.new(@input_dir)
    ingester.run
    xml_file_path = File.join(ingester.output_dir, 'sample-file-3.xml')
    document = Nokogiri::XML(File.read(xml_file_path))

    # Load the XSD schema and validate the document
    xsd = Nokogiri::XML::Schema(File.read(File.join(__dir__, 'wav.xsd')))
    errors = xsd.validate(document)
    assert errors.empty?, "XML does not conform to schema: #{errors.join(', ')}"
  end

  def test_xml_output_content
    expected_values = {
      "format"        => "PCM",
      "channel_count" => "2",
      "sampling_rate" => "44100",
      "bit_depth"     => "16",
      "bit_rate"      => "1411200",
      "byte_rate"     => "176400",
    }

    ingester = AudioIngester.new(@input_dir)
    ingester.run

    xml_file_path = File.join(ingester.output_dir, 'sample-file-3.xml')
    document = Nokogiri::XML(File.read(xml_file_path))

    # Check for each expected element and its value
    expected_values.each do |element, expected_value|
      actual_element = document.at_css(element)
      assert actual_element, "Element '#{element}' is missing"

      actual_value = actual_element&.content
      if element
        assert_equal expected_value, actual_value,
          "Value of element '#{element}' is incorrect"
      end
    end
  end
end
