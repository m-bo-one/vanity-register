import { ethers } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Registrar } from "../typechain";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();
  const signer = await hre.ethers.getSigner(deployer);

  const registrar: Registrar | null = await hre.ethers.getContractOrNull(
    "Registrar",
    signer
  );
  if (!registrar) {
    console.log(`\x1b[31mRegistrar not deployed, skipping.\x1b[0m`);
    return;
  }

  await deploy("Controller", {
    from: deployer,
    skipIfAlreadyDeployed: true,
    args: [
      registrar.address,
      process.env.COMMIT_TIME,
      process.env.DURATION_TIME,
      ethers.utils.parseEther(process.env.ETH_PER_LEN as string),
      process.env.MIN_NAME_LENGTH,
    ],
    log: true,
  });
};
func.tags = ["Controller"];
func.dependencies = ["Registrar"];

export default func;
