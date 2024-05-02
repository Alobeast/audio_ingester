require 'minitest/autorun'
require_relative '../lib/audio_ingester'
require 'fileutils'

class TestAudioIngester < Minitest::Test
  def setup
    @input_dir = File.expand_path('input_files', __dir__)
  end

  def teardown
    output_dir = File.join(File.dirname(@input_dir), "output")
    FileUtils.remove_entry_secure(output_dir) if Dir.exist?(output_dir)
  end

  def test_directory_not_found
    ingester = AudioIngester.new("/non/existent/directory")
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

  # Test successful processing of WAV files and creation of XML
  def test_output_dir_and_xml_file_creation
    ingester = AudioIngester.new(@input_dir)
    ingester.run

    # Check for the creation of the output directory
    output_base = File.join(File.dirname(@input_dir), "output")
    assert Dir.exist?(output_base), "output directory should exist"
    assert Dir.exist?(ingester.output_dir),
      "output/timestamped subdirectory should be created"

    # Check for each XML file creation
    Dir.glob(File.join(@input_dir, '*.wav')).each do |wav_file|
      xml_file = File.join(ingester.output_dir, File.basename(wav_file, '.wav') + '.xml')
      assert File.exist?(xml_file), "XML file for #{File.basename(wav_file)} should be created"
    end

    # check that the output directory has 2 files
    assert_equal 2, Dir.children(ingester.output_dir).size,
      "output directory should have 2 files"
  end
end
