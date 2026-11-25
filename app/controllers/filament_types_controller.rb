class FilamentTypesController < ApplicationController
  before_action :require_admin
  before_action :set_filament_type, only: %i[edit update destroy]

  def index
    @filament_types = FilamentType.ordered
    @printers = Printer.ordered
  end

  def new
    @filament_type = FilamentType.new
  end

  def edit; end

  def create
    @filament_type = FilamentType.new(filament_type_params)
    if @filament_type.save
      redirect_to filament_types_path, notice: "#{@filament_type.name} added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @filament_type.update(filament_type_params)
      redirect_to filament_types_path, notice: "#{@filament_type.name} updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @filament_type.destroy!
    redirect_to filament_types_path, notice: "#{@filament_type.name} removed."
  end

  private

  def set_filament_type
    @filament_type = FilamentType.find(params.expect(:id))
  end

  def filament_type_params
    params.expect(filament_type: %i[name aliases nozzle_min_c nozzle_max_c bed_min_c bed_max_c
                                    requires_hardened_nozzle requires_ventilation])
  end
end
