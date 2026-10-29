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

    class IssuesFormHookListener < Redmine::Hook::ViewListener

      include IssuesHelper

      def view_issues_form_details_bottom(context={})

        # The selected customer's vehicles. Changing the customer reloads the issue form (redmine_qbo's
        # updateIssueFrom), which re-renders this list for the new customer.
        #
        # An existing issue keeps its vehicle in the list while its customer is unchanged: if the
        # vehicle was sold since, it belongs to another customer now, and leaving it out would blank it
        # on the next save, dropping the issue from the vehicle's history. Once the customer is changed
        # in the form, only the new customer's vehicles are offered.
        issue = context[:issue]
        vehicles = issue.customer&.vehicles.to_a || []
        if issue.vehicle && issue.persisted? && !issue.customer_id_changed?
          vehicles |= [issue.vehicle]
        end

        context[:controller].send(:render_to_string, {
          partial: 'issues/form_hook_vehicles',
          locals: {
            vehicle: context[:form].select(
              :vehicle_id,
              vehicles.map { |v| [v.name, v.id] },
              selected: issue.vehicle&.id,
              include_blank: true
            )
          }
        })

      end

    end
  end
end