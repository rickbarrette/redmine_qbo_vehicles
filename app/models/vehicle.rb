#The MIT License (MIT)
#
#Copyright (c) 2016 - 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class Vehicle < ApplicationRecord
  include Redmine::Acts::Searchable
  include Redmine::Acts::Event

  belongs_to :customer
  # A vehicle with issues can't be deleted, so its service history is never lost. When a vehicle is
  # sold, change its customer instead: past issues keep their original customer and stay on this vehicle.
  has_many :issues, dependent: :restrict_with_error
  validates :customer, presence: true
  validates :vin, presence: true, uniqueness: true
  before_validation :normalize_vin
  after_commit :enqueue_vin_decode, if: :saved_change_to_vin?
  acts_as_searchable columns: %w[vin make model year], scope: ->(_context) { all }, date_column: :updated_at
  acts_as_event :title => Proc.new {|o| "#{o.to_s}"},
                :url => Proc.new {|o| { :controller => 'vehicles', :action => 'show', :id => o.id} },
                :type => :to_s,
                :description => Proc.new {|o| "#{o.vin} - #{o.customer}"},
                :datetime => Proc.new {|o| o.updated_at || o.created_at}

  def estimates
    issues.includes(:estimate).flat_map(&:estimate).uniq.compact
  end

  def invoices
    issues.includes(:invoices).flat_map(&:invoices).uniq.compact
  end

  # The issue custom field holding mileage: the one chosen in the plugin settings, else one named "Mileage"
  def self.mileage_custom_field
    settings = Setting.plugin_redmine_qbo_vehicles || {}
    chosen = settings['mileage_custom_field_id'].to_i
    (IssueCustomField.find_by(id: chosen) if chosen.positive?) || IssueCustomField.find_by(name: 'Mileage')
  end

  # The most recent issue for this vehicle with a mileage recorded
  def last_service
    field = self.class.mileage_custom_field
    return nil unless field

    issues
      .joins(:custom_values)
      .where(custom_values: { custom_field_id: field.id })
      .where.not(custom_values: { value: ['', nil] })
      .order(created_on: :desc)
      .first
  end

  # { date:, mileage: } from the most recent issue with a mileage, or nil. One query, cached per vehicle.
  def last_service_info
    return @last_service_info if defined?(@last_service_info)

    field = self.class.mileage_custom_field
    row = if field
            issues
              .joins(:custom_values)
              .where(custom_values: { custom_field_id: field.id })
              .where.not(custom_values: { value: ['', nil] })
              .order(created_on: :desc)
              .pick(:created_on, 'custom_values.value')
          end

    @last_service_info = row && { date: row[0]&.to_date, mileage: row[1].presence }
  end

  def last_service_date
    last_service_info&.dig(:date)
  end

  def last_service_mileage
    last_service_info&.dig(:mileage)
  end

  def make=(val)
    super(val.to_s.strip)
  end

  def model=(val)
    super(val.to_s.strip)
  end

  def name
    val = self[:name]
    val.present? ? val : to_s
  end

  # Redmine compatibility shim
  def project
    nil
  end

  # Vehicles matching one search term. A 4-digit term also matches the year exactly (comparing the
  # numeric year with LIKE fails on PostgreSQL). The name column covers "2018 Jeep Wrangler - ..." text.
  def self.search(query)
    term = query.to_s.strip
    q = "%#{sanitize_sql_like(term)}%"
    scope = where("vin LIKE :q OR make LIKE :q OR model LIKE :q OR name LIKE :q", q: q)
    scope = scope.or(where(year: term.to_i)) if term.match?(/\A\d{4}\z/)
    scope
  end

  # Vehicles matching every word of the query, e.g. "2018 jeep wrangler"
  def self.search_all(query)
    query.to_s.split.reduce(all) { |scope, term| scope.where(id: search(term).select(:id)) }
  end

  # Override the defult redmine seach method to rank results by id
  def self.search_result_ranks_and_ids(tokens, user, project = nil, options = {})
    return {} if tokens.blank?
    scope = self.all
    tokens.each do |token|
      scope = scope.search(token)
    end
    ids = scope.distinct.limit(options[:limit] || 100).pluck(:id)
    ids.index_with { |id| id }
  end

  def to_s
    return self[:name] if self[:name].present?
    return vin if year.blank? || make.blank? || model.blank?

    suffix = vin.to_s[9..] || vin
    "#{year} #{make} #{model} - #{suffix}"
  end

  private

  def enqueue_vin_decode
    VehicleVinDecodeJob.perform_later(id)
  end

  def normalize_vin
    return if vin.blank?
    cleaned = vin.to_s.upcase.gsub(/[^A-HJ-NPR-Z\d]/, "")
    self.vin = cleaned
  end

  def log(msg)
    Rails.logger.info "[Vehicle] #{msg}"
  end
end