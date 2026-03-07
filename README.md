# Redmine QuickBooks Online Vehicles

A Redmine plugin to complement the [Redmine QuickBooks Online](https://github.com/rickbarrette/redmine_qbo) plugin.

The goal of this project is to enable vehicle tracking for customer vehicles within Redmine.

## Requirements

* **Redmine:** 6.1+
* **Parent Plugin:** [Redmine QuickBooks Online](https://github.com/rickbarrette/redmine_qbo)

## Compatibility
| Plugin Version | Redmine Version | Ruby Version |
| :--- | :--- | :--- |
| 2026.1.2+ | Redmine 6.1 | 3.2+ |

## Features

* **Asset Tracking:** Adds vehicles owned by customers to the system.
* **Issue Association:** Allows these vehicles to be attached directly to Redmine issues for better service tracking.

## Installation

1.  **Clone the plugin:**
    Navigate to your Redmine plugins directory and clone the repository.
    ```bash
    cd path/to/redmine/plugins
    git clone git@github.com:rickbarrette/redmine_qbo_vehicles.git
    cd redmine_qbo_vehicles
    git checkout <tag> 
    ```
    *(Note: Replace `<tag>` with the specific release version you wish to use, or omit the last line to use the main branch.)*

2.  **Install dependencies:**
    *Crucial for Redmine 6 / Rails 7 compatibility.*
    ```bash
    bundle install
    ```

3.  **Migrate your database:**
    ```bash
    bundle exec rake redmine:plugins:migrate RAILS_ENV=production
    ```

4.  **Restart Redmine:**
    You must restart your Redmine server instance (e.g., Puma, Passenger, Unicorn) for the plugin and hooks to load correctly.

## Usage

1.  **Add a Vehicle:** Navigate to a Customer Profile. You will see a new option to add vehicles to that customer.
2.  **Link to Issue:** Once a vehicle is added to a customer, it can be selected and attached to an Issue relevant to that customer.

## License

> The MIT License (MIT)
>
> Copyright (c) 2016 - 2026 Rick Barrette
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.