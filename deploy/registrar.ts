import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  await deploy("Registrar", {
    from: deployer,
    skipIfAlreadyDeployed: true,
    args: [],
    log: true,
  });
};
func.tags = ["Registrar"];

export default func;
