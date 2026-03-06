module ray_state_3d_mod
  implicit none

  type :: ray_state_3d
    real(8) :: x, y, z       ! position(m)
    real(8) :: xi, eta, zeta ! slowness components
  end type ray_state_3d

end module ray_state_3d_mod