// Scan VIN: reads the VIN barcode (driver's door jamb, windshield sticker, or a QR/Data Matrix label) with the
// phone's camera and fills it in.
//
// Buttons: <button data-vin-scan data-vin-target="#vehicle_vin" [data-vin-submit] data-zxing-url data-labels>
//   data-vin-target  the field to fill in
//   data-vin-submit  also submit its form (the vehicle search: one match opens the vehicle)
//
// Android Chrome reads barcodes itself (BarcodeDetector). Elsewhere (iPhones) the bundled ZXing library is loaded
// the first time Scan is tapped; nothing is sent anywhere. A read only counts when it's a VIN: 17 letters and digits,
// without I, O or Q. If its check digit (the 9th character, used on North American VINs) doesn't match, the same
// VIN has to be read twice in a row, so a misread bar doesn't slip through.
(function () {
  'use strict';

  var WANTED = ['code_39', 'code_128', 'data_matrix', 'qr_code'];
  var VIN = /^[A-HJ-NPR-Z0-9]{17}$/;
  var VALUES = { A: 1, B: 2, C: 3, D: 4, E: 5, F: 6, G: 7, H: 8, J: 1, K: 2, L: 3, M: 4, N: 5, P: 7, R: 9,
                 S: 2, T: 3, U: 4, V: 5, W: 6, X: 7, Y: 8, Z: 9 };
  var WEIGHTS = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2];
  var INTERVAL = 120; // ms between attempts
  var zxingLoading = null;

  function checkDigitOk(vin) {
    var sum = 0;
    for (var i = 0; i < 17; i++) {
      var c = vin.charAt(i);
      sum += (/\d/.test(c) ? parseInt(c, 10) : VALUES[c]) * WEIGHTS[i];
    }
    var check = sum % 11;
    return vin.charAt(8) === (check === 10 ? 'X' : String(check));
  }

  // The VIN in what a barcode says, or null. Some door labels put an "I" (import) before the VIN in their Code 39
  // barcode; QR and Data Matrix labels may hold more than the VIN.
  function vinIn(text) {
    var t = String(text || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (t.length === 18 && t.charAt(0) === 'I' && VIN.test(t.slice(1))) t = t.slice(1);
    if (VIN.test(t)) return { vin: t, checked: checkDigitOk(t) };
    var fallback = null;
    for (var i = 0; i + 17 <= t.length; i++) {
      var part = t.substr(i, 17);
      if (!VIN.test(part)) continue;
      if (checkDigitOk(part)) return { vin: part, checked: true };
      fallback = fallback || part;
    }
    return fallback ? { vin: fallback, checked: false } : null;
  }

  function loadZxing(url) {
    if (window.ZXing) return Promise.resolve(window.ZXing);
    if (!zxingLoading) {
      zxingLoading = new Promise(function (resolve, reject) {
        var script = document.createElement('script');
        script.src = url;
        script.onload = function () { window.ZXing ? resolve(window.ZXing) : reject(new Error('zxing')); };
        script.onerror = function () { zxingLoading = null; reject(new Error('zxing')); };
        document.head.appendChild(script);
      });
    }
    return zxingLoading;
  }

  // A function that takes the video and resolves to the barcodes' texts
  function makeReader(zxingUrl) {
    if ('BarcodeDetector' in window && window.BarcodeDetector.getSupportedFormats) {
      return window.BarcodeDetector.getSupportedFormats().then(function (supported) {
        var formats = WANTED.filter(function (f) { return supported.indexOf(f) !== -1; });
        if (formats.indexOf('code_39') === -1) return zxingReader(zxingUrl);
        var detector = new window.BarcodeDetector({ formats: formats });
        return function (video) {
          return detector.detect(video).then(function (codes) { return codes.map(function (c) { return c.rawValue; }); });
        };
      }).catch(function () { return zxingReader(zxingUrl); });
    }
    return zxingReader(zxingUrl);
  }

  function zxingReader(url) {
    return loadZxing(url).then(function (ZXing) {
      var hints = new Map();
      hints.set(ZXing.DecodeHintType.POSSIBLE_FORMATS, [ZXing.BarcodeFormat.CODE_39, ZXing.BarcodeFormat.CODE_128,
                                                        ZXing.BarcodeFormat.DATA_MATRIX, ZXing.BarcodeFormat.QR_CODE]);
      hints.set(ZXing.DecodeHintType.TRY_HARDER, true);
      var reader = new ZXing.MultiFormatReader();
      reader.setHints(hints);
      var canvas = document.createElement('canvas');
      var ctx = canvas.getContext('2d', { willReadFrequently: true });
      var frame = 0;
      return function (video) {
        var w = video.videoWidth, h = video.videoHeight;
        if (!w || !h) return Promise.resolve([]);
        var scale = Math.min(1, 1280 / Math.max(w, h));
        var sw = Math.round(w * scale), sh = Math.round(h * scale);
        // Every other frame is turned a quarter turn, so a barcode running up and down (a door jamb label with
        // the phone held upright) reads too; ZXing reads barcodes across the picture
        var sideways = frame++ % 2 === 1;
        canvas.width = sideways ? sh : sw;
        canvas.height = sideways ? sw : sh;
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        if (sideways) {
          ctx.translate(sh, 0);
          ctx.rotate(Math.PI / 2);
        }
        ctx.drawImage(video, 0, 0, sw, sh);
        try {
          var source = new ZXing.HTMLCanvasElementLuminanceSource(canvas);
          var result = reader.decode(new ZXing.BinaryBitmap(new ZXing.HybridBinarizer(source)));
          return Promise.resolve([result.getText()]);
        } catch (e) {
          return Promise.resolve([]); // nothing found in this frame
        } finally {
          reader.reset();
        }
      };
    });
  }

  function el(tag, className, text) {
    var e = document.createElement(tag);
    if (className) e.className = className;
    if (text) e.textContent = text;
    return e;
  }

  // Opens the camera; calls done(vin) once a VIN is read. Cancel, Escape or tapping outside closes it.
  function scan(button, done) {
    var labels = JSON.parse(button.getAttribute('data-labels') || '{}');
    var overlay = el('div', 'vin-scanner');
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', labels.title || 'Scan VIN');
    var video = el('video', 'vin-scanner-video');
    video.setAttribute('playsinline', '');
    video.muted = true;
    var frame = el('div', 'vin-scanner-frame');
    var hint = el('p', 'vin-scanner-hint', labels.hint);
    var bar = el('div', 'vin-scanner-bar');
    var torch = el('button', 'vin-scanner-torch', labels.torch);
    torch.type = 'button';
    torch.hidden = true;
    var cancel = el('button', 'vin-scanner-cancel', labels.cancel);
    cancel.type = 'button';
    bar.appendChild(torch);
    bar.appendChild(cancel);
    overlay.appendChild(video);
    overlay.appendChild(frame);
    overlay.appendChild(hint);
    overlay.appendChild(bar);
    document.body.appendChild(overlay);
    document.documentElement.classList.add('vin-scanner-open');

    var stream = null, timer = null, closed = false, last = null, torchOn = false;

    function close() {
      if (closed) return;
      closed = true;
      clearTimeout(timer);
      if (stream) stream.getTracks().forEach(function (t) { t.stop(); });
      overlay.remove();
      document.documentElement.classList.remove('vin-scanner-open');
      document.removeEventListener('keydown', onKey);
      button.focus();
    }
    function onKey(e) { if (e.key === 'Escape') close(); }
    function fail(message) {
      hint.textContent = message;
      hint.classList.add('vin-scanner-error');
    }

    cancel.addEventListener('click', close);
    document.addEventListener('keydown', onKey);

    navigator.mediaDevices.getUserMedia({
      audio: false,
      video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1080 } }
    }).then(function (s) {
      if (closed) { s.getTracks().forEach(function (t) { t.stop(); }); return; }
      stream = s;
      video.srcObject = s;
      var track = s.getVideoTracks()[0];
      var caps = track && track.getCapabilities ? track.getCapabilities() : {};
      if (caps.torch) {
        torch.hidden = false;
        torch.addEventListener('click', function () {
          torchOn = !torchOn;
          track.applyConstraints({ advanced: [{ torch: torchOn }] }).catch(function () {});
          torch.classList.toggle('vin-scanner-on', torchOn);
        });
      }
      return video.play().then(function () { return makeReader(button.getAttribute('data-zxing-url')); });
    }).then(function (read) {
      if (!read || closed) return;
      (function tick() {
        if (closed) return;
        read(video).then(function (texts) {
          if (closed) return;
          for (var i = 0; i < texts.length; i++) {
            var found = vinIn(texts[i]);
            if (!found) continue;
            if (found.checked || found.vin === last) {
              if (navigator.vibrate) navigator.vibrate(80);
              close();
              done(found.vin);
              return;
            }
            last = found.vin;
          }
          timer = setTimeout(tick, INTERVAL);
        }, function () { timer = setTimeout(tick, INTERVAL); });
      })();
    }).catch(function (e) {
      if (closed) return;
      var denied = e && (e.name === 'NotAllowedError' || e.name === 'SecurityError');
      fail(denied ? labels.denied : (e && e.name === 'NotFoundError' ? labels.noCamera : labels.failed));
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    var buttons = document.querySelectorAll('[data-vin-scan]');
    if (!buttons.length || !navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) return;

    // Only offer Scan when there's a camera
    var check = navigator.mediaDevices.enumerateDevices
      ? navigator.mediaDevices.enumerateDevices().then(function (devices) {
          return devices.some(function (d) { return d.kind === 'videoinput'; });
        }).catch(function () { return true; })
      : Promise.resolve(true);

    check.then(function (hasCamera) {
      if (!hasCamera) return;
      buttons.forEach(function (button) {
        button.hidden = false;
        button.addEventListener('click', function (e) {
          e.preventDefault();
          var field = document.querySelector(button.getAttribute('data-vin-target'));
          if (!field) return;
          scan(button, function (vin) {
            field.value = vin;
            field.dispatchEvent(new Event('input', { bubbles: true }));
            field.dispatchEvent(new Event('change', { bubbles: true }));
            if (button.hasAttribute('data-vin-submit') && field.form) {
              field.form.requestSubmit ? field.form.requestSubmit() : field.form.submit();
            } else {
              field.focus();
            }
          });
        });
      });
    });
  });

  // For tests
  window.VinScanner = { vinIn: vinIn, checkDigitOk: checkDigitOk };
})();
