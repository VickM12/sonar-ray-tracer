program sonar_tracer_3d
  use ray_tracer_3d_mod
  implicit none

  real(8), parameter :: DS       = 100.0d0
  integer, parameter :: N_STEPS  = 25000
  integer, parameter :: N_ELEV   = 25
  integer, parameter :: N_AZIM   = 36
  real(8), parameter :: ELEV_MIN = -20.0d0
  real(8), parameter :: ELEV_MAX =  20.0d0
  real(8), parameter :: X0 = 0.0d0
  real(8), parameter :: Y0 = 0.0d0

  real(8) :: sub_depth, sub_heading

  call read_params(sub_depth, sub_heading)
  write(*,'(A,F8.1,A,F8.1,A)') &
    'Tracing rays: depth=', sub_depth, 'm  heading=', sub_heading, 'deg'

  call trace_fan_3d(X0, Y0, sub_depth, sub_heading, DS, N_STEPS, &
                    N_ELEV, N_AZIM, ELEV_MIN, ELEV_MAX, 'rays_3d.bin')

  write(*,*) 'Done. rays_3d.bin written.'

contains

  subroutine read_params(depth, heading)
    real(8), intent(out) :: depth, heading
    integer :: u, ios
    character(256) :: line
    depth = 300.0d0
    heading = 0.0d0
    open(newunit=u, file='params.json', status='old', iostat=ios)
    if (ios /= 0) return
    do
      read(u, '(A)', iostat=ios) line
      if (ios /= 0) exit
      line = adjustl(line)
      if (index(line, 'sub_depth') > 0)   call parse_json_value(line, depth)
      if (index(line, 'sub_heading') > 0) call parse_json_value(line, heading)
    end do
    close(u)
  end subroutine read_params

  subroutine parse_json_value(line, val)
    character(len=*), intent(in)  :: line
    real(8),          intent(out) :: val
    integer :: cp, comma
    character(64) :: ns
    cp = index(line, ':')
    if (cp == 0) return
    ns = adjustl(line(cp+1:))
    comma = index(ns, ',')
    if (comma > 0) ns(comma:) = ' '
    read(ns, *, iostat=cp) val
  end subroutine parse_json_value

end program sonar_tracer_3d