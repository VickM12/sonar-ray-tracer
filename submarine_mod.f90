module submarine_mod
  implicit none

  real(8), parameter :: KNOTS_TO_MS = 0.5414444d0

  type :: submarine
    real(8) :: x        ! range (m)
    real(8) :: z        ! depth (m)
    real(8) :: heading  ! degrees (0 = right, 90 = away from source)
    real(8) :: speed    ! knots
  end type submarine

contains

  subroutine update_sub(sub, dt)
    type(submarine), intent(inout) :: sub
    real(8),         intent(in)    :: dt
    real(8) :: speed_ms, heading_rad

    speed_ms = sub%speed * KNOTS_TO_MS
    heading_rad = sub%heading * atan(1.0d0) * 4.0d0 / 180.0d0

    sub%x = sub%x + speed_ms * cos(heading_rad) * dt
     sub%z = sub%z + speed_ms * sin(heading_rad) * dt

    ! Keep sub in water column
    if (sub%z < 50.0d0)   sub%z = 50.0d0
    if (sub%z > 4950.0d0) sub%z = 4950.0d0
  end subroutine update_sub

end module submarine_mod