// Wall-mounted double OralB Toothbrush Holder.

wall_thickness = 5;
corner_r    = 5;
chamfer = 1;

/* [Base plate] */
lobe_radius      = 15;
lobe_pitch       = 38;    // centre-to-centre distance between the lobes
plate_depth      = 22.5;  // lobe centre to back face of the wall
notch_fillet     = 2;     // fillet where the lobes meet between them
plate_bot_chamfer= 0.5;

/* [Drain holes] */
drain_count      = 6;
drain_pcd_radius = 10;
drain_radius     = 2.5;
drain_chamfer    = 1;
drain_angle      = 30;    // angle of the first hole

/* [Peg] */
peg_height       = 12.5;  // above the plate top
peg_back_width   = 7.4;  // wall side
peg_front_width  = 6.7;
peg_length       = 9;
peg_corner_r     = 2;
peg_taper        = 0.15;  // inset at the top of the straight section
peg_top_round    = 2;
peg_base_fillet  = 1.25;

/* [Back wall] */
wall_height      = 28;
wall_fillet      = 2.5;   // fillet between plate top and wall front

/* [Screw holes] */
screw_z          = 22;
screw_radius     = 2;
screw_head_radius= 4;     // countersink diameter at the wall face / 2

/* [Quality] */
arc_segments     = 48;    // per lobe arc
round_steps      = 8;     // per rounded edge
$fa              = 6;
$fs              = 0.4;

eps = 0.01;

lobe_xs = [0, lobe_pitch];
wall_front_y = plate_depth - wall_thickness;
x_min = -lobe_radius;
x_max = lobe_pitch + lobe_radius;

// Fillet circle centre (relative to the left lobe) and its tangent angle.
fillet_x   = sqrt(pow(lobe_radius + notch_fillet, 2) - pow(notch_fillet, 2));
fillet_phi = atan2(notch_fillet, fillet_x);

assert(lobe_pitch > 2 * fillet_x, "lobes overlap: no notch between them");

// Edge profiles as [position, inset] pairs, bottom/front to top/back.
plate_profile = [
    [0, plate_bot_chamfer],
    [plate_bot_chamfer, 0],
    [wall_thickness - chamfer, 0],
    [wall_thickness, chamfer]
];

wall_profile = [
    [wall_front_y, chamfer],
    [wall_front_y + chamfer, 0],
    [plate_depth, 0]
];

peg_body_profile = concat(
    [[0, 0]],
    [for (i = [0:round_steps]) let(a = 90 * i / round_steps)
        [peg_height - peg_top_round + peg_top_round * sin(a),
         peg_taper + peg_top_round * (1 - cos(a))]]
);

// Concave, so the inset is negative and it is hulled band by band.
peg_fillet_profile =
    [for (i = [0:round_steps]) let(a = 90 * i / round_steps)
        [peg_base_fillet * (1 - cos(a)), -peg_base_fillet * (1 - sin(a))]];

// ---------------------------------------------------------------- helpers --

function arc(c, r, a0, a1, n) =
    [for (i = [0:n]) let(a = a0 + (a1 - a0) * i / n) c + r * [cos(a), sin(a)]];

function tail(l) = [for (i = [1:len(l) - 1]) l[i]];

module at_lobes() {
    for (x = lobe_xs) translate([x, 0]) children();
}

// Hole along +z from 0 to depth, with 45 degree chamfers at either end.
module chamfered_hole(r, depth, bot = 0, top = 0) {
    rotate_extrude() polygon([
        [0, -eps], [r + bot + eps, -eps], [r, bot],
        [r, depth - top], [r + top + eps, depth + eps], [0, depth + eps]
    ]);
}

