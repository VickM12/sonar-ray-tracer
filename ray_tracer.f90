module ray_tracer
  use sound_speed
  implicit none

  ! State vector for a single ray
  ! x : horizontal range (m)
  ! z : depth (m)
  ! xi : horizontal slowness component (1/c * cos(theta))
  ! zeta : vertical slowness component (1/c * sin(theta))
  type :: ray_state
    real(8) :: x, z, xi, zeta
  end type ray_state

contains

  ! Convert launch angle (degrees from horizontal) to initial slowness vector
  function init_ray(z0, angle_deg) result(state)
    real(8), intent(in) :: z0, angle_deg
    type(ray_state)     :: state
    real(8)             :: angle_rad, c0

    angle_rad = angle_deg * atan(1.0d0) * 4.0d0 / 180.0d0   ! degrees to radians
    c0        = munk_profile(z0)

    state%x    = 0.0d0
    state%z    = z0
    state%xi   = cos(angle_rad) / c0
    state%zeta = sin(angle_rad) / c0
  end function init_ray

  ! Ray equations (Hamiltonian form)
  ! dx/ds  =  c * xi
  ! dz/ds  =  c * zeta
  ! dxi/ds =  0               (sound speed has no horizontal variation)
  ! dzeta/ds = -dc/dz / c^2   (this is what bends the ray)
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

  ! RK4 step — advances ray state by arc-length ds
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

  ! Trace a single ray, writing path to an open file unit
  subroutine trace_ray(launch_angle, z_source, ds, n_steps, z_max, file_unit)
    real(8), intent(in) :: launch_angle, z_source, ds, z_max
    integer, intent(in) :: n_steps, file_unit
    type(ray_state)     :: state
    integer             :: i

    state = init_ray(z_source, launch_angle)

    do i = 1, n_steps
      ! Surface reflection
      if (state%z < 0.0d0) then
        state%z    = -state%z
        state%zeta = -state%zeta
      end if

      ! Bottom reflection
      if (state%z > z_max) then
        state%z    = 2.0d0 * z_max - state%z
        state%zeta = -state%zeta
      end if

      write(file_unit, '(F12.2, A, F10.2, A, F10.4)') &
        state%x, ',', state%z, ',', launch_angle

      call rk4_step(state, ds)
    end do

  end subroutine trace_ray

end module ray_tracer