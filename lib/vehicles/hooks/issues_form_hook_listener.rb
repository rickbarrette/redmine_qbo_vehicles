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

      # Edit Issue Form
      # Here we build the required form components before passing them to a partial view formatting. 
      def view_issues_form_details_bottom(context={})
        f = context[:form]
        issue = context[:issue]

        # check project level vehicle ownership first
        # if context[:project]
        #   selected_vehicle = context[:project].vehicle.id unless context[:project].vehicle.nil?
        # end

        # Check to see if the issue already belongs to a customer
        selected_vehicle = issue.vehicle.id unless issue.vehicle.nil?

        # Load customer's vehicles
        if issue.customer
          if issue.customer.vehicles
            vehicles = issue.customer.vehicles.pluck(:name, :id)
          else
            vehicles = [nil].compact
          end
        else
          vehicles = [nil].compact
        end

        # Generate the drop down list of vehicles
        vehicle = f.select :vehicle_id, vehicles, :selected => selected_vehicle, include_blank: true

        # Pass all prebuilt form components to our partial
        context[:controller].send(:render_to_string, {
          :partial => 'issues/form_hook_vehicles',
            locals: {
              vehicle: vehicle
            } 
          })
      end
      
    end
  end
end