// Plate outline inset by d. Every inset has the same vertex count so the
// layers can be skinned into one polyhedron with smooth edge profiles.
function plate_outline(d) =
    let(
        f1 = [fillet_x, -notch_fillet],
        f2 = [lobe_pitch - fillet_x, -notch_fillet],
        nf = max(2, round(arc_segments / 6))
    )
    concat(
        [[x_min + d, plate_depth - d]],
        arc([0, 0], lobe_radius - d, 180, 360 - fillet_phi, arc_segments),
        tail(arc(f1, notch_fillet + d, 180 - fillet_phi, 90, nf)),
        arc(f2, notch_fillet + d, 90, fillet_phi, nf),
        tail(arc([lobe_pitch, 0], lobe_radius - d, 180 + fillet_phi, 360, arc_segments)),
        [[x_max - d, plate_depth - d]]
    );

// Skin a list of [z, inset] layers of plate_outline() into a solid.
module plate_sweep(profile) {
    n = len(plate_outline(0));
    m = len(profile);
    points = [for (l = profile) for (p = plate_outline(l[1])) [p.x, p.y, l[0]]];
    faces = concat(
        [[for (j = [0:n - 1]) j]],
        [[for (j = [n - 1:-1:0]) (m - 1) * n + j]],
        [for (i = [0:m - 2]) for (j = [0:n - 1])
            let(a = i * n, b = (i + 1) * n, k = (j + 1) % n)
            [a + j, b + j, b + k, a + k]]
    );
    polyhedron(points, faces, convexity = 4);
}

// ------------------------------------------------------------------ parts --

module plate() {
    difference() {
        plate_sweep(plate_profile);
        at_lobes() for (i = [0:drain_count - 1])
            rotate(drain_angle + i * 360 / drain_count) translate([drain_pcd_radius, 0])
                chamfered_hole(drain_radius, wall_thickness, drain_chamfer, drain_chamfer);
    }
}

module peg_section() {
    bx = peg_back_width / 2 - peg_corner_r;
    fx = peg_front_width / 2 - peg_corner_r;
    y  = peg_length / 2 - peg_corner_r;
    hull() for (p = [[bx, y], [-bx, y], [fx, -y], [-fx, -y]])
        translate(p) circle(r = peg_corner_r);
}

// p = [z, inset]
module peg_slice(p) {
    translate([0, 0, p[0]]) linear_extrude(eps) offset(r = -p[1]) peg_section();
}

module peg() {
    translate([0, 0, wall_thickness - eps]) {
        hull() for (p = peg_body_profile) peg_slice(p);
        for (i = [0:len(peg_fillet_profile) - 2])
            hull() for (p = [peg_fillet_profile[i], peg_fillet_profile[i + 1]]) peg_slice(p);
    }
}

// Wall outline in the XZ plane, inset by o.
module wall_section(o) {
    hull() {
        translate([x_min + o, o]) square([x_max - x_min - 2 * o, eps]);
        for (x = [x_min + corner_r, x_max - corner_r])
            translate([x, wall_height - corner_r]) circle(r = corner_r - o);
    }
}

// p = [y, inset]
module wall_slice(p) {
    translate([0, p[0], 0]) rotate([90, 0, 0])
        linear_extrude(eps, center = true) wall_section(p[1]);
}

module wall_fillet() {
    x0 = x_min + chamfer;
    span = x_max - x_min - 2 * chamfer;
    difference() {
        translate([x0, wall_front_y - wall_fillet, wall_thickness - eps])
            cube([span, wall_fillet + eps, wall_fillet + eps]);
        translate([x0 - eps, wall_front_y - wall_fillet, wall_thickness + wall_fillet])
            rotate([0, 90, 0]) cylinder(r = wall_fillet, h = span + 2 * eps);
    }
}

module wall() {
    difference() {
        union() {
            hull() for (p = wall_profile) wall_slice(p);
            wall_fillet();
        }
        at_lobes() translate([0, wall_front_y, screw_z]) rotate([-90, 0, 0])
            chamfered_hole(screw_radius, wall_thickness, bot = screw_head_radius - screw_radius);
    }
}

module toothbrush_holder() {
    plate();
    wall();
    at_lobes() peg();
}

toothbrush_holder();
