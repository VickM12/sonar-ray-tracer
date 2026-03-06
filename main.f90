program sonar_tracer
  use sound_speed
  implicit none

  integer, parameter :: N_DEPTHS = 500
  real(8) :: z, dz, c
  integer :: i

  real(8), parameter :: Z_MAX = 5000.0d0 ! ocean floor (m)

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

end program sonar_tracer