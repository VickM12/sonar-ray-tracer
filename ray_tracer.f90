module ray_tracer
  use sound_speed
  use intensity_grid_mod
  implicit none

  type :: ray_state
    real(8) :: x, z, xi, zeta
  end type ray_state

contains

  function init_ray(z0, x0, angle_deg) result(state)
    real(8), intent(in) :: z0, x0, angle_deg
    type(ray_state)     :: state
    real(8)             :: angle_rad, c0

    angle_rad = angle_deg * atan(1.0d0) * 4.0d0 / 180.0d0
    c0        = munk_profile(z0)

    state%x    = x0
    state%z    = z0
    state%xi   = cos(angle_rad) / c0
    state%zeta = sin(angle_rad) / c0
  end function init_ray

  subroutine ray_derivatives(state, dstate)
    type(ray_state), intent(in)  :: state
    type(ray_state), intent(out) :: dstate
    real(8) :: c, dcdz

    c     = munk_profile(state%z)
    dcdz  = munk_gradient(state%z)

    dstate%x    =  c * state%xi
    dstate%z    =  c * state%zeta
    dstate%xi   =  0.0d0
    dstate%zeta = -dcdz / (c * c)
  end subroutine ray_derivatives

  subroutine rk4_step(state, ds)
    type(ray_state), intent(inout) :: state
    real(8),         intent(in)    :: ds
    type(ray_state) :: k1, k2, k3, k4, tmp

    call ray_derivatives(state, k1)

    tmp%x    = state%x    + 0.5d0 * ds * k1%x
    tmp%z    = state%z    + 0.5d0 * ds * k1%z
    tmp%xi   = state%xi   + 0.5d0 * ds * k1%xi
    tmp%zeta = state%zeta + 0.5d0 * ds * k1%zeta
    call ray_derivatives(tmp, k2)

    tmp%x    = state%x    + 0.5d0 * ds * k2%x
    tmp%z    = state%z    + 0.5d0 * ds * k2%z
    tmp%xi   = state%xi   + 0.5d0 * ds * k2%xi
    tmp%zeta = state%zeta + 0.5d0 * ds * k2%zeta
    call ray_derivatives(tmp, k3)

    tmp%x    = state%x    + ds * k3%x
    tmp%z    = state%z    + ds * k3%z
    tmp%xi   = state%xi   + ds * k3%xi
    tmp%zeta = state%zeta + ds * k3%zeta
    call ray_derivatives(tmp, k4)

    state%x    = state%x    + ds/6.0d0 * (k1%x    + 2*k2%x    + 2*k3%x    + k4%x)
    state%z    = state%z    + ds/6.0d0 * (k1%z    + 2*k2%z    + 2*k3%z    + k4%z)
    state%xi   = state%xi   + ds/6.0d0 * (k1%xi   + 2*k2%xi   + 2*k3%xi   + k4%xi)
    state%zeta = state%zeta + ds/6.0d0 * (k1%zeta + 2*k2%zeta + 2*k3%zeta + k4%zeta)
  end subroutine rk4_step

  ! Trace a full ray fan from (x0, z0), accumulate into intensity grid
  subroutine trace_fan(x0, z0, ds, n_steps, n_rays, angle_min, angle_max)
    real(8), intent(in) :: x0, z0, ds, angle_min, angle_max
    integer, intent(in) :: n_steps, n_rays
    type(ray_state)     :: state
    real(8)             :: angle, dangle
    integer             :: i, j

    dangle = (angle_max - angle_min) / real(n_rays - 1, 8)

    !$OMP PARALLEL DO private(i, j, angle, state) shared(grid)
    do i = 1, n_rays
      angle = angle_min + real(i - 1, 8) * dangle
      state = init_ray(z0, x0, angle)

      do j = 1, n_steps
        if (state%z < 0.0d0) then
          state%z    = -state%z
          state%zeta = -state%zeta
        end if
        if (state%z > Z_MAX) then
          state%z    = 2.0d0 * Z_MAX - state%z
          state%zeta = -state%zeta
        end if

        if (state%x >= 0.0d0 .and. state%x <= R_MAX) then
          call accumulate(state%x, state%z)
        end if

        call rk4_step(state, ds)

        ! Stop ray if it travels past max range
        if (state%x > R_MAX) exit
      end do
    end do
    !$OMP END PARALLEL DO

  end subroutine trace_fan

end module ray_tracer