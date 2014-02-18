require 'spec_helper'

describe DevLoop do
  it "knows where the vlt executable lives" do
    expect(DevLoop.vlt_executable).to end_with("dev_loop/bin/vault/bin/vlt")
  end
end