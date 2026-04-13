import * as fs from "fs";
import * as path from "path";

export const loadArtifact = (contractName: string): any => {
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
    if (!match) throw new Error(`Artifact not found for: ${contractName}`);
    return JSON.parse(fs.readFileSync(match, "utf-8"));
};
