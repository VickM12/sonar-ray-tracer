module ray_output_3d_mod
  implicit none

contains

  ! Write a single ray path to an open binary file
  ! Format: n_points (int32), then n_points * 3 float64 (x, y, z in km)
  subroutine write_ray_path(unit, path_x, path_y, path_z, n)
    integer,  intent(in) :: unit, n
    real(8),  intent(in) :: path_x(n), path_y(n), path_z(n)
    integer(4) :: n4
    n4 = int(n, 4)
    write(unit) n4
    write(unit) path_x(1:n), path_y(1:n), path_z(1:n)
  end subroutine write_ray_path

end module ray_output_3d_mod