# frozen_string_literal: true

module Bulkrax
  module HasMatchers
    extend ActiveSupport::Concern

    included do
      class_attribute :matchers
      self.matchers ||= {}
    end

    class_methods do
      def matcher_class
        Bulkrax::ApplicationMatcher
      end

      def matcher(name, args = {})
        matcher = matcher_class.new(
          to: name,
          parsed: args[:parsed],
          split: args[:split],
          if: args[:if],
          excluded: args[:excluded]
        )
        self.matchers[name] = matcher
      end
    end

    def add_metadata(node_name, node_content)
      field_to(node_name).each do |name|
        matcher = self.class.matcher(name, mapping[name].symbolize_keys) if mapping[name] # the field matched to a pre parsed value in application_matcher.rb
        multiple = multiple?(name) # the field has multiple values. e.g. ['a', 'b', 'c']
        object = object_name(name) || false # the field is an object of key:value pairs. e.g. { obj: { key: value }}

        next unless field_supported?(name) || (object && field_supported?(object))

        if object
          Rails.logger.info("Bulkrax Column automatically matched object #{node_name}, #{node_content}")
          parsed_metadata[object] ||= {}
        end

        if matcher
          matched_metadata?(matcher, multiple, name, node_content, object)
        elsif multiple
          Rails.logger.info("Bulkrax Column automatically matched #{node_name}, #{node_content}")
          multiple_metadata?(name, node_name, node_content, object)
        else
          Rails.logger.info("Bulkrax Column automatically matched #{node_name}, #{node_content}")
          # if object
          #   puts "node_content >> #{node_content}"
          #   puts "object >> #{object}"
          #   puts "parsed_metadata >> #{parsed_metadata}"
          #   puts "name >> #{name}"
            # debugger
          # end

          node_content = node_content.content if node_content.is_a?(Nokogiri::XML::NodeSet)
          next parsed_metadata[object][name] = Array.wrap(node_content.to_s.strip).join('; ') if object && node_content
          parsed_metadata[name] = Array.wrap(node_content.to_s.strip).join('; ') if node_content
        end
      end
    end

    def field_supported?(field)
      field = field.gsub('_attributes', '')

      return false if excluded?(field)
      return true if ['file', 'remote_files', 'model', 'delete'].include?(field)
      return factory_class.method_defined?(field) && factory_class.properties[field].present?
    end

    def multiple?(field)
      return true if field == 'file' || field == 'remote_files'
      return false if field == 'model'
      field_supported?(field) && factory_class&.properties&.[](field)&.[]('multiple')
    end

    def object_name(field)
      mapping&.[](field)&.[]('object')
    end

    # Hyrax field to use for the given import field
    # @param field [String] the importer field name
    # @return [Array] hyrax fields
    def field_to(field)
      fields = mapping&.map do |key, value|
        key if (value.present? && value['from']&.include?(field)) || key == field
      end&.compact

      return [field] if fields.blank?
      return fields
    end

    # Check whether a field is explicitly excluded in the mapping
    def excluded?(field)
      return false unless mapping[field].present?
      mapping[field]['excluded'] || false
    end

    def multiple_metadata?(name, node_name, node_content, object = false)
      Rails.logger.info("Bulkrax Column automatically matched #{node_name}, #{node_content}")
      node_content = node_content.content if node_content.is_a?(Nokogiri::XML::NodeSet)
      # if object
      #   puts "name >> #{name}"
      #   puts "node_name >> #{node_name}"
      #   puts "node_content >> #{node_content}"
      #   puts "object >> #{object}"
      #   puts "parsed_metadata >> #{parsed_metadata}"
        # debugger
      # end

      if object
        parsed_metadata[object][name] ||= []
        parsed_metadata[object][name] += node_content.is_a?(Array) ? node_content : Array.wrap(node_content.strip)
      else
        parsed_metadata[name] ||= []
        parsed_metadata[name] += node_content.is_a?(Array) ? node_content : Array.wrap(node_content.strip)
      end
    end

    def matched_metadata?(matcher, multiple, name, node_content, object = false)
      result = matcher.result(self, node_content)
      return unless result
      # if object
      #   puts "result >> #{result}"
      #   puts "matcher >> #{matcher.inspect}"
      #   puts "multiple >> #{multiple}"
      #   puts "name >> #{name}"
      #   puts "node_content >> #{node_content}"
      #   puts "object >> #{object}"
      #   puts "parsed_metadata >> #{parsed_metadata}"
        # debugger
      # end

      if object
        if multiple
          parsed_metadata[object][name] ||= []
          parsed_metadata[object][name] += Array.wrap(result)
        else
          parsed_metadata[object][name] = Array.wrap(result).join('; ')
        end
      elsif multiple
        parsed_metadata[name] ||= []
        parsed_metadata[name] += Array.wrap(result)
      else
        parsed_metadata[name] = Array.wrap(result).join('; ')
      end
    end
  end
end
