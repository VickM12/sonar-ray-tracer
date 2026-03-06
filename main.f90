program sonar_tracer
  use sound_speed
  use intensity_grid_mod
  use ray_tracer
  use submarine_mod
  implicit none

  ! Ray parameters
  real(8), parameter :: DS         = 50.0d0
  integer, parameter :: N_STEPS    = 40000
  integer, parameter :: N_RAYS     = 101
  real(8), parameter :: ANGLE_MIN  = -20.0d0
  real(8), parameter :: ANGLE_MAX  =  20.0d0

  ! Simulation parameters
  integer, parameter :: N_FRAMES   = 30
  real(8), parameter :: DT         = 600.0d0   ! 10 minutes per frame

  type(submarine) :: sub
  character(64)   :: filename
  integer         :: frame, track_unit, i
  real(8)         :: t

  ! Sound speed profile — write once
  call write_sound_speed_profile()

  ! Initial sub state
  sub%x       = 10000.0d0    ! start 10km downrange
  sub%z       = 300.0d0      ! 300m depth — below thermocline
  sub%heading = 0.0d0        ! heading directly away from source
  sub%speed   = 10.0d0       ! 10 knots

  ! Sub track CSV
  open(newunit=track_unit, file='sub_track.csv', status='replace')
  write(track_unit, '(A)') 'time_s,range_m,depth_m'

  t = 0.0d0
  do frame = 1, N_FRAMES
    write(*,'(A,I3,A,I3)') 'Computing frame ', frame, ' of ', N_FRAMES

    call clear_grid()
    call trace_fan(sub%x, sub%z, DS, N_STEPS, N_RAYS, ANGLE_MIN, ANGLE_MAX)

    write(filename, '(A,I3.3,A)') 'frame_', frame, '.bin'
    call write_grid(trim(filename))
    call write_sub_position(sub%x, sub%z, t, track_unit)

    call update_sub(sub, DT)
    t = t + DT
  end do

  close(track_unit)
  write(*,*) 'Done. Run plot_czmap.py to animate.'

contains

  subroutine write_sound_speed_profile()
    integer, parameter :: N_DEPTHS = 500
    real(8) :: z, dz
    integer :: i, u

    dz = Z_MAX / real(N_DEPTHS - 1, 8)
    open(newunit=u, file='sound_speed_profile.csv', status='replace')
    write(u, '(A)') 'depth_m,speed_ms'
    do i = 1, N_DEPTHS
      z = real(i - 1, 8) * dz
      write(u, '(F10.2,A,F10.4)') z, ',', munk_profile(z)
    end do
    close(u)
  end subroutine write_sound_speed_profile

end program sonar_tracer