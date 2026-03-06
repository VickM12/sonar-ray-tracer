module intensity_grid_3d_mod
  implicit none

  integer, parameter :: NX = 200
  integer, parameter :: NY = 200
  integer, parameter :: NZ = 100

  real(8), parameter :: X_MAX =  500000.0d0   ! 500 km
  real(8), parameter :: Y_MAX =  500000.0d0   ! 500 km either side
  real(8), parameter :: Z_MAX =   5000.0d0

  real(8), parameter :: DX = X_MAX / real(NX, 8)
  real(8), parameter :: DY = (2.0d0 * Y_MAX) / real(NY, 8)
  real(8), parameter :: DZ = Z_MAX / real(NZ, 8)

  real(8) :: grid(NX, NY, NZ)

contains

  subroutine clear_grid()
    grid = 0.0d0
  end subroutine clear_grid

  subroutine accumulate(x, y, z)
    real(8), intent(in) :: x, y, z
    integer :: ix, iy, iz

    ix = int(x / DX) + 1
    iy = int((y + Y_MAX) / DY) + 1
    iz = int(z / DZ) + 1

    if (ix >= 1 .and. ix <= NX .and. &
        iy >= 1 .and. iy <= NY .and. &
        iz >= 1 .and. iz <= NZ) then
      grid(ix, iy, iz) = grid(ix, iy, iz) + 1.0d0
    end if
  end subroutine accumulate

  subroutine write_grid(filename)
    character(len=*), intent(in) :: filename
    integer :: u
    open(newunit=u, file=filename, form='unformatted', &
         status='replace', access='stream')
    write(u) grid
    close(u)
  end subroutine write_grid

end module intensity_grid_3d_mod