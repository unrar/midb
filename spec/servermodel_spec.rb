require 'spec_helper'

describe MIDB::API::Model do
  before :each do
    cc = Hash.new
    cc["dbengine"] = :sqlite3
    engy = MIDB::API::Engine.new("test", "100 WAITING", cc)

    @dbop = MIDB::API::Model.new("users", "test", engy)
  end

  lid = 0 # Last operation id

  describe "#get_structure" do
    it "returns a hash containing the JSON structure" do
      expect(@dbop.get_structure()).to eq(JSON.parse(IO.read("./json/users.json"))["id"])
    end
  end

  describe "#query_to_hash" do
    it "converts an HTTP query string to a hash" do
      expect(@dbop.query_to_hash("ayy=lmao&id=4321")).to eq({"ayy" => "lmao", "id" => "4321"})
    end
  end

  describe "#post" do
    it "inserts a record into a database" do
      post_query = @dbop.post("name=test3&age=20&password=spec4life")
      expect(post_query[:status]).to eq("201 created")
      lid = post_query[:id]
    end
  end

  describe "#get_entries" do
    it "gets an entry with a specified id" do
      get_entries_query = @dbop.get_entries(lid)
      expect(get_entries_query[lid]["name"]).to eq("test3")
    end
  end

  describe "#put" do
    it "alters a record from a database" do
      put_query = @dbop.put(lid, "name=altered_test3")
      expect(put_query[:status]).to eq("200 OK")
    end
  end

  describe "#delete" do
    it "removes a record from the database" do
      delete_query = @dbop.delete(lid)
      expect(delete_query[:status]).to eq("200 OK")
    end
  end

  describe "#get_all_entries" do
    it "gets all entries from the database" do
      getall_query = @dbop.get_all_entries()
      expect(getall_query.length).to be > 0
    end
  end
  
end