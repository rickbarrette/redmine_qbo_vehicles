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
    class ViewHookListener < Redmine::Hook::ViewListener

      def view_layouts_base_html_head(context = {})
        safe_join([
          stylesheet_link_tag('style', plugin: :redmine_qbo_vehicles, media: :all),
          # VIN click-to-copy, written into the page (see vehicles/_copy_vin_script)
          context[:hook_caller].render(partial: 'vehicles/copy_vin_script')
        ])
      end

      # redmine_qbo's estimate/invoice editor: VIN and Mileage behaviour (vehicles/_qbo_editor_script)
      def view_qbo_estimate_form_bottom(context = {})
        context[:hook_caller].render(partial: 'vehicles/qbo_editor_script')
      end

      # redmine_qbo's Create issues from estimate page: a Vehicle for all the issues, preselected from the
      # estimate's VIN
      def view_qbo_estimate_issues_form(context = {})
        return '' unless context[:estimate]

        context[:hook_caller].render(partial: 'vehicles/estimate_issues_vehicle',
                                     locals: { estimate: context[:estimate], defaults: context[:defaults] })
      end

    end
  end
end