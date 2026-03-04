import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import {
    CompanyAccount,
    OnTradeExchange,
    SegregatedTreasury,
} from "../../typechain";

import { BigNumber } from "ethers";
import { USD } from "../common/constants.factory";

import { OnTradeProtocolFactory } from "./factories/on-trade-protocol.factory";
import { mintAndOnTradeAtTime } from "./helpers/helpers";
import { CompanyAccountFactory } from "../company_account/factories/company-accounts.factory";
import { AuthRegistryFactory } from "../auth_registry/factories/auth-registry.factory";

describe("OnTradeExchange - Configuration & audit-related Tests", function () {
    let superAdmin: SignerWithAddress;
    let governor: SignerWithAddress;
    let manager: SignerWithAddress;
    let authorizer: SignerWithAddress;
    let owner: SignerWithAddress;
    let relay: SignerWithAddress;

    let protocol: any;

    let signer1: SignerWithAddress;
    let receiver1: SignerWithAddress;
    let signer2: SignerWithAddress;
    let receiver2: SignerWithAddress;

    let onTradeExchange: OnTradeExchange;
    let segregatedTreasury: SegregatedTreasury;

    let companyAccount1: CompanyAccount;
    let feeCompanyAccount: CompanyAccount;

    let timestampPrior: number;

    beforeEach(async function () {
        [
            superAdmin,
            governor,
            manager,
            authorizer,
            owner,
            relay,
            signer1,
            receiver1,
            signer2,
            receiver2,
        ] = await ethers.getSigners();

        protocol = await OnTradeProtocolFactory.create(
            superAdmin,
            governor,
            manager,
            authorizer,
            relay.address,
            false
        );

        await OnTradeProtocolFactory.addIUSD(protocol, false);
        await OnTradeProtocolFactory.addUSDC(protocol, relay, false);

        await OnTradeProtocolFactory.createOnRamp(
            protocol,
            owner.address,
            protocol.IUSD.address,
            protocol.USDC.address,
            [],
            ethers.constants.AddressZero
        );

        onTradeExchange = protocol.onTradeExchanges[0];
        segregatedTreasury = protocol.segregatedTreasuries[0];

        companyAccount1 = await CompanyAccountFactory.create(
            superAdmin,
            protocol.governance.address,
            protocol.authRegistry.address,
            signer1.address
        );

        await CompanyAccountFactory.setup(
            companyAccount1,
            protocol.governor,
            protocol.authorizer,
            signer1,
            [protocol.IUSD.address],
            [receiver1.address],
            [[onTradeExchange.address]]
        );

        feeCompanyAccount = await CompanyAccountFactory.create(
            superAdmin,
            protocol.governance.address,
            protocol.authRegistry.address,
            signer2.address
        );

        await onTradeExchange
            .connect(authorizer)
            .addCompanyAccount(companyAccount1.address);
        await onTradeExchange
            .connect(governor)
            .setFeeCompanyAccount(feeCompanyAccount.address);

        const blockNumBefore = await ethers.provider.getBlockNumber();
        const blockBefore = await ethers.provider.getBlock(blockNumBefore);
        timestampPrior = blockBefore.timestamp;
    });

    describe("setMinTradeAmount", function () {
        context("success", function () {
            it("should update minTradeAmount correctly", async function () {
                const minAmount = BigNumber.from(100).mul(USD);
                await onTradeExchange.connect(governor).setMinTradeAmount(minAmount);
                expect(await onTradeExchange.minTradeAmount()).to.equal(minAmount);
            });

            it("should update minTradeAmount to a new value", async function () {
                const minAmount = BigNumber.from(100).mul(USD);
                await onTradeExchange.connect(governor).setMinTradeAmount(minAmount);

                const newMinAmount = BigNumber.from(200).mul(USD);
                await onTradeExchange
                    .connect(governor)
                    .setMinTradeAmount(newMinAmount);
                expect(await onTradeExchange.minTradeAmount()).to.equal(
                    newMinAmount
                );
            });

            it("should emit MinTradeAmountSet event", async function () {
                const minAmount = BigNumber.from(100).mul(USD);
                await expect(
                    onTradeExchange.connect(governor).setMinTradeAmount(minAmount)
                )
                    .to.emit(onTradeExchange, "MinTradeAmountSet")
                    .withArgs(0, minAmount);
            });

            it("should emit MinTradeAmountSet event with previous value", async function () {
                const minAmount = BigNumber.from(100).mul(USD);
                await onTradeExchange.connect(governor).setMinTradeAmount(minAmount);

                const newMinAmount = BigNumber.from(200).mul(USD);
                await expect(
                    onTradeExchange.connect(governor).setMinTradeAmount(newMinAmount)
                )
                    .to.emit(onTradeExchange, "MinTradeAmountSet")
                    .withArgs(minAmount, newMinAmount);
            });

            it("should allow setting minTradeAmount to 0", async function () {
                await onTradeExchange.connect(governor).setMinTradeAmount(0);
                expect(await onTradeExchange.minTradeAmount()).to.equal(0);
            });
        });

        context("failures", function () {
            it("should revert if called by non-governor", async function () {
                await expect(
                    onTradeExchange
                        .connect(manager)
                        .setMinTradeAmount(BigNumber.from(100).mul(USD))
                ).to.be.revertedWith("Unauthorized()");
            });

            it("should revert if called by authorizer", async function () {
                await expect(
                    onTradeExchange
                        .connect(authorizer)
                        .setMinTradeAmount(BigNumber.from(100).mul(USD))
                ).to.be.revertedWith("Unauthorized()");
            });
        });
    });
    describe("onTrade with minimum amount enforcement", function () {
        context("success", function () {
            it("should allow trade when minTradeAmount is 0", async function () {
                expect(await onTradeExchange.minTradeAmount()).to.equal(0);

                await mintAndOnTradeAtTime(
                    signer1,
                    companyAccount1,
                    BigNumber.from(100).mul(USD),
                    BigNumber.from(0),
                    1,
                    protocol.IUSD,
                    onTradeExchange,
                    relay,
                    timestampPrior + 86400
                );
            });

            it("should allow trade at exactly minimum amount", async function () {
                const minAmount = BigNumber.from(100).mul(USD);
                await onTradeExchange.connect(governor).setMinTradeAmount(minAmount);

                await mintAndOnTradeAtTime(
                    signer1,
                    companyAccount1,
                    minAmount,
                    BigNumber.from(0),
                    1,
                    protocol.IUSD,
                    onTradeExchange,
                    relay,
                    timestampPrior + 86400
                );
            });

            it("should allow trade above minimum amount", async function () {
                const minAmount = BigNumber.from(50).mul(USD);
                await onTradeExchange.connect(governor).setMinTradeAmount(minAmount);

                await mintAndOnTradeAtTime(
                    signer1,
                    companyAccount1,
                    BigNumber.from(100).mul(USD),
                    BigNumber.from(0),
                    1,
                    protocol.IUSD,
                    onTradeExchange,
                    relay,
                    timestampPrior + 86400
                );
            });
        });

        context("failures", function () {
            it("should revert if trade below minimum", async function () {
                const minAmount = BigNumber.from(100).mul(USD);
                await onTradeExchange.connect(governor).setMinTradeAmount(minAmount);

                await expect(
                    mintAndOnTradeAtTime(
                        signer1,
                        companyAccount1,
                        BigNumber.from(50).mul(USD),
                        BigNumber.from(0),
                        1,
                        protocol.IUSD,
                        onTradeExchange,
                        relay,
                        timestampPrior + 86400
                    )
                ).to.be.revertedWith("TradeBelowMinimum()");
            });

            it("should revert if trade is 1 wei below minimum", async function () {
                const minAmount = BigNumber.from(100).mul(USD);
                await onTradeExchange.connect(governor).setMinTradeAmount(minAmount);

                await expect(
                    mintAndOnTradeAtTime(
                        signer1,
                        companyAccount1,
                        minAmount.sub(1),
                        BigNumber.from(0),
                        1,
                        protocol.IUSD,
                        onTradeExchange,
                        relay,
                        timestampPrior + 86400
                    )
                ).to.be.revertedWith("TradeBelowMinimum()");
            });
        });
    });
    describe("OnTradeExchange Constructor Validation", function () {
        context("failures", function () {
            it("should revert if offAsset is zero address", async function () {
                await expect(
                    OnTradeProtocolFactory.createOnRamp(
                        protocol,
                        owner.address,
                        ethers.constants.AddressZero,
                        protocol.USDC.address,
                        [],
                        ethers.constants.AddressZero
                    )
                ).to.be.revertedWith("AddressEmpty()");
            });
            it("should revert if onAsset is zero address", async function () {
                await expect(
                    OnTradeProtocolFactory.createOnRamp(
                        protocol,
                        owner.address,
                        protocol.IUSD.address,
                        ethers.constants.AddressZero,
                        [],
                        ethers.constants.AddressZero
                    )
                ).to.be.revertedWith("AddressEmpty()");
            });
            it("should revert if offAsset is not a contract", async function () {
                await expect(
                    OnTradeProtocolFactory.createOnRamp(
                        protocol,
                        owner.address,
                        signer1.address,
                        protocol.USDC.address,
                        [],
                        ethers.constants.AddressZero
                    )
                ).to.be.revertedWith("NotContract()");
            });
            it("should revert if onAsset is not a contract", async function () {
                await expect(
                    OnTradeProtocolFactory.createOnRamp(
                        protocol,
                        owner.address,
                        protocol.IUSD.address,
                        signer1.address,
                        [],
                        ethers.constants.AddressZero
                    )
                ).to.be.revertedWith("NotContract()");
            });
            it("should revert if offAsset and onAsset are the same", async function () {
                await expect(
                    OnTradeProtocolFactory.createOnRamp(
                        protocol,
                        owner.address,
                        protocol.IUSD.address,
                        protocol.IUSD.address,
                        [],
                        ethers.constants.AddressZero
                    )
                ).to.be.revertedWith("AssetsIdentical()");
            });
        });
    });
    describe("setAuthRegistry", function () {
        context("success", function () {
            it("should update authRegistry correctly", async function () {
                const newAuthRegistry = await AuthRegistryFactory.create(
                    protocol.governance.address
                );
                await onTradeExchange
                    .connect(governor)
                    .setAuthRegistry(newAuthRegistry.address);
                expect(await onTradeExchange.authRegistry()).to.equal(
                    newAuthRegistry.address
                );
            });
            it("should emit AuthRegistryTransferred event", async function () {
                const newAuthRegistry = await AuthRegistryFactory.create(
                    protocol.governance.address
                );
                await expect(
                    onTradeExchange
                        .connect(governor)
                        .setAuthRegistry(newAuthRegistry.address)
                )
                    .to.emit(onTradeExchange, "AuthRegistryTransferred")
                    .withArgs(
                        protocol.authRegistry.address,
                        newAuthRegistry.address
                    );
            });
        });
        context("failures", function () {
            it("should revert if called by non-governor", async function () {
                const newAuthRegistry = await AuthRegistryFactory.create(
                    protocol.governance.address
                );
                await expect(
                    onTradeExchange
                        .connect(manager)
                        .setAuthRegistry(newAuthRegistry.address)
                ).to.be.revertedWith("Unauthorized()");
            });
            it("should revert if new authRegistry is zero address", async function () {
                await expect(
                    onTradeExchange
                        .connect(governor)
                        .setAuthRegistry(ethers.constants.AddressZero)
                ).to.be.revertedWith("AddressEmpty()");
            });

            it("should revert if new authRegistry is same as current", async function () {
                await expect(
                    onTradeExchange
                        .connect(governor)
                        .setAuthRegistry(protocol.authRegistry.address)
                ).to.be.revertedWith("AddressExists()");
            });
        });
    });
    describe("setFeeCompanyAccount", function () {
        context("success", function () {
            it("should update feeCompanyAccount correctly", async function () {
                const newFeeAccount = await CompanyAccountFactory.create(
                    superAdmin,
                    protocol.governance.address,
                    protocol.authRegistry.address,
                    signer2.address
                );
                await onTradeExchange
                    .connect(governor)
                    .setFeeCompanyAccount(newFeeAccount.address);
                expect(await onTradeExchange.feeCompanyAccount()).to.equal(
                    newFeeAccount.address
                );
            });

            it("should emit FeeCompanyAccountUpdated event", async function () {
                const newFeeAccount = await CompanyAccountFactory.create(
                    superAdmin,
                    protocol.governance.address,
                    protocol.authRegistry.address,
                    signer2.address
                );
                await expect(
                    onTradeExchange
                        .connect(governor)
                        .setFeeCompanyAccount(newFeeAccount.address)
                )
                    .to.emit(onTradeExchange, "FeeCompanyAccountUpdated")
                    .withArgs(feeCompanyAccount.address, newFeeAccount.address);
            });
        });

        context("failures", function () {
            it("should revert if called by non-governor", async function () {
                const newFeeAccount = await CompanyAccountFactory.create(
                    superAdmin,
                    protocol.governance.address,
                    protocol.authRegistry.address,
                    signer2.address
                );
                await expect(
                    onTradeExchange
                        .connect(manager)
                        .setFeeCompanyAccount(newFeeAccount.address)
                ).to.be.revertedWith("Unauthorized()");
            });

            it("should revert if new feeCompanyAccount is zero address", async function () {
                await expect(
                    onTradeExchange
                        .connect(governor)
                        .setFeeCompanyAccount(ethers.constants.AddressZero)
                ).to.be.revertedWith("InvalidAxiymFeeCompanyAccount()");
            });

            it("should revert if new feeCompanyAccount is same as current", async function () {
                await expect(
                    onTradeExchange
                        .connect(governor)
                        .setFeeCompanyAccount(feeCompanyAccount.address)
                ).to.be.revertedWith("InvalidAxiymFeeCompanyAccount()");
            });

            it("should revert on trade if feeCompanyAccount is zero address via nonZerofeeAccount", async function () {
                await OnTradeProtocolFactory.createOnRamp(
                    protocol,
                    owner.address,
                    protocol.IUSD.address,
                    protocol.USDC.address,
                    [companyAccount1.address],
                    ethers.constants.AddressZero
                );

                const freshExchange = protocol.onTradeExchanges[1];

                await expect(
                    mintAndOnTradeAtTime(
                        signer1,
                        companyAccount1,
                        BigNumber.from(100).mul(USD),
                        BigNumber.from(0),
                        1,
                        protocol.IUSD,
                        freshExchange,
                        relay,
                        timestampPrior + 86400
                    )
                ).to.be.revertedWith("AddressEmpty()");
            });
        });
    });
});
