#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module Vehicles
  module Hooks
    # The vehicle on redmine_qbo_calendar's appointment pages, form, lists, tooltips and calendar
    class CalendarViewHookListener < Redmine::Hook::ViewListener
      render_on :view_customer_appointments_form_details, partial: 'vehicles/appointment_field'
      render_on :view_customer_appointments_show_details, partial: 'vehicles/appointment_attribute'
      render_on :view_customer_appointments_list_header, partial: 'vehicles/appointment_list_header'
      render_on :view_customer_appointments_list_row, partial: 'vehicles/appointment_list_row'
      render_on :view_customer_appointments_tooltip, partial: 'vehicles/appointment_tooltip'
      render_on :view_customer_appointments_calendar_event, partial: 'vehicles/appointment_calendar_event'
    end
  end
end
