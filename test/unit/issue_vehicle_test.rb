#The MIT License (MIT)
#
#Copyright (c) 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require File.expand_path('../test_helper', __dir__)

class IssueVehicleTest < ActiveSupport::TestCase
  include QboVehiclesTestHelper
  fixtures :journals, :journal_details

  def setup
    User.current = User.find(1)
    @customer = create_customer
    @vehicle = create_vehicle(customer: @customer)
    @issue = Issue.find(1)
    @issue.update_columns(customer_id: @customer.id, vehicle_id: nil)
  end

  def test_the_vehicle_must_be_the_customers
    other = create_vehicle(customer: create_customer(9302, 'Bob Builder'), vin: VIN2)
    @issue.vehicle_id = other.id
    assert_not @issue.valid?
    assert_includes @issue.errors[:base].join, other.to_s

    @issue.vehicle_id = @vehicle.id
    assert @issue.valid?, @issue.errors.full_messages.join(', ')
  end

  def test_a_missing_vehicle
    @issue.vehicle_id = 424242
    assert_not @issue.valid?
    assert_equal [I18n.t(:error_vehicle_not_found_for_issue)], @issue.errors[:base]
  end

  def test_a_vehicle_without_a_customer_on_the_issue
    @issue.update_columns(customer_id: nil)
    @issue.vehicle_id = @vehicle.id
    assert @issue.valid?
  end

  def test_an_old_mismatch_does_not_block_other_edits
    other = create_vehicle(customer: create_customer(9302, 'Bob Builder'), vin: VIN2)
    @issue.update_columns(vehicle_id: other.id)
    @issue.reload.subject = 'New subject'
    assert @issue.valid?, @issue.errors.full_messages.join(', ')
  end

  def test_the_subject_placeholder_gets_the_vehicle
    @issue.subject = 'Frame Evaluation // <VEHICLE>'
    @issue.vehicle = @vehicle
    @issue.valid?
    assert_equal 'Frame Evaluation // 2018 Jeep Wrangler - JW123456', @issue.subject
  end

  def test_the_placeholder_waits_for_a_vehicle_and_can_be_off
    @issue.subject = 'Frame Evaluation // <VEHICLE>'
    @issue.valid?
    assert_equal 'Frame Evaluation // <VEHICLE>', @issue.subject

    with_vehicle_settings('subject_placeholder' => '') do
      @issue.vehicle = @vehicle
      @issue.valid?
      assert_equal 'Frame Evaluation // <VEHICLE>', @issue.subject
    end
  end

  def test_vehicle_is_a_safe_attribute
    @issue.safe_attributes = { 'vehicle_id' => @vehicle.id.to_s }
    assert_equal @vehicle.id, @issue.vehicle_id
  end

  def test_history_shows_vehicle_names
    other = create_vehicle(vin: VIN2, make: 'Ford', model: 'F-150', year: 2019)
    journal = Journal.create!(journalized: @issue, user: User.find(1))
    detail = JournalDetail.create!(journal: journal, property: 'attr', prop_key: 'vehicle_id',
                                   old_value: @vehicle.id.to_s, value: other.id.to_s)
    helper = Object.new.extend(ApplicationHelper, IssuesHelper)
    text = helper.show_detail(detail, true)
    assert_includes text, '2018 Jeep Wrangler - JW123456'
    assert_includes text, '2019 Ford F-150 - KFA65432'

    other.issues.update_all(vehicle_id: nil)
    other.destroy
    text = Object.new.extend(ApplicationHelper, IssuesHelper).show_detail(detail.reload, true)
    assert_includes text, other.id.to_s
  end

  def test_other_history_is_untouched
    detail = JournalDetail.new(property: 'attr', prop_key: 'subject', old_value: 'Old', value: 'New')
    text = Object.new.extend(ApplicationHelper, IssuesHelper).show_detail(detail, true)
    assert_includes text, 'Old'
    assert_includes text, 'New'
  end
end
