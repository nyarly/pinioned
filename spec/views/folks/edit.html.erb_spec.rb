require 'spec_helper'

describe "folks/edit.html.erb" do
  before(:each) do
    @folk = assign(:folk, stub_model(Folk,
      :name => "MyString"
    ))
  end

  it "renders the edit folk form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => folks_path(@folk), :method => "post" do
      assert_select "input#folk_name", :name => "folk[name]"
    end
  end
end
