import { ethers } from "hardhat";
import { BigNumber } from "ethers";

let _localTSCahe = 0;

export const getTestTimestamp = (delta: number = 3600) => {
  if (!_localTSCahe) {
    _localTSCahe = Math.floor(Date.now() / 1000) + delta;
  } else {
    _localTSCahe += 100;
  }
  return _localTSCahe;
};

export const increaseTestTimestamp = (delta: number) => {
  _localTSCahe += delta;
};

export const getNameKey = (name: string) => {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
};

export const getTokenId = (name: string) => {
  return BigNumber.from(getNameKey(name));
};

export const createSecret = (secret: string) => {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(secret));
};

export const createCommitment = (
  name: string,
  owner: string,
  secret: string
) => {
  return ethers.utils.solidityKeccak256(
    ["bytes32", "address", "bytes32"],
    [getNameKey(name), owner, createSecret(secret)]
  );
};
