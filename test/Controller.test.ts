import { deployments, ethers, getChainId } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import { expect } from "chai";

import { Registrar, Controller } from "../typechain";

const setupTest = deployments.createFixture(
  async ({ deployments, getNamedAccounts, ethers }) => {
    await deployments.fixture(["Controller", "Registrar"]);
    const { deployer } = await getNamedAccounts();
    const registrar: Registrar = await ethers.getContract(
      "Registrar",
      deployer
    );
    const controller: Controller = await ethers.getContract(
      "Controller",
      deployer
    );
    await registrar.addController(controller.address).then((tx) => tx.wait());
    const chainId = +(await getChainId());
    return {
      registrar,
      controller,
      chainId,
    };
  }
);

const getNameKey = (name: string) => {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
};

const getTokenId = (name: string) => {
  return BigNumber.from(getNameKey(name));
};

const createSecret = (secret: string) => {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(secret));
};

const createCommitment = (name: string, owner: string, secret: string) => {
  return ethers.utils.solidityKeccak256(
    ["bytes32", "address", "bytes32"],
    [getNameKey(name), owner, createSecret(secret)]
  );
};

const testTimestamp = Math.floor(Date.now() / 1000) + 3600;

describe("Controller", () => {
  it("should get fee price with OK length", async () => {
    const { controller } = await setupTest();

    const str1 = "test";
    const ethPerLen = await controller.callStatic.ethPerLen();
    expect(await controller.getFeePrice(str1)).to.be.eq(
      ethPerLen.mul(str1.length)
    );

    const str2 = "testzv34ra@#§'`акуміііа";
    expect(await controller.getFeePrice(str2)).to.be.eq(
      ethPerLen.mul(str2.length)
    );
  });

  it("should not get fee price with NOT OK length", async () => {
    const { controller } = await setupTest();

    const str1 = "te";
    await expect(controller.getFeePrice(str1)).to.be.revertedWith(
      "VC: Length too short"
    );
  });

  it("should commit and get stored", async () => {
    const { controller } = await setupTest();
    const [, commitor] = await ethers.getSigners();

    const commitment = createCommitment("test", commitor.address, "megasecret");

    await expect(controller.connect(commitor).commit(commitment))
      .to.emit(controller, "Committed")
      .withArgs(commitment);

    // second will be failed as only first accepted
    await expect(
      controller.connect(commitor).commit(commitment)
    ).to.be.revertedWith("VC: Already reserved");
  });

  it("should register with known commitment and get stored", async () => {
    const { controller, registrar } = await setupTest();
    const [, commitor] = await ethers.getSigners();

    const name = "test";
    const secret = "megasecret";
    const commitment = createCommitment(name, commitor.address, secret);
    const tokenId = getTokenId(name);
    const value = ethers.utils.parseEther("1");
    const durationTime = await controller.durationTime();

    await ethers.provider.send("evm_setNextBlockTimestamp", [testTimestamp]);

    await expect(controller.connect(commitor).commit(commitment));

    await expect(
      controller
        .connect(commitor)
        .register(name, commitor.address, createSecret(secret), { value })
    ).to.be.emit(controller, "Registered");

    const block = await ethers.provider.getBlock("latest");
    expect(await registrar.balanceOf(commitor.address)).to.be.eq(1);
    expect(await registrar.ownerOf(tokenId)).to.be.eq(commitor.address);
    expect(await registrar.expiries(tokenId)).to.be.eq(
      block.timestamp + durationTime.toNumber()
    );
  });

  it("should not double register with known commitment and get stored", async () => {
    const { controller } = await setupTest();
    const [, commitor] = await ethers.getSigners();

    const name = "test";
    const secret = "megasecret";
    const commitment = createCommitment(name, commitor.address, secret);
    const value = ethers.utils.parseEther("1");

    await expect(controller.connect(commitor).commit(commitment));

    await expect(
      controller
        .connect(commitor)
        .register(name, commitor.address, createSecret(secret), { value })
    ).to.be.emit(controller, "Registered");

    // will be expired as duration set
    await expect(
      controller
        .connect(commitor)
        .register(name, commitor.address, createSecret(secret), { value })
    ).to.be.revertedWith("VC: Commit expired");

    // could be commited again
    await expect(controller.connect(commitor).commit(commitment));

    // but u will be failed as it already occupied for our period
    await expect(
      controller
        .connect(commitor)
        .register(name, commitor.address, createSecret(secret), { value })
    ).to.be.revertedWith("VC: Not available");
  });

  it("should not register with small length for name", async () => {
    const { controller } = await setupTest();
    const [, commitor] = await ethers.getSigners();

    const name = "te";
    const secret = "megasecret";
    const commitment = createCommitment(name, commitor.address, secret);
    const value = ethers.utils.parseEther("1");

    await expect(controller.connect(commitor).commit(commitment));

    // small length, aborted
    await expect(
      controller
        .connect(commitor)
        .register(name, commitor.address, createSecret(secret), { value })
    ).to.be.revertedWith("VC: Length too short");
  });

  it("should not register with small length for name", async () => {
    const { controller } = await setupTest();
    const [, commitor] = await ethers.getSigners();

    const name = "te";
    const secret = "megasecret";
    const commitment = createCommitment(name, commitor.address, secret);
    const value = ethers.utils.parseEther("1");

    await expect(controller.connect(commitor).commit(commitment));

    // small length, aborted
    await expect(
      controller
        .connect(commitor)
        .register(name, commitor.address, createSecret(secret), { value })
    ).to.be.revertedWith("VC: Length too short");
  });

  it("should not register with small amount for name price", async () => {
    const { controller } = await setupTest();
    const [, commitor] = await ethers.getSigners();

    const name = "test";
    const secret = "megasecret";
    const commitment = createCommitment(name, commitor.address, secret);
    const value = ethers.utils.parseEther("0.000001");

    await expect(controller.connect(commitor).commit(commitment));

    // small amount, aborted
    await expect(
      controller
        .connect(commitor)
        .register(name, commitor.address, createSecret(secret), { value })
    ).to.be.revertedWith("VC: Not enough amount");
  });

  it("should renew with known commitment and get stored", async () => {
    const { controller, registrar } = await setupTest();
    const [, commitor, renewer] = await ethers.getSigners();

    const name = "test";
    const secret = "megasecret";
    const commitment = createCommitment(name, commitor.address, secret);
    const tokenId = getTokenId(name);
    const value = ethers.utils.parseEther("1");
    const durationTime = await controller.durationTime();

    await ethers.provider.send("evm_setNextBlockTimestamp", [testTimestamp]);

    await expect(controller.connect(commitor).commit(commitment));
    await expect(
      controller
        .connect(commitor)
        .register(name, commitor.address, createSecret(secret), { value })
    );
    // should be mined to commit
    await ethers.provider.send("evm_mine", []);

    const block = await ethers.provider.getBlock("latest");

    await expect(controller.connect(renewer).renew(name, { value })).to.be.emit(
      controller,
      "Renewed"
    );
    expect(await registrar.balanceOf(commitor.address)).to.be.eq(1);
    expect(await registrar.ownerOf(tokenId)).to.be.eq(commitor.address);
    expect(await registrar.expiries(tokenId)).to.be.eq(
      block.timestamp + durationTime.toNumber() * 2
    );
  });
});
