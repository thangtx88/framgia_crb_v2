class EventsController < ApplicationController
  load_and_authorize_resource
  before_action :load_calendars, only: [:new, :edit]
  before_action :load_attendees, :load_notification_event,
    only: [:new, :edit, :show]
  before_action only: [:edit, :update, :destroy] do
    validate_permission_change_of_calendar @event.calendar
  end
  before_action only: [:show] do
    validate_permission_see_detail_of_calendar @event.calendar
  end

  def new
    if params[:event_id]
      @event = Event.find(params[:event_id]).dup
    end
  end

  def show
    @attendees = @event.attendees
    @notification_events = @event.notification_events
  end

  def create
    @event = current_user.events.new event_params
    if event_params[:start_repeat].blank?
      @event.start_repeat = event_params[:start_date]
    else
      @event.start_repeat = event_params[:start_repeat]
    end
    if event_params[:end_repeat].blank?
      @event.end_repeat = event_params[:finish_date].to_date
    else
      @event.end_repeat = event_params[:end_repeat].to_date
    end

    respond_to do |format|
      if @event.save
        ChatworkServices.new(@event).perform
        NotificationDesktopService.new(@event, current_user).perform

        if valid_params? params[:repeat_ons], event_params[:repeat_type]
          @repeat_ons = params[:repeat_ons]
          @repeat_ons.each do |repeat_on|
            RepeatOn.create! repeat_on: repeat_on, event_id: @event.id
          end
        end

        if @event.repeat_type.present?
          FullcalendarService.new.generate_event_delay @event
        else
          NotificationEmailService.new(@event).perform
        end

        flash[:success] = t "events.flashs.created"
        format.html do
          redirect_to user_event_path current_user, @event
        end
        format.js {@data = @event.json_data(current_user.id)}
      else
        flash[:error] = t "events.flashs.not_created"
        format.html do
          redirect_to new_user_event_path current_user
        end
        format.js
      end
    end
  end

  def edit
    @repeat_ons = @event.repeat_ons
  end

  def update
    if @event.update_attributes event_params
      GoogleCalendarService.update_event @event
      NotificationDesktopService.new(@event, current_user).perform
      flash[:success] = t "events.flashs.updated"
      redirect_to user_event_path current_user, @event
    else
      render :edit
    end
  end

  def destroy
    if @event.destroy
      GoogleCalendarService.delete_event @event
      flash[:success] = t "events.flashs.deleted"
    else
      flash[:danger] = t "events.flashs.not_deleted"
    end
    redirect_to root_path
  end

  private
  def event_params
    params.require(:event).permit Event::ATTRIBUTES_PARAMS
  end

  def load_calendars
    @calendars = current_user.manage_calendars
  end

  def load_attendees
    @users = User.all
    @attendee = Attendee.new
  end

  def load_notification_event
    @notifications = Notification.all
    @notification_event = NotificationEvent.new
  end

  def valid_params? repeat_on, repeat_type
    repeat_on.present? && repeat_type == Settings.repeat.repeat_type.weekly
  end
end
