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
        output << [l(:field_vin), context[:issue].vehicle ? context[:issue].vehicle.vin.gsub(/(.{9})/, '\1 ') : nil]
        output << [l(:field_notes), context[:issue].vehicle ? context[:issue].vehicle.notes : nil]
        return output
      end
        
    end
  end
end