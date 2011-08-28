require 'spec_helper'

describe "folks/index.html.erb" do
  before(:each) do
    assign(:folks, [
      stub_model(Folk,
        :name => "Name"
      ),
      stub_model(Folk,
        :name => "Name"
      )
    ])
  end

  it "renders a list of folks" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
  end
end
