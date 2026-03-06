program sonar_tracer
  use sound_speed
  use ray_tracer
  implicit none

 ! --- Profile Parameters ---
  integer, parameter :: N_DEPTHS = 500
  real(8) :: z, dz, c
  real(8), parameter :: Z_MAX = 5000.0d0 ! ocean floor (m)

! --- Ray Parameters ---
  real(8),  parameter :: Z_SOURCE  = 1300.0d0  ! source depth (m) — on SOFAR axis
  real(8),  parameter :: DS        = 50.0d0    ! arc-length step (m)
  integer,  parameter :: N_STEPS   = 20000     ! steps per ray
  integer,  parameter :: N_RAYS    = 15        ! number of rays in fan
  real(8),  parameter :: ANGLE_MIN = -15.0d0   ! degrees from horizontal
  real(8),  parameter :: ANGLE_MAX =  15.0d0
  real(8)             :: angle, dangle
  integer :: i

! --- Write Sound Profile ---
  dz = Z_MAX / real(N_DEPTHS - 1, 8)
  ! Write profile to csv for plotting
  open(unit=10, file='sound_speed_profile.csv', status='replace')
  write(10, '(A)') 'depth_m,speed_ms'

  do i = 1, N_DEPTHS
    z = real(i - 1, 8) *dz
    c = munk_profile(z)
    write(10, '(F10.2, A, F10.4)') z, ',', c
  end do

  close(10)
  write(*,*) 'Profile written to sound_speed_profile.csv'


! --- Trace Ray fan ---
  dangle = (ANGLE_MAX - ANGLE_MIN) / real(N_RAYS - 1, 8)
  open(unit=20, file='ray_paths.csv', status='replace')
  write(20, '(A)') 'range_m,depth_m,angle_deg'

  do i = 1, N_RAYS
    angle = ANGLE_MIN + real(i -1, 8) * dangle
    call trace_ray(angle, Z_SOURCE, DS, N_STEPS, Z_MAX, 20)
  end do

  close(20)
  write(*,*) 'Ray paths written to ray_paths.csv'
  
end program sonar_tracer