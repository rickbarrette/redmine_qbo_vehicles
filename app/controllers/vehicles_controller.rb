#The MIT License (MIT)
#
#Copyright (c) 2016 - 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class VehiclesController < ApplicationController

  helper :sort
  include SortHelper

  # Checks the vehicle permissions declared in init.rb (also requires login)
  before_action :authorize_global
  before_action :find_vehicle, only: [:show, :status, :edit, :update, :destroy]

  # How long to wait before the status check may queue another VIN decode for the same vehicle
  DECODE_REQUEST_THROTTLE = 5.minutes

  def allowed_params
    params.require(:vehicle).permit(:year, :make, :model, :customer_id, :notes, :vin)
  end

  # Every vehicle (or one customer's), sortable and paged like Redmine's lists; a search narrows it to the
  # vehicles matching every word (a single match opens that vehicle)
  def index
    if params[:customer_id].present?
      @customer = Customer.find_by(id: params[:customer_id])
      return render_404 unless @customer
    end

    sort_init 'vehicle', 'asc'
    sort_update 'vehicle' => %w[year make model].map { |c| "#{Vehicle.table_name}.#{c}" },
                'vin' => "#{Vehicle.table_name}.vin",
                'customer' => "#{Customer.table_name}.name",
                'updated' => "#{Vehicle.table_name}.updated_at"

    @search = params[:search].to_s.strip
    scope = @customer ? @customer.vehicles : Vehicle.all
    # Searched before joining customers, whose name column would make Vehicle.search's ambiguous
    scope = scope.search_all(@search) if @search.present?
    paginate_vehicles(scope.left_joins(:customer).preload(:customer).reorder(sort_clause).order(:id))
    return redirect_to(@vehicles.first) if @search.present? && @vehicle_count == 1

    @last_services = Vehicle.last_service_infos(@vehicles.map(&:id))
  end

  # Form for a new vehicle, pre-filled with the customer when coming from a customer or appointment
  def new
    @vehicle = Vehicle.new(customer: Customer.find_by(id: params[:customer_id]))
  end

  def create
    @vehicle = Vehicle.new(allowed_params)

    if @vehicle.save
      flash[:notice] = t :notice_vehicle_created
      # For whatever the vehicle was added from (e.g. an appointment, which then gets this vehicle: see
      # Vehicles::Hooks::AppointmentVehicleHookListener). Context: params, vehicle
      call_hook(:controller_vehicles_new_after_save, params: params, vehicle: @vehicle)
      # Back to where the vehicle was added from (back_url), else the vehicle
      redirect_back_or_default @vehicle
    else
      # A duplicate VIN: point to the vehicle that already has it
      @existing_vehicle = Vehicle.find_by(vin: @vehicle.vin) if @vehicle.errors.of_kind?(:vin, :taken)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @issues = @vehicle.issues
      .joins(:status)
      .includes(:estimate, :invoices, :status, :project, :tracker, :priority)
      .order(id: :desc)
    @open_issues = @issues.reject { |i| i.status.is_closed }
    @closed_issues = @issues.select { |i| i.status.is_closed }

    flash.now[:error] = t :alert_no_customer if @vehicle.customer.nil?
  end

  # Used by the polling script on the vehicle page while the VIN is being decoded
  def status
    # Queue a decode if it never happened (e.g. the job was lost), at most once per throttle window
    if !@vehicle.vin_decoded? && @vehicle.error.blank?
      key = "redmine_qbo_vehicles/vin_decode_requested/#{@vehicle.id}"
      unless Rails.cache.exist?(key)
        Rails.cache.write(key, true, expires_in: DECODE_REQUEST_THROTTLE)
        VehicleVinDecodeJob.perform_later(@vehicle.id)
      end
    end

    render json: { decoded: @vehicle.vin_decoded, error: @vehicle.error }
  end

  def edit
  end

  def update
    if @vehicle.update(allowed_params)
      flash[:notice] = t :notice_vehicle_updated
      redirect_to @vehicle
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Vehicles with issues can't be deleted (see Vehicle has_many :issues), to keep their history
  def destroy
    if @vehicle.destroy
      flash[:notice] = t :notice_vehicle_deleted
      redirect_to @vehicle.customer ? customer_path(@vehicle.customer) : vehicles_path
    else
      flash[:error] = t(:alert_vehicle_has_issues)
      redirect_to @vehicle
    end
  end

  private

  def find_vehicle
    @vehicle = Vehicle.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Redmine's paging: @vehicle_count, @vehicle_pages and this page's @vehicles
  def paginate_vehicles(scope)
    @vehicle_count = scope.count
    @vehicle_pages = Paginator.new @vehicle_count, per_page_option, params['page']
    @vehicles = scope.limit(@vehicle_pages.per_page).offset(@vehicle_pages.offset).to_a
  end

end
