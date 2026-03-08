module ray_state_3d_mod
  use sound_speed
  implicit none

  type :: ray_state_3d
    real(8) :: x, y, z       ! position (m)
    real(8) :: xi, eta, zeta ! slowness components
  end type ray_state_3d

contains

  ! Initialize ray at (x0, y0, z0) with elevation (deg from horizontal) and azimuth (deg)
  function init_ray_3d(x0, y0, z0, elev_deg, azim_deg) result(state)
    real(8), intent(in) :: x0, y0, z0, elev_deg, azim_deg
    type(ray_state_3d)  :: state
    real(8) :: elev_rad, azim_rad, c0

    elev_rad = elev_deg * atan(1.0d0) * 4.0d0 / 180.0d0
    azim_rad = azim_deg * atan(1.0d0) * 4.0d0 / 180.0d0
    c0       = munk_profile(z0)

    state%x = x0
    state%y = y0
    state%z = z0
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

    dstate%x    = c * state%xi
    dstate%y    = c * state%eta
    dstate%z    = c * state%zeta
    dstate%xi   = 0.0d0
    dstate%eta  = 0.0d0
    dstate%zeta = -dcdz / (c * c)
  end subroutine ray_derivatives_3d

  subroutine rk4_step_3d(state, ds)
    type(ray_state_3d), intent(inout) :: state
    real(8), intent(in) :: ds
    type(ray_state_3d) :: k1, k2, k3, k4, tmp

    call ray_derivatives_3d(state, k1)

    tmp%x = state%x + 0.5d0 * ds * k1%x
    tmp%y = state%y + 0.5d0 * ds * k1%y
    tmp%z = state%z + 0.5d0 * ds * k1%z
    tmp%xi   = state%xi   + 0.5d0 * ds * k1%xi
    tmp%eta  = state%eta  + 0.5d0 * ds * k1%eta
    tmp%zeta = state%zeta + 0.5d0 * ds * k1%zeta
    call ray_derivatives_3d(tmp, k2)

    tmp%x = state%x + 0.5d0 * ds * k2%x
    tmp%y = state%y + 0.5d0 * ds * k2%y
    tmp%z = state%z + 0.5d0 * ds * k2%z
    tmp%xi   = state%xi   + 0.5d0 * ds * k2%xi
    tmp%eta  = state%eta  + 0.5d0 * ds * k2%eta
    tmp%zeta = state%zeta + 0.5d0 * ds * k2%zeta
    call ray_derivatives_3d(tmp, k3)

    tmp%x = state%x + ds * k3%x
    tmp%y = state%y + ds * k3%y
    tmp%z = state%z + ds * k3%z
    tmp%xi   = state%xi   + ds * k3%xi
    tmp%eta  = state%eta  + ds * k3%eta
    tmp%zeta = state%zeta + ds * k3%zeta
    call ray_derivatives_3d(tmp, k4)

    state%x    = state%x    + ds/6.0d0 * (k1%x    + 2*k2%x    + 2*k3%x    + k4%x)
    state%y    = state%y    + ds/6.0d0 * (k1%y    + 2*k2%y    + 2*k3%y    + k4%y)
    state%z    = state%z    + ds/6.0d0 * (k1%z    + 2*k2%z    + 2*k3%z    + k4%z)
    state%xi   = state%xi   + ds/6.0d0 * (k1%xi   + 2*k2%xi   + 2*k3%xi   + k4%xi)
    state%eta  = state%eta  + ds/6.0d0 * (k1%eta  + 2*k2%eta  + 2*k3%eta  + k4%eta)
    state%zeta = state%zeta + ds/6.0d0 * (k1%zeta + 2*k2%zeta + 2*k3%zeta + k4%zeta)
  end subroutine rk4_step_3d

end module ray_state_3d_mod