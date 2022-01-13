import { Staking } from "../typechain";
import { deployProxy } from "../helper/deployer";
import { TokenAddress, RewardTreasuryAddress, FeeCollectorAddress } from '../helper/address'

async function main() {
  const rewardToken = TokenAddress.matic;
  const lpToken = TokenAddress.matic;
  const rewardTreasury = RewardTreasuryAddress.matic;
  const feeCollector = FeeCollectorAddress.matic;

  const staking = <Staking>await deployProxy("Staking",
    rewardToken,
    lpToken,
    rewardTreasury,
    feeCollector,
    1200,
  );

  console.log("Staking Sale:", staking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });