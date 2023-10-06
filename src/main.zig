const std = @import("std");
const bmp = @import("bmp.zig");
const directory = @import("directory.zig");
const fs = @import("filesystem.zig");
const inode = @import("inode.zig");

const BmpTable = bmp.BmpTable;
const DirEntry = directory.DirEntry;
const Inode = inode.Inode;
const PackedIntArray = std.packed_int_array.PackedIntArray;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn main() !void {

    const allocator = std.heap.page_allocator;
    const memory = try allocator.alloc(u8, fs.toKb(64));

    const ptrs = fs.getPointers(memory);
    // No destructuring syntax yet
    const bmps = ptrs.bmps;
    const inodes = ptrs.inodes;
    const data = ptrs.data;

    fs.init(ptrs);

    std.debug.print("Pointers:\n", .{});
    std.debug.print("{*}\n", .{memory.ptr});
    std.debug.print("{*}\n", .{bmps});
    std.debug.print("{*}\n", .{inodes.ptr});
    std.debug.print("{*}\n\n", .{data.ptr});

    std.debug.print("Values:\n", .{});
    std.debug.print("{any}\n", .{bmps.inodes_bmp});
    std.debug.print("{any}\n", .{bmps.data_bmp});
    std.debug.print("{any}\n", .{inodes[0]});
    std.debug.print("{any}\n", .{directory.getDir(data, 0)});
}

test "BmpTable has expected size" {
    // Each array pads out to 128
    try expectEqual(@bitSizeOf(BmpTable), 128 * 2);
}

test "Inode has expected size" {
    try expectEqual(@sizeOf(Inode), 8);
}

test "Inode has expected layout" {
    try expectEqual(@offsetOf(Inode, "size"), 0);
    try expectEqual(@offsetOf(Inode, "file_type"), 2);
    try expectEqual(@offsetOf(Inode, "data_direct"), 3);
    try expectEqual(@offsetOf(Inode, "data_indirect"), 7);
}

test "DirEntry has expected size" {
    try expectEqual(@sizeOf(DirEntry), 16);
}
