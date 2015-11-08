require 'spec_helper'

describe MIDB::ServerModel do

  describe "#get_structure" do
    it "returns a hash containing the JSON structure" do
      MIDB::ServerModel.jsf = "users"
      MIDB::ServerModel.get_structure().should eql JSON.parse(IO.read("./json/users.json"))["id"]
    end
  end
  
end