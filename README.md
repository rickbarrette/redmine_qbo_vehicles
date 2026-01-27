# Redmine QuickBooks Online Vehicles

A redmine plugin to compliment the Redmine QuickBooks Online Vehicles plug in.

The goal of this project is to allow add vehicle tracking for customer vehicles.

## Compatibility

| Redmine QBO Plugin Version | Redmine Version |
| :--- | :--- |
| Version 2026.1.2+ | Redmine 6.1 |

## Features

Adds vehicles that are owned by customers that can be attached to issues.

## Installation

1. **Clone the plugin:**
   Clone this repo into your plugin folder and checkout a tagged version.
   ```bash
   cd path/to/redmine/plugins
   git clone git@github.com:rickbarrette/redmine_qbo_vehicles.git
   cd redmine_qbo
   git checkout <tag>
   ```

2.  **Install dependencies:** *Crucial for Redmine 6 / Rails 7 compatibility.*
    
    Bash
    
    ```
    bundle install
    ```
    
3.  **Migrate your database:**
    
    Bash
    
    ```
    bundle exec rake redmine:plugins:migrate RAILS_ENV=production
    ```
    
4.  **Restart Redmine:** You must restart your Redmine server instance for the plugin and hooks to load.

## Usage

Simply add vehicles to customers via Customer view

Once a customer is attached to the customer, they can be attached to an issue.

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