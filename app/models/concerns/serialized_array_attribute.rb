module SerializedArrayAttribute
  extend ActiveSupport::Concern

  class_methods do
    def array_attribute(*names)
      names.each do |name|
        serialize name, coder: JSON
        define_method("#{name}_array") { parse_serialized_array(name) }
      end
    end
  end

  private

  def parse_serialized_array(name)
    raw = read_attribute_before_type_cast(name)

    parsed =
      case raw
      when nil
        []
      when Array
        raw
      when String
        begin
          JSON.parse(raw)
        rescue JSON::ParserError
          [raw]
        end
      else
        Array(raw)
      end

    Array(parsed).map(&:to_s).map(&:strip).reject(&:blank?)
  end
end
