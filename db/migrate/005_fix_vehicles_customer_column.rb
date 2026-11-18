#The MIT License (MIT)
#
#Copyright (c) 2016 - 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Vehicles belong to a customer through vehicles.customer_id. Until 2026.11.9, a new install's first migration
# made the column customers_id instead (databases that had vehicles from redmine_qbo got customer_id from there),
# which breaks the vehicle form. This renames it, and does nothing where the column is already right.
class FixVehiclesCustomerColumn < ActiveRecord::Migration[7.0]

  def up
    return unless column_exists?(:vehicles, :customers_id)
    return if column_exists?(:vehicles, :customer_id)

    rename_column :vehicles, :customers_id, :customer_id
  end

  def down
    # Nothing to undo: customer_id is the right name
  end

end
