module ray_tracer_3d_mod
  use sound_speed
  use intensity_grid_3d_mod
  use ray_state_3d_mod
  implicit none

contains

  ! Initialize a 3D ray from source position with elevation and azimuth angles
  function init_ray_3d(x0, y0, z0, elev_deg, azim_deg) result(state)
    real(8), intent(in) :: x0, y0, z0, elev_deg, azim_deg
    type(ray_state_3d)  :: state
    real(8) :: elev_rad, azim_rad, c0
    real(8), parameter  :: PI = 4.0d0 * atan(1.0d0)

    elev_rad = elev_deg * PI / 180.0d0
    azim_rad = azim_deg * PI / 180.0d0
    c0       = munk_profile(z0)

    state%x    = x0
    state%y    = y0
    state%z    = z0

    ! Slowness vector components
    ! xi/eta are horizontal, zeta is vertical
    state%xi   = cos(elev_rad) * cos(azim_rad) / c0
    state%eta  = cos(elev_rad) * sin(azim_rad) / c0
    state%zeta = sin(elev_rad) / c0
  end function init_ray_3d

  subroutine ray_derivatives_3d(state, dstate)
    type(ray_state_3d), intent(in)  :: state
    type(ray_state_3d), intent(out) :: dstate
    real(8) :: c, dcdz

    c    = munk_profile(state%z)
    dcdz = munk_gradient(state%z)

    dstate%x    =  c * state%xi
    dstate%y    =  c * state%eta
    dstate%z    =  c * state%zeta
    dstate%xi   =  0.0d0          ! no horizontal sound speed variation
    dstate%eta  =  0.0d0          ! no horizontal sound speed variation
    dstate%zeta = -dcdz / (c * c)
  end subroutine ray_derivatives_3d

  subroutine rk4_step_3d(state, ds)
    type(ray_state_3d), intent(inout) :: state
    real(8),            intent(in)    :: ds
    type(ray_state_3d) :: k1, k2, k3, k4, tmp

    call ray_derivatives_3d(state, k1)

    tmp%x    = state%x    + 0.5d0*ds*k1%x
    tmp%y    = state%y    + 0.5d0*ds*k1%y
    tmp%z    = state%z    + 0.5d0*ds*k1%z
    tmp%xi   = state%xi   + 0.5d0*ds*k1%xi
    tmp%eta  = state%eta  + 0.5d0*ds*k1%eta
    tmp%zeta = state%zeta + 0.5d0*ds*k1%zeta
    call ray_derivatives_3d(tmp, k2)

    tmp%x    = state%x    + 0.5d0*ds*k2%x
    tmp%y    = state%y    + 0.5d0*ds*k2%y
    tmp%z    = state%z    + 0.5d0*ds*k2%z
    tmp%xi   = state%xi   + 0.5d0*ds*k2%xi
    tmp%eta  = state%eta  + 0.5d0*ds*k2%eta
    tmp%zeta = state%zeta + 0.5d0*ds*k2%zeta
    call ray_derivatives_3d(tmp, k3)

    tmp%x    = state%x    + ds*k3%x
    tmp%y    = state%y    + ds*k3%y
    tmp%z    = state%z    + ds*k3%z
    tmp%xi   = state%xi   + ds*k3%xi
    tmp%eta  = state%eta  + ds*k3%eta
    tmp%zeta = state%zeta + ds*k3%zeta
    call ray_derivatives_3d(tmp, k4)

    state%x    = state%x    + ds/6.0d0*(k1%x    + 2*k2%x    + 2*k3%x    + k4%x)
    state%y    = state%y    + ds/6.0d0*(k1%y    + 2*k2%y    + 2*k3%y    + k4%y)
    state%z    = state%z    + ds/6.0d0*(k1%z    + 2*k2%z    + 2*k3%z    + k4%z)
    state%xi   = state%xi   + ds/6.0d0*(k1%xi   + 2*k2%xi   + 2*k3%xi   + k4%xi)
    state%eta  = state%eta  + ds/6.0d0*(k1%eta  + 2*k2%eta  + 2*k3%eta  + k4%eta)
    state%zeta = state%zeta + ds/6.0d0*(k1%zeta + 2*k2%zeta + 2*k3%zeta + k4%zeta)
  end subroutine rk4_step_3d

  ! Trace full 3D ray fan from source position
  ! azim_offset: sub heading in degrees — rotates the fan
  subroutine trace_fan_3d(x0, y0, z0, azim_offset_deg, ds, n_steps, &
                           n_elev, n_azim, elev_min, elev_max)
    real(8), intent(in) :: x0, y0, z0, azim_offset_deg, ds
    real(8), intent(in) :: elev_min, elev_max
    integer, intent(in) :: n_steps, n_elev, n_azim
    type(ray_state_3d)  :: state
    real(8) :: elev, azim, delev, dazim
    integer :: ie, ia, j
    real(8), parameter :: PI = 4.0d0 * atan(1.0d0)

    delev = (elev_max - elev_min) / real(n_elev - 1, 8)
    dazim = 360.0d0 / real(n_azim, 8)

    !$OMP PARALLEL DO COLLAPSE(2) private(ie, ia, j, elev, azim, state) &
    !$OMP shared(grid)
    do ie = 1, n_elev
      do ia = 1, n_azim
        elev  = elev_min + real(ie - 1, 8) * delev
        azim  = real(ia - 1, 8) * dazim + azim_offset_deg
        state = init_ray_3d(x0, y0, z0, elev, azim)

        do j = 1, n_steps
          ! Surface reflection
          if (state%z < 0.0d0) then
            state%z    = -state%z
            state%zeta = -state%zeta
          end if
          ! Bottom reflection
          if (state%z > Z_MAX) then
            state%z    = 2.0d0*Z_MAX - state%z
            state%zeta = -state%zeta
          end if

          call accumulate(state%x, state%y, state%z)
          call rk4_step_3d(state, ds)

          ! Stop if out of horizontal bounds
          if (abs(state%x) > X_MAX .or. abs(state%y) > Y_MAX) exit
        end do
      end do
    end do
    !$OMP END PARALLEL DO

  end subroutine trace_fan_3d

end module ray_tracer_3d_mod