//! Bitmaps to track Inode and Data
const fs = @import("filesystem.zig");
const std = @import("std");
const PackedIntArray = std.packed_int_array.PackedIntArray;

pub const Bmp = PackedIntArray(bool, fs.DATA_BLOCK_COUNT);

// TODO -- Can I make this whole program generic over disk and block size?
pub const BmpTable = struct {
    inodes_bmp: Bmp,
    data_bmp: Bmp,
};
