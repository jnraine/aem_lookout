require 'spec_helper'

describe DevLoop do
  it "knows where the vlt executable lives" do
    vlt_executable = DevLoop.vlt_executable
    expect(File.basename(vlt_executable)).to eq("vlt")
    expect(File.executable?(vlt_executable)).to eq(true)
  end
end