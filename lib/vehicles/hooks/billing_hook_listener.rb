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

    # Hooks for redmine_qbo's estimates and invoices
    class BillingHookListener < Redmine::Hook::Listener

      # Each work order's VIN (its vehicle) and mileage (Redmine's issue custom field named "Mileage"), keyed
      # by the QuickBooks VIN and Mileage fields. The editor script (vehicles/_qbo_editor_script) uses them
      # when time or estimates are imported; redmine_qbo_lineitems puts them on its estimates.
      def qbo_billing_issue_values(context = {})
        issues = Array(context[:issues])
        values = {}
        if (vin = QboFields.vin_field)
          values[vin.id.to_s] = issues.each_with_object({}) do |issue, by_issue|
            value = issue.respond_to?(:vehicle) ? issue.vehicle&.vin : nil
            by_issue[issue.id] = value if value.present?
          end
        end
        if (mileage = QboFields.mileage_field)
          values[mileage.id.to_s] = mileage_by_issue(issues)
        end
        values
      end

      # The customer's vehicles as suggestions for the VIN box
      def qbo_billing_field_options(context = {})
        customer = context[:customer]
        vin = QboFields.vin_field
        return {} unless vin && customer.respond_to?(:vehicles)

        { vin.id.to_s => customer.vehicles.select { |v| v.vin.present? }.map { |v| { value: v.vin, label: v.to_s } } }
      end

      # Values for a document's work orders (e.g. an invoice made from an estimate that leaves them blank):
      # their vehicle's VIN when they share one, and the highest mileage
      def qbo_billing_field_defaults(context = {})
        issues = Array(context[:issues])
        defaults = {}
        if (vin = QboFields.vin_field)
          vins = issues.filter_map { |issue| issue.respond_to?(:vehicle) ? issue.vehicle&.vin.presence : nil }.map(&:upcase).uniq
          defaults[vin.id.to_s] = vins.first if vins.size == 1
        end
        if (mileage = QboFields.mileage_field)
          highest = mileage_by_issue(issues).values.filter_map { |m| m.to_s.delete(',').strip.presence&.to_f }.max
          defaults[mileage.id.to_s] = (highest % 1).zero? ? highest.to_i.to_s : highest.to_s if highest
        end
        defaults
      end

      # redmine_qbo_calendar's Add appointment link on an estimate: the customer's vehicle with the estimate's VIN
      def qbo_calendar_appointment_params(context = {})
        vin = QboFields.vin_field
        return {} unless vin

        vehicle = EstimateVehicle.for_vin(context[:customer], (context[:custom_fields] || {})[vin.id.to_s])
        vehicle ? { vehicle_id: vehicle.id } : {}
      end

      # Issues created from an estimate get a vehicle: the one picked on the Create issues page (or passed in,
      # e.g. redmine_qbo_calendar's appointment vehicle; blank means none), else the customer's vehicle whose
      # VIN is on the estimate
      def qbo_billing_build_issue(context = {})
        issue = context[:issue]
        return unless issue.respond_to?(:vehicle_id=)

        defaults = (context[:defaults] || {}).to_h.symbolize_keys
        vehicle_id = defaults.key?(:vehicle_id) ? defaults[:vehicle_id].presence : Vehicles::EstimateVehicle.match(context[:estimate])&.id
        issue.vehicle_id = vehicle_id if vehicle_id
      end

      # One vehicle per invoice (OSOR SOP): an invoice whose work orders are for more than one vehicle
      # isn't saved
      def qbo_billing_validate(context = {})
        return nil unless context[:document].to_s == 'invoice'

        vehicles = Array(context[:issues]).filter_map { |issue| issue.respond_to?(:vehicle) ? issue.vehicle : nil }.uniq
        return nil if vehicles.size <= 1

        details = vehicles.map do |vehicle|
          numbers = Array(context[:issues]).select { |issue| issue.vehicle == vehicle }.map { |issue| "##{issue.id}" }
          "#{vehicle} (#{numbers.join(', ')})"
        end
        I18n.t(:error_one_vehicle_per_invoice, vehicles: details.join('; '))
      end

      private

      # { issue_id => mileage } from the issue custom field named "Mileage"; empty without that field
      def mileage_by_issue(issues)
        issue_ids = issues.map(&:id)
        field = IssueCustomField.all.detect { |f| f.name.to_s.strip.casecmp?('mileage') }
        return {} if field.nil? || issue_ids.empty?

        CustomValue.where(customized_type: 'Issue', customized_id: issue_ids, custom_field_id: field.id)
                   .where.not(value: [nil, ''])
                   .pluck(:customized_id, :value)
                   .to_h
      end

    end
  end
end
