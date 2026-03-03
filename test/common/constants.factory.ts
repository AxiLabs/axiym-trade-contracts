import { BigNumber } from "ethers";

export const USDDecimals = 6;
export const USD = BigNumber.from(10).pow(USDDecimals);

export const USD2000 = BigNumber.from(2000).mul(USD);
export const USD1000 = BigNumber.from(1000).mul(USD);
export const USD500 = BigNumber.from(500).mul(USD);
export const USD400 = BigNumber.from(400).mul(USD);
export const USD200 = BigNumber.from(200).mul(USD);
export const USD100 = BigNumber.from(100).mul(USD);
export const USD2600 = BigNumber.from(2600).mul(USD);
export const USD2500 = BigNumber.from(2500).mul(USD);
export const USD18 = BigNumber.from(18).mul(USD);
export const USD0 = BigNumber.from(0);
export const USD50 = BigNumber.from(50).mul(USD);
export const USD10 = BigNumber.from(10).mul(USD);
export const USD1_8 = BigNumber.from(18).mul(USD).div(10);
export const USD1_4 = BigNumber.from(14).mul(USD).div(10);
export const USD3_1 = BigNumber.from(31).mul(USD).div(10);
export const USD150 = BigNumber.from(150).mul(USD);
export const MAX_UINT256 = BigNumber.from(
  "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
);
export const USD40 = BigNumber.from(40).mul(USD);
