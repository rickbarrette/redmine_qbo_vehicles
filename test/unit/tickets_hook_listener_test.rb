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

# The vehicle on redmine_qbo_tickets' key tickets (Vehicles::Hooks::TicketsHookListener)
class TicketsHookListenerTest < ActiveSupport::TestCase
  include QboVehiclesTestHelper

  def setup
    skip 'redmine_qbo_calendar is not installed' unless Redmine::Plugin.installed?(:redmine_qbo_calendar)
    @listener = Vehicles::Hooks::TicketsHookListener.instance
    @customer = create_customer
    @appointment = CustomerAppointment.create!(subject: 'Lift kit install', date: Time.zone.local(2026, 11, 23, 8),
                                               duration: 1, estimated_hours: 4, user_id: 2, project_id: 1,
                                               customer: @customer)
  end

  def teardown
    CustomerAppointment.where(id: @appointment.id).delete_all if @appointment
  end

  def test_an_appointment_with_a_vehicle
    vehicle = create_vehicle(customer: @customer)
    @appointment.update_columns(vehicle_id: vehicle.id)
    @appointment.reload

    assert_equal [['Vehicle', vehicle.to_s]], @listener.qbo_tickets_details(appointment: @appointment)
    qr = @listener.qbo_tickets_qr(appointment: @appointment, base_url: 'https://redmine.example.com')
    assert_equal "https://redmine.example.com/vehicles/#{vehicle.id}", qr[:url]
    assert_equal 'Scan to open the vehicle', qr[:caption]
  end

  def test_an_appointment_without_a_vehicle_adds_one
    assert_equal [], @listener.qbo_tickets_details(appointment: @appointment)
    qr = @listener.qbo_tickets_qr(appointment: @appointment, base_url: 'https://redmine.example.com')
    uri = URI.parse(qr[:url])
    params = Rack::Utils.parse_query(uri.query)
    assert_equal '/vehicles/new', uri.path
    assert_equal @customer.id.to_s, params['customer_id']
    assert_equal @appointment.id.to_s, params['appointment_id']
    assert_equal "/customer_appointments/#{@appointment.id}", params['back_url']
    assert_equal 'Scan to add the vehicle', qr[:caption]
  end

  def test_no_customer_no_qr_code
    @appointment.update_columns(customer_id: nil)
    assert_equal({}, @listener.qbo_tickets_qr(appointment: @appointment.reload, base_url: ''))
  end
end
