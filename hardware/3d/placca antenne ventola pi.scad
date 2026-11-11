// Dimensioni HAT modificate | IT/EN: Modified HAT dimensions
hat_length = 120; // Da 65 a 120 | IT/EN: From 65 to 120
hat_width = 100;  // Da 55 a 100 | IT/EN: From 55 to 100
hat_height = 10; // Altezza totale dal PCB | IT/EN: Total height from the PCB
hat_hole_inset = 2.5; // Bordi fori di fissaggio | IT/EN: Mounting-hole edge margins
hat_hole_diameter = 3.2; // Diametro fori HAT | IT/EN: HAT-hole diameter

// Dimensioni ventola | IT/EN: Fan dimensions
fan_size = 40;
fan_hole_spacing = 32; // Interasse fori | IT/EN: Hole spacing
fan_hole_diameter = 3.3; // Diametro fori ventola | IT/EN: Fan-hole diameter
fan_airflow_diameter = 38; // Diametro apertura centrale | IT/EN: Center-opening diameter

// Parametri struttura | IT/EN: Structure parameters
base_thickness = 2;
pillar_height = hat_height - base_thickness;
pillar_diameter = 6;
top_thickness = 2;

// Parametri fori antenne | IT/EN: Antenna-hole parameters
antenna_diameter = 6.6; // Diametro fori RP-SMA | IT/EN: RP-SMA hole diameter
antenna_margin = 20; // Distanza dal bordo superiore/inferiore (aumentata) | IT/EN: Increased distance from top/bottom edge
antenna_spacing = 20; // Distanza tra i fori | IT/EN: Distance between holes
antenna_offset = 10; // Distanza dal bordo laterale (aumentata per essere più interni) | IT/EN: Increased side-edge distance, placing the holes farther inward

// Calcolo offset per centrare i fori | IT/EN: Calculate offsets to center the holes
offset_x = (hat_length - 65) / 2;
offset_y = (hat_width - 55) / 2;

// Calcolo posizioni fori HAT (mantenute relative) | IT/EN: Calculate HAT-hole positions, retaining relative placement
hat_hole_positions = [
    [hat_hole_inset + offset_x, hat_hole_inset + offset_y],
    [65 - hat_hole_inset + offset_x, hat_hole_inset + offset_y],
    [hat_hole_inset + offset_x, 55 - hat_hole_inset + offset_y],
    [65 - hat_hole_inset + offset_x, 55 - hat_hole_inset + offset_y]
];

// Calcolo posizioni fori ventola (mantenute relative) | IT/EN: Calculate fan-hole positions, retaining relative placement
fan_center_x = 65/2 + offset_x;
fan_center_y = 55/2 + offset_y;
fan_hole_offset = fan_hole_spacing / 2;

fan_hole_positions = [
    [fan_center_x - fan_hole_offset, fan_center_y - fan_hole_offset],
    [fan_center_x + fan_hole_offset, fan_center_y - fan_hole_offset],
    [fan_center_x - fan_hole_offset, fan_center_y + fan_hole_offset],
    [fan_center_x + fan_hole_offset, fan_center_y + fan_hole_offset]
];

// Piastra superiore | IT/EN: Top plate
module top_plate() {
    translate([0, 0, base_thickness + pillar_height]) {
        difference() {
            // Piastra principale (nuove dimensioni) | IT/EN: Main plate with the new dimensions
            cube([hat_length, hat_width, top_thickness]);
            
            // Foro centrale per flusso d'aria | IT/EN: Center airflow opening
            translate([fan_center_x, fan_center_y, -0.1])
            cylinder(d = fan_airflow_diameter, h = top_thickness + 0.2);
            
            // Fori di montaggio ventola | IT/EN: Fan mounting holes
            for(pos = fan_hole_positions) {
                translate([pos[0], pos[1], -0.1])
                cylinder(d = fan_hole_diameter, h = top_thickness + 0.2);
            }
            
            // Fori passanti pilastri | IT/EN: Through-holes for pillars
            for(pos = hat_hole_positions) {
                translate([pos[0], pos[1], -0.1])
                cylinder(d = hat_hole_diameter, h = top_thickness + 0.2);
            }
            
            // Fori per antenne RP-SMA (lato sinistro - x=0) | IT/EN: RP-SMA antenna holes on the left side, x=0
            for(i = [0:3]) {
                translate([
                    antenna_offset, 
                    antenna_margin + i * antenna_spacing, 
                    -0.1
                ])
                cylinder(d = antenna_diameter, h = top_thickness + 0.2);
            }
            
            // Fori per antenne RP-SMA (lato destro - x=hat_length) | IT/EN: RP-SMA antenna holes on the right side, x=hat_length
            for(i = [0:3]) {
                translate([
                    hat_length - antenna_offset, 
                    antenna_margin + i * antenna_spacing, 
                    -0.1
                ])
                cylinder(d = antenna_diameter, h = top_thickness + 0.2);
            }
        }
    }
}

// Assemblaggio finale | IT/EN: Final assembly
union() {
    top_plate();
}