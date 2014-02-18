require 'spec_helper'
require 'json'
require 'builder'

describe DevLoop::SlingInitialContentConverter do
  it "converts a json file into a .content.xml file" do
    node_example = {
      "cq:isContainer" => false,
      "jcr:description" => "A list of upcoming events pulled from a calendar",
      "jcr:primaryType" => "cq:Component",
      "jcr:title" => "Upcoming Events",
      "componentGroup" => "Social"
    }
    content_xml = DevLoop::SlingInitialContentConverter.convert(node_example.to_json)
    xml_exemplar = '<jcr:root xmlns:cq="http://www.day.com/jcr/cq/1.0" xmlns:sling="http://sling.apache.org/jcr/sling/1.0" xmlns:jcr="http://www.jcp.org/jcr/1.0" xmlns:vlt="http://www.day.com/jcr/vault/1.0" xmlns:nt="http://www.jcp.org/jcr/nt/1.0" cq:isContainer="{Boolean}false" jcr:description="A list of upcoming events pulled from a calendar" jcr:primaryType="cq:Component" jcr:title="Upcoming Events" componentGroup="Social"></jcr:root>'
    expect(content_xml).to eq(xml_exemplar)
  end

  it "prints an example of a complex JSON desciptor file" do
    json = File.read("/Users/jnraine/projects/cq/java-core/src/main/resources/components/twitter-timeline.json")
    puts DevLoop::SlingInitialContentConverter.convert(json)
  end

  describe ".convert_to_serialized_jcr_value" do
    let(:klass) { DevLoop::SlingInitialContentConverter }

    it "converts booleans to serialized JCR booleans" do
      klass.convert_to_serialized_jcr_value(true).should == "{Boolean}true"
      klass.convert_to_serialized_jcr_value(false).should == "{Boolean}false"
    end

    it "converts arrays to serialized JCR arrays" do
      klass.convert_to_serialized_jcr_value(["foo", "bar", "baz"]).should == "[foo,bar,baz]"
    end

    it "converts dates to serialized JCR dates" do
      # this only handles local time
      local_time = Time.parse("2010-03-17T17:14:41.775")
      klass.convert_to_serialized_jcr_value(local_time).should == "{Date}2010-03-17T17:14:41.775-07:00"
    end
  end
end