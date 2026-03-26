#The MIT License (MIT)
#
#Copyright (c) 2016 - 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class VinDecoder
  Result = Struct.new(:success?, :data, :error)

  def self.call(vin)
    new(vin).call
  end

  def initialize(vin)
    @vin = vin
  end

  def call
    log "Decoding VIN"
    validation = NhtsaVin.validate(@vin)
    return failure(validation.error) unless validation.valid?

    query = NhtsaVin.get(@vin)
    return failure(query.error) unless query.valid?

    success(query.response)
  rescue StandardError => e
    failure(e.message)
  end

  private

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