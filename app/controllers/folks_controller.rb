class FolksController < ApplicationController
  # GET /folks
  # GET /folks.xml
  def index
    @folks = Folk.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @folks }
    end
  end

  # GET /folks/1
  # GET /folks/1.xml
  def show
    @folk = Folk.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @folk }
    end
  end

  # GET /folks/new
  # GET /folks/new.xml
  def new
    @folk = Folk.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @folk }
    end
  end

  # GET /folks/1/edit
  def edit
    @folk = Folk.find(params[:id])
  end

  # POST /folks
  # POST /folks.xml
  def create
    @folk = Folk.new(params[:folk])

    respond_to do |format|
      if @folk.save
        format.html { redirect_to(@folk, :notice => 'Folk was successfully created.') }
        format.xml  { render :xml => @folk, :status => :created, :location => @folk }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @folk.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /folks/1
  # PUT /folks/1.xml
  def update
    @folk = Folk.find(params[:id])

    respond_to do |format|
      if @folk.update_attributes(params[:folk])
        format.html { redirect_to(@folk, :notice => 'Folk was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @folk.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /folks/1
  # DELETE /folks/1.xml
  def destroy
    @folk = Folk.find(params[:id])
    @folk.destroy

    respond_to do |format|
      format.html { redirect_to(folks_url) }
      format.xml  { head :ok }
    end
  end
end
