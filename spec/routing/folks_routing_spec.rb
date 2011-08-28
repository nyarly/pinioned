require "spec_helper"

describe FolksController do
  describe "routing" do

    it "routes to #index" do
      get("/folks").should route_to("folks#index")
    end

    it "routes to #new" do
      get("/folks/new").should route_to("folks#new")
    end

    it "routes to #show" do
      get("/folks/1").should route_to("folks#show", :id => "1")
    end

    it "routes to #edit" do
      get("/folks/1/edit").should route_to("folks#edit", :id => "1")
    end

    it "routes to #create" do
      post("/folks").should route_to("folks#create")
    end

    it "routes to #update" do
      put("/folks/1").should route_to("folks#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/folks/1").should route_to("folks#destroy", :id => "1")
    end

  end
end
