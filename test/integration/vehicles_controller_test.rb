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
require File.expand_path('../../../redmine_qbo/test/qbo_fake_service', __dir__)

class VehiclesControllerTest < Redmine::IntegrationTest
  include QboVehiclesTestHelper
  include QboFakeServiceHelper

  def setup
    @customer = create_customer
    @jeep = create_vehicle(customer: @customer)
    @ford = create_vehicle(customer: create_customer(9302, 'Bob Builder'), vin: VIN2, year: 2019, make: 'Ford',
                           model: 'F-150')
    clear_enqueued_jobs
  end

  # Gives jsmith's Manager role the permissions and logs jsmith in (again, if someone was logged in)
  def grant(*permissions)
    role = Role.find(1)
    (%i[view_vehicles add_vehicles edit_vehicles delete_vehicles] - permissions).each { |p| role.remove_permission!(p) }
    permissions.each { |p| role.add_permission!(p) }
    reset!
    log_user('jsmith', 'jsmith')
  end

  def test_pages_need_permissions
    grant
    get '/vehicles'
    assert_response :forbidden
    get "/vehicles/#{@jeep.id}"
    assert_response :forbidden
    get "/vehicles/#{@jeep.id}/status"
    assert_response :forbidden

    grant(:view_vehicles)
    get '/vehicles/new'
    assert_response :forbidden
    post '/vehicles', params: { vehicle: { vin: 'J12345', customer_id: @customer.id } }
    assert_response :forbidden
    get "/vehicles/#{@jeep.id}/edit"
    assert_response :forbidden
    patch "/vehicles/#{@jeep.id}", params: { vehicle: { notes: 'x' } }
    assert_response :forbidden
    delete "/vehicles/#{@jeep.id}"
    assert_response :forbidden
    assert Vehicle.exists?(@jeep.id)
  end

  def test_anonymous_users_log_in
    get '/vehicles'
    assert_response :redirect
    assert_match %r{/login}, response.location
  end

  def test_index
    grant(:view_vehicles)
    get '/vehicles'
    assert_response :success
    assert_select 'table.vehicles td.name a', text: @jeep.to_s
    assert_select 'table.vehicles td.name a', text: @ford.to_s
    assert_select 'td.customer a[href=?]', '/customers/9302'
    assert_select 'a.icon-add', count: 0
  end

  def test_index_sorts
    grant(:view_vehicles)
    get '/vehicles', params: { sort: 'vehicle:desc' }
    assert_equal [@ford.to_s, @jeep.to_s], css_select('td.name a').map(&:text)
    get '/vehicles', params: { sort: 'customer' }
    assert_equal [@ford.to_s, @jeep.to_s], css_select('td.name a').map(&:text)
    get '/vehicles', params: { sort: 'vin,updated:desc' }
    assert_response :success
  end

  def test_index_shows_the_last_service
    field = mileage_field
    Issue.find(1).update_columns(vehicle_id: @jeep.id, customer_id: @customer.id, created_on: Time.zone.local(2026, 10, 15, 9))
    set_mileage(Issue.find(1), field, '84250')
    grant(:view_vehicles)
    get '/vehicles'
    assert_select 'td.last-service', text: /84,250 miles/
  end

  def test_search
    grant(:view_vehicles)
    create_vehicle(customer: @customer, vin: 'J12345', year: 1978, make: 'Jeep', model: 'CJ-5')
    get '/vehicles', params: { search: 'jeep' }
    assert_response :success
    assert_select 'td.name', count: 2
    get '/vehicles', params: { search: '2018 jeep' }
    assert_redirected_to "/vehicles/#{@jeep.id}"
    get '/vehicles', params: { search: 'tesla' }
    assert_select 'p.nodata', text: /tesla/
  end

  def test_a_customers_vehicles
    grant(:view_vehicles, :add_vehicles)
    get "/customers/#{@customer.id}/vehicles"
    assert_response :success
    assert_select 'td.name', count: 1
    assert_select 'td.customer', count: 0
    assert_select 'a.icon-add[href=?]', "/customers/#{@customer.id}/vehicles/new"
    get '/customers/424242/vehicles'
    assert_response :not_found
  end

  def test_show
    Issue.find(1).update_columns(vehicle_id: @jeep.id, customer_id: @customer.id)
    Issue.find(8).update_columns(vehicle_id: @jeep.id, customer_id: @customer.id)
    @jeep.update_columns(vin_decoded: true)
    grant(:view_vehicles)
    get "/vehicles/#{@jeep.id}"
    assert_response :success
    assert_select 'h3', text: /1 Open issues/i
    assert_select 'h3', text: /1 Closed issues/i
    assert_select 'a[href=?]', '/issues/1'
    assert_select 'a[href=?]', '/issues/8'
    assert_select '#vin-status', count: 0
    assert_select 'a.icon-edit', count: 0
    assert_select 'a.icon-del', count: 0
    get '/vehicles/424242'
    assert_response :not_found
  end

  def test_show_while_decoding_and_after_a_failure
    grant(:view_vehicles, :edit_vehicles, :delete_vehicles)
    get "/vehicles/#{@jeep.id}"
    assert_select '#vin-status.notice'
    assert_select 'a.icon-edit[href=?]', "/vehicles/#{@jeep.id}/edit"
    assert_select 'a.icon-del'

    @jeep.update_columns(error: '6 - Incomplete VIN')
    get "/vehicles/#{@jeep.id}"
    assert_select '#vin-status.error', text: /Incomplete VIN/
  end

  def test_no_delete_link_with_issues
    Issue.find(1).update_columns(vehicle_id: @jeep.id)
    grant(:view_vehicles, :delete_vehicles)
    get "/vehicles/#{@jeep.id}"
    assert_select 'a.icon-del', count: 0
  end

  def test_show_without_a_customer
    @jeep.update_columns(customer_id: 424242)
    grant(:view_vehicles)
    get "/vehicles/#{@jeep.id}"
    assert_response :success
    assert_select '#flash_error'
  end

  def test_status_queues_a_lost_decode_once
    Rails.stubs(:cache).returns(ActiveSupport::Cache::MemoryStore.new)
    grant(:view_vehicles)
    assert_enqueued_with(job: VehicleVinDecodeJob, args: [@jeep.id]) do
      get "/vehicles/#{@jeep.id}/status"
    end
    assert_equal({ 'decoded' => false, 'error' => nil }, response.parsed_body)
    assert_no_enqueued_jobs { get "/vehicles/#{@jeep.id}/status" }
  end

  def test_status_after_the_decode
    grant(:view_vehicles)
    @jeep.update_columns(vin_decoded: true)
    assert_no_enqueued_jobs { get "/vehicles/#{@jeep.id}/status" }
    assert_equal({ 'decoded' => true, 'error' => nil }, response.parsed_body)

    @ford.update_columns(error: 'NHTSA lookup failed')
    assert_no_enqueued_jobs { get "/vehicles/#{@ford.id}/status" }
    assert_equal 'NHTSA lookup failed', response.parsed_body['error']
  end

  def test_new_from_a_customer
    grant(:view_vehicles, :add_vehicles)
    get "/customers/#{@customer.id}/vehicles/new"
    assert_response :success
    assert_select 'input#customer_id[value=?]', @customer.id.to_s
    assert_select 'input.customer-name[value=?]', 'Jane Customer'
  end

  def test_create
    grant(:view_vehicles, :add_vehicles)
    assert_enqueued_with(job: VehicleVinDecodeJob) do
      post '/vehicles', params: { vehicle: { vin: 'j-12345', year: '1978', make: 'Jeep', model: 'CJ-5',
                                             customer_id: @customer.id, notes: 'Barn find' } }
    end
    vehicle = Vehicle.order(:id).last
    assert_redirected_to "/vehicles/#{vehicle.id}"
    assert_equal 'J12345', vehicle.vin
    assert_equal 'Barn find', vehicle.notes
    assert_equal @customer, vehicle.customer
  end

  def test_create_goes_back
    grant(:view_vehicles, :add_vehicles)
    post '/vehicles', params: { vehicle: { vin: 'J12345', customer_id: @customer.id }, back_url: "/customers/#{@customer.id}" }
    assert_redirected_to "/customers/#{@customer.id}"
  end

  def test_a_duplicate_vin_links_the_vehicle_on_file
    grant(:view_vehicles, :add_vehicles)
    assert_no_difference('Vehicle.count') do
      post '/vehicles', params: { vehicle: { vin: VIN.downcase, customer_id: @customer.id } }
    end
    assert_response :unprocessable_entity
    assert_select '.flash.warning a[href=?]', "/vehicles/#{@jeep.id}"

    post '/vehicles', params: { vehicle: { vin: '', customer_id: '' } }
    assert_response :unprocessable_entity
    assert_select '#errorExplanation'
    assert_select '.flash.warning', count: 0
  end

  def test_update
    grant(:view_vehicles, :edit_vehicles)
    get "/vehicles/#{@jeep.id}/edit"
    assert_response :success
    patch "/vehicles/#{@jeep.id}", params: { vehicle: { notes: 'Lift kit', customer_id: 9302 } }
    assert_redirected_to "/vehicles/#{@jeep.id}"
    assert_equal 'Lift kit', @jeep.reload.notes
    assert_equal 9302, @jeep.customer_id

    patch "/vehicles/#{@jeep.id}", params: { vehicle: { vin: VIN2 } }
    assert_response :unprocessable_entity
    assert_equal VIN, @jeep.reload.vin
  end

  def test_destroy
    grant(:view_vehicles, :delete_vehicles)
    delete "/vehicles/#{@jeep.id}"
    assert_redirected_to "/customers/#{@customer.id}"
    assert_not Vehicle.exists?(@jeep.id)

    @ford.update_columns(customer_id: 424242)
    delete "/vehicles/#{@ford.id}"
    assert_redirected_to '/vehicles'
  end

  def test_a_vehicle_with_issues_is_kept
    Issue.find(1).update_columns(vehicle_id: @jeep.id)
    grant(:view_vehicles, :delete_vehicles)
    delete "/vehicles/#{@jeep.id}"
    assert_redirected_to "/vehicles/#{@jeep.id}"
    assert_equal I18n.t(:alert_vehicle_has_issues), flash[:error]
    assert Vehicle.exists?(@jeep.id)
  end

  def test_redmine_search_finds_vehicles
    grant(:view_vehicles)
    get '/search', params: { q: 'wrangler', vehicles: '1' }
    assert_response :success
    assert_select 'dt a[href=?]', "/vehicles/#{@jeep.id}"
  end

  def test_top_menu
    grant(:view_vehicles)
    get '/my/page'
    assert_select '#top-menu a.vehicles[href="/vehicles"]'
    grant
    get '/my/page'
    assert_select '#top-menu a.vehicles', count: 0
  end
end
