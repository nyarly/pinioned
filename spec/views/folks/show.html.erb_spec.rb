require 'spec_helper'

describe "folks/show.html.erb" do
  before(:each) do
    @folk = assign(:folk, stub_model(Folk,
      :name => "Name"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
  end
end
