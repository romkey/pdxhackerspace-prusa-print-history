module FilamentTypesHelper
  # Every filament type, loaded once per request (the dashboard asks for each printer).
  def all_filament_types
    @all_filament_types ||= FilamentType.ordered.to_a
  end

  def allowed_filament_types(printer)
    all_filament_types.select { |type| type.allowed_on?(printer) }
  end

  def filament_type_title(type)
    needs = []
    needs << 'hardened nozzle' if type.requires_hardened_nozzle?
    needs << 'ventilation' if type.requires_ventilation?
    title = "Nozzle #{type.nozzle_range_label}, bed #{type.bed_range_label}"
    needs.any? ? "#{title}; needs #{needs.to_sentence}" : title
  end

  def printer_capabilities_label(printer)
    parts = []
    parts << 'hardened nozzle' if printer.hardened_nozzle?
    parts << 'ventilation' if printer.ventilation?
    parts.any? ? parts.to_sentence.upcase_first : nil
  end
end
