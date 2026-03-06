module intensity_grid_mod
  implicit none

  integer, parameter :: NR = 1000   ! range cells
  integer, parameter :: NZ = 500    ! depth cells

  real(8), parameter :: R_MAX = 1000000.0d0   ! 1000 km in meters
  real(8), parameter :: Z_MAX =   5000.0d0    ! ocean depth (m)

  real(8), parameter :: DR = R_MAX / real(NR, 8)
  real(8), parameter :: DZ = Z_MAX / real(NZ, 8)

  ! The grid itself — shared across modules
  real(8) :: grid(NR, NZ)

contains

  subroutine clear_grid()
    grid = 0.0d0
  end subroutine clear_grid

  ! Accumulate a ray hit at position (x, z)
  subroutine accumulate(x, z)
    real(8), intent(in) :: x, z
    integer :: ir, iz

    ir = int(x / DR) + 1
    iz = int(z / DZ) + 1

    if (ir >= 1 .and. ir <= NR .and. iz >= 1 .and. iz <= NZ) then
      grid(ir, iz) = grid(ir, iz) + 1.0d0
    end if
  end subroutine accumulate

  ! Write current grid to a binary file for fast I/O
  subroutine write_grid(filename)
    character(len=*), intent(in) :: filename
    integer :: unit

    open(newunit=unit, file=filename, form='unformatted', &
         status='replace', access='stream')
    write(unit) grid
    close(unit)
  end subroutine write_grid

  ! Write sub track position to CSV (appends)
  subroutine write_sub_position(x, z, t, unit)
    real(8), intent(in) :: x, z, t
    integer, intent(in) :: unit
    write(unit, '(F12.2, A, F10.2, A, F10.2)') t, ',', x, ',', z
  end subroutine write_sub_position

end module intensity_grid_mod