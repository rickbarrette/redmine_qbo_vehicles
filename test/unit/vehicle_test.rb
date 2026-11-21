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

class VehicleTest < ActiveSupport::TestCase
  include QboVehiclesTestHelper

  def test_vin_is_cleaned_up
    vehicle = create_vehicle(vin: ' 1c4h-jxfg 0jw.123456 ')
    assert_equal VIN, vehicle.vin
  end

  def test_letters_never_used_in_vins_are_dropped
    vehicle = Vehicle.new(vin: '1C4HJXFGOIQ0JW123456')
    vehicle.valid?
    assert_equal '1C4HJXFG0JW123456', vehicle.vin
  end

  def test_vin_and_customer_are_required
    vehicle = Vehicle.new
    assert_not vehicle.valid?
    assert vehicle.errors.added?(:vin, :blank)
    assert vehicle.errors.added?(:customer, :blank)
  end

  def test_vins_are_unique
    create_vehicle
    duplicate = Vehicle.new(customer: create_customer(9302, 'Bob Builder'), vin: VIN.downcase)
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:vin, :taken)
  end

  def test_make_and_model_are_stripped
    vehicle = Vehicle.new(make: '  Jeep ', model: "Wrangler\n")
    assert_equal 'Jeep', vehicle.make
    assert_equal 'Wrangler', vehicle.model
  end

  def test_to_s
    vehicle = create_vehicle
    assert_equal '2018 Jeep Wrangler - JW123456', vehicle.to_s
    vehicle.name = 'Shop truck'
    assert_equal 'Shop truck', vehicle.to_s
    assert_equal 'Shop truck', vehicle.name
  end

  def test_to_s_is_the_vin_without_year_make_and_model
    vehicle = create_vehicle(make: '')
    assert_equal VIN, vehicle.to_s
    assert_equal VIN, vehicle.name
  end

  def test_short_vins
    vehicle = create_vehicle(vin: 'J12345')
    assert_equal '2018 Jeep Wrangler - J12345', vehicle.to_s
  end

  def test_search_by_vin_make_model_and_year
    jeep = create_vehicle
    ford = create_vehicle(vin: VIN2, year: 2019, make: 'Ford', model: 'F-150')
    assert_equal [jeep], Vehicle.search('jw1234').to_a
    assert_equal [ford], Vehicle.search('ford').to_a
    assert_equal [ford], Vehicle.search('F-15').to_a
    assert_equal [ford], Vehicle.search('2019').to_a
    assert_empty Vehicle.search('100%').to_a
  end

  def test_search_all_needs_every_word
    jeep = create_vehicle
    create_vehicle(vin: VIN2, year: 2018, make: 'Ford', model: 'F-150')
    assert_equal 2, Vehicle.search_all('2018').count
    assert_equal [jeep], Vehicle.search_all('2018 jeep').to_a
    assert_empty Vehicle.search_all('2018 jeep f-150').to_a
    assert_equal 2, Vehicle.search_all('').count
  end

  def test_redmine_search
    jeep = create_vehicle
    create_vehicle(vin: VIN2, make: 'Ford', model: 'F-150')
    ranks = Vehicle.search_result_ranks_and_ids(%w[jeep wrangler], User.find(1))
    assert_equal({ jeep.id => jeep.id }, ranks)
    assert_equal({}, Vehicle.search_result_ranks_and_ids([], User.find(1)))
  end

  def test_event_for_redmine_search_results
    vehicle = create_vehicle
    assert_equal vehicle.to_s, vehicle.event_title
    assert_equal({ controller: 'vehicles', action: 'show', id: vehicle.id }, vehicle.event_url)
    assert_equal "#{VIN} - Jane Customer", vehicle.event_description
  end

  def test_a_vehicle_with_issues_is_not_deleted
    vehicle = create_vehicle
    Issue.find(1).update_columns(vehicle_id: vehicle.id)
    assert_not vehicle.destroy
    assert Vehicle.exists?(vehicle.id)

    Issue.find(1).update_columns(vehicle_id: nil)
    assert vehicle.reload.destroy
  end

  def test_saving_a_new_vin_queues_a_decode
    assert_enqueued_with(job: VehicleVinDecodeJob) { create_vehicle }
    vehicle = Vehicle.last
    assert_no_enqueued_jobs(only: VehicleVinDecodeJob) { vehicle.update!(notes: 'Lift kit') }
    assert_enqueued_with(job: VehicleVinDecodeJob, args: [vehicle.id]) { vehicle.update!(vin: VIN2) }
  end

  def test_subject_placeholder
    assert_equal '<VEHICLE>', Vehicle.subject_placeholder
    with_vehicle_settings('subject_placeholder' => '[truck]') { assert_equal '[truck]', Vehicle.subject_placeholder }
    with_vehicle_settings('subject_placeholder' => ' ') { assert_nil Vehicle.subject_placeholder }
    # Settings saved before the option existed
    with_vehicle_settings('mileage_custom_field_id' => '') { assert_equal '<VEHICLE>', Vehicle.subject_placeholder }
    with_vehicle_settings(subject_placeholder: '{v}') { assert_equal '{v}', Vehicle.subject_placeholder }
  end

  def test_mileage_custom_field
    assert_nil Vehicle.mileage_custom_field
    named = mileage_field
    odometer = mileage_field(name: 'Odometer')
    assert_equal named, Vehicle.mileage_custom_field
    with_vehicle_settings('mileage_custom_field_id' => odometer.id.to_s) { assert_equal odometer, Vehicle.mileage_custom_field }
    with_vehicle_settings('mileage_custom_field_id' => '424242') { assert_equal named, Vehicle.mileage_custom_field }
  end

  def test_last_service_from_the_newest_issue_with_a_mileage
    field = mileage_field
    vehicle = create_vehicle
    older, newer, newest = Issue.find(1), Issue.find(2), Issue.find(3)
    [older, newer, newest].each { |issue| issue.update_columns(vehicle_id: vehicle.id) }
    older.update_columns(created_on: Time.zone.local(2026, 9, 1, 10))
    newer.update_columns(created_on: Time.zone.local(2026, 10, 15, 10))
    newest.update_columns(created_on: Time.zone.local(2026, 11, 2, 10))
    set_mileage(older, field, '81000')
    set_mileage(newer, field, '84,250')
    set_mileage(newest, field, '') # no mileage recorded

    vehicle = Vehicle.find(vehicle.id)
    assert_equal Date.new(2026, 10, 15), vehicle.last_service_date
    assert_equal '84,250', vehicle.last_service_mileage

    other = create_vehicle(vin: VIN2)
    infos = Vehicle.last_service_infos([vehicle.id, other.id])
    assert_equal({ vehicle.id => { date: Date.new(2026, 10, 15), mileage: '84,250' } }, infos)
  end

  def test_no_last_service_without_a_mileage_field
    vehicle = create_vehicle
    Issue.find(1).update_columns(vehicle_id: vehicle.id)
    assert_nil vehicle.last_service_info
    assert_nil vehicle.last_service_date
    assert_equal({}, Vehicle.last_service_infos([vehicle.id]))
    mileage_field
    assert_equal({}, Vehicle.last_service_infos([]))
  end

  def test_customers_have_vehicles
    vehicle = create_vehicle
    assert_equal [vehicle], Customer.find(9301).vehicles.to_a
  end

  def test_no_project
    assert_nil Vehicle.new.project
  end
end
