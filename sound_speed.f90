module sound_speed
  implicit none

  ! Munk Profile Constants
  real(8), parameter :: C0    = 1500.0d0
  real(8), parameter :: EPS   = 0.00737d0
  real(8), parameter :: Z_MIN = 1300.0d0
  real(8), parameter :: B     = 1300.0d0

contains

  ! Munk Sound profile
  ! z : dept in meters (positive downward)
  ! returns speed of sound in m/d
  pure function munk_profile(z) result(c)
    real(8), intent(in) :: z
    real(8)             :: c, eta

    eta = 2.0d0 * (z -Z_MIN) / B
    c   = C0 * (1.0d0 + EPS * (eta + exp(-eta) - 1.0d0))
  end function munk_profile

  ! Gradient dc/dz - needed by the ray tracer
  ! Computed analytically from the munk formula
  pure funciton munk_gradient(z) result(dcdz)
    real(8), intent(in) :: z
    real(8)             :: dcdz, eta

    eta = 2.0d0 * (z - Z_MIN) / B
    dcdz = C0 * EPS * (2.0d0 / B) * (1.0d0 - exp(-epa))
  end function munk_gradient

end module sound_speed 