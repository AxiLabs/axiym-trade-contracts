// npx ts-node scripts/deploy/generate-bytecode.ts
import * as fs from "fs";
import * as path from "path";
import { loadArtifact } from "../helpers/helpers";

const CONTRACT_NAME = "OnTradeExchange";

const main = async () => {
    const artifact = loadArtifact(CONTRACT_NAME);

    const outputPath = path.join(__dirname, `${CONTRACT_NAME}-bytecode.json`);
    fs.writeFileSync(
        outputPath,
        JSON.stringify({ bytecode: artifact.bytecode }, null, 2)
    );

    console.log("Contract:        ", CONTRACT_NAME);
    console.log("Bytecode length: ", artifact.bytecode.length / 2 - 1, "bytes");
    console.log("Saved to:        ", outputPath);
};

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error(err);
        process.exit(1);
    });
