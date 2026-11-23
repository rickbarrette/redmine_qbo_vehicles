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

# The vehicle on redmine_qbo_tickets' intake forms (Vehicles::Hooks::TicketsHookListener, kind 'intake')
class TicketsIntakeHookListenerTest < ActiveSupport::TestCase
  include QboVehiclesTestHelper

  BASE = 'https://redmine.example.com'

  def setup
    @listener = Vehicles::Hooks::TicketsHookListener.instance
    @customer = create_customer
    @jeep = create_vehicle(customer: @customer)
  end

  def context(params = {})
    { appointment: nil, customer: @customer, params: params, base_url: BASE, kind: 'intake' }
  end

  def test_the_ticked_vehicle_and_its_vin
    details = @listener.qbo_tickets_details(context('vehicle_id' => @jeep.id.to_s))
    assert_equal [['Vehicle', @jeep.to_s], ['VIN', @jeep.vin]], details
    qr = @listener.qbo_tickets_qr(context('vehicle_id' => @jeep.id.to_s))
    assert_equal "#{BASE}/vehicles/#{@jeep.id}", qr[:url]
    assert_equal 'Scan to open the vehicle', qr[:caption]
  end

  def test_without_a_vehicle_the_qr_code_adds_one
    assert_equal [], @listener.qbo_tickets_details(context)
    uri = URI.parse(@listener.qbo_tickets_qr(context)[:url])
    params = Rack::Utils.parse_query(uri.query)
    assert_equal '/vehicles/new', uri.path
    assert_equal @customer.id.to_s, params['customer_id']
    assert_equal "/customers/#{@customer.id}", params['back_url']
    assert_nil params['appointment_id']
  end

  def test_another_customers_vehicle_is_left_out
    other = create_vehicle(customer: create_customer(9302, 'Bob Builder'), vin: VIN2)
    assert_equal [], @listener.qbo_tickets_details(context('vehicle_id' => other.id.to_s))
    assert_equal '/vehicles/new', URI.parse(@listener.qbo_tickets_qr(context('vehicle_id' => other.id.to_s))[:url]).path
  end
end
