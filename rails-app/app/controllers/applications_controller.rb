class ApplicationsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_application, only: [:show, :update]

  def index
    applications = Application.all
    render json: applications, each_serializer: ApplicationSerializer
  end

  def create
    application = Application.new(application_params)
    
    if application.save
      application.sync_chat_counter_to_redis
      render json: application, status: :created, serializer: ApplicationSerializer
    else
      render json: { errors: application.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: @application, serializer: ApplicationSerializer
  end

  def update
    if @application.update(application_params)
      render json: @application, serializer: ApplicationSerializer
    else
      render json: { errors: @application.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_application
    @application = Application.find_by(token: params[:id])
    unless @application
      render json: { error: "Application not found" }, status: :not_found
    end
  end

  def application_params
    params.require(:application).permit(:name)
  end
end
