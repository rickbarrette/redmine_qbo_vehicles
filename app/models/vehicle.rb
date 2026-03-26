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
  has_many :issues
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

  def make=(val)
    super(val.to_s.strip)
  end

  def model=(val)
    super(val.to_s.strip)
  end

  # Redmine compatibility shim
  def project
    nil
  end

  def self.search(query)
    return none if query.blank?
    q = "%#{sanitize_sql_like(query)}%"
    where( "vin LIKE :q OR make LIKE :q OR model LIKE :q OR year LIKE :q", q: q)
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