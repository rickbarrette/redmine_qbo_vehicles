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

      # Edit Issue Form
      # Here we build the required form components before passing them to a partial view formatting. 
      def pdf_left(context={})
        issue = context[:issue]
        output = []
        v = issue.vehicle
        vehicle = v ? v.to_s : nil
        vin = v ? v.vin : nil
        notes = v ? v.notes : nil
        output << [l(:field_vehicles), vehicle]
        output << [l(:field_vin), vin ? vin.gsub(/(.{9})/, '\1 ') : nil]
        output << [l(:field_notes), notes]
        return output
      end
        
    end
  end
end