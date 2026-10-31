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
  # The customer's vehicle that matches an estimate's VIN (redmine_qbo's QuickBooks VIN field)
  module EstimateVehicle
    module_function

    # The VIN on the estimate, or nil. Read by redmine_qbo with QuickBooks' newer custom fields: the local
    # estimate's details leave them out, so a VIN field added recently in QuickBooks would never match.
    def vin(estimate)
      return nil unless estimate
      QboFields.estimate_vin(estimate.id)
    rescue StandardError
      nil
    end

    # The customer's vehicles, for picking one
    def vehicles(estimate)
      customer = estimate&.customer
      customer.respond_to?(:vehicles) ? customer.vehicles.to_a : []
    end

    # The customer's vehicle whose VIN is on the estimate, or nil
    def match(estimate, estimate_vin = vin(estimate))
      return nil if estimate_vin.blank?

      vehicles(estimate).detect { |v| v.vin.to_s.strip.casecmp?(estimate_vin) }
    end

    # A customer's vehicle with the given VIN, or nil
    def for_vin(customer, vin)
      return nil if vin.blank? || !customer.respond_to?(:vehicles)

      customer.vehicles.detect { |v| v.vin.to_s.strip.casecmp?(vin.to_s.strip) }
    end
  end
end
