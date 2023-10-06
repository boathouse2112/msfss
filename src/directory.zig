const fs = @import("filesystem.zig");
const types = @import("types.zig");

const PackedOptional = types.PackedOptional;

const Directory = struct {
    entries: [fs.DIR_ENTRIES_PER_BLOCK]DirEntry,
};

/// Should always be 16B
pub const DirEntry = struct {
    file_name: [14:0]u8,
    inode: PackedOptional(u7),
};

pub fn getDir(data: []u8, idx: u7) *Directory {
    const idx_usize: usize = @intCast(idx);
    const block_start = idx_usize * fs.BLOCK_SIZE;
    const block_end = block_start + fs.BLOCK_SIZE;
    const block = data[block_start .. block_end];
    const dir: *Directory = @alignCast(@ptrCast(block));
    return dir;
}
