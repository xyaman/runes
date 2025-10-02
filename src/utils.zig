pub fn copyGeometry(dest: anytype, source: anytype) void {
    dest.x = source.x;
    dest.y = source.y;
    dest.w = source.w;
    dest.h = source.h;
}
