// https://github.com/markormesher/3d-models/blob/main/ikea-365-lid-hanger/hanger.scad

include <BOSL2/std.scad>;

$fn = $preview ? 18 : 180;
fuzz = 0.01;

// configurable parameters
hook_count = 8;
length = 140;
screw_head_d = 6.2;
screw_d = 3.3;
screws_every_n_hooks = 8;

// lid measurements - you shouldn't need to change these
lid_thickness = 14;
lid_spacing = 1.5;
flap_thickness = 5;
clip_inset = 10;
clip_length = 5;
clip_thickness = 4.5;

rounding = 0.5;
end_chamf = 3;
wall = 1.5;

total_width = lid_thickness + lid_spacing * 2;
total_height = clip_inset + clip_thickness + wall * 2;

module single(left_end = false, right_end = false) {
  tag_scope() {
    linear_extrude(length) {
      diff() {
        rect(
          [total_width, total_height],
          anchor=FRONT + LEFT,
          chamfer=right_end ? [end_chamf, 0, 0, end_chamf] : 0
        ) {

          // main slot
          tag("remove") {
            right(lid_spacing) {
              attach(FRONT + LEFT, FRONT + LEFT, inside=true, overlap=fuzz) {
                rect(
                  [flap_thickness, total_height - wall + fuzz],
                  rounding=[rounding, rounding, -rounding, -rounding]
                );
              }
            }
          }

          // clip slot
          tag("remove") {
            translate([lid_spacing + flap_thickness - fuzz, -(clip_inset + wall)]) {
              attach(LEFT, FRONT, align=BACK, inside=true) {
                rect(
                  [clip_thickness, clip_length],
                  rounding=[rounding, rounding, -rounding, -rounding]
                );
              }
            }
          }

          // optional end chamfer
          if (left_end) {
            attach(LEFT, RIGHT) {
              rect([end_chamf, total_height], chamfer=[0, end_chamf, end_chamf, 0]);
            }
          }
        }
      }
    }
  }
}

diff() {
  for (i = [0:hook_count - 1]) {
    right(i * total_width) {
      single(left_end=i == 0, right_end=i == hook_count - 1);
    }
  }

  first_screw_x_offset = screw_head_d / 2 + total_width + lid_spacing / 2 - screw_head_d;
  last_screw_x_offset = first_screw_x_offset + total_width * (hook_count - 2);
  screw_x_spacing = total_width * screws_every_n_hooks;
  screw_x_positions = flatten(
    [
      [for(x = first_screw_x_offset;x < last_screw_x_offset;x = min(x + screw_x_spacing, last_screw_x_offset))x],
      last_screw_x_offset,
    ]
  );

  tag("remove") {
    for (x = screw_x_positions) {
      for (z = [0, 1]) {
        translate(
          [
            x,
            0,
            screw_head_d / 2 + screw_head_d * 2 + (length - screw_head_d * 5) * z,
          ]
        ) {
          xrot(-90) {
            cyl(d=screw_head_d, h=total_height - wall + fuzz, anchor=BOTTOM) {
              attach(TOP, BOTTOM) {
                cyl(d=screw_d, h=wall + fuzz);
              }
            }
          }
        }
      }
    }
  }
}
