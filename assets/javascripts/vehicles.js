//The MIT License (MIT)
//
//Copyright (c) 2016 - 2026 rick barrette
//
//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Refreshes the issue form's vehicle list when the customer changes, so only that customer's vehicles
// can be picked. redmine_qbo's customer autocomplete fires "change" on #customer_id through jQuery,
// so this listens with jQuery too.
(function ($) {
  if (!$) return;

  $(document).on('change', '#customer_id', function () {
    var select = document.getElementById('issue_vehicle_id');
    if (!select || !select.dataset.vehiclesUrl) return;

    var customerId = this.value;
    var previous = select.value;

    function fill(vehicles) {
      select.innerHTML = '';
      select.appendChild(new Option('', ''));
      vehicles.forEach(function (v) { select.appendChild(new Option(v.name, v.id)); });
      if (vehicles.some(function (v) { return String(v.id) === previous; })) select.value = previous;
    }

    if (!customerId) { fill([]); return; }

    // No ".json" in the URL: Redmine treats those as API requests and ignores the browser session
    fetch(select.dataset.vehiclesUrl.replace('__CUSTOMER_ID__', encodeURIComponent(customerId)), {
      headers: { 'Accept': 'application/json' },
      credentials: 'same-origin'
    })
      .then(function (res) { return res.ok ? res.json() : null; })
      .then(function (vehicles) { if (vehicles) fill(vehicles); })  // on failure, leave the list alone
      .catch(function (err) { console.warn('Could not load vehicles', err); });
  });
})(window.jQuery);
