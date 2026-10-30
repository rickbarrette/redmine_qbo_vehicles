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

    class PdfHookListener < Redmine::Hook::ViewListener

      include IssuesHelper
      
      # Add vehicle information to the left column of the issue PDF
      def pdf_left(context={})
        output = []
        output << [l(:field_vehicles), context[:issue].vehicle ? context[:issue].vehicle.to_s : nil]
        output << pdf_vin_row(context[:issue].vehicle&.vin)
        output << [l(:field_notes), context[:issue].vehicle ? context[:issue].vehicle.notes : nil]
        return output
      end

      private

      # Same as on screen: 17-character VINs with the last 8 in bold (what dealerships ask for when
      # ordering parts), older or short VINs plain. Bold needs redmine_qbo's HTML values in its PDF grid;
      # with an older redmine_qbo the last 8 are set apart with a space instead.
      def pdf_vin_row(vin)
        vin = vin.to_s
        return [l(:field_vin), nil] if vin.empty?
        return [l(:field_vin), vin] unless vin.length == 17

        first, last = ERB::Util.h(vin[0, 9]), ERB::Util.h(vin[9, 8])
        if defined?(RedmineQbo::Patches::PdfPatch::PDF_HTML_VALUES)
          [l(:field_vin), vin, { html: "#{first}<b>#{last}</b>" }]
        else
          [l(:field_vin), "#{vin[0, 9]} #{vin[9, 8]}"]
        end
      end
        
    end
  end
end