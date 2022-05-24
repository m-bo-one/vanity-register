import { deployments, ethers, getChainId } from "hardhat";
import { Wallet } from "ethers";
import { expect } from "chai";

import { Registrar } from "../typechain";

const setupTest = deployments.createFixture(
  async ({ deployments, getNamedAccounts, ethers }) => {
    await deployments.fixture(["Registrar"]);
    const { deployer } = await getNamedAccounts();
    const registrar: Registrar = await ethers.getContract(
      "Registrar",
      deployer
    );
    const chainId = +(await getChainId());
    return {
      registrar,
      chainId,
    };
  }
);

const testTimestamp = Math.floor(Date.now() / 1000) + 3600;

describe("Registrar", () => {
  it("should add controller", async () => {
    const { registrar } = await setupTest();
    const [controller] = await ethers.getSigners();

    expect(await registrar.controllers(controller.address)).to.be.eq(false);

    const tx = registrar.addController(controller.address);
    await expect(tx)
      .to.emit(registrar, "ControllerAdded")
      .withArgs(controller.address);

    expect(await registrar.controllers(controller.address)).to.be.eq(true);
  });

  it("should remove controller", async () => {
    const { registrar } = await setupTest();
    const [controller] = await ethers.getSigners();

    await registrar.addController(controller.address);
    expect(await registrar.controllers(controller.address)).to.be.eq(true);

    const tx = registrar.removeController(controller.address);
    await expect(tx)
      .to.emit(registrar, "ControllerRemoved")
      .withArgs(controller.address);

    expect(await registrar.controllers(controller.address)).to.be.eq(false);
  });

  it("should register a new token", async () => {
    const { registrar } = await setupTest();
    const [controller, assetOwner] = await ethers.getSigners();

    await registrar.addController(controller.address);

    expect(await registrar.balanceOf(assetOwner.address)).to.be.eq(0);
    await expect(registrar.ownerOf(1)).to.be.revertedWith(
      "ERC721: owner query for nonexistent token"
    );
    expect(await registrar.available(1)).to.be.eq(true);
    expect(await registrar.expiries(1)).to.be.eq(0);

    await ethers.provider.send("evm_setNextBlockTimestamp", [testTimestamp]);

    const tx = registrar
      .connect(controller)
      .register(1, assetOwner.address, 300);
    await expect(tx)
      .to.emit(registrar, "Registered")
      .withArgs(1, assetOwner.address, testTimestamp + 300);

    expect(await registrar.balanceOf(assetOwner.address)).to.be.eq(1);
    expect(await registrar.ownerOf(1)).to.be.eq(assetOwner.address);
    expect(await registrar.available(1)).to.be.eq(false);
    expect(await registrar.expiries(1)).to.be.eq(testTimestamp + 300);
  });

  it("should renew a new token", async () => {
    const { registrar } = await setupTest();
    const [controller, assetOwner] = await ethers.getSigners();

    await registrar.addController(controller.address);

    await ethers.provider.send("evm_setNextBlockTimestamp", [testTimestamp]);
    await registrar.connect(controller).register(1, assetOwner.address, 300);
    const expires = await registrar.expiries(1);

    const tx = registrar.connect(controller).renew(1, 100);
    await expect(tx)
      .to.emit(registrar, "Renewed")
      .withArgs(1, expires.toNumber() + 100);

    expect(await registrar.balanceOf(assetOwner.address)).to.be.eq(1);
    expect(await registrar.ownerOf(1)).to.be.eq(assetOwner.address);
    expect(await registrar.available(1)).to.be.eq(false);
    expect(await registrar.expiries(1)).to.be.eq(expires.toNumber() + 100);
  });
});
