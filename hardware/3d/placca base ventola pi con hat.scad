// =====================
// Dimensioni HAT | IT/EN: HAT dimensions
// =====================
hat_length = 65;
hat_width  = 55;
hat_height = 10;

hat_hole_inset   = 2.5;
hat_hole_diameter = 3.2;

// =====================
// Ventola | IT/EN: Fan
// =====================
fan_size = 40;
fan_hole_spacing = 32;
fan_hole_diameter = 3.3;
fan_airflow_diameter = 38;

// =====================
// Struttura | IT/EN: Structure
// =====================
base_thickness = 2;
pillar_height  = hat_height - base_thickness;
top_thickness  = 2;

// =====================
// Rientranza GPIO | IT/EN: GPIO recess
// =====================
gpio_width  = 52;
gpio_depth  = 8;
gpio_margin = 3;

// =====================
// Offset | IT/EN: Scostamento
// =====================
offset_x = (hat_length - 65) / 2;
offset_y = (hat_width  - 55) / 2;

// =====================
// Fori HAT | IT/EN: HAT holes
// =====================
hat_hole_positions = [
    [hat_hole_inset + offset_x, hat_hole_inset + offset_y],
    [65 - hat_hole_inset + offset_x, hat_hole_inset + offset_y],
    [hat_hole_inset + offset_x, 55 - hat_hole_inset + offset_y],
    [65 - hat_hole_inset + offset_x, 55 - hat_hole_inset + offset_y]
];

// =====================
// Ventola | IT/EN: Fan
// =====================
fan_center_x = 65/2 + offset_x;
fan_center_y = 50/2 + offset_y;
fan_hole_offset = fan_hole_spacing / 2;

fan_hole_positions = [
    [fan_center_x - fan_hole_offset, fan_center_y - fan_hole_offset],
    [fan_center_x + fan_hole_offset, fan_center_y - fan_hole_offset],
    [fan_center_x - fan_hole_offset, fan_center_y + fan_hole_offset],
    [fan_center_x + fan_hole_offset, fan_center_y + fan_hole_offset]
];

// =====================
// Rientranza GPIO (Y) | IT/EN: GPIO recess, Y direction
// =====================
gpio_y_start = hat_hole_inset + offset_y + gpio_margin;
gpio_y_end   = 65 - hat_hole_inset + offset_y - gpio_margin;
gpio_y_size  = gpio_y_end - gpio_y_start;

// =====================
// Piastra superiore | IT/EN: Top plate
// =====================
module top_plate() {
    translate([0, 0, base_thickness + pillar_height]) {
        difference() {

            cube([hat_length, hat_width, top_thickness]);

            // Foro aria | IT/EN: Air opening
            translate([fan_center_x, fan_center_y, -0.1])
                cylinder(d = fan_airflow_diameter, h = top_thickness + 0.2);

            // Fori ventola | IT/EN: Fan holes
            for(pos = fan_hole_positions)
                translate([pos[0], pos[1], -0.1])
                    cylinder(d = fan_hole_diameter, h = top_thickness + 0.2);

            // Fori HAT | IT/EN: HAT holes
            for(pos = hat_hole_positions)
                translate([pos[0], pos[1], -0.1])
                    cylinder(d = hat_hole_diameter, h = top_thickness + 0.2);

            // RIENTRANZA GPIO – lato X = 65 | IT/EN: GPIO RECESS on the X=65 side
            translate([gpio_y_start, hat_width - gpio_depth + 0.1, -0.1])
    cube([gpio_y_size, gpio_depth + 0.2, top_thickness + 0.2]);
        }
    }
}

// =====================
// Assemblaggio | IT/EN: Assembly
// =====================
top_plate();
