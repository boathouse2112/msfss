// 三徳ヘッダ
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/mman.h>

// KB = 2^10
#define KB(x) \
    ((size_t) (x) << 10)

#define DISK_SIZE KB(64)
#define BLOCK_SIZE 256

#define BMPS_START 0
#define INODES_START BLOCK_SIZE
#define DATA_START BLOCK_SIZE * 3

#define INODE_TYPE_FILE 0
#define INODE_TYPE_DIR 1

typedef uint8_t InodePtr;
typedef uint8_t DataPtr;
/// NULL or a data block
typedef uint8_t MaybeDataPtr;

typedef struct BmpBlock {
    uint64_t inode_bmp[2];
    uint64_t data_bmp[2];
} BmpBlock;

typedef struct Inode {
    // Bit 15 -- INODE_TYPE_FILE or INODE_TYPE_DIR
    // Bits (12 ..= 0) -- Filesize
    uint16_t file_type_size;
    MaybeDataPtr data_direct[2];
    MaybeDataPtr data_indirect;
} Inode;

typedef struct Block {
    uint8_t bytes[512];
} Block;

typedef struct DirEntry {
    uint8_t file_name[15];
    InodePtr inode;
} DirEntry;

void init_bmps(BmpBlock *bmps) {
    // 0th block of each is in use
    BmpBlock bmp_block = {
        .inode_bmp = { 0, 1 },
        .data_bmp = { 0, 1 },
    }
}

/**
 * Format inode blocks.
 * Start at BL 2
 * 6B inodes
 * 85 inodes / block
 * Need 2 blocks
 *
 * Root directory at inode 0
 */
void init_inodes(Inode *inodes) {
    Inode node = {
        .file_type_size = INODE_TYPE_DIR & 0,
        .data_direct = { 0 },
        .data_indirect = NULL,
    };
    *inodes = node;
}

int main(/* int argc, char *argv[] */) {
    void *disk = mmap(
        NULL, // addr
        DISK_SIZE, // length
        PROT_READ | PROT_WRITE, // prot flags
        MAP_ANONYMOUS | MAP_PRIVATE, // flags
        -1, // FD -- anonymous => -1
        0 // Offset
    );

    BmpBlock *bmps = disk + BMPS_START;
    Inode *inodes = disk + INODES_START;
    void *data = disk + DATA_START;

    printf("%p\n", disk);
    printf("%d\n", *((uint8_t *)disk + 200));
    return 0;
}
