module ray_tracer_3d_mod
  use ray_state_3d_mod
  use ray_output_3d_mod
  use intensity_grid_3d_mod, only: X_MAX, Y_MAX, Z_MAX
  implicit none

contains

subroutine trace_fan_3d(x0, y0, z0, azim_offset_deg, ds, n_steps, &
                         n_elev, n_azim, elev_min, elev_max, outfile)
  real(8), intent(in)      :: x0, y0, z0, azim_offset_deg, ds
  real(8), intent(in)      :: elev_min, elev_max
  integer, intent(in)      :: n_steps, n_elev, n_azim
  character(*), intent(in) :: outfile

  type(ray_state_3d) :: state
  real(8), allocatable :: path_x(:), path_y(:), path_z(:)
  real(8) :: elev, azim, delev, dazim
  integer :: ie, ia, j, n_written, unit
  real(8), parameter :: PI      = 4.0d0 * atan(1.0d0)
  real(8), parameter :: KM      = 1.0d0 / 1000.0d0   ! m to km

  delev = (elev_max - elev_min) / real(n_elev - 1, 8)
  dazim = 360.0d0 / real(n_azim, 8)

  allocate(path_x(n_steps), path_y(n_steps), path_z(n_steps))

  open(newunit=unit, file=outfile, form='unformatted', &
       status='replace', access='stream')

  ! Write total ray count header
  write(unit) int(n_elev * n_azim, 4)

  do ie = 1, n_elev
    do ia = 1, n_azim
      elev  = elev_min + real(ie - 1, 8) * delev
      azim  = real(ia - 1, 8) * dazim + azim_offset_deg
      state = init_ray_3d(x0, y0, z0, elev, azim)

      n_written = 0
      do j = 1, n_steps
        ! Boundary reflections
        if (state%z < 0.0d0) then
          state%z    = -state%z
          state%zeta = -state%zeta
        end if
        if (state%z > Z_MAX) then
          state%z    = 2.0d0 * Z_MAX - state%z
          state%zeta = -state%zeta
        end if

        ! Stop if out of horizontal bounds
        if (abs(state%x) > X_MAX .or. abs(state%y) > Y_MAX) exit

        n_written = n_written + 1
        path_x(n_written) = state%x * KM
        path_y(n_written) = state%y * KM
        path_z(n_written) = state%z * KM

        call rk4_step_3d(state, ds)
      end do

      call write_ray_path(unit, path_x, path_y, path_z, n_written)
    end do
  end do

  close(unit)
  deallocate(path_x, path_y, path_z)
end subroutine trace_fan_3d

end module ray_tracer_3d_mod