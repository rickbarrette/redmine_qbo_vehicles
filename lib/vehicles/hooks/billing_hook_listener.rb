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

      # Each work order's VIN and mileage, so the invoice's VIN and mileage boxes are filled when its time or
      # estimates are imported (redmine_qbo uses the highest mileage). Mileage comes from Redmine's issue
      # custom field named "Mileage" (any capitalisation).
      def qbo_billing_issue_values(context = {})
        issues = Array(context[:issues])
        vins = issues.each_with_object({}) do |issue, by_issue|
          vin = issue.respond_to?(:vehicle) ? issue.vehicle&.vin : nil
          by_issue[issue.id] = vin if vin.present?
        end
        { vin: vins, mileage: mileage_by_issue(issues) }
      end

      # The customer's vehicles as VIN suggestions for the estimate/invoice VIN box
      def qbo_billing_vin_options(context = {})
        customer = context[:customer]
        return [] unless customer.respond_to?(:vehicles)

        customer.vehicles.select { |v| v.vin.present? }.map { |v| { vin: v.vin, name: v.to_s } }
      end

      # The VIN a new estimate or invoice starts with: the work orders' vehicle when they share one, else the
      # customer's only vehicle with a VIN. Nothing when it's ambiguous (work orders for several vehicles, or a
      # customer with several and no work orders); the VIN box's suggestions still list them.
      def qbo_billing_default_vin(context = {})
        vins = Array(context[:issues]).filter_map { |issue| issue.respond_to?(:vehicle) ? issue.vehicle&.vin.presence : nil }
                                      .map(&:upcase).uniq
        return vins.first if vins.size == 1
        return nil if vins.size > 1

        customer = context[:customer]
        return nil unless customer.respond_to?(:vehicles)

        with_vin = customer.vehicles.select { |v| v.vin.present? }
        with_vin.first.vin if with_vin.size == 1
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
