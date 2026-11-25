require 'test_helper'

class FilamentTypeTest < ActiveSupport::TestCase
  test 'matches materials by name, alias, and leading word, preferring the longest name' do
    assert_equal filament_types(:pla), FilamentType.match('pla')
    assert_equal filament_types(:pla), FilamentType.match('PLA Basic')
    assert_equal filament_types(:petg), FilamentType.match('PET-G')
    assert_equal filament_types(:pa_cf), FilamentType.match('PAHT-CF')
    assert_equal filament_types(:petg), FilamentType.match('PETG HF')
    assert_nil FilamentType.match('PLAX')
    assert_nil FilamentType.match('Mystery goo')
    assert_nil FilamentType.match('')
  end

  test 'a fiber-filled material never falls back to its unfilled base type' do
    filament_types(:pla).update!(aliases: 'Nylon')

    assert_nil FilamentType.match('Nylon-CF')
    assert_nil FilamentType.match('Nylon CF')
    assert_nil FilamentType.match('PLA Glass Fiber')
    assert_nil FilamentType.match('PLA-S'), 'only a space separates extra words'
  end

  test 'a CF variant is not mistaken for its base filament' do
    pla_cf = FilamentType.create!(name: 'PLA-CF', nozzle_min_c: 210, nozzle_max_c: 240, bed_min_c: 45,
                                  bed_max_c: 65, requires_hardened_nozzle: true)

    assert_equal pla_cf, FilamentType.match('PLA-CF')
  end

  test 'allowed on a printer unless it lacks a hardened nozzle or ventilation' do
    printer = printers(:prusa_mk4)
    printer.assign_attributes(hardened_nozzle: false, ventilation: false)

    assert filament_types(:pla).allowed_on?(printer)
    assert_equal ['ventilation'], filament_types(:abs).missing_on(printer)
    assert_equal ['a hardened nozzle', 'ventilation'], filament_types(:pa_cf).missing_on(printer)

    printer.assign_attributes(hardened_nozzle: true, ventilation: true)

    assert filament_types(:pa_cf).allowed_on?(printer)
  end

  test 'validates names and temperature ranges' do
    type = FilamentType.new(name: 'pla', nozzle_min_c: 230, nozzle_max_c: 190, bed_min_c: 45, bed_max_c: 600)

    assert_not type.valid?
    assert_includes type.errors[:name], 'has already been taken'
    assert_includes type.errors[:nozzle_max_c], 'must be at least the minimum'
    assert type.errors[:bed_max_c].any?
  end

  test 'normalizes aliases' do
    type = FilamentType.new(aliases: ' Nylon ,, PA6 ')

    assert_equal 'Nylon, PA6', type.aliases
  end

  test 'seed_defaults! adds the common types without touching existing ones' do
    filament_types(:pla).update!(nozzle_max_c: 215)

    FilamentType.seed_defaults!

    assert_equal 215, filament_types(:pla).reload.nozzle_max_c
    assert_equal FilamentType::DEFAULTS.size, FilamentType.count
    assert FilamentType.find_by(name: 'PETG-CF').requires_hardened_nozzle?
    assert FilamentType.find_by(name: 'ASA').requires_ventilation?
  end
end
