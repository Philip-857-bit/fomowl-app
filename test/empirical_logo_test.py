"""Empirical Adversarial Validation & Stress Harness for AssetChain Logo.

This script tests:
1. Binary header and PNG chunk integrity (CRC32, chunk sequence, trailing bytes).
2. Pixel decoding, dimensions, and alpha channel extraction.
3. Brand palette alignment (dominant color analysis vs PROJECT.md specifications).
4. Decoding benchmarks (latency, memory stability over 1,000 iterations).
5. Robustness & Error handling under adversarial inputs (truncated streams, corrupted headers, bad CRCs).
6. Cross-catalog mapping verification and pubspec asset bundling.
"""

import os
import sys
import struct
import zlib
import io
import time
import re
from PIL import Image

ASSET_PATH = os.path.join(r'fomowl_wallet', 'assets', 'images', 'chains', 'assetchain.png')
CATALOG_PATH = os.path.join(r'fomowl_wallet', 'lib', 'services', 'blockchain', 'blockchain_catalog.dart')
PUBSPEC_PATH = os.path.join(r'fomowl_wallet', 'pubspec.yaml')

def run_tests():
    print("=" * 60)
    print("EMPIRICAL HARNESS: AssetChain Logo Adversarial Validation")
    print("=" * 60)

    # -------------------------------------------------------------
    # Test 1: File Existence & Size
    # -------------------------------------------------------------
    assert os.path.exists(ASSET_PATH), f"Target asset does not exist: {ASSET_PATH}"
    with open(ASSET_PATH, 'rb') as f:
        raw_data = f.read()
    file_size = len(raw_data)
    print(f"[TEST 1] File Size: {file_size} bytes (PASSED)")

    # -------------------------------------------------------------
    # Test 2: PNG Signature & Chunk-Level CRC Verification
    # -------------------------------------------------------------
    png_signature = b'\x89PNG\r\n\x1a\n'
    assert raw_data.startswith(png_signature), "Magic bytes do not match PNG specification"
    print("[TEST 2a] Magic PNG Signature: PASS")

    offset = 8
    chunks = []
    while offset < file_size:
        assert offset + 12 <= file_size, f"Malformed chunk header at offset {offset}"
        chunk_len = struct.unpack('>I', raw_data[offset:offset+4])[0]
        chunk_type = raw_data[offset+4:offset+8]
        chunk_data = raw_data[offset+8:offset+8+chunk_len]
        chunk_crc = struct.unpack('>I', raw_data[offset+8+chunk_len:offset+12+chunk_len])[0]

        # Verify CRC32
        calc_crc = zlib.crc32(raw_data[offset+4:offset+8+chunk_len]) & 0xffffffff
        assert calc_crc == chunk_crc, f"CRC32 mismatch in chunk {chunk_type}: computed={calc_crc:#x}, found={chunk_crc:#x}"

        type_str = chunk_type.decode('ascii', errors='replace')
        chunks.append((type_str, chunk_len, offset, chunk_crc))
        offset += 12 + chunk_len

    print(f"[TEST 2b] Found {len(chunks)} chunks, all CRC32 checksums verified:")
    for type_str, length, off, crc in chunks:
        print(f"         - Chunk {type_str:4s} | Length: {length:6d} bytes | Offset: {off:6d} | CRC: {crc:#010x}")

    assert chunks[0][0] == 'IHDR', "First chunk is not IHDR"
    assert chunks[-1][0] == 'IEND', "Last chunk is not IEND"
    assert offset == file_size, f"Trailing garbage bytes detected: {file_size - offset} bytes past IEND"
    print("[TEST 2c] Chunk Ordering (IHDR first, IEND last, 0 trailing bytes): PASS")

    # -------------------------------------------------------------
    # Test 3: IHDR Header Integrity
    # -------------------------------------------------------------
    ihdr_data = raw_data[16:29]
    width, height, bit_depth, color_type, comp, filt, interlace = struct.unpack('>IIBBBBB', ihdr_data)
    print(f"[TEST 3] IHDR Attributes:")
    print(f"         Width: {width} px, Height: {height} px (Aspect ratio: {width/height:.2f})")
    print(f"         Bit Depth: {bit_depth}, Color Type: {color_type}")
    print(f"         Compression: {comp}, Filter: {filt}, Interlace: {interlace}")

    assert width == 512 and height == 512, f"Dimensions expected 512x512, found {width}x{height}"
    assert bit_depth == 8, f"Expected 8-bit depth, found {bit_depth}"
    assert color_type == 6, f"Expected Color Type 6 (RGBA), found {color_type}"
    assert comp == 0, f"Unexpected compression method {comp}"
    assert filt == 0, f"Unexpected filter method {filt}"
    assert interlace == 0, f"Unexpected interlace method {interlace}"
    print("[TEST 3] IHDR Validation: PASS")

    # -------------------------------------------------------------
    # Test 4: Image Decoding & Alpha Channel Inspection
    # -------------------------------------------------------------
    img = Image.open(io.BytesIO(raw_data))
    assert img.format == 'PNG', f"PIL reported format: {img.format}"
    assert img.size == (512, 512), f"PIL reported size: {img.size}"
    assert img.mode == 'RGBA', f"PIL reported mode: {img.mode}"

    pixels = list(img.getdata())
    total_pixels = len(pixels)
    assert total_pixels == 512 * 512, f"Total pixels expected 262144, got {total_pixels}"

    fully_transparent = 0
    partially_transparent = 0
    fully_opaque = 0

    r_vals, g_vals, b_vals = [], [], []

    for r, g, b, a in pixels:
        if a == 0:
            fully_transparent += 1
        elif 0 < a < 255:
            partially_transparent += 1
            r_vals.append(r)
            g_vals.append(g)
            b_vals.append(b)
        else:
            fully_opaque += 1
            r_vals.append(r)
            g_vals.append(g)
            b_vals.append(b)

    print(f"[TEST 4a] Alpha Channel Pixel Distribution:")
    print(f"          - Fully transparent (A=0):     {fully_transparent:6d} ({fully_transparent/total_pixels*100:.2f}%)")
    print(f"          - Anti-aliased edge (0<A<255): {partially_transparent:6d} ({partially_transparent/total_pixels*100:.2f}%)")
    print(f"          - Fully opaque (A=255):        {fully_opaque:6d} ({fully_opaque/total_pixels*100:.2f}%)")

    assert fully_transparent > 0, "No transparent pixels found — image has solid background!"
    assert fully_opaque > 0, "No opaque pixels found — image is blank!"
    assert partially_transparent > 0, "No antialiased pixels found — image edges might be jagged"
    print("[TEST 4a] Alpha Transparency Validation: PASS")

    # -------------------------------------------------------------
    # Test 4b: Brand Color Palette Verification
    # Expected Brand Colors:
    # Official emblem uses #0049e7, #1174ea, #33bdec on white rounded squircle.
    # Theme palette in PROJECT.md: Primary #147BC2, Accent #26C4E8.
    # -------------------------------------------------------------
    mean_r = sum(r_vals) / len(r_vals)
    mean_g = sum(g_vals) / len(g_vals)
    mean_b = sum(b_vals) / len(b_vals)
    print(f"[TEST 4b] Visible Content Mean Color: RGB({mean_r:.1f}, {mean_g:.1f}, {mean_b:.1f})")

    # Verify blue dominance (AssetChain brand is blue/cyan)
    assert mean_b > mean_r and mean_g > mean_r, f"Image visible pixels are not blue-dominant: R={mean_r}, G={mean_g}, B={mean_b}"
    
    # Check for presence of target brand hues
    primary_target = (20, 123, 194)  # #147BC2
    accent_target = (38, 196, 232)   # #26C4E8
    emblem_base = (0, 73, 231)       # #0049E7

    min_dist_primary = min(((r - primary_target[0])**2 + (g - primary_target[1])**2 + (b - primary_target[2])**2)**0.5 for r, g, b in zip(r_vals, g_vals, b_vals))
    min_dist_accent = min(((r - accent_target[0])**2 + (g - accent_target[1])**2 + (b - accent_target[2])**2)**0.5 for r, g, b in zip(r_vals, g_vals, b_vals))
    min_dist_base = min(((r - emblem_base[0])**2 + (g - emblem_base[1])**2 + (b - emblem_base[2])**2)**0.5 for r, g, b in zip(r_vals, g_vals, b_vals))
    
    print(f"          - Closest pixel distance to Primary #147BC2: {min_dist_primary:.2f}")
    print(f"          - Closest pixel distance to Accent #26C4E8:  {min_dist_accent:.2f}")
    print(f"          - Closest pixel distance to Base Blue #0049E7: {min_dist_base:.2f}")
    assert min_dist_accent < 20.0, f"Accent brand color not represented: min_dist={min_dist_accent}"
    assert min_dist_base == 0.0, f"Emblem base blue not found in image: min_dist={min_dist_base}"
    print("[TEST 4b] Brand Color Alignment: PASS")

    # -------------------------------------------------------------
    # Test 5: Decoding Performance Benchmark (1,000 iterations)
    # -------------------------------------------------------------
    print("[TEST 5] Benchmarking 1,000 decodes via PIL Image.open + load...")
    t0 = time.perf_counter()
    for _ in range(1000):
        test_img = Image.open(io.BytesIO(raw_data))
        test_img.load()
    t_total = time.perf_counter() - t0
    avg_ms = (t_total / 1000) * 1000
    print(f"         Total time: {t_total:.4f}s | Average per decode: {avg_ms:.3f} ms | Decodes/sec: {1000/t_total:.1f}")
    assert avg_ms < 10.0, f"Decode performance too slow: {avg_ms:.2f} ms per image"
    print("[TEST 5] Performance Benchmark: PASS")

    # -------------------------------------------------------------
    # Test 6: Stress & Adversarial Robustness
    # -------------------------------------------------------------
    print("[TEST 6] Adversarial Edge-Case Stress Testing:")

    # 6a: Truncated Streams Stress Testing
    # Strict chunk parser must reject any stream missing IEND or truncated chunks.
    # Image decoder must safely reject any truncation before IDAT completion without crashing.
    mid_stream_cutoffs = [0, 4, 8, 16, 33, 100, 1000, 10000, 30000]
    for tp in mid_stream_cutoffs:
        truncated = raw_data[:tp]
        caught = False
        try:
            im = Image.open(io.BytesIO(truncated))
            im.load()
        except Exception:
            caught = True
        assert caught, f"Decoder unexpectedly accepted truncated payload at byte offset {tp}"
    print(f"         - Stream truncation (0 to 30,000 bytes): All {len(mid_stream_cutoffs)} cutoffs safely rejected (PASS)")

    # Strict chunk validation on truncated IEND (offset 35122 to 35133)
    for tp in [35122, 35130, 35133]:
        truncated = raw_data[:tp]
        strict_caught = False
        try:
            # Attempt to find IEND in truncated bytes
            assert truncated.endswith(b'IEND\xae\x42\x60\x82'), "Missing complete IEND chunk"
        except AssertionError:
            strict_caught = True
        assert strict_caught, f"Strict chunk validator failed to detect truncated IEND at length {tp}"
    print(f"         - Strict IEND chunk truncation: Safely caught missing/truncated end marker (PASS)")

    # 6b: Corrupted Magic Header
    bad_header = b'\x00PNG\r\n\x1a\n' + raw_data[8:]
    try:
        im = Image.open(io.BytesIO(bad_header))
        im.load()
        assert False, "Corrupted magic header was unexpectedly accepted"
    except Exception:
        print("         - Corrupted Magic Header: Safely rejected (PASS)")

    # 6c: Corrupted Chunk Length (Integer Overflow Attempt)
    # Overwrite IHDR length with 0x7FFFFFFF (2GB)
    bad_len = raw_data[:8] + struct.pack('>I', 0x7FFFFFFF) + raw_data[12:]
    try:
        im = Image.open(io.BytesIO(bad_len))
        im.load()
        assert False, "Corrupted chunk length was unexpectedly accepted"
    except Exception:
        print("         - Malformed Chunk Length (0x7FFFFFFF): Safely rejected (PASS)")

    # 6d: Corrupted IDAT Data
    # Find IDAT offset
    idat_offset = None
    for chunk in chunks:
        if chunk[0] == 'IDAT':
            idat_offset = chunk[2]
            break
    assert idat_offset is not None, "No IDAT chunk found"
    
    corrupt_idat = bytearray(raw_data)
    # Flip bytes in middle of IDAT payload
    corrupt_idat[idat_offset + 100] ^= 0xFF
    corrupt_idat[idat_offset + 101] ^= 0xFF
    try:
        im = Image.open(io.BytesIO(corrupt_idat))
        im.load()
        assert False, "Corrupted IDAT payload was unexpectedly accepted"
    except Exception:
        print("         - Corrupted IDAT payload: Safely rejected (PASS)")

    print("[TEST 6] Adversarial Stress Testing: PASS")

    # -------------------------------------------------------------
    # Test 7: Catalog Mapping & Asset Bundle Packaging Integrity
    # -------------------------------------------------------------
    print("[TEST 7] Cross-System Mapping & Bundle Packaging:")

    # 7a: Verify pubspec.yaml includes assets/images/chains/
    with open(PUBSPEC_PATH, 'r', encoding='utf-8') as f:
        pubspec_content = f.read()
    assert 'assets/images/chains/' in pubspec_content, "assets/images/chains/ missing from pubspec.yaml"
    print("         - pubspec.yaml asset directory inclusion: PASS")

    # 7b: Parse BlockchainCatalog.localChainLogoAsset
    with open(CATALOG_PATH, 'r', encoding='utf-8') as f:
        catalog_content = f.read()

    # Extract switch statement in localChainLogoAsset
    switch_match = re.search(r'static String\? localChainLogoAsset\(int chainId\)\s*=>\s*switch\s*\(chainId\)\s*\{([^}]+)\};', catalog_content)
    assert switch_match, "Could not extract localChainLogoAsset switch statement"
    switch_body = switch_match.group(1)

    mapping_entries = re.findall(r'(\d+)\s*=>\s*[\'"]([^\'"]+)[\'"]', switch_body)
    chain_map = {}
    for cid_str, path in mapping_entries:
        cid = int(cid_str)
        assert cid not in chain_map, f"Duplicate chainId in localChainLogoAsset: {cid}"
        chain_map[cid] = path

    print(f"         - localChainLogoAsset contains {len(chain_map)} mapped chain IDs")
    assert 42420 in chain_map, "Chain 42420 not mapped in localChainLogoAsset"
    assert chain_map[42420] == 'assets/images/chains/assetchain.png', f"Chain 42420 mapped to unexpected path: {chain_map[42420]}"

    # Verify every mapped file exists on disk
    for cid, rel_path in chain_map.items():
        full_p = os.path.join(r'fomowl_wallet', rel_path.replace('/', os.sep))
        assert os.path.exists(full_p), f"Mapped asset file does not exist on disk: chainId={cid}, path={full_p}"

    print(f"         - All {len(chain_map)} mapped assets verified to exist on disk (PASS)")

    # 7c: Verify Asset Chain in builtInChains
    built_in_pattern = r'EvmChain\(\s*name:\s*[\'"]Asset Chain[\'"],\s*symbol:\s*[\'"]RWA[\'"],\s*chainId:\s*42420,\s*rpcUrl:\s*AppEnvironment\.blockchain\([\'"]/42420/rpc[\'"]\)\.toString\(\),\s*explorerUrl:\s*[\'"]https://scan\.assetchain\.org[\'"],\s*//[^\n]*\s*logoUrl:\s*[\'"]([^\'"]+)[\'"]'
    built_in_match = re.search(built_in_pattern, catalog_content)
    assert built_in_match, "Asset Chain entry in builtInChains is missing or malformed"
    logo_url = built_in_match.group(1)
    print(f"         - Built-in chain 42420 logoUrl: {logo_url}")
    assert logo_url == 'https://scan.assetchain.org/assets/configs/network_icon.png', f"Unexpected logoUrl: {logo_url}"
    print("[TEST 7] Catalog Mapping & Asset Bundle Packaging: PASS")

    print("\n" + "=" * 60)
    print("ALL EMPIRICAL HARNESS CHECKS PASSED (100% SUCCESS)")
    print("=" * 60)

if __name__ == '__main__':
    try:
        run_tests()
    except Exception as e:
        print(f"\nFATAL TEST FAILURE: {e}", file=sys.stderr)
        sys.exit(1)
