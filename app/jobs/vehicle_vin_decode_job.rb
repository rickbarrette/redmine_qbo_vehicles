#The MIT License (MIT)
#
#Copyright (c) 2016 - 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class VehicleVinDecodeJob < ApplicationJob
  queue_as :default
  # Network trouble is retried; if it never succeeds, the error is shown on the vehicle page
  retry_on VinDecoder::TransientError, wait: 2.minutes, attempts: 5 do |job, error|
    vehicle_id = job.arguments.first
    vehicle_id = vehicle_id.id if vehicle_id.respond_to?(:id)
    Vehicle.find_by(id: vehicle_id)&.update_columns(error: error.message.to_s.truncate(255), vin_decoded: false)
  end

  # Takes a vehicle id (jobs queued by older versions may pass the Vehicle itself, which still works)
  def perform(vehicle_or_id)
    vehicle_id = vehicle_or_id.respond_to?(:id) ? vehicle_or_id.id : vehicle_or_id
    log "Looking up VIN for vehicle ##{vehicle_id}"
    vehicle = Vehicle.find_by(id: vehicle_id)
    return unless vehicle&.vin.present?
    # The year on file (if someone entered one) helps NHTSA, especially for older vehicles
    result = VinDecoder.call(vehicle.vin, model_year: vehicle.year)
    
    unless result.success?
      log "Failed to decode vin"
      save_decode(vehicle, vin_decoded: false, error: result.error.to_s.truncate(255))
      return
    end

    details = result.data

    save_decode(vehicle,
      year: details.year.presence || vehicle.year,
      make: details.make.presence || vehicle.make,
      model: details.model.presence || vehicle.model,
      doors: details.doors.presence || vehicle.doors,
      trim: details.trim.presence || vehicle.trim,
      name: build_name(vehicle, details),
      vin_decoded: true,
      error: nil
    )
  end

  private

  # Saves decode results without validations: a vehicle whose customer was deleted in QuickBooks
  # would otherwise fail "customer must exist" and lose its decoded details.
  def save_decode(vehicle, attributes)
    vehicle.assign_attributes(attributes)
    vehicle.save(validate: false)
  end

  def build_name(vehicle, details)
    if details.year && details.make && details.model
      suffix = vehicle.vin.to_s[9..]
      "#{details.year} #{details.make} #{details.model} - #{suffix}"
    else
      vehicle.vin
    end
  end

  def log(msg)
    Rails.logger.info "[VehicleVinDecodeJob] #{msg}"
  end
end