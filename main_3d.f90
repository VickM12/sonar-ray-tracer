program sonar_tracer_3d
  use intensity_grid_3d_mod
  use ray_tracer_3d_mod
  implicit none

  ! Ray parameters
  real(8), parameter :: DS        = 100.0d0
  integer, parameter :: N_STEPS   = 25000
  integer, parameter :: N_ELEV    = 25      ! elevation angles
  integer, parameter :: N_AZIM    = 36      ! azimuthal angles (every 10 degrees)
  real(8), parameter :: ELEV_MIN  = -20.0d0
  real(8), parameter :: ELEV_MAX  =  20.0d0

  ! Sub initial position — always at origin of grid
  real(8), parameter :: X0 = 0.0d0
  real(8), parameter :: Y0 = 0.0d0

  real(8) :: sub_depth, sub_heading
  integer :: u

  ! Read params from JSON (simple parse)
  call read_params(sub_depth, sub_heading)

  write(*,'(A,F8.1,A,F8.1)') 'Sub depth: ', sub_depth, &
                               'm  heading: ', sub_heading, ' deg'

  call clear_grid()
  call trace_fan_3d(X0, Y0, sub_depth, sub_heading, DS, N_STEPS, &
                    N_ELEV, N_AZIM, ELEV_MIN, ELEV_MAX)
  call write_grid('intensity_3d.bin')

  write(*,*) 'Done. intensity_3d.bin written.'

contains

  subroutine read_params(depth, heading)
    real(8), intent(out) :: depth, heading
    integer :: u, ios
    character(256) :: line
    character(32)  :: key, val

    depth   = 300.0d0    ! defaults
    heading = 0.0d0

    open(newunit=u, file='params.json', status='old', iostat=ios)
    if (ios /= 0) return

    do
      read(u, '(A)', iostat=ios) line
      if (ios /= 0) exit
      line = adjustl(line)

      if (index(line, 'sub_depth') > 0) then
        call parse_json_value(line, depth)
      else if (index(line, 'sub_heading') > 0) then
        call parse_json_value(line, heading)
      end if
    end do
    close(u)
  end subroutine read_params

  ! Extract numeric value after the colon in a JSON line
  subroutine parse_json_value(line, val)
    character(len=*), intent(in)  :: line
    real(8),          intent(out) :: val
    integer :: colon_pos, comma_pos
    character(64) :: numstr

    colon_pos = index(line, ':')
    if (colon_pos == 0) return

    numstr = adjustl(line(colon_pos+1:))
    comma_pos = index(numstr, ',')
    if (comma_pos > 0) numstr(comma_pos:) = ' '

    read(numstr, *, iostat=colon_pos) val
  end subroutine parse_json_value

end program sonar_tracer_3d