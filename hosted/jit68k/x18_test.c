/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 John Knipper */
/* Execute the production decoder/engine objects and capture their real MAP_JIT
 * bytes at the existing cache-finalization seam. No production emitter hook. */
#include "j5d_jit68k.h"
#include "jit_region.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern int32_t _pc_rel;
extern uint32_t *EMIT_AdvancePC(uint32_t *, uint8_t);
extern uint32_t *EMIT_FlushPC(uint32_t *);
extern uint32_t *EMIT_GetOffsetPC(uint32_t *, int8_t *);
extern uint32_t *EMIT_ResetOffsetPC(uint32_t *);
void jit_finalize_actual(jit_region *, void *, size_t);
static const char *dumpdir;
static unsigned captures;

void jit_finalize(jit_region *region, void *ptr, size_t len)
{
    char path[1024];
    snprintf(path, sizeof path, "%s/block-%u.bin", dumpdir, captures++);
    FILE *file = fopen(path, "wb");
    assert(file && fwrite(ptr, 1, len, file) == len);
    assert(fclose(file) == 0);
    jit_finalize_actual(region, ptr, len);
}

int main(int argc, char **argv)
{
    assert(argc == 2); dumpdir = argv[1]; alarm(10);
    uint32_t words[16]; memset(words, 0xa5, sizeof words);
    uint32_t *ptr = EMIT_ResetOffsetPC(words);
    ptr = EMIT_AdvancePC(ptr, 100); ptr = EMIT_AdvancePC(ptr, 100);
    assert(ptr == words && _pc_rel == 0);
    _pc_rel = -121; ptr = EMIT_FlushPC(ptr);
    assert(ptr == words && _pc_rel == 0);
    _pc_rel = 120; int8_t offset = 100;
    ptr = EMIT_GetOffsetPC(ptr, &offset);
    assert(ptr == words && offset == 100 && _pc_rel == 0);
    _pc_rel = 12; offset = 3;
    ptr = EMIT_GetOffsetPC(ptr, &offset);
    assert(ptr == words && offset == 15 && _pc_rel == 12);
    ptr = EMIT_FlushPC(ptr);
    assert(ptr == words && _pc_rel == 0 && words[0] == 0xa5a5a5a5);

    const uint32_t origin = 0x00210000, size = 0x4000;
    uint8_t *mem = calloc(1, size), *refmem = calloc(1, size);
    assert(mem && refmem);
    mem[0] = 0x70; mem[1] = 0; /* moveq #0,d0 */
    for (unsigned i = 0; i < 100; i++) { mem[2+i*2] = 0x52; mem[3+i*2] = 0x80; }
    mem[202] = 0x60; mem[203] = 2; /* bra.s to a separate terminal block */
    mem[204] = 0x4e; mem[205] = 0x71; /* skipped nop */
    mem[206] = 0x4e; mem[207] = 0x75; /* rts; >120 bytes crosses PC offset flush */
    memcpy(refmem, mem, size);
    j5d_sandbox sb = {mem, origin, size}, refsb = {refmem, origin, size};
    struct j5d_m68k_state state = {0}, ref = {0};
    state.a[7] = ref.a[7] = origin + size - 16;
    uint32_t result = 0, reference = 0; char error[256] = {0};
    assert(j5d_run(&sb, origin, 0, &state, &result, NULL, NULL, error, sizeof error) == 0);
    assert(j5d_interp_run(&refsb, origin, 0, &ref, &reference, NULL, NULL, error, sizeof error) == 0);
    assert(result == 100 && reference == 100);
    assert(memcmp(state.d, ref.d, sizeof state.d) == 0);
    assert(memcmp(state.a, ref.a, sizeof state.a) == 0);
    assert(state.pc == origin + 206 && state.pc == ref.pc);
    assert((state.ccr & 0x1f) == (ref.ccr & 0x1f));
    j5d_stats stats; j5d_get_stats(&stats);
    assert(stats.blocks_translated && stats.blocks_executed && captures);
    char path[1024]; snprintf(path, sizeof path, "%s/negative.bin", dumpdir);
    FILE *file = fopen(path, "wb"); uint32_t bad = 0x91000652; /* add x18,x18,#1 */
    assert(file && fwrite(&bad, sizeof bad, 1, file) == 1); assert(fclose(file) == 0);
    printf("[JIT-X18] execution PASS result=100 oracle=100 blocks=%u captures=%u\n", stats.blocks_executed, captures);
    j5d_run_free(); free(mem); free(refmem); return 0;
}
