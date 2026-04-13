// npx ts-node scripts/deploy/generate-bytecode.ts
import * as fs from "fs";
import * as path from "path";
import { loadArtifact } from "../helpers/helpers";

const CONTRACT_NAME = "OnTradeExchange";

const main = async () => {
    const artifact = loadArtifact(CONTRACT_NAME);

    // CRITICAL FIX: Use deployedBytecode (Runtime) instead of bytecode (Creation)
    const runtimeBytecode = artifact.deployedBytecode
        .replace(/^0x/, "")
        .toLowerCase();

    const outputPath = path.join(__dirname, `${CONTRACT_NAME}-runtime.json`);
    fs.writeFileSync(outputPath, JSON.stringify({ runtimeBytecode }, null, 2));

    console.log("Contract:", CONTRACT_NAME);
    console.log("Runtime Bytecode length:", runtimeBytecode.length / 2, "bytes");
};

main();
