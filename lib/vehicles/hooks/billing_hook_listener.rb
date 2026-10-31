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

      # Each work order's VIN, so the invoice's VIN box is filled when its time or estimates are imported
      def qbo_billing_issue_values(context = {})
        vins = Array(context[:issues]).each_with_object({}) do |issue, by_issue|
          vin = issue.respond_to?(:vehicle) ? issue.vehicle&.vin : nil
          by_issue[issue.id] = vin if vin.present?
        end
        { vin: vins }
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

    end
  end
end
