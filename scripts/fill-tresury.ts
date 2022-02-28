import { ethers } from "hardhat";
import { Erc20 } from "../typechain";
import { TokenAddress, RewardTreasuryAddress, StakingAddress } from '../helper/address'
import TokenJson from '../deployments/mumbai/PaycerToken.json'

async function main() {
  const tokenAddress = TokenAddress.matic;
  const stakingAdress = StakingAddress.matic;
  const rewardTresuryAdress = RewardTreasuryAddress.matic;
  const tresuryAmount = ethers.utils.parseUnits('2250000', 18);


  const tokenContract = <Erc20>await ethers.getContractAt(
      TokenJson.abi,
      tokenAddress
  );

  const tresuryBalance = await tokenContract.balanceOf(rewardTresuryAdress)

  const tresuryAmountDiff = tresuryAmount.sub(tresuryBalance)
  if (tresuryAmountDiff.gt(0)) {
      const mintTx = await tokenContract.mint(
         rewardTresuryAdress,
         tresuryAmountDiff
       )

       console.log(mintTx)

      await tokenContract.connect(rewardTresuryAdress)

      const approveTx = await tokenContract.approve(
        stakingAdress,
        tresuryAmountDiff
      )

      console.log(approveTx)
  }

  const allowance = await tokenContract.allowance(
    rewardTresuryAdress,
    stakingAdress
  )

  console.log('allowance: ', allowance)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });