 // ==========================
// Tappo USB 14x38 con rientranza | IT/EN: 14x38 USB cover with recess
// ==========================

// Dimensioni esterne | IT/EN: External dimensions
outer_x = 38;   // lunghezza | IT/EN: length
outer_y = 18.5;   // larghezza | IT/EN: width
outer_z = 8;    // spessore totale | IT/EN: total thickness

// Rientranza | IT/EN: Recess
recess_depth = 7;   // profondità rientranza | IT/EN: recess depth
wall = 1.5;         // spessore pareti laterali | IT/EN: side-wall thickness

difference() {

    // Corpo esterno | IT/EN: Outer body
    cube([outer_x, outer_y, outer_z], center = false);

    // Rientranza interna | IT/EN: Internal recess
    translate([wall, wall, outer_z - recess_depth])
        cube([
            outer_x - 2*wall,
            outer_y - 2*wall,
            recess_depth + 0.01
        ], center = false);
}
