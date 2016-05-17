class Api::EventsController < ApplicationController
  respond_to :json
  before_action only: [:edit, :update, :destroy] do
    load_event
    validate_permission_change_of_calendar @event.calendar
  end

  def index
    if params[:page].present? || params[:calendar_id]
      @data = current_user.events.upcoming_event(params[:calendar_id]).
        page(params[:page]).per Settings.users.upcoming_event
      respond_to do |format|
        format.html {
          render partial: "users/event", locals: {events: @data, user: current_user}
        }
      end
    else
      @events = Event.in_calendars params[:calendars]
      @data = @events.map{|event| event.json_data(current_user.id)}
      render json: @data
    end
  end

  def update
    @event = Event.find_by id: params[:id]
    if params[:start_repeat].nil?
      params[:start_repeat] = params[:start_date]
    else
      params[:start_repeat] = params[:start_repeat]
    end
    if params[:end_repeat].nil?
      difference = (params[:start_date].to_date - @event.start_date.to_date).to_i
      params[:end_repeat] = @event.end_repeat + difference.days
    else
      params[:end_repeat] = params[:end_repeat].to_date + 1.days
    end
    render text: @event.update_attributes(event_params) ?
      t("events.flashs.updated") : t("events.flashs.not_updated")
  end

  def show
    @event = Event.find_by id: params[:id]
    respond_to do |format|
      format.html {
        render partial: "events/popup_event",
          locals: {user: current_user, event: @event}
      }
    end
  end

  def destroy
    @event = Event.find_by id: params[:id]
    if @event.repeat_type.nil? || (@event.repeat_type && 
      params[:exception_type] == "delete_all" && @event.parent_id.nil?)
      destroy_event @event
    elsif params[:exception_type] == "delete_all"
      destroy_event @event.event_parent
      render text: t("events.flashs.deleted") 
    else
      destroy_event_repeat @event, params[:exception_type]
      render text: t("events.flashs.deleted") 
    end
  end

  private
  def event_params
    params.permit :id, :title, :all_day, :start_repeat, :end_repeat,
      :start_date, :finish_date
  end

  def load_event
    @event = Event.find_by id: params[:id]
  end

  def destroy_event event
    if event.destroy
      render text: t("events.flashs.deleted") 
    else
      render text: t("events.flashs.not_deleted")
    end
  end

  def destroy_event_repeat event, exception_type
    event_exception = event.dup
    event_exception.update_attributes(exception_type: exception_type, 
      exception_time: event.start_date, parent_id: event.id)
  end
end
