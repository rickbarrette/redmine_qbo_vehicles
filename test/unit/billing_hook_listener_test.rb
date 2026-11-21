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

class BillingHookListenerTest < ActiveSupport::TestCase
  include QboVehiclesTestHelper

  def setup
    RedmineQboBilling::Company.stubs(:settings).returns(
      custom_fields: [{ id: 1, name: 'Sales Rep' }, { id: 2, name: 'VIN' }, { id: 3, name: 'Mileage' }]
    )
    @hook = Vehicles::Hooks::BillingHookListener.instance
    @customer = create_customer
    @jeep = create_vehicle(customer: @customer)
    @ford = create_vehicle(customer: @customer, vin: VIN2, year: 2019, make: 'Ford', model: 'F-150')
    @issue1, @issue2 = Issue.find(1), Issue.find(2)
    @issue1.update_columns(customer_id: @customer.id, vehicle_id: @jeep.id)
    @issue2.update_columns(customer_id: @customer.id, vehicle_id: nil)
  end

  def test_qbo_fields_by_name
    assert_equal 2, Vehicles::QboFields.vin_field.id
    assert_equal 3, Vehicles::QboFields.mileage_field.id
    RedmineQboBilling::Company.stubs(:settings).returns(custom_fields: [{ id: 2, name: 'VIN miles' }, { id: 3, name: 'Odometer' }])
    assert_equal 3, Vehicles::QboFields.mileage_field.id
    RedmineQboBilling::Company.stubs(:settings).returns(custom_fields: [{ id: 1, name: 'Sales Rep' }])
    assert_nil Vehicles::QboFields.vin_field
    assert_nil Vehicles::QboFields.mileage_field
  end

  def test_issue_values
    field = mileage_field
    set_mileage(@issue1, field, '84,250')
    values = @hook.qbo_billing_issue_values(issues: [@issue1, @issue2])
    assert_equal({ '2' => { 1 => VIN }, '3' => { 1 => '84,250' } }, values)
  end

  def test_no_values_without_the_quickbooks_fields
    RedmineQboBilling::Company.stubs(:settings).returns(custom_fields: [])
    assert_equal({}, @hook.qbo_billing_issue_values(issues: [@issue1]))
    assert_equal({}, @hook.qbo_billing_field_options(customer: @customer))
    assert_equal({}, @hook.qbo_billing_field_defaults(issues: [@issue1]))
    assert_equal({}, @hook.qbo_calendar_appointment_params(customer: @customer, custom_fields: { '2' => VIN }))
  end

  def test_field_options_are_the_customers_vehicles
    options = @hook.qbo_billing_field_options(customer: @customer)
    assert_equal [{ value: VIN, label: @jeep.to_s }, { value: VIN2, label: @ford.to_s }], options['2'].sort_by { |o| o[:value] }
    assert_equal({}, @hook.qbo_billing_field_options(customer: nil))
  end

  def test_field_defaults
    field = mileage_field
    set_mileage(@issue1, field, '84,250')
    set_mileage(@issue2, field, '84300.5')
    @issue2.update_columns(vehicle_id: @jeep.id)
    assert_equal({ '2' => VIN, '3' => '84300.5' }, @hook.qbo_billing_field_defaults(issues: [@issue1, @issue2]))

    set_mileage(@issue2, field, '84300')
    assert_equal '84300', @hook.qbo_billing_field_defaults(issues: [@issue1, @issue2])['3']
  end

  def test_no_vin_default_when_the_issues_have_different_vehicles
    @issue2.update_columns(vehicle_id: @ford.id)
    assert_equal({}, @hook.qbo_billing_field_defaults(issues: [@issue1, @issue2]))
  end

  def test_appointment_params_from_the_estimates_vin
    params = @hook.qbo_calendar_appointment_params(customer: @customer, custom_fields: { '2' => " #{VIN2.downcase} " })
    assert_equal({ vehicle_id: @ford.id }, params)
    assert_equal({}, @hook.qbo_calendar_appointment_params(customer: @customer, custom_fields: { '2' => 'NOPE' }))
    assert_equal({}, @hook.qbo_calendar_appointment_params(customer: @customer))
  end

  def test_issues_from_an_estimate_get_the_vehicle_with_its_vin
    estimate = Estimate.new(id: 7001, customer_id: @customer.id)
    RedmineQboBilling::EstimateWriter.stubs(:custom_field_value).returns(VIN2.downcase)
    issue = Issue.new
    @hook.qbo_billing_build_issue(issue: issue, estimate: estimate)
    assert_equal @ford.id, issue.vehicle_id
  end

  def test_the_vehicle_picked_wins_and_blank_means_none
    estimate = Estimate.new(id: 7001, customer_id: @customer.id)
    RedmineQboBilling::EstimateWriter.stubs(:custom_field_value).returns(VIN2)
    issue = Issue.new
    @hook.qbo_billing_build_issue(issue: issue, estimate: estimate, defaults: { 'vehicle_id' => @jeep.id.to_s })
    assert_equal @jeep.id, issue.vehicle_id

    issue = Issue.new
    @hook.qbo_billing_build_issue(issue: issue, estimate: estimate, defaults: { vehicle_id: '' })
    assert_nil issue.vehicle_id
  end

  def test_estimate_vehicle
    estimate = Estimate.new(id: 7001, customer_id: @customer.id)
    RedmineQboBilling::EstimateWriter.stubs(:custom_field_value).returns(VIN)
    assert_equal VIN, Vehicles::EstimateVehicle.vin(estimate)
    assert_equal @jeep, Vehicles::EstimateVehicle.match(estimate)
    assert_nil Vehicles::EstimateVehicle.match(estimate, '')
    assert_nil Vehicles::EstimateVehicle.vin(nil)
    assert_equal [], Vehicles::EstimateVehicle.vehicles(nil)
    assert_nil Vehicles::EstimateVehicle.for_vin(@customer, ' ')

    RedmineQboBilling::EstimateWriter.stubs(:custom_field_value).raises(StandardError, 'QuickBooks is down')
    assert_nil Vehicles::EstimateVehicle.vin(estimate)
  end

  def test_one_vehicle_per_invoice
    assert_nil @hook.qbo_billing_validate(document: 'invoice', issues: [@issue1, @issue2])
    @issue2.update_columns(vehicle_id: @ford.id)
    message = @hook.qbo_billing_validate(document: 'invoice', issues: [@issue1, @issue2])
    assert_includes message, "#{@jeep} (#1)"
    assert_includes message, "#{@ford} (#2)"
    assert_nil @hook.qbo_billing_validate(document: 'estimate', issues: [@issue1, @issue2])
  end

  def test_pdf_rows
    hook = Vehicles::Hooks::PdfHookListener.instance
    @jeep.update_columns(notes: 'Lift kit')
    rows = hook.pdf_left(issue: @issue1)
    assert_equal @jeep.to_s, rows[0][1]
    assert_equal VIN, rows[1][1]
    assert_equal({ html: '1C4HJXFG0<b>JW123456</b>' }, rows[1][2])
    assert_equal 'Lift kit', rows[2][1]

    @jeep.update_columns(vin: 'J12345')
    assert_equal 'J12345', hook.pdf_left(issue: @issue1.reload)[1][1]
    assert_nil hook.pdf_left(issue: @issue2)[1][1]
  end
end
