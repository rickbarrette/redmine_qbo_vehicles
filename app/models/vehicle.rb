#The MIT License (MIT)
#
#Copyright (c) 2016 - 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class Vehicle < ActiveRecord::Base
  
  belongs_to :customer
  has_many :issues
  validates_presence_of :customer
  validates :vin, uniqueness: true
  before_save :decode_vin

  def self.searchable_columns
    ['vin', 'make', 'model', 'year']
  end

  def self.searchable_options
    {
      columns: searchable_columns,
      scope: self.all
    }
  end

  def self.search_result_ranks_and_ids(tokens, user, project = nil, options = {})
    return {} if tokens.blank?

    scope = self.all

    tokens.each do |token|
      q = "%#{sanitize_sql_like(token)}%"
      scope = where("vin LIKE ? OR make LIKE ? OR model LIKE ? OR year LIKE ?", "%#{q}%", "%#{q}%", "%#{q}%", "%#{q}%") 
    end

    ids = scope.distinct.limit(options[:limit] || 100).pluck(:id)

    # Assign simple uniform ranking
    ids.each_with_object({}) { |id, h| h[id] = id }
  end

  def self.search_results_from_ids(ids, *args)
    return [] if ids.blank?

    Rails.logger.warn "IDS: #{ids.inspect}"

    ids = ids.map(&:to_i)
    records = where(id: ids).index_by(&:id)
    ids.map { |id| records[id] }.compact
  end
  
  # ---- Redmine Search Event Interface ----
  def event_type
    'vehicle'
  end

  def event_title
    to_s
  end

  def event_description
    "#{vin} #{year} #{make} #{model}"
  end

  def event_url
    Rails.application.routes.url_helpers.vehicle_path(self)
  end

  def event_datetime
    updated_at || created_at
  end

  def project
    # Vehicles are not project scoped in your schema.
    # Return nil so global search works cleanly.
    nil
  end

  # returns a human readable string
  def to_s
    if year.nil? or make.nil? or model.nil?
      return "#{vin}"
    else
      split_vin = vin.scan(/.{1,9}/)
      return "#{year} #{make} #{model} - #{split_vin[1]}"
    end
  end
  
  # returns the raw JSON details from NHTSA
  def details
    get_details if @details.nil?
    return @details
  end
  
  # Force Upper Case for make numbers
  def make=(val)
    # The to_s is in case you get nil/non-string
    write_attribute(:make, val.to_s.titleize)
  end
  
  # Force Upper Case for model numbers
  def model=(val)
    # The to_s is in case you get nil/non-string
    write_attribute(:model, val.to_s.titleize)
  end
  
  # Force Upper Case & strip VIN of all illegal chars (for barcode scanner)
  def vin=(val)
    val = val.to_s.upcase.gsub(/[^A-HJ-NPR-Za-hj-npr-z\d]+/,"")
    write_attribute(:vin, val)
  end
  
  # search for a vehicle by vin, make, model, or year
  def self.search(query)
    q = sanitize_sql_like(query)
    where("vin LIKE ? OR make LIKE ? OR model LIKE ? OR year LIKE ?", "%#{q}%", "%#{q}%", "%#{q}%", "%#{q}%") 
  end
	
  # decodes a vin and updates self
  def decode_vin
    get_details
    if @details
      begin
        self.year = @details.year unless @details.year.nil?
        self.make = @details.make unless @details.make.nil?
        self.model = @details.model unless @details.model.nil?
        self.doors = @details.doors unless @details.doors.nil?
        self.trim = @details.trim unless @details.trim.nil?
      rescue Exception => e
        errors.add(:vin, e.message)
      end
    end
    self.name = to_s
  end

  # reurns all invoices for this vehicle
  def invoices
    self.issues.flat_map(&:invoices).uniq.compact
  end

  # returns all estimates for this vehicle
  def estimates
    self.issues.flat_map(&:estimate).uniq.compact
  end
  
  private
  
  # init method to pull JSON details from NHTSA
  def get_details
    if self.vin?
      #validate the vin before calling a remote server
      validation = NhtsaVin.validate(self.vin)
      begin
        #if the vin validation failed, raise an exception and exit
        raise RuntimeError, validation.error unless validation.valid?
        # query NHTSA for details on the vin
        query = NhtsaVin.get(self.vin)
        raise RuntimeError, query.error unless query.valid?
        @details = query.response
      rescue Exception => e
        errors.add(:vin, e.message)
      end
    end
  end
  
end
