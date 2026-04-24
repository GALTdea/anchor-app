class Spaces::ChildProfilesController < ApplicationController
  before_action :set_space
  before_action :set_child_profile, only: %i[show edit update destroy]

  def index
    @child_profile = @space.child_profiles.build
    authorize @child_profile, :index?
    @child_profiles = @space.child_profiles.active.order(first_name: :asc)
  end

  def show
    authorize @child_profile
    @results_presenter = ChildProfileResultsPresenter.new(@child_profile)
    @current_profile = @results_presenter.current_profile
    @recommendations = @results_presenter.active_recommendations
    @latest_assessment_response = @results_presenter.latest_assessment_response

    authorize @current_profile
    authorize Recommendation.new(child_profile: @child_profile), :index?
  end

  def new
    @child_profile = @space.child_profiles.build
    authorize @child_profile
  end

  def create
    @child_profile = @space.child_profiles.build(child_profile_params)
    authorize @child_profile

    respond_to do |format|
      if @child_profile.save
        format.html { redirect_to space_child_profile_path(@space, @child_profile), notice: "Child profile was successfully created." }
        format.json { render :show, status: :created, location: [ @space, @child_profile ] }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @child_profile.errors, status: :unprocessable_content }
      end
    end
  end

  def edit
    authorize @child_profile
  end

  def update
    authorize @child_profile

    respond_to do |format|
      if @child_profile.update(child_profile_params)
        format.html { redirect_to space_child_profile_path(@space, @child_profile), notice: "Child profile was successfully updated." }
        format.json { render :show, status: :ok, location: [ @space, @child_profile ] }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @child_profile.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    authorize @child_profile

    @child_profile.update!(status: :archived)

    respond_to do |format|
      format.html { redirect_to space_child_profiles_path(@space), notice: "Child profile was archived." }
      format.json { head :no_content }
    end
  end

  private

  def set_space
    @space = Space.find(params[:space_id])
  end

  def set_child_profile
    @child_profile = @space.child_profiles.friendly.find(params[:id])
  end

  def child_profile_params
    params.require(:child_profile).permit(:first_name, :last_name, :date_of_birth, :notes)
  end
end
