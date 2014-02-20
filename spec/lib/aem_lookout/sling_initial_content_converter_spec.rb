require 'spec_helper'

describe AemLookout::SlingInitialContentConverter do
  it "converts a json file into a .content.xml file" do
    node_example = {
      "cq:isContainer" => false,
      "jcr:description" => "A list of upcoming events pulled from a calendar",
      "jcr:primaryType" => "cq:Component",
      "jcr:title" => "Upcoming Events",
      "componentGroup" => "Social"
    }
    content_xml = AemLookout::SlingInitialContentConverter.convert(node_example.to_json)
    xml_exemplar = '<jcr:root xmlns:cq="http://www.day.com/jcr/cq/1.0" xmlns:sling="http://sling.apache.org/jcr/sling/1.0" xmlns:jcr="http://www.jcp.org/jcr/1.0" xmlns:vlt="http://www.day.com/jcr/vault/1.0" xmlns:nt="http://www.jcp.org/jcr/nt/1.0" cq:isContainer="{Boolean}false" jcr:description="A list of upcoming events pulled from a calendar" jcr:primaryType="cq:Component" jcr:title="Upcoming Events" componentGroup="Social"></jcr:root>'
    expect(content_xml).to eq(xml_exemplar)
  end

  # xit "prints an example of a complex JSON desciptor file" do
  #   json = File.read("/Users/jnraine/projects/cq/java-core/src/main/resources/components/twitter-timeline.json")
  #   puts AemLookout::SlingInitialContentConverter.convert(json)
  # end

  describe ".convert_to_serialized_jcr_value" do
    let(:klass) { AemLookout::SlingInitialContentConverter }

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


  describe "#convert_json_descriptor_files" do
    def build_fake_package
      tmp_dir = Pathname(Dir.mktmpdir("sync-test"))
      File.open(tmp_dir + "#{node_name}.json", 'w') {|f| f.write(properties.to_json) }
      tmp_dir
    end

    let(:properties) do
      {foo: "hello", bar: "world", baz: "ur nice"}
    end

    let(:node_name) { "foo" }
    let(:fake_package_path) { build_fake_package }

    it "takes any json files at a given path and converts them to .content.xml files" do
      AemLookout::SlingInitialContentConverter.convert_package(fake_package_path)
      content_xml_path = fake_package_path + "foo" + ".content.xml"
      expect(File).to exist(content_xml_path)
      expect(File.read(content_xml_path)).to match("foo=\"hello\" bar=\"world\" baz=\"ur nice\"")
    end
  end

  describe ".json_files_within" do
    it "returns all json files found within a directory structure recursively" do
      # setup
      tmp_dir = Pathname(Dir.mktmpdir("test"))
      nested_dir = tmp_dir + "foo" + "bar" + "baz"
      FileUtils.mkdir_p(nested_dir.to_s)
      sleep 0.01
      FileUtils.touch([tmp_dir + "my.json", nested_dir + "another.json"])
      # execute and assert
      json_files = AemLookout::SlingInitialContentConverter.json_files_within(tmp_dir)
      expect(json_files.length).to eq(2)
      json_files.each {|json_file| expect(json_file).to end_with(".json") }
    end
  end

  describe ".generate_content_xml_path" do
    it "creates a content XML path for the named node" do
      content_xml_path = AemLookout::SlingInitialContentConverter.generate_content_xml_path("/foo/my_node.json")
      expect(content_xml_path).to eq(Pathname("/foo/my_node/.content.xml"))
    end

    it "raises an error when passed a path to a non-json file" do
      expect { 
        AemLookout::SlingInitialContentConverter.generate_content_xml_path("/foo/my_node.txt")
      }.to raise_error(ArgumentError)
    end
  end
end