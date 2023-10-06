pub fn PackedOptional(comptime T: type) type {
  return packed struct {
        exists: bool,
        value: T,

        pub fn value(self: PackedOptional(u7)) ?T {
            return if (self._exists) self._value else null ;
        }
    };
}

pub fn someIdx(idx: u7) PackedOptional(u7) {
    return .{
        .exists = true,
        .value = idx,
    };
}

pub fn none() PackedOptional(u7) {
    return .{
        .exists = false,
        .value = undefined,
    };
}
