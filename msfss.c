#include <stdint.h>
#include <sys/mman.h>

// KB = 2^10
#define KB(x) \
    ((size_t) (x) << 10)

#define DISK_SIZE KB(64)

#define INODE_TYPE_FILE 0
#define INODE_TYPE_DIR 1

typedef uint8_t InodePtr;
typedef uint8_t DataPtr;
typedef uint8_t MaybeDataPtr;

typedef struct BmpBlock {
    uint8_t inode_bmp;
    uint8_t data_bmp;
} BmpBlock;

typedef struct Inode {
    // Bit 15 -- INODE_TYPE_FILE or INODE_TYPE_DIR
    // Bits (12 ..= 0) -- Filesize
    uint16_t file_type_size;
    MaybeDataPtr data_direct[2];
    MaybeDataPtr data_indirect;
} Inode;

typedef struct DirEntry {
    uint8_t file_name[15];
    InodePtr inode;
} DirEntry;

int main(/* int argc, char *argv[] */) {
    void *disk =
    return 0;
}
