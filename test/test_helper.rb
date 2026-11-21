#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require File.expand_path('../../../test/test_helper', __dir__)

module QboVehiclesTestHelper
  # Made-up 17-character VINs (valid characters, not real vehicles)
  VIN = '1C4HJXFG0JW123456'
  VIN2 = '1FTFW1E50KFA65432'

  def self.included(base)
    base.include ActiveJob::TestHelper
    base.fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles, :issues, :trackers,
                  :projects_trackers, :issue_statuses, :enabled_modules, :enumerations, :workflows
    base.setup do
      # Redmine's test environment runs jobs inline; queue them instead (VIN decodes are tested on their own)
      @saved_queue_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      # Never call NHTSA from tests; a test that needs a decode stubs http_get itself
      VinDecoder.any_instance.stubs(:http_get).raises(VinDecoder::TransientError, 'no network in tests')
      Vehicle.delete_all
      Customer.where(id: 9300..9399).delete_all
      Setting.plugin_redmine_qbo_vehicles = { 'mileage_custom_field_id' => '', 'subject_placeholder' => '<VEHICLE>' }
    end
    base.teardown { ActiveJob::Base.queue_adapter = @saved_queue_adapter }
  end

  # A customer, without sending it to QuickBooks
  def create_customer(id = 9301, name = 'Jane Customer')
    customer = Customer.new(id: id, name: name)
    customer.skip_qbo_push = true
    customer.save!
    customer
  end

  def create_vehicle(customer: nil, vin: VIN, **attributes)
    customer ||= Customer.find_by(id: 9301) || create_customer
    Vehicle.create!({ customer: customer, vin: vin, year: 2018, make: 'Jeep', model: 'Wrangler' }.merge(attributes))
  end

  # NHTSA's vPIC answer for one VIN (DecodeVinValues), with the given fields
  def vpic_body(fields = {})
    record = { 'ModelYear' => '2018', 'Make' => 'JEEP', 'Model' => 'Wrangler', 'Trim' => 'Sport', 'Series' => '',
               'Doors' => '4', 'BodyClass' => 'Sport Utility Vehicle (SUV)', 'DisplacementL' => '3.6',
               'EngineCylinders' => '6', 'ErrorCode' => '0', 'ErrorText' => '0 - VIN decoded clean.' }.merge(fields)
    { 'Count' => 1, 'Results' => [record] }.to_json
  end

  def stub_vpic(fields = {})
    VinDecoder.any_instance.stubs(:http_get).returns(vpic_body(fields))
  end

  # An issue custom field named "Mileage", on every tracker and project
  def mileage_field(name: 'Mileage')
    IssueCustomField.create!(name: name, field_format: 'string', is_for_all: true, tracker_ids: Tracker.ids)
  end

  def set_mileage(issue, field, value)
    CustomValue.where(customized: issue, custom_field: field).delete_all
    CustomValue.create!(customized: issue, custom_field: field, value: value)
  end

  def with_vehicle_settings(values)
    saved = Setting.plugin_redmine_qbo_vehicles
    Setting.plugin_redmine_qbo_vehicles = values
    yield
  ensure
    Setting.plugin_redmine_qbo_vehicles = saved
  end
end
