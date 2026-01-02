## AXI4-Lite Scratchpad

This module is used to access static RAM via AXI4-Lite interface. It supports bus (RAM) widths
of 32- or 64-bits, and flexible depth. The bus width and the RAM depth are controlled via 
MEMORY_BW_p and MEMORY_DEPTH_p parameters.

The AXI address and data withs also depend on those parameters and are automatically calculated.

The AXI4-Scratchpad slave uses skid buffers (register slices). This allows writes on every
clock-cycle via the AXI4 bus, or reads on every clock cycle via the AXI4 bus, i.e. full throuhtput.

Scratchpad supports writing to the individual bytes, i.e. AXI4-Lite strobes are supported.

If the RAM depth is not a power-of-two, it's possible to access address space inside the 
AXI4-Scratchpad that is unassigned. The slave will generate AXI4 SLVERR if that is the case.

## Example 4k Scratchpad

MEMORY_BW_p = 32, MEMORY_DEPTH_p = 1024
32-bits = 4 bytes
4 bytes * 1024 rows = 4K

## Integration

- Connect clock to the 'clk' port
- Connect negative logic reset to the 'rst_n' port
- Connect AXI4-Lite signals

## Known issues

*ORDERING BEHAVIOR:*
This slave does not guarantee read-after-write ordering. Masters must wait for write response
(BVALID) before issuing reads to the same address if they require updated data.

This is compliant with AXI4-Lite specification which does not mandate ordering between read and
write channels, but still it's annoying. 

```c
// raw_hazard_test.c
// Simple test to reproduce Read-After-Write hazard

#include <stdint.h>
#include <stdio.h>

#define SCRATCHPAD_BASE  0x00000000

volatile uint32_t *scratchpad = (volatile uint32_t *)SCRATCHPAD_BASE;

int main(void) {
    uint32_t test_addr = 0x100 / 4;  // Word offset
    uint32_t write_value = 0xDEADBEEF;
    uint32_t read_value;
    
    // Initialize to zero
    scratchpad[test_addr] = 0x00000000;
    
    // Create RAW hazard: write then immediately read
    scratchpad[test_addr] = write_value;
    read_value = scratchpad[test_addr];

    // NOTE: It's possible master will wait for BVALID assertion
    // before issuing the read, but this is not guaranteed
    
    printf("Wrote: 0x%08X\n", write_value);
    printf("Read:  0x%08X\n", read_value);
    
    if (read_value != write_value) {
        printf("RAW HAZARD DETECTED!\n");
        return 1;
    } else {
        printf("No hazard detected.\n");
        return 0;
    }
}

```
