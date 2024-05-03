# WAV file Parser
This Ruby script processes WAV audio files from a specified input directory, extracts metadata, and generates XML files containing this metadata for each processed file.

## System Requirements

Ruby Version: Developed and tested with Ruby 3.2.1

## Dependencies

The script uses the nokogiri and wavefile gems, which are not included in the standard Ruby library.

## Running the Script

To run the script, you must use the `ruby` command to execute the file, specifying the path where the script is located, followed by the directory containing the WAV files as a parameter. Use the following command format:

`ruby /path/to/audio_ingester.rb /path/to/input_directory`
