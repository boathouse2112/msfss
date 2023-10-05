const std = @import("std");
const PackedIntArray = std.packed_int_array.PackedIntArray;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn toKb(comptime bytes: comptime_int) comptime_int {
    return bytes << 10;
}

fn blockCount(comptime size: comptime_int) !comptime_int {
    return std.math.divCeil(comptime_int, size, BLOCK_SIZE);
}
fn perBlock(comptime T: type) !comptime_int {
    return std.math.divCeil(comptime_int, BLOCK_SIZE, @sizeOf(T));
}

const DISK_SIZE = toKb(64);
const BLOCK_SIZE = 512;
const BLOCK_COUNT = DISK_SIZE / BLOCK_SIZE;

const BMPS_BLOCK_COUNT = 1; // Trust me bro

const INODES_SIZE = BLOCK_COUNT * @sizeOf(Inode);
const INODES_PER_BLOCK = perBlock(Inode)
    catch @compileError("INODES_PER_BLOCK divCeil error");
const INODES_BLOCK_COUNT = blockCount(INODES_SIZE) // [= 2]
    catch @compileError("INODES_BLOCK_COUNT divCeil error");

const DATA_BLOCK_COUNT = BLOCK_COUNT - BMPS_BLOCK_COUNT - INODES_BLOCK_COUNT;

const DIR_ENTRIES_PER_BLOCK = perBlock(DirEntry)
    catch @compileError("DIR_ENTRIES_PER_BLOCK divCeil error");

fn PackedOptional(comptime T: type) type {
  return packed struct {
        exists: bool,
        value: T,

        pub fn value(self: PackedOptional(u7)) ?T {
            return if (self._exists) self._value else null ;
        }
    };
}

fn someIdx(idx: u7) PackedOptional(u7) {
    return .{
        .exists = true,
        .value = idx,
    };
}

fn none() PackedOptional(u7) {
    return .{
        .exists = false,
        .value = undefined,
    };
}

const Bmp = PackedIntArray(bool, DATA_BLOCK_COUNT);

// TODO -- Can I make this whole program generic over disk and block size?
const Bmps = struct {
    inodes_bmp: Bmp,
    data_bmp: Bmp,
};

const FileType = enum(u1) {
    File,
    Directory,
};

/// Not actually a stable representation. But we can pray.
/// Can't use `extern` because of the bit-packing
/// Can't use `packed` because of the array
const Inode = struct {
    file_type: FileType,
    size: u16, // Zig's auto-placing the largest field in front
    data_direct: [4]PackedOptional(u7),
    data_indirect: PackedOptional(u7),
};

const Directory = struct {
    entries: [DIR_ENTRIES_PER_BLOCK]DirEntry,
};

/// Should always be 16B
const DirEntry = struct {
    file_name: [14:0]u8,
    inode: PackedOptional(u7),
};

const FilesystemPointers = struct { bmps: *Bmps, inodes: []Inode, data: []u8 };

/// Get pointers to the different structures in the filesystem
fn get_fs_ptrs(disk_memory: []u8) FilesystemPointers {
    const bmps_ptr: [*]Bmps = @alignCast(@ptrCast(disk_memory.ptr));
    const bmps: *Bmps = @ptrCast(bmps_ptr);

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

fn getDirBlock(data: []u8, idx: u7) *Directory {
    const idx_usize: usize = @intCast(idx);
    const block_start = idx_usize * BLOCK_SIZE;
    const block_end = block_start + BLOCK_SIZE;
    const block = data[block_start .. block_end];
    const dir: *Directory = @alignCast(@ptrCast(block));
    return dir;
}

/// Initialize the filesystem.
/// Add a root directory at inode 0, data 0
fn initializeFilesystem(pointers: FilesystemPointers) void {
    var ptrs = pointers;

    var inodes_bmp = Bmp.initAllTo(false);
    inodes_bmp.set(0, true);

    var data_bmp = Bmp.initAllTo(false);
    data_bmp.set(0, true);


    ptrs.bmps.* = Bmps {
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
    const root_dir = getDirBlock(ptrs.data, 0);
    for (root_dir_entries, 0..) |entry, i| {
        root_dir.entries[i] = entry;
    }
}

pub fn main() !void {

    const allocator = std.heap.page_allocator;
    const memory = try allocator.alloc(u8, toKb(64));

    const ptrs = get_fs_ptrs(memory);
    // No destructuring syntax yet
    const bmps = ptrs.bmps;
    const inodes = ptrs.inodes;
    const data = ptrs.data;

    initializeFilesystem(ptrs);

    std.debug.print("Pointers:\n", .{});
    std.debug.print("{*}\n", .{memory.ptr});
    std.debug.print("{*}\n", .{bmps});
    std.debug.print("{*}\n", .{inodes.ptr});
    std.debug.print("{*}\n\n", .{data.ptr});

    std.debug.print("Values:\n", .{});
    std.debug.print("{any}\n", .{bmps.inodes_bmp});
    std.debug.print("{any}\n", .{bmps.data_bmp});
    std.debug.print("{any}\n", .{inodes[0]});
    std.debug.print("{any}\n", .{getDirBlock(data, 0)});
}

test "Bmps has expected size" {
    // Each array pads out to 128
    try expectEqual(@bitSizeOf(Bmps), 128 * 2);
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
