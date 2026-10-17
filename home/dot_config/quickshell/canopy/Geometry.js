.pragma library

// The fourth-power superellipse used by the original Canopy QPainter paths.
function corner(cx, cy, radius, start, end) {
    let path = "";
    for (let i = 1; i <= 20; i++) {
        const angle = start + (end - start) * i / 20;
        const c = Math.cos(angle), s = Math.sin(angle);
        path += " L " + (cx + radius * Math.sign(c) * Math.sqrt(Math.abs(c)))
             + " " + (cy + radius * Math.sign(s) * Math.sqrt(Math.abs(s)));
    }
    return path;
}

function squircle(x, y, width, height, corners) {
    const r = corners.map(v => Math.max(0, Math.min(v, width / 2, height / 2)));
    return "M " + (x+r[0]) + " " + y + " H " + (x+width-r[1])
        + corner(x+width-r[1], y+r[1], r[1], -Math.PI/2, 0)
        + " V " + (y+height-r[2]) + corner(x+width-r[2], y+height-r[2], r[2], 0, Math.PI/2)
        + " H " + (x+r[3]) + corner(x+r[3], y+height-r[3], r[3], Math.PI/2, Math.PI)
        + " V " + (y+r[0]) + corner(x+r[0], y+r[0], r[0], Math.PI, Math.PI*1.5) + " Z";
}

function island(width, height, edge) {
    const r = 16;
    let path = squircle(r, 0, width-r*2, height, [0,0,edge === "right" ? 0:r,edge === "left" ? 0:r]);
    if (edge !== "left") path += " M 0 0 H 16 V 16" + corner(0,16,16,0,-Math.PI/2) + " Z";
    if (edge !== "right") path += " M " + width + " 0 H " + (width-r) + " V 16"
        + corner(width,16,r,Math.PI,Math.PI*1.5) + " Z";
    return path;
}
