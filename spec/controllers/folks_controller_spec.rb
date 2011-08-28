require 'spec_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

describe FolksController do

  # This should return the minimal set of attributes required to create a valid
  # Folk. As you add validations to Folk, be sure to
  # update the return value of this method accordingly.
  def valid_attributes
    {}
  end

  describe "GET index" do
    it "assigns all folks as @folks" do
      folk = Folk.create! valid_attributes
      get :index
      assigns(:folks).should eq([folk])
    end
  end

  describe "GET show" do
    it "assigns the requested folk as @folk" do
      folk = Folk.create! valid_attributes
      get :show, :id => folk.id.to_s
      assigns(:folk).should eq(folk)
    end
  end

  describe "GET new" do
    it "assigns a new folk as @folk" do
      get :new
      assigns(:folk).should be_a_new(Folk)
    end
  end

  describe "GET edit" do
    it "assigns the requested folk as @folk" do
      folk = Folk.create! valid_attributes
      get :edit, :id => folk.id.to_s
      assigns(:folk).should eq(folk)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new Folk" do
        expect {
          post :create, :folk => valid_attributes
        }.to change(Folk, :count).by(1)
      end

      it "assigns a newly created folk as @folk" do
        post :create, :folk => valid_attributes
        assigns(:folk).should be_a(Folk)
        assigns(:folk).should be_persisted
      end

      it "redirects to the created folk" do
        post :create, :folk => valid_attributes
        response.should redirect_to(Folk.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved folk as @folk" do
        # Trigger the behavior that occurs when invalid params are submitted
        Folk.any_instance.stub(:save).and_return(false)
        post :create, :folk => {}
        assigns(:folk).should be_a_new(Folk)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        Folk.any_instance.stub(:save).and_return(false)
        post :create, :folk => {}
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested folk" do
        folk = Folk.create! valid_attributes
        # Assuming there are no other folks in the database, this
        # specifies that the Folk created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        Folk.any_instance.should_receive(:update_attributes).with({'these' => 'params'})
        put :update, :id => folk.id, :folk => {'these' => 'params'}
      end

      it "assigns the requested folk as @folk" do
        folk = Folk.create! valid_attributes
        put :update, :id => folk.id, :folk => valid_attributes
        assigns(:folk).should eq(folk)
      end

      it "redirects to the folk" do
        folk = Folk.create! valid_attributes
        put :update, :id => folk.id, :folk => valid_attributes
        response.should redirect_to(folk)
      end
    end

    describe "with invalid params" do
      it "assigns the folk as @folk" do
        folk = Folk.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Folk.any_instance.stub(:save).and_return(false)
        put :update, :id => folk.id.to_s, :folk => {}
        assigns(:folk).should eq(folk)
      end

      it "re-renders the 'edit' template" do
        folk = Folk.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Folk.any_instance.stub(:save).and_return(false)
        put :update, :id => folk.id.to_s, :folk => {}
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested folk" do
      folk = Folk.create! valid_attributes
      expect {
        delete :destroy, :id => folk.id.to_s
      }.to change(Folk, :count).by(-1)
    end

    it "redirects to the folks list" do
      folk = Folk.create! valid_attributes
      delete :destroy, :id => folk.id.to_s
      response.should redirect_to(folks_url)
    end
  end

end
