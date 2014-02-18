module DevLoop
  class SlingInitialContentConverter
    def self.convert(json_string)
      node_data = JSON.parse(json_string)
      builder = Builder::XmlMarkup.new
      serialized_attributes, children = group_data(node_data)

      builder.tag!("jcr:root", namespaces.merge(serialized_attributes)) do |b|
        add_children(children, b)
      end
    end

    def self.add_children(children, builder)
      children.each do |name, node_data|
        serialized_attributes, children = group_data(node_data)
        builder.tag!(name, serialized_attributes) do |b|
          add_children(children, b)
        end
      end
    end

    # Divide node data into serialized attributes and children
    def self.group_data(node_data)
      serialized_attributes = {}
      children = {}
      node_data.each do |key,value|
        if !value.is_a?(Hash)
          serialized_attributes[key] = convert_to_serialized_jcr_value(value)
        else
          children[key] = value
        end
      end

      [serialized_attributes, children]
    end

    # All known namespaces
    def self.namespaces
      {
        "xmlns:cq"    => "http://www.day.com/jcr/cq/1.0",
        "xmlns:sling" => "http://sling.apache.org/jcr/sling/1.0",
        "xmlns:jcr"   => "http://www.jcp.org/jcr/1.0",
        "xmlns:vlt"   => "http://www.day.com/jcr/vault/1.0",
        "xmlns:nt"    => "http://www.jcp.org/jcr/nt/1.0"
      }
    end

    def self.convert_to_serialized_jcr_value(value)
      if value == true || value == false
        "{Boolean}#{value}"
      elsif value.is_a?(Array)
        values = value.map {|el| convert_to_serialized_jcr_value(el) }
        "[#{values.join(",")}]"
      elsif value.is_a?(Time)
        "{Date}#{value.strftime("%Y-%m-%dT%H:%M:%S.%L%:z")}"
      elsif value.is_a?(String)
        value
      else
        raise "Unknown type, cannot serialize #{value.class} value: #{value}"
      end
    end
  end
end