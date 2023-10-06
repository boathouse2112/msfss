const types = @import("types.zig");
const PackedOptional = types.PackedOptional;

pub const FileType = enum(u1) {
    File,
    Directory,
};

/// Not actually a stable representation. But we can pray.
/// Can't use `extern` because of the bit-packing
/// Can't use `packed` because of the array
pub const Inode = struct {
    file_type: FileType,
    size: u16, // Zig's auto-placing the largest field in front
    data_direct: [4]PackedOptional(u7),
    data_indirect: PackedOptional(u7),
};
