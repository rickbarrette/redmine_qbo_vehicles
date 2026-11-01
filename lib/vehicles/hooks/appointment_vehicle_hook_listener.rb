#The MIT License (MIT)
#
#Copyright (c) 2016 - 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module Vehicles
  module Hooks

    # A vehicle added from an appointment (redmine_qbo_calendar) that has none becomes the appointment's vehicle
    class AppointmentVehicleHookListener < Redmine::Hook::Listener

      def controller_vehicles_new_after_save(context = {})
        appointment_id = context[:params] && context[:params][:appointment_id]
        vehicle = context[:vehicle]
        return if appointment_id.blank? || vehicle.nil? || !Redmine::Plugin.installed?(:redmine_qbo_calendar)

        appointment = CustomerAppointment.find_by(id: appointment_id)
        # Only the customer's own appointment, only when it has no vehicle yet, and only for someone who may edit it
        return if appointment.nil? || appointment.vehicle_id.present? || appointment.customer_id != vehicle.customer_id
        return unless User.current.allowed_to?(:edit_customer_appointments, nil, global: true)

        # Just the vehicle: saving the whole appointment would re-check its date and hours
        appointment.update_columns(vehicle_id: vehicle.id)
        if (controller = context[:controller])
          controller.flash[:notice] = I18n.t(:notice_vehicle_added_to_appointment, vehicle: vehicle.to_s)
        end
        Rails.logger.info "[Vehicles] Vehicle ##{vehicle.id} set on appointment ##{appointment.id}"
      rescue StandardError => e
        Rails.logger.warn "[Vehicles] Could not set vehicle ##{vehicle&.id} on appointment ##{appointment_id}: #{e.message}"
      end
    end
  end
end
