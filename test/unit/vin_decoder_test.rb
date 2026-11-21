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

class VinDecoderTest < ActiveSupport::TestCase
  include QboVehiclesTestHelper

  def test_decodes_a_vin
    stub_vpic
    result = VinDecoder.call(VIN)
    assert result.success?
    vehicle = result.data
    assert_equal 2018, vehicle.year
    assert_equal 'Jeep', vehicle.make
    assert_equal 'Wrangler', vehicle.model
    assert_equal 'Sport', vehicle.trim
    assert_equal '4', vehicle.doors
    assert_equal 'Sport Utility Vehicle (SUV)', vehicle.body_class
    assert_equal '3.6L 6 cyl', vehicle.engine
    assert_nil vehicle.warning
  end

  def test_makes_are_capitalized_except_abbreviations
    { 'LAND ROVER' => 'Land Rover', 'MERCEDES-BENZ' => 'Mercedes-Benz', 'GMC' => 'GMC', 'RAM' => 'RAM',
      'CHEVROLET' => 'Chevrolet' }.each do |nhtsa, shown|
      stub_vpic('Make' => nhtsa)
      assert_equal shown, VinDecoder.call(VIN).data.make
    end
  end

  def test_series_stands_in_for_a_missing_trim
    stub_vpic('Trim' => '', 'Series' => 'Unlimited')
    assert_equal 'Unlimited', VinDecoder.call(VIN).data.trim
  end

  def test_engine_description
    stub_vpic('DisplacementL' => '5', 'EngineCylinders' => '')
    assert_equal '5.0L', VinDecoder.call(VIN).data.engine
    stub_vpic('DisplacementL' => '', 'EngineCylinders' => '8')
    assert_equal '8 cyl', VinDecoder.call(VIN).data.engine
    stub_vpic('DisplacementL' => '', 'EngineCylinders' => '')
    assert_nil VinDecoder.call(VIN).data.engine
  end

  def test_a_decode_with_a_warning_still_counts
    stub_vpic('ErrorCode' => '1', 'ErrorText' => '1 - Check Digit (9th position) does not calculate properly')
    result = VinDecoder.call(VIN)
    assert result.success?
    assert_match(/Check Digit/, result.data.warning)
  end

  def test_nhtsa_cannot_decode
    stub_vpic('Make' => '', 'Model' => '', 'ErrorCode' => '11', 'ErrorText' => '11 - Incorrect Model Year')
    result = VinDecoder.call(VIN)
    assert_not result.success?
    assert_equal '11 - Incorrect Model Year', result.error

    stub_vpic('Make' => '', 'ErrorText' => '')
    assert_equal 'NHTSA could not decode this VIN', VinDecoder.call(VIN).error
  end

  def test_bad_vins_are_not_looked_up
    VinDecoder.any_instance.expects(:http_get).never
    assert_equal 'VIN is blank', VinDecoder.call('  ').error
    assert_match(/invalid characters/, VinDecoder.call('1C4HJXFGOJW123456').error)
    assert_match(/too long \(18 characters/, VinDecoder.call("#{VIN}9").error)
  end

  def test_the_request
    uri = VinDecoder.new(VIN.downcase, model_year: '2018').send(:request_uri)
    assert_equal "https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/#{VIN}?format=json&modelyear=2018", uri.to_s
    uri = VinDecoder.new(VIN, model_year: 0).send(:request_uri)
    assert_equal 'format=json', uri.query
  end

  def test_network_trouble_is_transient
    VinDecoder.any_instance.stubs(:http_get).raises(SocketError, 'getaddrinfo failed')
    error = assert_raises(VinDecoder::TransientError) { VinDecoder.call(VIN) }
    assert_match(/SocketError: getaddrinfo failed/, error.message)

    VinDecoder.any_instance.stubs(:http_get).returns('<html>down</html>')
    assert_raises(VinDecoder::TransientError) { VinDecoder.call(VIN) }

    VinDecoder.any_instance.stubs(:http_get).returns({ 'Results' => [] }.to_json)
    assert_raises(VinDecoder::TransientError) { VinDecoder.call(VIN) }
  end

  def test_http_responses
    decoder = VinDecoder.new(VIN)
    VinDecoder.any_instance.unstub(:http_get)
    ok = Net::HTTPOK.new('1.1', '200', 'OK')
    ok.stubs(:body).returns('{}')
    Net::HTTP.stubs(:start).returns(ok)
    assert_equal '{}', decoder.send(:http_get, decoder.send(:request_uri))

    [Net::HTTPTooManyRequests.new('1.1', '429', 'Slow down'), Net::HTTPServiceUnavailable.new('1.1', '503', 'Down'),
     Net::HTTPNotFound.new('1.1', '404', 'Missing')].each do |response|
      Net::HTTP.stubs(:start).returns(response)
      error = assert_raises(VinDecoder::TransientError) { decoder.send(:http_get, decoder.send(:request_uri)) }
      assert_includes error.message, response.code
    end
  end
end
