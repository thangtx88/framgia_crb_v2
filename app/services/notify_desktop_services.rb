class NotifyDesktopServices
  def initialize event, current_user
    @event = event
    @current_user = current_user
  end

  def perform
    notify_desktop_when_create_event
  end

  private
  def notify_desktop_when_create_event
    event_title = @event.title
    event_start = @event.start_date.strftime Settings.event.format_datetime
    event_finish = @event.finish_date.strftime Settings.event.format_datetime
    event_desc = @event.description
    from_user = @current_user.name
    notify_to_attendees = Array.new
    @event.attendees.each do |attendee|
      notify_to_attendees << attendee.user_name
    end
    notify_data = {title: event_title, start: event_start, finish: event_finish,
      desc: event_desc, attendees: notify_to_attendees.join(", "),
      from_user: from_user}
    @event.attendees.each do |attendee|
      notify_data[:to_user] = attendee.user_name
      if @current_user.id != attendee.user_id
        WebsocketRails.users[attendee.user_id].send_message(:websocket_notify,
          notify_data)
      end
    end
  end
end
