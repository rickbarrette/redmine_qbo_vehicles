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
  # The QuickBooks custom fields this plugin fills on redmine_qbo's estimates and invoices, found by name:
  # a text field named like "VIN" and, optionally, one named like "Mileage" or "Odometer". redmine_qbo shows
  # every enabled custom field; this plugin supplies their values (hooks) and editor behaviour (script).
  module QboFields
    VIN_NAME = /\bvin\b/i
    MILEAGE_NAME = /mileage|odometer|\bmiles\b/i

    module_function

    def vin_field
      company.custom_field_matching(VIN_NAME)
    end

    def mileage_field
      company.custom_fields.detect { |f| f.name.to_s =~ MILEAGE_NAME && f.name.to_s !~ VIN_NAME }
    end

    # The VIN on an estimate (read by redmine_qbo with QuickBooks' newer custom fields), or nil
    def estimate_vin(estimate_id)
      field = vin_field
      field ? RedmineQboBilling::EstimateWriter.custom_field_value(estimate_id, field) : nil
    end

    def company
      RedmineQboBilling::Company
    end
  end
end
