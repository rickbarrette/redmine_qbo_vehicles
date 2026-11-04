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
  module Patches
    # Shows the vehicle by name in an issue's history, emails and PDF. Redmine records it by id, like
    # its own fields, but only looks up names for the fields it knows about. The id stays in the
    # database, so existing history entries show names too.
    module IssuesHelperPatch
      def show_detail(detail, no_html = false, options = {})
        return super unless detail.property == 'attr' && detail.prop_key == 'vehicle_id'

        # Hand Redmine a copy with names in place of ids, so it formats it like any other change
        named = JournalDetail.new(property: detail.property, prop_key: detail.prop_key,
                                  old_value: vehicle_journal_name(detail.old_value),
                                  value: vehicle_journal_name(detail.value))
        named.id = detail.id
        named.journal_id = detail.journal_id
        super(named, no_html, options)
      end

      private

      # The vehicle's name, or the id when it no longer exists. Cached for the request.
      def vehicle_journal_name(id)
        return id if id.blank?

        @vehicle_journal_names ||= {}
        @vehicle_journal_names[id] ||= Vehicle.find_by(id: id)&.to_s.presence || id
      end
    end
  end
end
