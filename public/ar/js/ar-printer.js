/*
 * AR printer status HUD.
 *
 * Adapted from the standalone pdxhackerspace AR site to run against this app's
 * own /printers.json endpoint. One fetch loop pulls the full printer array;
 * setActivePrinter(id) (called by the marker-routing layer in the page) selects
 * which printer the HUD paints. No per-printer endpoint and no Home Assistant
 * sensor shape — everything comes from StatusExport's JSON.
 */
(function () {
  "use strict";

  var config = window.AR_CONFIG || {};
  var REFRESH_MS =
    Math.max(2, parseInt(config.printerRefreshSeconds, 10) || 8) * 1000;
  var KNOWN_PRINTERS = Array.isArray(config.printers) ? config.printers : [];
  var STATUS_URL = config.statusUrl || "/printers.json";

  // Gauge ceilings. This app exposes enclosure/ambient environment temps rather
  // than live nozzle/bed temps, so the two gauges are repurposed accordingly.
  var ENCLOSURE_MAX_C = 60;
  var AMBIENT_MAX_C = 50;

  // ---- pure view-model helpers -------------------------------------------

  function titleCase(s) {
    return String(s).replace(/\w\S*/g, function (word) {
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    });
  }

  function toNumber(value) {
    if (value == null) return null;
    var n = Number(value);
    return Number.isFinite(n) ? n : null;
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function roundNum(value, digits) {
    var n = Number(value);
    if (!Number.isFinite(n)) return null;
    return Number(n.toFixed(digits || 0));
  }

  function tempPct(current, max) {
    var n = toNumber(current);
    if (n == null || !(max > 0)) return 0;
    return clamp((n / max) * 100, 0, 100);
  }

  function progressPct(value) {
    var n = toNumber(value);
    if (n == null) return 0;
    return clamp(n, 0, 100);
  }

  function basename(name) {
    if (!name) return null;
    var parts = String(name).split(/[\\/]/);
    return parts[parts.length - 1] || String(name);
  }

  function classifyState(raw, progress) {
    if (raw == null || raw === "") {
      if (Number(progress) >= 100) return { kind: "finished", label: "Finished" };
      return { kind: "unknown", label: "Unknown" };
    }
    var lower = String(raw).toLowerCase();
    var label = titleCase(String(raw).replace(/_/g, " "));

    if (/(error|fault|stopped|cancell)/.test(lower)) return { kind: "error", label: label };
    if (/(attention|warn)/.test(lower)) return { kind: "attention", label: label };
    if (/(offline|unavailable|disconnect)/.test(lower)) return { kind: "offline", label: label };
    if (/(pause)/.test(lower)) return { kind: "paused", label: label };
    if (/(finish|complete|done)/.test(lower)) return { kind: "finished", label: label };
    if (/(print|busy|running)/.test(lower)) return { kind: "printing", label: label };
    if (Number(progress) >= 100) return { kind: "finished", label: label };
    if (/(idle|ready|operational|standby|off)/.test(lower)) return { kind: "idle", label: label };
    return { kind: "unknown", label: label };
  }

  function formatRemainingFromFinish(finishIso, now) {
    if (!finishIso) return null;
    var d = new Date(finishIso);
    if (Number.isNaN(d.getTime())) return null;
    var total = Math.round((d.getTime() - now.getTime()) / 1000);
    if (total <= 0) return null;
    var h = Math.floor(total / 3600);
    var m = Math.floor((total % 3600) / 60);
    if (h > 0) return h + "h " + m + "m";
    if (m > 0) return m + "m";
    return total + "s";
  }

  function formatFinishTime(value, now) {
    if (!value) return null;
    var d = new Date(value);
    if (Number.isNaN(d.getTime())) return String(value);
    var sameDay =
      d.getFullYear() === now.getFullYear() &&
      d.getMonth() === now.getMonth() &&
      d.getDate() === now.getDate();
    var time = d
      .toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
      .replace(/\s/g, "");
    if (sameDay) return time;
    var day = d.toLocaleDateString([], {
      weekday: "short",
      month: "numeric",
      day: "numeric",
    });
    return day + " " + time;
  }

  function buildTemp(current, max, label) {
    var n = toNumber(current);
    if (n == null) return null;
    return {
      current: n,
      target: null,
      unit: "°C",
      label: label,
      pct: tempPct(n, max),
      heating: false,
      atTarget: false,
      active: false,
    };
  }

  function buildAriaSummary(name, state, progress, finishText, remainingText) {
    var parts = [name || "Printer", state.label];
    if (progress != null) parts.push(roundNum(progress, 0) + "% complete");
    var eta = finishText || remainingText;
    if (eta) parts.push("done " + eta);
    return parts.join(", ");
  }

  function firstMaterial(printer, job) {
    if (job && Array.isArray(job.tools)) {
      for (var i = 0; i < job.tools.length; i++) {
        if (job.tools[i] && job.tools[i].material) return job.tools[i].material;
      }
    }
    if (Array.isArray(printer.heads)) {
      for (var j = 0; j < printer.heads.length; j++) {
        if (printer.heads[j] && printer.heads[j].material) return printer.heads[j].material;
      }
    }
    return null;
  }

  function firstNozzle(printer) {
    if (Array.isArray(printer.heads) && printer.heads[0] && printer.heads[0].nozzle_size_mm != null) {
      return roundNum(printer.heads[0].nozzle_size_mm, 2) + "mm";
    }
    return null;
  }

  function buildPrinterModel(printer, now) {
    now = now || new Date();
    var job = printer.job || null;

    var progressValue = job ? toNumber(job.progress_percent) : null;
    var stateRaw = printer.display_status || printer.operational_state;
    var state = classifyState(stateRaw, progressValue);

    var filenameRaw = job ? job.filename : null;
    var finishText = job ? formatFinishTime(job.estimated_finish_at, now) : null;
    var remainingText = job ? formatRemainingFromFinish(job.estimated_finish_at, now) : null;

    var enclosure = buildTemp(printer.enclosure_temp, ENCLOSURE_MAX_C, "Enclosure");
    var ambient = buildTemp(printer.ambient_temp, AMBIENT_MAX_C, "Ambient");

    var isPrinting = state.kind === "printing" || state.kind === "paused";

    return {
      id: printer.id,
      name: printer.name || (printer.id != null ? "Printer " + printer.id : "Printer"),
      fetchedAt: printer.updated_at || null,
      hasData: true,
      state: state,
      isPrinting: isPrinting,
      progress: {
        value: progressValue,
        pct: progressPct(progressValue),
        text: progressValue != null ? roundNum(progressValue, 1) + "%" : null,
      },
      filename: filenameRaw
        ? { raw: String(filenameRaw), display: basename(filenameRaw) }
        : null,
      remainingText: remainingText,
      finishText: finishText,
      eta: finishText || remainingText || null,
      material: firstMaterial(printer, job),
      nozzleDiameter: firstNozzle(printer),
      humidity: toNumber(printer.enclosure_humidity),
      nozzle: enclosure,
      bed: ambient,
      preview: { available: false },
      errors: [],
      ariaSummary: buildAriaSummary(printer.name, state, progressValue, finishText, remainingText),
    };
  }

  function buildErrorModel(name, reason) {
    return {
      id: null,
      name: name || "Printer",
      fetchedAt: null,
      hasData: false,
      state: { kind: "offline", label: "Status unavailable" },
      isPrinting: false,
      progress: { value: null, pct: 0, text: null },
      filename: null,
      remainingText: null,
      finishText: null,
      eta: null,
      material: null,
      nozzleDiameter: null,
      humidity: null,
      nozzle: null,
      bed: null,
      preview: { available: false },
      errors: reason ? [reason] : [],
      ariaSummary: (name || "Printer") + ", status unavailable",
    };
  }

  // ---- data source -------------------------------------------------------

  function printerName(id) {
    var known = KNOWN_PRINTERS.find(function (p) {
      return p.id === id;
    });
    return known ? known.name : "Printer " + id;
  }

  function loadingModel(id) {
    var model = buildErrorModel(printerName(id), null);
    model.id = id;
    model.state = { kind: "loading", label: "Connecting…" };
    model.errors = [];
    return model;
  }

  var defaultId =
    KNOWN_PRINTERS.length > 0 ? KNOWN_PRINTERS[0].id : null;
  var params = new URLSearchParams(location.search);
  var overrideId = parseInt(params.get("printer"), 10);
  if (!Number.isNaN(overrideId)) defaultId = overrideId;

  var activePrinterId = defaultId;
  var byId = {};
  var lastFetchError = null;
  var inFlight = null;

  function currentModel() {
    if (activePrinterId == null) {
      return buildErrorModel("Printer", "No printers configured");
    }
    var printer = byId[activePrinterId];
    if (printer) return buildPrinterModel(printer);
    if (lastFetchError) return buildErrorModel(printerName(activePrinterId), lastFetchError);
    return loadingModel(activePrinterId);
  }

  function refresh() {
    if (inFlight) return;
    inFlight = fetch(STATUS_URL, { cache: "no-store", credentials: "same-origin" })
      .then(function (res) {
        if (!res.ok) throw new Error("HTTP " + res.status);
        return res.json();
      })
      .then(function (list) {
        var map = {};
        (list || []).forEach(function (p) {
          if (p && p.id != null) map[p.id] = p;
        });
        byId = map;
        lastFetchError = null;
        if (activePrinterId == null && list && list.length) {
          activePrinterId = list[0].id;
        }
      })
      .catch(function (err) {
        lastFetchError = (err && err.message) || "fetch failed";
        console.error("ar-printer fetch failed", STATUS_URL, err);
      })
      .then(function () {
        inFlight = null;
      });
  }

  window.getPrinterStatusModel = currentModel;

  window.setActivePrinter = function (id) {
    var next = parseInt(id, 10);
    if (Number.isNaN(next) || next === activePrinterId) return;
    activePrinterId = next;
    if (!byId[next]) refresh();
  };

  refresh();
  setInterval(refresh, REFRESH_MS);

  // ---- HUD renderer ------------------------------------------------------

  var RING_RADIUS = 42;
  var GAUGE_RADIUS = 40;
  var GAUGE_SWEEP_DEG = 270;
  var ringCircumference = 2 * Math.PI * RING_RADIUS;
  var gaugeLength = (GAUGE_SWEEP_DEG / 360) * 2 * Math.PI * GAUGE_RADIUS;

  var STATE_KINDS = [
    "loading", "printing", "paused", "idle", "finished",
    "attention", "error", "offline", "unknown",
  ];

  var hud = document.getElementById("printer-hud");

  function q(sel) {
    return hud ? hud.querySelector(sel) : null;
  }

  var els = hud
    ? {
        panel: q(".phud__panel"),
        name: q(".phud__name"),
        stateLabel: q(".phud__state-label"),
        state: q(".phud__state"),
        etaValue: q(".phud__eta-value"),
        previewImg: q(".phud__preview-img"),
        previewFallback: q(".phud__preview-fallback"),
        fileName: q(".phud__file-name"),
        ringFill: q(".phud__ring-fill"),
        ringPct: q(".phud__ring-pct"),
        ringSub: q(".phud__ring-sub"),
        nozzleFill: q(".phud__gauge--nozzle .phud__gauge-fill"),
        nozzleValue: q(".phud__gauge--nozzle .phud__gauge-value"),
        nozzleName: q(".phud__gauge--nozzle .phud__gauge-name"),
        nozzleFig: q(".phud__gauge--nozzle"),
        bedFill: q(".phud__gauge--bed .phud__gauge-fill"),
        bedValue: q(".phud__gauge--bed .phud__gauge-value"),
        bedName: q(".phud__gauge--bed .phud__gauge-name"),
        bedFig: q(".phud__gauge--bed"),
        chips: q(".phud__chips"),
        errors: q(".phud__errors"),
      }
    : null;

  function initSvgGeometry() {
    if (!els) return;
    if (els.ringFill) els.ringFill.style.strokeDasharray = "0 " + ringCircumference;
    [els.nozzleFill, els.bedFill].forEach(function (fill) {
      if (fill) fill.style.strokeDasharray = "0 " + gaugeLength;
    });
  }

  function setRing(pct) {
    if (!els.ringFill) return;
    var dash = (clamp(pct, 0, 100) / 100) * ringCircumference;
    els.ringFill.style.strokeDasharray = dash + " " + ringCircumference;
  }

  function setGauge(fill, pct) {
    if (!fill) return;
    var dash = (clamp(pct, 0, 100) / 100) * gaugeLength;
    fill.style.strokeDasharray = dash + " " + gaugeLength;
  }

  function fmtTemp(temp) {
    if (!temp || temp.current == null) return "—";
    return Math.round(temp.current) + (temp.unit || "°C");
  }

  function renderGauge(figEl, fillEl, valueEl, nameEl, temp) {
    setGauge(fillEl, temp ? temp.pct : 0);
    if (valueEl) valueEl.textContent = fmtTemp(temp);
    if (nameEl && temp && temp.label) nameEl.textContent = temp.label;
    if (figEl) {
      figEl.classList.toggle("is-heating", Boolean(temp && temp.heating));
      figEl.classList.toggle("is-attarget", Boolean(temp && temp.atTarget));
    }
  }

  function renderChips(model) {
    if (!els.chips) return;
    els.chips.innerHTML = "";
    var chips = [];
    if (model.material) chips.push({ label: "Material", value: model.material });
    if (model.nozzleDiameter) chips.push({ label: "Nozzle", value: model.nozzleDiameter });
    if (model.humidity != null) chips.push({ label: "Humidity", value: Math.round(model.humidity) + "%" });
    if (model.remainingText) chips.push({ label: "Remaining", value: model.remainingText });
    chips.forEach(function (chip) {
      var li = document.createElement("li");
      li.className = "phud__chip";
      var label = document.createElement("span");
      label.className = "phud__chip-label";
      label.textContent = chip.label;
      var value = document.createElement("span");
      value.className = "phud__chip-value";
      value.textContent = chip.value;
      li.appendChild(label);
      li.appendChild(value);
      els.chips.appendChild(li);
    });
    els.chips.hidden = chips.length === 0;
  }

  function renderErrors(model) {
    if (!els.errors) return;
    els.errors.innerHTML = "";
    var messages = (model.errors || []).slice(0, 3);
    messages.forEach(function (msg) {
      var li = document.createElement("li");
      li.className = "phud__error";
      li.textContent = msg;
      els.errors.appendChild(li);
    });
    els.errors.hidden = messages.length === 0;
  }

  function render() {
    if (!els) return;
    var model = currentModel();
    if (!model) return;

    els.name.textContent = model.name;
    if (model.ariaSummary) hud.setAttribute("aria-label", model.ariaSummary);

    var kind = (model.state && model.state.kind) || "unknown";
    els.stateLabel.textContent = (model.state && model.state.label) || "—";
    STATE_KINDS.forEach(function (k) {
      els.state.classList.toggle("is-" + k, k === kind);
      if (els.panel) els.panel.classList.toggle("is-" + k, k === kind);
    });

    els.etaValue.textContent = model.eta || "—";

    setRing(model.progress.pct);
    els.ringPct.textContent =
      model.progress.value != null ? Math.round(model.progress.value) + "%" : "—";
    els.ringSub.textContent = (model.state && model.state.label) || "";

    renderGauge(els.nozzleFig, els.nozzleFill, els.nozzleValue, els.nozzleName, model.nozzle);
    renderGauge(els.bedFig, els.bedFill, els.bedValue, els.bedName, model.bed);

    els.fileName.textContent = model.filename ? model.filename.display : "No active file";

    // Preview always falls back to the placeholder icon; this app has no
    // per-job thumbnail endpoint.
    if (els.previewImg && els.previewFallback) {
      els.previewImg.hidden = true;
      els.previewFallback.hidden = false;
    }

    renderChips(model);
    renderErrors(model);
  }

  window.setPrinterHudVisible = function (visible) {
    if (hud) hud.classList.toggle("is-visible", !!visible);
  };

  if (hud) {
    initSvgGeometry();
    setInterval(render, 250);
    render();
  }
})();
