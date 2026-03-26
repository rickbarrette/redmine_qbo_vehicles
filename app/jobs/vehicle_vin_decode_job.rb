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
  retry_on StandardError, wait: 5.minutes, attempts: 5

  def perform(vehicle_id)
    log "Looking up VIN for vehicle ##{vehicle_id}"
    vehicle = Vehicle.find_by(id: vehicle_id)
    return unless vehicle&.vin.present?
    result = VinDecoder.call(vehicle.vin)
    
    unless result.success?
      log "Failed to decode vin"
      vehicle.update(vin_decoded: false, error: result.error)
      return
    end

    details = result.data

    vehicle.update(
      year: details.year.presence || vehicle.year,
      make: details.make.presence || vehicle.make,
      model: details.model.presence || vehicle.model,
      doors: details.doors.presence || vehicle.doors,
      trim: details.trim.presence || vehicle.trim,
      name: vehicle.to_s,
      vin_decoded: true,
      error: nil
    )
  end

  private

  def log(msg)
    Rails.logger.info "[VehicleVinDecodeJob] #{msg}"
  end
end