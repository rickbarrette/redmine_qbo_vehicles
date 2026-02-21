#The MIT License (MIT)
#
#Copyright (c) 2016 - 2026 rick barrette
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Redmine::Plugin.register :redmine_qbo_vehicles do
  
  # About
  name 'Redmine QBO Vehicles plugin'
  author 'Rick Barrette'
  description 'This is a plugin for Redmine to intergrate with the redmine_qbo plugin to provide vehicle data tracking'
  version '2026.2.5'
  url 'https://github.com/rickbarrette/redmine_qbo_vehicles'
  author_url 'https://barrettefabrication.com'
  requires_redmine version_or_higher: '6.1.0'

  # Ensure redmine_qbo is installed
  begin
    requires_redmine_plugin :redmine_qbo, version_or_higher: '2026.1.2'
  rescue Redmine::PluginNotFound
    raise 'Please install the redmine_qbo plugin (https://github.com/rickbarrette/redmine_qbo)'
  end
  
  # Add safe attributes for core models
  Issue.safe_attributes :vehicle_id

  # Permissions for security
  permission :view_vehicles, vehicles: :new, public: false

  # Register top menu items
  menu :top_menu, :vehicles, { controller: :vehicles, action: :index }, caption: :field_vehicles, if: Proc.new { User.current.logged? }
    
  Redmine::Search.map do |search|
    search.register :vehicles
  end

end

# Dynamically load all Hooks & Patches recursively
base_dir = File.join(File.dirname(__FILE__), 'lib')

# '**' looks inside subdirectories, '*.rb' matches Ruby files
Dir.glob(File.join(base_dir, '**', '*.rb')).sort.each do |file|
  require file
end