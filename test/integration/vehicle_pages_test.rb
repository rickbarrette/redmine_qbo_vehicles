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
require File.expand_path('../../../redmine_qbo/test/test_helper', __dir__)

# The vehicle on redmine_qbo's and Redmine's pages: issues, customers, Create issues from an estimate, and
# redmine_qbo_calendar's appointments
class VehiclePagesTest < Redmine::IntegrationTest
  include QboVehiclesTestHelper
  include QboEditorTestHelper
  fixtures :journals, :journal_details

  def setup
    # QboEditorTestHelper's customer (9101), with a vehicle
    @jeep = create_vehicle(customer: @customer, notes: 'Lift kit')
    @ford = create_vehicle(customer: create_customer(9302, 'Bob Builder'), vin: VIN2, year: 2019, make: 'Ford',
                           model: 'F-150')
    @issue = Issue.find(1)
    @issue.update_columns(customer_id: @customer.id, vehicle_id: @jeep.id)
    Role.find(1).add_permission!(:view_vehicles)
  end

  def test_issue_page_shows_the_vehicle
    login_with
    get '/issues/1'
    assert_response :success
    assert_select '.vehicle.attribute a[href=?]', "/vehicles/#{@jeep.id}", text: @jeep.to_s
    assert_select '#vin', text: /1C4HJXFG0/
    assert_select '.vehicle_notes .wiki', text: /Lift kit/
  end

  def test_issue_pdf_has_the_vehicle
    login_with
    get '/issues/1.pdf'
    assert_response :success
    assert_equal 'application/pdf', response.media_type
  end

  def test_issue_form_offers_the_customers_vehicles
    other = create_vehicle(customer: @customer, vin: 'J12345', year: 1978, make: 'Jeep', model: 'CJ-5')
    login_with
    get '/issues/1/edit'
    assert_response :success
    assert_select 'select#issue_vehicle_id' do
      assert_select 'option[selected][value=?]', @jeep.id.to_s
      assert_select 'option[value=?]', other.id.to_s
      assert_select 'option[value=?]', @ford.id.to_s, count: 0
    end
  end

  def test_a_sold_vehicle_stays_on_its_issues
    @jeep.update_columns(customer_id: 9302)
    login_with
    get '/issues/1/edit'
    assert_select 'select#issue_vehicle_id option[selected][value=?]', @jeep.id.to_s
  end

  def test_setting_the_vehicle_on_an_issue
    @issue.update_columns(vehicle_id: nil, subject: 'Frame Evaluation // <VEHICLE>')
    login_with
    patch '/issues/1', params: { issue: { vehicle_id: @jeep.id } }
    assert_redirected_to '/issues/1'
    @issue.reload
    assert_equal @jeep.id, @issue.vehicle_id
    assert_equal "Frame Evaluation // #{@jeep}", @issue.subject

    get '/issues/1'
    assert_select '.journal-details li', text: /Vehicle set to #{Regexp.escape(@jeep.to_s)}/
  end

  def test_another_customers_vehicle_is_refused
    login_with
    patch '/issues/1', params: { issue: { vehicle_id: @ford.id } }
    assert_response :success
    assert_select '#errorExplanation', text: /#{Regexp.escape(@ford.to_s)}/
    assert_equal @jeep.id, @issue.reload.vehicle_id
  end

  def test_customer_page_lists_vehicles
    Role.find(1).add_permission!(:add_vehicles)
    login_with(:view_customers)
    get "/customers/#{@customer.id}"
    assert_response :success
    assert_select '.vehicle-list .vehicle-name a[href=?]', "/vehicles/#{@jeep.id}"
    assert_select 'input.vehicle-checkbox[value=?][data-ticked-field=vehicle_id]', @jeep.id.to_s
    assert_select "form[action=?]", "/customers/#{@customer.id}/vehicles/new"
  end

  def test_customer_page_without_view_vehicles
    Role.find(1).remove_permission!(:view_vehicles)
    login_with(:view_customers)
    get "/customers/#{@customer.id}"
    assert_response :success
    assert_select '.vehicle-list', count: 0
  end

  def test_create_issues_picks_the_vehicle_with_the_estimates_vin
    other = create_vehicle(customer: @customer, vin: 'J12345', year: 1978, make: 'Jeep', model: 'CJ-5')
    setup_estimate(vin: 'j12345')
    login_with(:create_estimate_issues, :add_issues)
    get '/qbo_estimates/598/issues_preview'
    assert_response :success
    assert_select 'select#estimate_issue_vehicle_id option[selected][value=?]', other.id.to_s
    assert_select '.estimate-issue-vehicle em.info', text: /J12345/i

    post '/qbo_estimates/598/create_issues', params: { project_id: 1, lines: { '2' => { selected: '1', tracker_id: '1' } } }
    assert_redirected_to '/qbo_estimates/598/edit'
    assert_equal other.id, Issue.where(estimate_id: 598).last.vehicle_id
  end

  def test_create_issues_with_a_vin_no_vehicle_has
    setup_estimate(vin: 'NOPE12345')
    login_with(:create_estimate_issues, :add_issues)
    get '/qbo_estimates/598/issues_preview'
    assert_select 'select#estimate_issue_vehicle_id option[selected]', count: 0
    assert_select 'em.estimate-vehicle-unmatched', text: /NOPE12345/

    post '/qbo_estimates/598/create_issues',
         params: { project_id: 1, issue_plugin_fields: { vehicle_id: @jeep.id }, lines: { '2' => { selected: '1', tracker_id: '1' } } }
    assert_equal @jeep.id, Issue.where(estimate_id: 598).last.vehicle_id
  end

  def test_a_vehicle_added_from_an_appointment_goes_on_it
    skip 'redmine_qbo_calendar is not installed' unless Redmine::Plugin.installed?(:redmine_qbo_calendar)

    appointment = CustomerAppointment.new(subject: 'Lift kit', description: '', date: Date.new(2026, 11, 23), project_id: 1,
                                          user_id: 2, customer_id: @customer.id)
    appointment.save!(validate: false)
    Role.find(1).add_permission!(:add_vehicles)
    login_with(:edit_customer_appointments)
    post '/vehicles', params: { appointment_id: appointment.id, back_url: "/customer_appointments/#{appointment.id}",
                                vehicle: { vin: 'J12345', customer_id: @customer.id } }
    vehicle = Vehicle.find_by(vin: 'J12345')
    assert_redirected_to "/customer_appointments/#{appointment.id}"
    assert_equal vehicle.id, appointment.reload.vehicle_id
    assert_match(/J12345/, flash[:notice])

    # Never another customer's appointment, and never replacing its vehicle
    post '/vehicles', params: { appointment_id: appointment.id, vehicle: { vin: 'J54321', customer_id: @customer.id } }
    assert_equal vehicle.id, appointment.reload.vehicle_id
  end

  def test_the_appointment_needs_edit_permission
    skip 'redmine_qbo_calendar is not installed' unless Redmine::Plugin.installed?(:redmine_qbo_calendar)

    appointment = CustomerAppointment.new(subject: 'Lift kit', description: '', date: Date.new(2026, 11, 23), project_id: 1,
                                          user_id: 2, customer_id: @customer.id)
    appointment.save!(validate: false)
    Role.find(1).add_permission!(:add_vehicles)
    login_with
    post '/vehicles', params: { appointment_id: appointment.id, vehicle: { vin: 'J12345', customer_id: @customer.id } }
    assert Vehicle.exists?(vin: 'J12345')
    assert_nil appointment.reload.vehicle_id
  end

  # ---- redmine_qbo_calendar's appointments (through its hooks) ----

  def calendar_appointment(**attributes)
    CustomerAppointment.create!({ subject: 'Lift kit install', date: Time.utc(2026, 11, 23, 9), duration: 1,
                                  estimated_hours: 4, user_id: 2, project_id: 1, customer_id: @customer.id }.merge(attributes))
  end

  def test_appointments_have_the_vehicle
    skip 'redmine_qbo_calendar is not installed' unless Redmine::Plugin.installed?(:redmine_qbo_calendar)

    RedmineQboBilling::EstimateIssueBuilder.stubs(:labor_hours).returns(0)
    appointment = calendar_appointment(vehicle_id: @jeep.id)
    login_with(:view_customer_appointments, :add_customer_appointments, :edit_customer_appointments)

    get "/customer_appointments/#{appointment.id}"
    assert_select '.attribute a[href=?]', "/vehicles/#{@jeep.id}", text: @jeep.name
    assert_select 'a[href*=?]', "issue%5Bvehicle_id%5D=#{@jeep.id}"

    get "/customer_appointments/#{appointment.id}/edit"
    assert_select 'select#appointment_vehicle_id[data-customer-option] option[selected][value=?]', @jeep.id.to_s
    assert_select 'select#appointment_vehicle_id option[value=?]', @ford.id.to_s, count: 0

    get '/customer_appointments/customer_options', params: { customer_id: @customer.id }
    assert_equal [@jeep.id], response.parsed_body['options']['appointment_vehicle_id'].map { |v| v['id'] }

    get '/customer_appointments'
    assert_select 'td.vehicle a[href=?]', "/vehicles/#{@jeep.id}"
    get '/issues/calendar', params: { year: 2026, month: 11 }
    assert_select '.appointment-detail', text: /#{Regexp.escape(@jeep.name)}/
    assert_select '.tip a[href=?]', "/vehicles/#{@jeep.id}"
  end

  def test_saving_an_appointments_vehicle
    skip 'redmine_qbo_calendar is not installed' unless Redmine::Plugin.installed?(:redmine_qbo_calendar)

    RedmineQboBilling::EstimateIssueBuilder.stubs(:labor_hours).returns(0)
    login_with(:view_customer_appointments, :add_customer_appointments)
    # A link with a vehicle (e.g. ticked on the customer page) fills it in, if it's the customer's
    get '/customer_appointments/new', params: { customer_id: @customer.id, vehicle_id: @jeep.id }
    assert_select 'select#appointment_vehicle_id option[selected][value=?]', @jeep.id.to_s
    get '/customer_appointments/new', params: { customer_id: @customer.id, vehicle_id: @ford.id }
    assert_select 'select#appointment_vehicle_id option[selected]', 0

    post '/customer_appointments', params: { customer_appointment: {
      subject: 'Brakes', customer_id: @customer.id, vehicle_id: @jeep.id, user_id: 2, date: '2026-11-24T09:00', duration: 1, estimated_hours: 2
    } }
    assert_equal @jeep.id, CustomerAppointment.order(:id).last.vehicle_id

    # A call-out has no vehicle
    call_out = CustomerAppointment.create!(event_type: 'call_out', date: Time.utc(2026, 11, 24, 8), user_id: 3, vehicle_id: @jeep.id)
    assert_nil call_out.vehicle_id
  end

  def test_create_issues_from_an_appointment_gets_its_vehicle
    skip 'redmine_qbo_calendar is not installed' unless Redmine::Plugin.installed?(:redmine_qbo_calendar)

    other = create_vehicle(customer: @customer, vin: 'J12345', year: 1978, make: 'Jeep', model: 'CJ-5')
    setup_estimate(vin: nil)
    appointment = calendar_appointment(estimate_id: 598, vehicle_id: other.id)
    appointment.update_columns(estimate_id: 598)
    login_with(:create_estimate_issues, :add_issues, :view_customer_appointments)
    get '/qbo_estimates/598/issues_preview', params: { appointment_id: appointment.id }
    assert_select 'select#estimate_issue_vehicle_id option[selected][value=?]', other.id.to_s
  end

  def test_create_issues_under_a_parent_gets_its_vehicle
    setup_estimate(vin: nil)
    login_with(:create_estimate_issues, :add_issues)
    get '/qbo_estimates/598/issues_preview', params: { parent_issue_id: 1 }
    assert_select 'select#estimate_issue_vehicle_id option[selected][value=?]', @jeep.id.to_s

    hook = Vehicles::Hooks::BillingHookListener.instance
    issue = Issue.new
    hook.qbo_billing_build_issue(issue: issue, estimate: Estimate.find(598), defaults: { vehicle_id: '' }, parent: Issue.find(1))
    assert_equal @jeep.id, issue.vehicle_id
  end

  def test_reminders_get_the_vehicle
    hook = Vehicles::Hooks::RemindersHookListener.instance
    assert_equal ['vehicle'], hook.qbo_reminder_placeholders
    assert_equal({ 'vehicle' => '2022 Jeep Gladiator', 'calendar_detail' => '2022 Jeep Gladiator' }, hook.qbo_reminder_values(appointment: nil))
    skip 'redmine_qbo_calendar is not installed' unless Redmine::Plugin.installed?(:redmine_qbo_calendar)

    RedmineQboBilling::EstimateIssueBuilder.stubs(:labor_hours).returns(0)
    appointment = calendar_appointment(vehicle_id: @jeep.id)
    assert_equal({ 'vehicle' => @jeep.to_s, 'calendar_detail' => @jeep.to_s }, hook.qbo_reminder_values(appointment: appointment))
    assert_equal({}, hook.qbo_reminder_values(appointment: calendar_appointment))
    if defined?(RedmineQboReminders::Message)
      settings = RedmineQboReminders::Settings.new('time_zone' => 'UTC', 'shop_name' => 'Example Garage', 'from_address' => 'shop@example.com')
      message = RedmineQboReminders::Message.for(appointment, settings)
      assert_equal @jeep.to_s, message.values['vehicle']
      assert_includes message.ics, "SUMMARY:Appointment at Example Garage – #{@jeep}"
      assert_includes RedmineQboReminders::Template.placeholders, 'vehicle'
    end
  end

  private

  def setup_estimate(vin:)
    Estimate.where(id: 598).delete_all
    Estimate.create!(id: 598, doc_number: '1068', customer_id: @customer.id)
    Estimate.any_instance.stubs(:line_items).returns([qbo_sales_line(2, 10, 'Labor', 2, 120, description: 'Install lift kit')])
    Setting.stubs(:plugin_redmine_qbo).returns('issue_default_project_id' => '1')
    RedmineQboBilling::EstimateWriter.stubs(:custom_field_value).returns(vin)
    @fake.add(estimate_doc)
  end
end
