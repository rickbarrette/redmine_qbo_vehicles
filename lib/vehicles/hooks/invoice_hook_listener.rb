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

    class InvoiceHookListener < Redmine::Hook::ViewListener

      include IssuesHelper

      # Called by Redmine QBO Invoice
      def process_invoice_custom_fields(context={})
        Rails.logger.info "redmine_qbo_vehicles.process_invoice_custom_fields"
        issue = context[:issue]
        invoice = context[:invoice]

        # update the invoive custom fields with infomation from the issue if available
        context[:invoice].custom_fields.each do |cf|

          Rails.logger.info "Checking invoice.custom field: #{cf.name}"
          
          # VIN from the attached vehicle 
          begin
            if cf.name.eql? "VIN"
              # Only update if blank to prevent infite loops
              # TODO check cf_sync_confict flag once implemented
              if cf.string_value.to_s.blank?

                Rails.logger.info "VIN was blank, updating the invoice vin in quickbooks"
                vin = context[:issue].vehicle.vin
                break if vin.nil?
                
                if not cf.string_value.to_s.eql? vin
                  cf.string_value = vin.to_s
                  Rails.logger.info "VIN has changed"
                  context[:is_changed] = true
                end

              end

            end
          rescue
            #do nothing
            Rails.logger.info "redmine_qbo_vehicles.process_invoice_custom_fields failed, skipping"
            return nil
          end
        end

        return context if context[:is_changed]
        
        return nil
      end
    end

  end

end