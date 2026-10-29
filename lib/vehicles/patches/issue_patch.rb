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
  module Patches

    # Patches Redmine's Issues dynamically.
    # Adds a relationship for attahcing a vehilce to an issue
    module IssuePatch
      extend ActiveSupport::Concern

      prepended do
        belongs_to :vehicle, optional: true

        # The vehicle must belong to the issue's customer. Only checked when either changes, so older
        # issues with a mismatch don't block unrelated edits.
        validate :vehicle_matches_customer, if: -> { will_save_change_to_vehicle_id? || will_save_change_to_customer_id? }
      end

      private

      def vehicle_matches_customer
        return if vehicle_id.blank?

        if vehicle.nil?
          errors.add(:base, ::I18n.t(:error_vehicle_not_found_for_issue))
        elsif customer_id.present? && vehicle.customer_id != customer_id
          errors.add(:base, ::I18n.t(:error_vehicle_customer_mismatch, vehicle: vehicle.to_s))
        end
      end
      
    end
  end  
end