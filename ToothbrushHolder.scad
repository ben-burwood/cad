// Wall-mounted double OralB Toothbrush Holder.

wall_thickness = 4;
corner_r    = 5;
chamfer = 1;

/* [Brush] */
barrel_diameter  = 30;
barrel_clearance = 0.5;   // radial

/* [Collar] */
collar_thickness = 2.5;
collar_height    = 15;    // above the plate top
base_fillet      = 1.5;   // between the plate top and the bore wall

/* [Base plate] */
barrel_gap       = 5;     // wall between the two bores
notch_fillet     = 2;     // fillet where the lobes meet between them
plate_bot_chamfer= 0.5;

/* [Holes] */
center_hole_radius = 4;
drain_count      = 6;
drain_pcd_radius = 10;
drain_radius     = 2.5;
drain_chamfer    = 1;
drain_angle      = 30;    // angle of the first hole

/* [Back wall] */
wall_height      = 32;
wall_fillet      = 2;     // fillet between collar top and wall front

/* [Screw holes] */
screw_spacing    = 42;    // fixed, centred on the part
screw_z          = 26;
screw_radius     = 2;
screw_head_radius= 4;     // countersink diameter at the wall face / 2

/* [Quality] */
arc_segments     = 48;    // per lobe arc
round_steps      = 8;     // per fillet
$fa              = 6;
$fs              = 0.4;

eps = 0.01;

bore_r       = barrel_diameter / 2 + barrel_clearance;
lobe_radius  = bore_r + collar_thickness;
lobe_pitch   = 2 * bore_r + barrel_gap;
collar_top   = wall_thickness + collar_height;
wall_front_y = bore_r;    // the wall closes the back of each collar
plate_depth  = wall_front_y + wall_thickness;

lobe_xs  = [0, lobe_pitch];
screw_xs = [for (s = [-1, 1]) lobe_pitch / 2 + s * screw_spacing / 2];
x_min = -lobe_radius;
x_max = lobe_pitch + lobe_radius;
plate_width = x_max - x_min;
notch_segments = max(2, round(arc_segments / 6));

// Notch fillet circle centre (relative to the left lobe) and its tangent
// angle. When the lobes are close enough to overlap, both fillets merge into
// one circle on the centre line, tangent to both lobes.
fillet_x      = min(sqrt(pow(lobe_radius + notch_fillet, 2) - pow(notch_fillet, 2)), lobe_pitch / 2);
fillet_y      = sqrt(pow(lobe_radius + notch_fillet, 2) - pow(fillet_x, 2));
fillet_phi    = atan2(fillet_y, fillet_x);
fillet_merged = fillet_x == lobe_pitch / 2;

assert(barrel_gap > 0, "bores overlap");
assert(screw_z - screw_head_radius > collar_top, "collar blocks the screw heads");
assert(screw_spacing / 2 + screw_head_radius < plate_width / 2 - chamfer,
       "screw holes run off the end of the wall");
assert(drain_pcd_radius - drain_radius > center_hole_radius, "drain holes hit the centre hole");

// Edge profiles as [position, inset] pairs, bottom/front to top/back. The
// plate and collars share one outline, so a single sweep gives flush sides,
// the notch fillet all the way up and the chamfer on the outer top edge only.
body_profile = [
    [0, plate_bot_chamfer],
    [plate_bot_chamfer, 0],
    [collar_top - chamfer, 0],
    [collar_top, chamfer]
];

wall_profile = [
    [wall_front_y, chamfer],
    [wall_front_y + chamfer, 0],
    [plate_depth, 0]
];

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
        f1 = [fillet_x, -fillet_y],
        f2 = [lobe_pitch - fillet_x, -fillet_y],
        a2 = arc(f2, notch_fillet + d, 90, fillet_phi, notch_segments)
    )
    concat(
        [[x_min + d, plate_depth - d]],
        arc([0, 0], lobe_radius - d, 180, 360 - fillet_phi, arc_segments),
        tail(arc(f1, notch_fillet + d, 180 - fillet_phi, 90, notch_segments)),
        fillet_merged ? tail(a2) : a2,
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

module floor_holes() {
    chamfered_hole(center_hole_radius, wall_thickness, drain_chamfer, drain_chamfer);
    for (i = [0:drain_count - 1])
        rotate(drain_angle + i * 360 / drain_count) translate([drain_pcd_radius, 0])
            chamfered_hole(drain_radius, wall_thickness, drain_chamfer, drain_chamfer);
}

// Bore with a fillet into the plate and a lead-in chamfer at the top. The
// chamfer carries on up through the wall fillet, and the whole cutter stops
// at the wall face so the back of the barrel stays flush with it.
module bore() {
    r = bore_r + chamfer + wall_fillet + 1;
    translate([0, 0, wall_thickness]) intersection() {
        rotate_extrude() polygon(concat(
            [[0, 0]],
            [for (i = [0:round_steps]) let(a = 270 + 90 * i / round_steps)
                [bore_r - base_fillet + base_fillet * cos(a), base_fillet + base_fillet * sin(a)]],
            [[bore_r, collar_height - chamfer],
             [bore_r + chamfer + wall_fillet + eps, collar_height + wall_fillet + eps],
             [0, collar_height + wall_fillet + eps]]
        ));
        translate([-r, -r, -1]) cube([2 * r, r + wall_front_y, collar_height + wall_fillet + 2]);
    }
}

// Wall outline in the XZ plane, inset by o.
module wall_section(o) {
    hull() {
        translate([x_min + o, o]) square([plate_width - 2 * o, eps]);
        for (x = [x_min + corner_r, x_max - corner_r])
            translate([x, wall_height - corner_r]) circle(r = corner_r - o);
    }
}

// p = [y, inset]
module wall_slice(p) {
    translate([0, p[0], 0]) rotate([90, 0, 0])
        linear_extrude(eps, center = true) wall_section(p[1]);
}

// Fillet along the top of the collars where they meet the wall; bore()
// trims it where it crosses the bores.
module wall_fillet() {
    x0 = x_min + chamfer;
    span = plate_width - 2 * chamfer;
    difference() {
        translate([x0, wall_front_y - wall_fillet, collar_top - eps])
            cube([span, wall_fillet + eps, wall_fillet + eps]);
        translate([x0 - eps, wall_front_y - wall_fillet, collar_top + wall_fillet])
            rotate([0, 90, 0]) cylinder(r = wall_fillet, h = span + 2 * eps);
    }
}

module wall() {
    difference() {
        union() {
            hull() for (p = wall_profile) wall_slice(p);
            wall_fillet();
        }
        for (x = screw_xs) translate([x, wall_front_y, screw_z]) rotate([-90, 0, 0])
            chamfered_hole(screw_radius, wall_thickness, bot = screw_head_radius - screw_radius);
    }
}

module toothbrush_holder() {
    difference() {
        union() {
            plate_sweep(body_profile);
            wall();
        }
        at_lobes() {
            bore();
            floor_holes();
        }
    }
}

toothbrush_holder();
