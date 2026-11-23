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
    # The vehicle on redmine_qbo_tickets' tickets.
    #
    # Key tickets (an appointment's): a Vehicle line, and a QR code that opens the vehicle, or, when the
    # appointment has none yet, adds one for the customer (it then becomes the appointment's vehicle, see
    # AppointmentVehicleHookListener).
    #
    # Intake forms (kind 'intake', a customer's, without an appointment): the vehicle ticked on the customer page
    # or printed from the vehicle's page (params' vehicle_id, one of the customer's) with its VIN, and a QR code
    # that opens it, or, without one, adds a vehicle for the customer.
    class TicketsHookListener < Redmine::Hook::Listener
      include Rails.application.routes.url_helpers

      def qbo_tickets_details(context = {})
        if context[:kind] == 'intake'
          vehicle = intake_vehicle(context)
          return [] unless vehicle

          [[I18n.t(:field_vehicle), vehicle.to_s], [I18n.t(:field_vin), vehicle.vin]]
        else
          vehicle = appointment_vehicle(context[:appointment])
          vehicle ? [[I18n.t(:field_vehicle), vehicle.to_s]] : []
        end
      end

      def qbo_tickets_qr(context = {})
        return intake_qr(context) if context[:kind] == 'intake'

        appointment = context[:appointment]
        base_url = context[:base_url].to_s
        return {} unless appointment.respond_to?(:vehicle_id)

        if (vehicle = appointment_vehicle(appointment))
          { url: base_url + vehicle_path(vehicle), caption: I18n.t(:text_ticket_qr_vehicle) }
        elsif appointment.customer_id
          path = new_vehicle_path(customer_id: appointment.customer_id, appointment_id: appointment.id,
                                  back_url: customer_appointment_path(appointment))
          { url: base_url + path, caption: I18n.t(:text_ticket_qr_add_vehicle) }
        else
          {}
        end
      end

      private

      def appointment_vehicle(appointment)
        appointment.respond_to?(:vehicle) ? appointment.vehicle : nil
      end

      # The intake form's vehicle: params' vehicle_id, when it's the customer's
      def intake_vehicle(context)
        customer = context[:customer]
        id = (context[:params] || {})['vehicle_id'].to_s
        return nil if customer.nil? || id.blank?

        customer.vehicles.find_by(id: id)
      end

      def intake_qr(context)
        customer = context[:customer]
        return {} unless customer

        base_url = context[:base_url].to_s
        if (vehicle = intake_vehicle(context))
          { url: base_url + vehicle_path(vehicle), caption: I18n.t(:text_ticket_qr_vehicle) }
        else
          path = new_vehicle_path(customer_id: customer.id, back_url: customer_path(customer))
          { url: base_url + path, caption: I18n.t(:text_ticket_qr_add_vehicle) }
        end
      end
    end
  end
end
