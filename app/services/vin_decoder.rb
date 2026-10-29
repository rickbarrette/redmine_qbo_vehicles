#The MIT License (MIT)
#
#Copyright (c) 2016 - 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'json'
require 'net/http'
require 'openssl'
require 'timeout'

# Decodes VINs with NHTSA's free vPIC service (https://vpic.nhtsa.dot.gov/api/), no API key needed.
#
#   result = VinDecoder.call("1C4HJXFG0JW123456", model_year: 2018)
#   result.success?  # => true
#   result.data      # => #<VinDecoder::Vehicle year=2018, make="Jeep", model="Wrangler", ...>
#
# - Invalid VINs and VINs NHTSA can't decode come back as a failure with NHTSA's explanation (final).
# - Network trouble, timeouts and NHTSA outages raise TransientError so the job can retry later.
# - NHTSA flags some decodes with warnings (e.g. a wrong check digit) but still returns the vehicle;
#   those count as decoded, and the warning is kept in data.warning.
class VinDecoder
  Result = Struct.new(:success?, :data, :error)

  # Decoded vehicle details, with the same field names the old nhtsa_vin gem provided
  Vehicle = Struct.new(:year, :make, :model, :trim, :doors, :body_class, :engine, :warning, keyword_init: true)

  # Raised when the lookup itself fails (network, timeout, NHTSA down or throttling). Worth retrying.
  class TransientError < StandardError; end

  ENDPOINT = 'https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/'
  OPEN_TIMEOUT = 5   # seconds
  READ_TIMEOUT = 20  # vPIC can take several seconds

  # Characters allowed in a VIN (I, O and Q are never used)
  VIN_FORMAT = /\A[A-HJ-NPR-Z0-9]+\z/

  NETWORK_ERRORS = [
    SocketError, Timeout::Error, IOError, EOFError, SystemCallError,
    OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError, JSON::ParserError
  ].freeze

  def self.call(vin, model_year: nil)
    new(vin, model_year: model_year).call
  end

  def initialize(vin, model_year: nil)
    @vin = vin.to_s.strip.upcase
    @model_year = model_year.to_i.positive? ? model_year.to_i : nil
  end

  def call
    log "Decoding VIN #{@vin}"
    return failure('VIN is blank') if @vin.empty?
    return failure("VIN contains invalid characters (I, O and Q are never used)") unless @vin.match?(VIN_FORMAT)
    return failure("VIN is too long (#{@vin.length} characters, at most 17)") if @vin.length > 17

    record = fetch_record
    vehicle = build_vehicle(record)

    if vehicle.make.blank? || vehicle.model.blank?
      failure(error_text(record).presence || 'NHTSA could not decode this VIN')
    else
      log "Decoded #{@vin}: #{vehicle.year} #{vehicle.make} #{vehicle.model}#{" (#{vehicle.warning})" if vehicle.warning}"
      success(vehicle)
    end
  end

  private

  # Calls vPIC and returns the single result record (a Hash of NHTSA field names to values)
  def fetch_record
    body = http_get(request_uri)
    record = Array(JSON.parse(body)['Results']).first
    raise TransientError, 'NHTSA returned no results' unless record.is_a?(Hash)

    record
  rescue *NETWORK_ERRORS => e
    raise TransientError, "NHTSA lookup failed: #{e.class}: #{e.message}"
  end

  def request_uri
    uri = URI.join(ENDPOINT, URI.encode_www_form_component(@vin))
    params = { format: 'json' }
    params[:modelyear] = @model_year if @model_year # NHTSA recommends sending it; helps pre-1980 VINs
    uri.query = URI.encode_www_form(params)
    uri
  end

  # Separate method so tests can stand in for the network
  def http_get(uri)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                               open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/json'
      request['User-Agent'] = 'redmine_qbo_vehicles'
      http.request(request)
    end

    case response
    when Net::HTTPSuccess then response.body
    when Net::HTTPTooManyRequests, Net::HTTPForbidden, Net::HTTPServerError
      raise TransientError, "NHTSA returned HTTP #{response.code}" # throttled or down: retry later
    else
      raise TransientError, "NHTSA returned unexpected HTTP #{response.code}"
    end
  end

  def build_vehicle(record)
    Vehicle.new(
      year: record['ModelYear'].to_i.positive? ? record['ModelYear'].to_i : nil,
      make: format_make(record['Make']),
      model: clean(record['Model']),
      trim: clean(record['Trim']).presence || clean(record['Series']),
      doors: clean(record['Doors']),
      body_class: clean(record['BodyClass']),
      engine: engine_description(record),
      warning: warning_text(record)
    )
  end

  # NHTSA sends makes in capitals ("JEEP", "LAND ROVER", "MERCEDES-BENZ"). Short ones are usually
  # abbreviations (GMC, RAM, BMW, KIA) and stay as they are; longer words are capitalized.
  def format_make(make)
    clean(make).split(' ').map do |word|
      word.split('-').map { |part| part.length <= 3 ? part : part.capitalize }.join('-')
    end.join(' ')
  end

  def engine_description(record)
    liters = clean(record['DisplacementL'])
    liters = format('%.1fL', liters.to_f) if liters.present? && liters.to_f.positive?
    cylinders = clean(record['EngineCylinders'])
    [liters.presence, (cylinders.present? ? "#{cylinders} cyl" : nil)].compact.join(' ').presence
  end

  # NHTSA's ErrorCode is "0" for a clean decode; anything else comes with an explanation in ErrorText
  def warning_text(record)
    codes = clean(record['ErrorCode']).split(',').map(&:strip)
    return nil if codes.empty? || codes == ['0']

    error_text(record)
  end

  def error_text(record)
    clean(record['ErrorText']).truncate(255)
  end

  def clean(value)
    value.to_s.strip
  end

  def success(data)
    Result.new(true, data, nil)
  end

  def failure(error)
    log "VIN decode failed for #{@vin}: #{error}"
    Result.new(false, nil, error)
  end

  def log(msg)
    Rails.logger.info "[VinDecoder] #{msg}"
  end
end
