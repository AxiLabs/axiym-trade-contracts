// npx ts-node scripts/deploy/compare-bytecode.ts [network]
// Example: npx ts-node scripts/deploy/compare-bytecode.ts tron

import * as fs from "fs";
import * as path from "path";

/* ═══════════════════════════════════════════════
   CONFIG — EDIT THESE
═══════════════════════════════════════════════ */
const CONTRACT_NAME = "OnTradeExchange";
const CONTRACT_ADDRESS = "TKw99wAyBhE51vg2kop4pxEqMr2ThKNf1B";
/* ═══════════════════════════════════════════════ */

const NETWORK = process.argv[2] || "tron_shasta";

const NETWORK_URLS: Record<string, string> = {
    tron: "https://api.trongrid.io",
    tron_mainnet: "https://api.trongrid.io",
    tron_shasta: "https://api.shasta.trongrid.io",
    tron_nile: "https://nile.trongrid.io",
};

const BASE_URL = NETWORK_URLS[NETWORK];
if (!BASE_URL) {
    console.error(`Unknown network: ${NETWORK}`);
    process.exit(1);
}

/* ─── Helpers ─────────────────────────────────── */

const clean = (hex: string) => hex.replace(/^0x/, "").toLowerCase();

const loadArtifact = (contractName: string): any => {
    const artifactsDir = path.join(process.cwd(), "artifacts/contracts");
    const findFile = (dir: string): string | null => {
        for (const entry of fs.readdirSync(dir)) {
            const fullPath = path.join(dir, entry);
            if (fs.statSync(fullPath).isDirectory()) {
                const found = findFile(fullPath);
                if (found) return found;
            } else if (
                entry === `${contractName}.json` &&
                !entry.endsWith(".dbg.json")
            ) {
                return fullPath;
            }
        }
        return null;
    };
    const match = findFile(artifactsDir);
    if (!match)
        throw new Error(
            `Artifact not found for: ${contractName}. Run 'npx hardhat compile' first.`
        );
    return JSON.parse(fs.readFileSync(match, "utf-8"));
};

// Get runtime bytecode from the transaction receipt's contractResult field.
// This is the true runtime bytecode — what's left after the constructor executed.
const TX_HASH = "d3022c95c6d05fe13f3334ac682f90072ad4d62a9f6ae82a5ab570281dd5d131";

const getCode = async (): Promise<string> => {
    const res = await fetch(`${BASE_URL}/wallet/gettransactioninfobyid`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ value: TX_HASH }),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status} fetching transaction info`);
    const data: any = await res.json();
    const contractResult = data.contractResult?.[0];
    if (!contractResult) throw new Error("No contractResult in transaction receipt");
    return clean(contractResult);
};

const stripMetadata = (hex: string): { stripped: string; metadata: string } => {
    const marker = "64736f6c6343"; // "dsolcC"
    const idx = hex.lastIndexOf(marker);
    if (idx === -1) return { stripped: hex, metadata: "" };
    return {
        stripped: hex.slice(0, idx - 4),
        metadata: hex.slice(idx - 4),
    };
};

const findDiffRegions = (a: string, b: string) => {
    const regions: { start: number; end: number; aChunk: string; bChunk: string }[] =
        [];
    const len = Math.min(a.length, b.length);
    let inDiff = false,
        diffStart = 0;
    for (let i = 0; i < len; i += 2) {
        if (a.slice(i, i + 2) !== b.slice(i, i + 2)) {
            if (!inDiff) {
                inDiff = true;
                diffStart = i;
            }
        } else if (inDiff) {
            regions.push({
                start: diffStart / 2,
                end: i / 2 - 1,
                aChunk: a.slice(diffStart, i),
                bChunk: b.slice(diffStart, i),
            });
            inDiff = false;
        }
    }
    if (inDiff)
        regions.push({
            start: diffStart / 2,
            end: len / 2 - 1,
            aChunk: a.slice(diffStart, len),
            bChunk: b.slice(diffStart, len),
        });
    return regions;
};

/* ─── Main ────────────────────────────────────── */

const main = async () => {
    const hr = "─".repeat(64);

    console.log(hr);
    console.log("Runtime Bytecode Comparison");
    console.log(hr);
    console.log(`Contract : ${CONTRACT_NAME}`);
    console.log(`Address  : ${CONTRACT_ADDRESS}`);
    console.log(`Network  : ${NETWORK}`);
    console.log(hr);

    // Load local artifact
    const artifact = loadArtifact(CONTRACT_NAME);
    const localHex = clean(artifact.deployedBytecode || "");
    console.log(`\n[LOCAL] deployedBytecode : ${localHex.length / 2} bytes`);

    // Fetch on-chain runtime bytecode (Tron equivalent of provider.getCode())
    const onChainHex = await getCode();
    console.log(`[CHAIN] deployedBytecode : ${onChainHex.length / 2} bytes`);

    if (!onChainHex) throw new Error("No contract found at this address");

    // Strip metadata
    const { stripped: localStripped, metadata: localMeta } = stripMetadata(localHex);
    const { stripped: chainStripped, metadata: chainMeta } =
        stripMetadata(onChainHex);

    console.log(`\n${hr}`);
    console.log("METADATA");
    console.log(hr);
    console.log(`Local : ${localMeta || "(none)"}`);
    console.log(`Chain : ${chainMeta || "(none)"}`);
    console.log(
        `Match : ${
            localMeta === chainMeta
                ? "✅ YES"
                : "❌ NO (compiler/version/path differences)"
        }`
    );

    // Compare
    console.log(`\n${hr}`);
    console.log("RUNTIME BYTECODE (metadata stripped)");
    console.log(hr);

    if (localStripped === chainStripped) {
        console.log("✅ MATCH — runtime bytecode is identical");
    } else {
        console.log("❌ MISMATCH");

        const lenDiff = localStripped.length - chainStripped.length;
        console.log(`Local : ${localStripped.length / 2} bytes`);
        console.log(`Chain : ${chainStripped.length / 2} bytes`);
        if (lenDiff !== 0) {
            console.log(
                `Delta : ${Math.abs(lenDiff) / 2} bytes ${
                    lenDiff > 0 ? "larger locally" : "larger on-chain"
                }`
            );
        }

        const regions = findDiffRegions(localStripped, chainStripped);
        console.log(`\nDiffering regions: ${regions.length}`);
        regions.slice(0, 10).forEach((r, i) => {
            console.log(
                `\n[${i + 1}] Bytes ${r.start}–${r.end} (${
                    r.end - r.start + 1
                } byte(s))`
            );
            console.log(`  Local : ${r.aChunk}`);
            console.log(`  Chain : ${r.bChunk}`);
        });
        if (regions.length > 10)
            console.log(`\n... and ${regions.length - 10} more`);
    }

    // Save report next to script
    const reportPath = path.join(__dirname, `${CONTRACT_NAME}-bytecode-report.json`);
    fs.writeFileSync(
        reportPath,
        JSON.stringify(
            {
                contractName: CONTRACT_NAME,
                contractAddress: CONTRACT_ADDRESS,
                network: NETWORK,
                match: localStripped === chainStripped,
                metadataMatch: localMeta === chainMeta,
                localMetadata: localMeta,
                chainMetadata: chainMeta,
                localBytes: localStripped.length / 2,
                chainBytes: chainStripped.length / 2,
                diffRegions: findDiffRegions(localStripped, chainStripped),
            },
            null,
            2
        )
    );

    console.log(`\n${hr}`);
    console.log(`Report saved → ${reportPath}`);
};

main().catch((err) => {
    console.error("❌ Error:", err.message);
    process.exit(1);
});
