class FilamentType
  # The types seeded on a new install; common ones are listed first and on the dashboard.
  # Temperatures are typical manufacturer ranges in °C (mostly from the Prusa and Bambu slicer
  # profiles); admins can adjust them. Aliases are the other names printers and slicers report, e.g. Prusa reports TPU as FLEX and Bambu reports
  # its support filaments as PLA-S, PA-S and ABS-S.
  module Defaults
    ALL = [
      { name: 'PLA', common: true, nozzle: 190..230, bed: 45..65, aliases: 'PLA-AERO, PLA-S, Support W' },
      { name: 'PETG', common: true, nozzle: 220..260, bed: 65..90, aliases: 'PET-G, PET' },
      { name: 'PETG-CF', nozzle: 230..270, bed: 65..90, hardened: true },
      { name: 'PETG-ESD', nozzle: 250..270, bed: 80..90, hardened: true },
      { name: 'PET-CF', nozzle: 260..290, bed: 80..100, hardened: true, ventilation: true },
      { name: 'ABS', common: true, nozzle: 240..280, bed: 90..110, ventilation: true, aliases: 'ABS-S' },
      { name: 'ABS-GF', nozzle: 240..280, bed: 90..100, hardened: true, ventilation: true },
      { name: 'ASA', common: true, nozzle: 240..280, bed: 90..110, ventilation: true },
      { name: 'ASA-Aero', nozzle: 240..280, bed: 90..100, ventilation: true, aliases: 'ASA Aero' },
      { name: 'ASA-CF', nozzle: 250..280, bed: 90..100, hardened: true, ventilation: true },
      { name: 'TPU', common: true, nozzle: 200..240, bed: 30..60, ventilation: true,
        aliases: 'FLEX, TPU-AMS, TPU for AMS' },
      { name: 'PC', nozzle: 260..300, bed: 100..120, ventilation: true, aliases: 'PC FR' },
      { name: 'PC-CF', nozzle: 270..300, bed: 100..115, hardened: true, ventilation: true },
      { name: 'PA', nozzle: 260..300, bed: 70..110, ventilation: true, aliases: 'Nylon, PA6, PA12, PA-S, Support G' },
      { name: 'PA-CF', nozzle: 260..300, bed: 80..110, hardened: true, ventilation: true,
        aliases: 'PA6-CF, PA12-CF, PAHT-CF, PA11-CF' },
      { name: 'PA-GF', nozzle: 260..300, bed: 90..100, hardened: true, ventilation: true, aliases: 'PA6-GF' },
      { name: 'PPA-CF', nozzle: 280..320, bed: 100..110, hardened: true, ventilation: true },
      { name: 'PPS-CF', nozzle: 310..340, bed: 100..110, hardened: true, ventilation: true },
      { name: 'PLA-CF', nozzle: 210..240, bed: 45..65, hardened: true },
      { name: 'PP', nozzle: 220..250, bed: 55..100 },
      { name: 'PP-GF', nozzle: 235..255, bed: 90..100, hardened: true },
      { name: 'PP-CF', nozzle: 250..280, bed: 85..95, hardened: true },
      { name: 'PEI', nozzle: 395..410, bed: 140..150, ventilation: true, aliases: 'PEI 1010, ULTEM' },
      { name: 'PVA', nozzle: 190..220, bed: 45..60 },
      { name: 'PVB', nozzle: 205..225, bed: 65..85 },
      { name: 'BVOH', nozzle: 210..230, bed: 50..70 },
      { name: 'HIPS', nozzle: 220..250, bed: 90..110, ventilation: true }
    ].freeze
  end
end
