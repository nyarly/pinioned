require 'spec_helper'

describe "folks/new.html.erb" do
  before(:each) do
    assign(:folk, stub_model(Folk,
      :name => "MyString"
    ).as_new_record)
  end

  it "renders new folk form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => folks_path, :method => "post" do
      assert_select "input#folk_name", :name => "folk[name]"
    end
  end
end
