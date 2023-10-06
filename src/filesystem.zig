const std = @import("std");
const bmp = @import("bmp.zig");
const directory = @import("directory.zig");
const inode = @import("inode.zig");
const types = @import("types.zig");

const Bmp = bmp.Bmp;
const BmpTable = bmp.BmpTable;
const DirEntry = directory.DirEntry;
const Inode = inode.Inode;
const PackedOptional = types.PackedOptional;

const someIdx = types.someIdx;
const none = types.none;

pub fn toKb(comptime bytes: comptime_int) comptime_int {
    return bytes << 10;
}

pub fn blockCount(comptime size: comptime_int) !comptime_int {
    return std.math.divCeil(comptime_int, size, BLOCK_SIZE);
}

pub fn perBlock(comptime T: type) !comptime_int {
    return std.math.divCeil(comptime_int, BLOCK_SIZE, @sizeOf(T));
}

pub const DISK_SIZE = toKb(64);
pub const BLOCK_SIZE = 512;
pub const BLOCK_COUNT = DISK_SIZE / BLOCK_SIZE;

pub const INODES_SIZE = BLOCK_COUNT * @sizeOf(Inode);
pub const INODES_PER_BLOCK = perBlock(Inode)
    catch @compileError("INODES_PER_BLOCK divCeil error");
pub const INODES_BLOCK_COUNT = blockCount(INODES_SIZE) // [= 2]
    catch @compileError("INODES_BLOCK_COUNT divCeil error");

const BMPS_BLOCK_COUNT = 1;

pub const DATA_BLOCK_COUNT = BLOCK_COUNT - BMPS_BLOCK_COUNT - INODES_BLOCK_COUNT;

pub const DIR_ENTRIES_PER_BLOCK = perBlock(DirEntry)
    catch @compileError("DIR_ENTRIES_PER_BLOCK divCeil error");

pub const FilesystemPointers = struct { bmps: *BmpTable, inodes: []Inode, data: []u8 };

/// Get pointers to the different structures in the filesystem
pub fn getPointers(disk_memory: []u8) FilesystemPointers {
    const bmps_ptr: [*]BmpTable = @alignCast(@ptrCast(disk_memory.ptr));
    const bmps: *BmpTable = @ptrCast(bmps_ptr);

    const inodes_start = BMPS_BLOCK_COUNT * BLOCK_SIZE;
    // Can't @ptrCast slices yet. It's easier to set the slice start to `inodes_start`
    const inode_ptr: [*]Inode = @alignCast(@ptrCast(disk_memory.ptr + inodes_start));
    const inodes: []Inode = inode_ptr[0..INODES_PER_BLOCK * INODES_BLOCK_COUNT];

    const data_start = (BMPS_BLOCK_COUNT + INODES_BLOCK_COUNT) * BLOCK_SIZE;
    const data: []u8 = disk_memory.ptr[data_start .. DISK_SIZE];

    return .{
        .bmps = bmps,
        .inodes = inodes,
        .data = data,
    };
}

/// Initialize the filesystem.
/// Add a root directory at inode 0, data 0
pub fn init(pointers: FilesystemPointers) void {
    var ptrs = pointers;

    var inodes_bmp = Bmp.initAllTo(false);
    inodes_bmp.set(0, true);

    var data_bmp = Bmp.initAllTo(false);
    data_bmp.set(0, true);


    ptrs.bmps.* = BmpTable {
        .inodes_bmp = inodes_bmp,
        .data_bmp = data_bmp,
    };

    const root_inode = Inode {
        .file_type = .Directory,
        .size = @sizeOf(DirEntry) * 2,
        .data_direct = [_]PackedOptional(u7){ someIdx(0), none(), none(), none() },
        .data_indirect = none(),
    };
    ptrs.inodes[0] = root_inode;

    // Root "/" has "." and ".." set to "/"
    const root_dir_entries = [_]DirEntry {
        .{ .file_name = std.mem.zeroes([14:0]u8), .inode = someIdx(0) },
        .{ .file_name = std.mem.zeroes([14:0]u8), .inode = someIdx(0) },
    };
    const root_dir = directory.getDir(ptrs.data, 0);
    for (root_dir_entries, 0..) |entry, i| {
        root_dir.entries[i] = entry;
    }
}
