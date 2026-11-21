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

class VehicleVinDecodeJobTest < ActiveSupport::TestCase
  include QboVehiclesTestHelper

  def test_fills_in_the_vehicle
    vehicle = create_vehicle(year: nil, make: '', model: '')
    stub_vpic('Make' => 'FORD', 'Model' => 'F-150', 'ModelYear' => '2019', 'Trim' => 'XLT')
    VehicleVinDecodeJob.perform_now(vehicle.id)
    vehicle.reload
    assert vehicle.vin_decoded?
    assert_nil vehicle.error
    assert_equal 2019, vehicle.year
    assert_equal 'Ford', vehicle.make
    assert_equal 'F-150', vehicle.model
    assert_equal 'XLT', vehicle.trim
    assert_equal '4', vehicle.doors
    assert_equal '2019 Ford F-150 - JW123456', vehicle.name
  end

  def test_sends_the_year_on_file
    vehicle = create_vehicle(year: 1978)
    VinDecoder.expects(:call).with(VIN, model_year: 1978).returns(VinDecoder::Result.new(false, nil, 'Old'))
    VehicleVinDecodeJob.perform_now(vehicle.id)
  end

  def test_keeps_what_the_decode_leaves_out
    vehicle = create_vehicle(year: 2017, make: 'Jeep', model: 'Wrangler')
    vehicle.update_columns(doors: '2', trim: 'Rubicon')
    stub_vpic('ModelYear' => '', 'Doors' => '', 'Trim' => '', 'Series' => '')
    VehicleVinDecodeJob.perform_now(vehicle.id)
    vehicle.reload
    assert_equal 2017, vehicle.year
    assert_equal '2', vehicle.doors
    assert_equal 'Rubicon', vehicle.trim
    # No year from NHTSA: the name falls back to the VIN, and to_s uses it
    assert_equal VIN, vehicle.name
  end

  def test_a_failed_decode_is_shown
    vehicle = create_vehicle
    stub_vpic('Make' => '', 'ErrorText' => '6 - Incomplete VIN')
    VehicleVinDecodeJob.perform_now(vehicle.id)
    vehicle.reload
    assert_not vehicle.vin_decoded?
    assert_equal '6 - Incomplete VIN', vehicle.error
  end

  def test_saved_even_when_the_customer_is_gone
    vehicle = create_vehicle
    vehicle.update_columns(customer_id: 424242)
    stub_vpic
    VehicleVinDecodeJob.perform_now(vehicle.id)
    assert vehicle.reload.vin_decoded?
  end

  def test_older_jobs_pass_the_vehicle
    vehicle = create_vehicle
    stub_vpic
    VehicleVinDecodeJob.perform_now(vehicle)
    assert vehicle.reload.vin_decoded?
  end

  def test_a_deleted_vehicle_is_skipped
    VinDecoder.expects(:call).never
    VehicleVinDecodeJob.perform_now(424242)
  end

  def test_network_trouble_is_retried
    vehicle = create_vehicle
    assert_enqueued_with(job: VehicleVinDecodeJob) { VehicleVinDecodeJob.perform_now(vehicle.id) }
    assert_not vehicle.reload.vin_decoded?
    assert_nil vehicle.error
  end

  def test_the_error_is_shown_after_the_last_retry
    vehicle = create_vehicle
    job = VehicleVinDecodeJob.new(vehicle.id)
    job.exception_executions = { '[VinDecoder::TransientError]' => 4 }
    job.perform_now
    assert_match(/no network in tests/, vehicle.reload.error)
  end
end
