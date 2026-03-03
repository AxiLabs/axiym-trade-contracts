import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { Governance, SatoshiTest, USDC } from "../../typechain";
import { GovernanceFactory } from "./factories/governance.factory";
import { SatoshiTestFactory } from "./factories/satoshi-test.factory";
import { USDCFactory } from "../currencies/factories/usdc.factory";

describe("SatoshiTest contract", function () {
    let governance: Governance;
    let satoshiTest: SatoshiTest;

    let superAdmin: SignerWithAddress;
    let governor: SignerWithAddress;
    let manager: SignerWithAddress;
    let authorizer: SignerWithAddress;
    let other: SignerWithAddress;
    let relay: SignerWithAddress;

    let usdc: USDC;

    beforeEach(async function () {
        [superAdmin, governor, manager, authorizer, other, relay] =
            await ethers.getSigners();

        governance = await GovernanceFactory.create(
            superAdmin.address,
            governor.address,
            manager.address,
            authorizer.address
        );

        satoshiTest = await SatoshiTestFactory.create(governance.address);

        usdc = await USDCFactory.create(relay);
    });
    describe("Deployment", function () {
        it("should set correct roles", async function () {
            expect(await satoshiTest.superAdmin()).to.equal(superAdmin.address);
            expect(await satoshiTest.governor()).to.equal(governor.address);
            expect(await satoshiTest.manager()).to.equal(manager.address);
        });
    });
    describe("Receive Native", function () {
        it("should receive ETH", async function () {
            await relay.sendTransaction({
                to: satoshiTest.address,
                value: ethers.utils.parseEther("1"),
            });

            expect(await ethers.provider.getBalance(satoshiTest.address)).to.equal(
                ethers.utils.parseEther("1")
            );
        });
    });
    describe("Withdraw Native", function () {
        it("manager can withdraw", async function () {
            await relay.sendTransaction({
                to: satoshiTest.address,
                value: ethers.utils.parseEther("1"),
            });
            await satoshiTest.connect(manager).withdrawAll();
            expect(await ethers.provider.getBalance(satoshiTest.address)).to.equal(
                0
            );
        });
        it("random address cannot withdraw", async function () {
            await relay.sendTransaction({
                to: satoshiTest.address,
                value: ethers.utils.parseEther("1"),
            });

            await expect(satoshiTest.connect(other).withdrawAll()).to.be.reverted;
        });
    });
    describe("ERC20 Handling (USDC as liquidity asset)", function () {
        const usdcAmount = ethers.utils.parseUnits("1000", 6); // assuming USDC is 6 decimals

        beforeEach(async function () {
            // Relay transfers USDC to SatoshiTest
            await usdc.connect(relay).transfer(satoshiTest.address, usdcAmount);
        });
        it("should receive USDC", async function () {
            expect(await usdc.balanceOf(satoshiTest.address)).to.equal(usdcAmount);

            expect(await satoshiTest.getERC20Balance(usdc.address)).to.equal(
                usdcAmount
            );
        });
        it("manager can withdraw full ERC20 balance", async function () {
            const superAdminBalanceBefore = await usdc.balanceOf(superAdmin.address);

            await satoshiTest.connect(manager).withdrawERC20(usdc.address);

            expect(await usdc.balanceOf(satoshiTest.address)).to.equal(0);

            expect(await usdc.balanceOf(superAdmin.address)).to.equal(
                superAdminBalanceBefore.add(usdcAmount)
            );
        });
        it("manager can withdraw partial ERC20 amount", async function () {
            const partial = ethers.utils.parseUnits("400", 6);

            const superAdminBalanceBefore = await usdc.balanceOf(superAdmin.address);

            await satoshiTest
                .connect(manager)
                .withdrawERC20Amount(usdc.address, partial);

            expect(await usdc.balanceOf(satoshiTest.address)).to.equal(
                usdcAmount.sub(partial)
            );

            expect(await usdc.balanceOf(superAdmin.address)).to.equal(
                superAdminBalanceBefore.add(partial)
            );
        });
        it("random address cannot withdraw ERC20", async function () {
            await expect(satoshiTest.connect(other).withdrawERC20(usdc.address)).to
                .be.reverted;
        });
        it("should revert if no ERC20 balance", async function () {
            // First withdraw everything
            await satoshiTest.connect(manager).withdrawERC20(usdc.address);

            await expect(
                satoshiTest.connect(manager).withdrawERC20(usdc.address)
            ).to.be.revertedWith("No token balance");
        });
        it("should revert on zero token address", async function () {
            await expect(
                satoshiTest
                    .connect(manager)
                    .withdrawERC20(ethers.constants.AddressZero)
            ).to.be.revertedWith("Invalid token");
        });
    });
});
