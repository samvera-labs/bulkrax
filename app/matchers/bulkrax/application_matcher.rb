require 'language_list'

module Bulkrax
  class ApplicationMatcher
    attr_accessor :to, :from, :parsed, :if, :split, :excluded

    def initialize(args)
      args.each do |k, v|
        send("#{k}=", v)
      end
    end

    def result(parser, content)
      return nil if self.excluded == true || Bulkrax.reserved_properties.include?(self.to)
      return nil if self.if && (!self.if.is_a?(Array) && self.if.length != 2)

      if self.if
        return unless content.send(self.if[0], Regexp.new(self.if[1]))
      end

      @result = content.gsub(/\s/, ' ') # remove any line feeds and tabs
      @result.strip!

      if self.split.is_a?(TrueClass)
        @result = @result.split(/\s*[:;|]\s*/) # default split by : ; |
      elsif self.split
        @result = @result.split(Regexp.new(self.split))
      end

      if @result.is_a?(Array) && @result.size == 1
        @result = @result[0]
      end

      if @result.is_a?(Array) && self.parsed && self.respond_to?("parse_#{to}")
        @result.each_with_index do |res, index|
          @result[index] = send("parse_#{to}", res.strip)
        end
        @result.delete(nil)
      elsif self.parsed && self.respond_to?("parse_#{to}")
        @result = send("parse_#{to}", @result)
      end

      return @result
    end

    def parse_remote_files(src)
      { url: src.strip } if src.present?
    end

    def parse_language(src)
      l = ::LanguageList::LanguageInfo.find(src.strip)
      l ? l.name : src
    end

    def parse_subject(src)
      string = src.to_s.strip.downcase
      if string.present?
        string.slice(0,1).capitalize + string.slice(1..-1)
      end
    end

    def parse_types(src)
      src.to_s.strip.titleize
    end

    # Allow for mapping a model field to the work type or collection
    def parse_model(src)
      if src&.match(URI::ABS_URI)
        url.split('/').last.constantize
      else
        src.constantize
      end
    rescue StandardError
      nil
    end

    # Only add valid resource types
    def parse_resource_type(src)
      Hyrax::ResourceTypesService.label(src.to_s.strip.titleize)
    rescue KeyError
      nil
    end

    def parse_format_original(src)
      # drop the case completely then upcase the first letter
      string = src.to_s.strip.downcase
      if string.present?
        string.slice(0,1).capitalize + string.slice(1..-1)
      end
    end

  end
end
