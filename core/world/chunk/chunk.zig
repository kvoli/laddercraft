const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

const block = @import("../block/block.zig");

pub const ChunkSection = @import("chunk_section.zig").ChunkSection;
pub const CompactedDataArray = @import("compacted_data_array.zig").CompactedDataArray;

pub const Chunk = struct {
    alloc: *Allocator,

    sections: std.AutoArrayHashMap(u8, ChunkSection),
    block_entities: std.AutoArrayHashMap(block.BlockPos, block.BlockEntity),

    x: i32,
    z: i32,

    pub fn initEmpty(alloc: *Allocator, x: i32, z: i32) !*Chunk {
        const chunk = try alloc.create(Chunk);
        chunk.* = Chunk{
            .alloc = alloc,

            .sections = std.AutoArrayHashMap(u8, ChunkSection).init(alloc),
            .block_entities = std.AutoArrayHashMap(block.BlockPos, block.BlockEntity).init(alloc),

            .x = x,
            .z = z,
        };
        return chunk;
    }

    pub fn initFlat(alloc: *Allocator, x: i32, z: i32) !*Chunk {
        var chunk = try initEmpty(alloc, x, z);

        var cy: u32 = 0;
        while (cy < 4) : (cy += 1) {
            var cz: u32 = 0;
            while (cz < 16) : (cz += 1) {
                var cx: u32 = 0;
                while (cx < 16) : (cx += 1) {
                    _ = try chunk.setBlock(cx, cy, cz, 0x1);
                }
            }
        }

        return chunk;
    }

    pub fn deinit(self: *Chunk) void {
        for (self.sections.values()) |*value| value.deinit(self.alloc);
        self.sections.deinit();
        self.block_entities.deinit();

        self.alloc.destroy(self);
    }

    pub fn getBlock(self: *Chunk, x: u32, y: u32, z: u32) block.BlockState {
        const section_y = @intCast(u8, (y / 16));
        if (self.sections.get(section_y)) |*section| {
            return section.getBlock(x, @mod(y, 16), z);
        } else {
            return 0;
        }
    }

    pub fn setBlock(self: *Chunk, x: u32, y: u32, z: u32, block_state: block.BlockState) !bool {
        const section_y = @intCast(u8, (y / 16));
        if (self.sections.get(section_y)) |*section| {
            return section.setBlock(x, @mod(y, 16), z, block_state);
        } else if (block_state != 0) {
            var section = try ChunkSection.init(self.alloc);
            _ = section.setBlock(x, @mod(y, 16), z, block_state);
            try self.sections.put(section_y, section);
            return true;
        } else return false;
    }

    pub fn getHighestBlockSection(self: *Chunk, x: u32, z: u32) u32 {
        var highest: u32 = 0;
        var iterator = self.sections.iterator();
        while (iterator.next()) |section| {
            var y: u32 = 15;
            while (y > 0) : (y -= 1) {
                const block_state = section.value_ptr.getBlock(x, y, z);
                if (block_state != 0 and highest < y + section.key_ptr.* * 16) {
                    highest = section.key_ptr.* * 16;
                }
            }
        }
        return highest;
    }

    pub fn chunkID(self: *Chunk) callconv(.Inline) u64 {
        return (@bitCast(u64, @as(i64, self.x)) << 32) | @bitCast(u32, self.z);
    }
};
