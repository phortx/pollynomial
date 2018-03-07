require 'aws-sdk-polly'

module Pollynomial
  class Synthesizer
    POLLY_TEXT_LIMIT_SIZE = 1500
    DEFAULT_DELIMITER = '[.。]'
    COMMA = '[,、]'

    attr_reader :voice_id, :output_format, :sample_rate, :client, :text_type

    def initialize(options={})
      options[:region] ||= 'us-east-1'
      # You can use voice IDs http://docs.aws.amazon.com/polly/latest/dg/API_Voice.html
      # If you want to synthesize Japanese voice, you can use "Mizuki"
      @voice_id = options.delete(:voice_id) || 'Joanna'
      @delimiter = options.delete(:delimiter)|| DEFAULT_DELIMITER
      @comma = options.delete(:comma) || COMMA
      @sample_rate = options.delete(:sample_rate) || '16000'
      @output_format = options.delete(:output_format) || 'mp3'
      @text_type = options.delete(:text_type) || 'text'
      @client = Aws::Polly::Client.new(options)
    end

    def synthesize(text, file_name: "tmp.mp3")
      File.delete(file_name) if File.exist?(file_name)
      File.open(file_name, 'ab') do |file|
        split_text(text).each do |_text|
          if @text_type == 'ssml'
            _text.prepend('<speak>')
            _text += '</speak>'
          end
          tmp_file = Tempfile.new
          tmp_file.binmode
          client.synthesize_speech(
              response_target: tmp_file,
              text: _text,
              output_format: output_format,
              sample_rate: sample_rate,
              voice_id: voice_id,
              text_type: @text_type
            )
          IO.copy_stream(tmp_file, file)
          sleep(0.1)
        end
      end
    end


    def synthesize_to_file(text, file)
      split_text(text).each do |_text|
        if @text_type == 'ssml'
          _text.prepend('<speak>')
          _text += '</speak>'
        end
        tmp_file = Tempfile.new
        tmp_file.binmode
        client.synthesize_speech(
            response_target: tmp_file,
            text: _text,
            output_format: output_format,
            sample_rate: sample_rate,
            voice_id: voice_id,
            text_type: @text_type
          )
        IO.copy_stream(tmp_file, file)
        sleep(0.1)
      end
    end

    def available_voices_in(language_code: 'en-US')
      voices = client.describe_voices(language_code: language_code)
      voices.voices if voices
    end

    def split_text(raw_text)
      combined_texts = []
      tmp_string = ""
      raw_text.split(/\n|(?<=#{@delimiter}) ?/).each do |text|
        if tmp_string.size + text.size > POLLY_TEXT_LIMIT_SIZE
          if tmp_string.size > POLLY_TEXT_LIMIT_SIZE
            combined_texts << tmp_string.split(/(?<=#{@comma})/)
          else
            combined_texts << tmp_string
          end
          tmp_string = text
        else
          tmp_string << " #{text}"
        end
      end
      combined_texts << tmp_string.lstrip
      combined_texts.flatten!
      combined_texts
    end
  end
end
