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
    # The vehicle on redmine_qbo_calendar's appointments, through the calendar's hooks: saved from the
    # appointment form, filled in from links, offered for the customer, and passed to new issues
    class CalendarHookListener < Redmine::Hook::Listener
      def qbo_calendar_appointment_attributes(_context = {})
        [:vehicle_id]
      end

      def qbo_calendar_appointment_preloads(_context = {})
        [:vehicle]
      end

      # A new appointment from a link with a vehicle (a customer page's ticked vehicle, an estimate's VIN):
      # used only when it's the appointment's customer's
      def qbo_calendar_new_appointment(context = {})
        appointment = context[:appointment]
        vehicle_id = context[:params] && context[:params][:vehicle_id]
        customer = appointment&.customer
        return if vehicle_id.blank? || !customer.respond_to?(:vehicles)

        appointment.vehicle_id = vehicle_id if customer.vehicles.exists?(id: vehicle_id)
      end

      # The customer's vehicles for the form's Vehicle list (vehicles/_appointment_field)
      def qbo_calendar_customer_options(context = {})
        customer = context[:customer]
        return {} unless customer.respond_to?(:vehicles)

        { 'appointment_vehicle_id' => customer.vehicles.map { |v| { id: v.id, name: v.name } } }
      end

      # The appointment page's New issue link
      def qbo_calendar_new_issue_params(context = {})
        vehicle_id = context[:appointment]&.vehicle_id
        vehicle_id ? { vehicle_id: vehicle_id } : {}
      end
    end
  end
end
